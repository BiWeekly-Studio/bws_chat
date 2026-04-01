import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/chat_config.dart';
import '../models/message.dart';
import '../providers/chat_providers.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import 'chat_room_info_screen.dart';

// ---------------------------------------------------------------------------
// Chat Room Screen
// ---------------------------------------------------------------------------

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSendingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _inputFocus.dispose();
    _clearTypingStatus();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markAsRead();
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll / pagination
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messageLimitProvider(widget.roomId).notifier).loadMore();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  // ---------------------------------------------------------------------------
  // Read receipts
  // ---------------------------------------------------------------------------

  Future<void> _markAsRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;
    await ref.read(chatServiceProvider).markAsRead(
          roomId: widget.roomId,
          userId: userId,
        );
  }

  // ---------------------------------------------------------------------------
  // Typing indicator
  // ---------------------------------------------------------------------------

  void _onTextChanged(String text) {
    final config = ref.read(chatConfigProvider);
    if (!config.typingIndicatorsEnabled) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;

    if (!_isTyping) {
      _isTyping = true;
      ref.read(chatServiceProvider).updateTypingStatus(
            roomId: widget.roomId,
            userId: userId,
            isTyping: true,
          );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
      ref.read(chatServiceProvider).updateTypingStatus(
            roomId: widget.roomId,
            userId: userId,
            isTyping: false,
          );
    });
  }

  Future<void> _clearTypingStatus() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty || !_isTyping) return;
    _isTyping = false;
    await ref.read(chatServiceProvider).updateTypingStatus(
          roomId: widget.roomId,
          userId: userId,
          isTyping: false,
        );
  }

  // ---------------------------------------------------------------------------
  // Send text
  // ---------------------------------------------------------------------------

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;

    final room = ref
        .read(chatRoomsProvider)
        .value
        ?.firstWhere((r) => r.id == widget.roomId, orElse: () => throw StateError(''));

    _textController.clear();
    _typingTimer?.cancel();
    _isTyping = false;

    await ref.read(chatServiceProvider).updateTypingStatus(
          roomId: widget.roomId,
          userId: userId,
          isTyping: false,
        );

    await ref.read(chatServiceProvider).sendTextMessage(
          roomId: widget.roomId,
          senderId: userId,
          senderName: room?.participantProfiles[userId]?.displayName ?? userId,
          senderProfileUrl:
              room?.participantProfiles[userId]?.profileImageUrl,
          text: text,
        );

    _scrollToBottom();
    await _markAsRead();
  }

  // ---------------------------------------------------------------------------
  // Send image
  // ---------------------------------------------------------------------------

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;

    final room = ref
        .read(chatRoomsProvider)
        .value
        ?.firstWhere((r) => r.id == widget.roomId, orElse: () => throw StateError(''));

    setState(() => _isSendingImage = true);

    try {
      final uploaded = await ref.read(storageServiceProvider).uploadChatImage(
            roomId: widget.roomId,
            imageFile: File(picked.path),
          );

      await ref.read(chatServiceProvider).sendImageMessage(
            roomId: widget.roomId,
            senderId: userId,
            senderName:
                room?.participantProfiles[userId]?.displayName ?? userId,
            senderProfileUrl:
                room?.participantProfiles[userId]?.profileImageUrl,
            imageUrl: uploaded.imageUrl,
            thumbnailUrl: uploaded.thumbnailUrl,
          );

      _scrollToBottom();
      await _markAsRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(chatConfigProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final messagesAsync = ref.watch(paginatedMessagesProvider(widget.roomId));
    final roomsAsync = ref.watch(chatRoomsProvider);

    final room = roomsAsync.value?.where((r) => r.id == widget.roomId).firstOrNull;
    final participantCount = room?.participantIds.length ?? 0;

    // Auto-scroll when new messages arrive
    ref.listen(paginatedMessagesProvider(widget.roomId), (prev, next) {
      final prevLen = prev?.value?.length ?? 0;
      final nextLen = next.value?.length ?? 0;
      if (nextLen > prevLen) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        _markAsRead();
      }
    });

    return Scaffold(
      backgroundColor: config.backgroundColor,
      appBar: _buildAppBar(config, participantCount, currentUserId, room),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessageList(
                messages,
                currentUserId,
                config,
                room,
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('메시지를 불러오지 못했습니다\n$err',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
          _buildTypingIndicator(room, currentUserId, config),
          _buildInputBar(config),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(
    ChatConfig config,
    int participantCount,
    String currentUserId,
    dynamic room,
  ) {
    // Check if any participant (excluding current user) is online
    final otherId = room?.participantIds
        .where((id) => id != currentUserId)
        .firstOrNull;
    final otherOnlineAsync =
        otherId != null ? ref.watch(userPresenceProvider(otherId)) : null;
    final isOtherOnline = otherOnlineAsync?.value ?? false;
    final isGroup = (room?.participantIds.length ?? 0) > 2;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A1A1A), size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.roomName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (participantCount > 2) ...[
                const SizedBox(width: 4),
                Text(
                  '$participantCount',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
          if (!isGroup && isOtherOnline)
            const Text(
              '온라인',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => _openRoomInfo(room),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE5E5E5), height: 1),
      ),
    );
  }

  void _openRoomInfo(dynamic room) {
    if (room == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomInfoScreen(roomId: widget.roomId),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message list
  // ---------------------------------------------------------------------------

  Widget _buildMessageList(
    List<Message> messages,
    String currentUserId,
    ChatConfig config,
    dynamic room,
  ) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          '첫 번째 메시지를 보내보세요!',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      );
    }

    // Messages come in newest-first order from Firestore; we render them
    // bottom-to-top using reverse: true so index 0 is visually at the bottom.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final prevMsg = index + 1 < messages.length ? messages[index + 1] : null;
        final nextMsg = index > 0 ? messages[index - 1] : null;

        final showDateDivider = prevMsg == null ||
            ChatDateFormatter.isDifferentDay(msg.createdAt, prevMsg.createdAt);

        final isConsecutive = prevMsg != null &&
            prevMsg.senderId == msg.senderId &&
            !ChatDateFormatter.isDifferentDay(msg.createdAt, prevMsg.createdAt) &&
            msg.createdAt.difference(prevMsg.createdAt).inMinutes < 1;

        // Show time only on the last message in a consecutive group, or
        // if the next message is from a different sender/time
        final showTime = nextMsg == null ||
            nextMsg.senderId != msg.senderId ||
            ChatDateFormatter.isDifferentDay(msg.createdAt, nextMsg.createdAt) ||
            nextMsg.createdAt.difference(msg.createdAt).inMinutes >= 1;

        return Column(
          children: [
            if (showDateDivider) _DateDivider(dateTime: msg.createdAt),
            if (msg.type == MessageType.system)
              _SystemMessageBubble(message: msg)
            else if (msg.senderId == currentUserId)
              _SentMessageBubble(
                message: msg,
                config: config,
                showTime: showTime,
                participantCount: room?.participantIds.length ?? 1,
              )
            else
              _ReceivedMessageBubble(
                message: msg,
                config: config,
                showTime: showTime,
                showAvatar: !isConsecutive,
                showName: !isConsecutive &&
                    (room?.type?.name == 'group' ||
                        (room?.participantIds.length ?? 2) > 2),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Typing indicator
  // ---------------------------------------------------------------------------

  Widget _buildTypingIndicator(
      dynamic room, String currentUserId, ChatConfig config) {
    if (!config.typingIndicatorsEnabled || room == null) {
      return const SizedBox.shrink();
    }

    final typingNames = <String>[];

    for (final entry in (room.participantProfiles as Map).entries) {
      final uid = entry.key as String;
      if (uid == currentUserId) continue;
      final profile = entry.value;
      final isTyping = profile?.typing?[widget.roomId] as bool? ?? false;
      if (isTyping) typingNames.add(profile?.displayName as String? ?? uid);
    }

    if (typingNames.isEmpty) return const SizedBox.shrink();

    final label = typingNames.length == 1
        ? '${typingNames[0]}이(가) 입력 중...'
        : '상대방이 입력 중...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white,
      child: Row(
        children: [
          _TypingDots(color: config.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar
  // ---------------------------------------------------------------------------

  Widget _buildInputBar(ChatConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: config.inputBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image picker
          _isSendingImage
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.image_outlined,
                      color: Color(0xFF757575)),
                  onPressed: _pickAndSendImage,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
          const SizedBox(width: 4),
          // Text input
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocus,
                onChanged: _onTextChanged,
                maxLines: null,
                maxLength: ChatLimits.messagesPerPage * 10,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
                style: const TextStyle(fontSize: 15),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: '메시지 입력',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 15),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F2),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _sendText : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasText ? config.primaryColor : const Color(0xFFDDDDDD),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: hasText
                        ? _contrastColor(config.primaryColor)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _contrastColor(Color bg) {
    return bg.computeLuminance() > 0.4
        ? const Color(0xFF1A1A1A)
        : Colors.white;
  }
}

// ---------------------------------------------------------------------------
// Date divider
// ---------------------------------------------------------------------------

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFDDDDDD))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              ChatDateFormatter.formatDivider(dateTime),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFDDDDDD))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// System message bubble
// ---------------------------------------------------------------------------

class _SystemMessageBubble extends StatelessWidget {
  const _SystemMessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sent message bubble (right side, KakaoTalk yellow)
// ---------------------------------------------------------------------------

class _SentMessageBubble extends StatelessWidget {
  const _SentMessageBubble({
    required this.message,
    required this.config,
    required this.showTime,
    required this.participantCount,
  });

  final Message message;
  final ChatConfig config;
  final bool showTime;
  final int participantCount;

  @override
  Widget build(BuildContext context) {
    final unreadCount = participantCount - message.readBy.length;
    final displayUnread = unreadCount > 0 ? unreadCount : null;

    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 12, top: 2, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (displayUnread != null &&
                      config.readReceiptsEnabled)
                    Text(
                      '$displayUnread',
                      style: TextStyle(
                        fontSize: 11,
                        color: config.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    ChatDateFormatter.formatMessageTime(message.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          _buildBubbleContent(context),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    if (message.isDeleted) {
      return _textBubble('삭제된 메시지입니다.', deleted: true);
    }
    if (message.type == MessageType.image && message.imageUrl != null) {
      return _imageBubble(context);
    }
    return _textBubble(message.content);
  }

  Widget _textBubble(String text, {bool deleted = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: deleted
            ? const Color(0xFFDDDDDD)
            : config.bubbleColors.sent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: deleted
              ? const Color(0xFF9E9E9E)
              : config.bubbleColors.sentText,
          fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _imageBubble(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: CachedNetworkImage(
          imageUrl: message.imageThumbnailUrl ?? message.imageUrl!,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 200,
            height: 200,
            color: const Color(0xFFEEEEEE),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 200,
            height: 200,
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.broken_image_outlined, size: 40),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenImageScreen(imageUrl: message.imageUrl!),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Received message bubble (left side, white)
// ---------------------------------------------------------------------------

class _ReceivedMessageBubble extends StatelessWidget {
  const _ReceivedMessageBubble({
    required this.message,
    required this.config,
    required this.showTime,
    required this.showAvatar,
    required this.showName,
  });

  final Message message;
  final ChatConfig config;
  final bool showTime;
  final bool showAvatar;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 60, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar column: either avatar or spacer
          SizedBox(
            width: 36,
            child: showAvatar
                ? _ProfileAvatar(
                    url: message.senderProfileUrl,
                    label: message.senderName,
                    size: 36,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // Bubble + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBubbleContent(context),
                  if (showTime)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        ChatDateFormatter.formatMessageTime(message.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    if (message.isDeleted) {
      return _textBubble('삭제된 메시지입니다.', deleted: true);
    }
    if (message.type == MessageType.image && message.imageUrl != null) {
      return _imageBubble(context);
    }
    return _textBubble(message.content);
  }

  Widget _textBubble(String text, {bool deleted = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: deleted ? const Color(0xFFDDDDDD) : config.bubbleColors.received,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: deleted
              ? const Color(0xFF9E9E9E)
              : config.bubbleColors.receivedText,
          fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _imageBubble(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullscreenImageScreen(imageUrl: message.imageUrl!),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: CachedNetworkImage(
          imageUrl: message.imageThumbnailUrl ?? message.imageUrl!,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 200,
            height: 200,
            color: const Color(0xFFEEEEEE),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 200,
            height: 200,
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.broken_image_outlined, size: 40),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile avatar
// ---------------------------------------------------------------------------

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.url,
    required this.label,
    required this.size,
  });

  final String? url;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback(),
          placeholder: (_, __) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    const colors = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFEC407A),
      Color(0xFFFF7043),
      Color(0xFF8D6E63),
      Color(0xFF42A5F5),
    ];
    final color =
        label.isEmpty ? colors[0] : colors[label.codeUnitAt(0) % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing animation dots
// ---------------------------------------------------------------------------

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2))
                .clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Fullscreen image viewer
// ---------------------------------------------------------------------------

class _FullscreenImageScreen extends StatelessWidget {
  const _FullscreenImageScreen({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
