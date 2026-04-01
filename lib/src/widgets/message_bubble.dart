import 'package:flutter/material.dart';

import '../config/chat_config.dart';
import '../models/message.dart';
import '../utils/date_formatter.dart';

// ---------------------------------------------------------------------------
// Public MessageBubble widget
//
// Renders a single chat message in KakaoTalk style:
//   • Sent     – right-aligned, yellow bubble, no avatar
//   • Received – left-aligned, white bubble, optional avatar + name
//   • System   – centred, pill-shaped, gray
// ---------------------------------------------------------------------------

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.config,
    this.participantCount = 1,
    this.showAvatar = true,
    this.showName = false,
    this.showTime = true,
  });

  final Message message;
  final String currentUserId;
  final ChatConfig config;

  /// Total number of people in the room (used to compute unread count).
  final int participantCount;

  /// Whether to show the sender's profile image (received messages only).
  final bool showAvatar;

  /// Whether to show the sender's display name (group chat received messages).
  final bool showName;

  /// Whether to show the timestamp next to this bubble.
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return _SystemBubble(message: message);
    }
    if (message.senderId == currentUserId) {
      return _SentBubble(
        message: message,
        config: config,
        participantCount: participantCount,
        showTime: showTime,
      );
    }
    return _ReceivedBubble(
      message: message,
      config: config,
      showAvatar: showAvatar,
      showName: showName,
      showTime: showTime,
    );
  }
}

// ---------------------------------------------------------------------------
// System message
// ---------------------------------------------------------------------------

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.message});

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
// Sent bubble (right-aligned, KakaoTalk yellow)
// ---------------------------------------------------------------------------

class _SentBubble extends StatelessWidget {
  const _SentBubble({
    required this.message,
    required this.config,
    required this.participantCount,
    required this.showTime,
  });

  final Message message;
  final ChatConfig config;
  final int participantCount;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final unreadCount = participantCount - message.readBy.length;
    final displayUnread = (config.readReceiptsEnabled && unreadCount > 0)
        ? unreadCount
        : null;

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
                  if (displayUnread != null)
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
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isDeleted) return _textBubble('삭제된 메시지입니다.', deleted: true);
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
      child: SelectableText(
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
      child: Hero(
        tag: 'chat_image_${message.id}',
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          child: _NetworkThumbnail(
            url: message.imageThumbnailUrl ?? message.imageUrl!,
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenImagePage(
          imageUrl: message.imageUrl!,
          heroTag: 'chat_image_${message.id}',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Received bubble (left-aligned, white)
// ---------------------------------------------------------------------------

class _ReceivedBubble extends StatelessWidget {
  const _ReceivedBubble({
    required this.message,
    required this.config,
    required this.showAvatar,
    required this.showName,
    required this.showTime,
  });

  final Message message;
  final ChatConfig config;
  final bool showAvatar;
  final bool showName;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 60, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar or spacer
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
          // Content column
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
                  _buildContent(context),
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

  Widget _buildContent(BuildContext context) {
    if (message.isDeleted) return _textBubble('삭제된 메시지입니다.', deleted: true);
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
      child: SelectableText(
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
          builder: (_) => _FullscreenImagePage(
            imageUrl: message.imageUrl!,
            heroTag: 'chat_image_${message.id}',
          ),
        ),
      ),
      child: Hero(
        tag: 'chat_image_${message.id}',
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          child: _NetworkThumbnail(
            url: message.imageThumbnailUrl ?? message.imageUrl!,
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
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

  static const _colors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEC407A),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
    Color(0xFF42A5F5),
  ];

  Color get _fallbackColor {
    if (label.isEmpty) return _colors[0];
    return _colors[label.codeUnitAt(0) % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _fallbackColor, shape: BoxShape.circle),
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

    if (url == null || url!.isEmpty) return fallback;

    // Use Image.network via ClipOval; cached_network_image would be used if
    // this widget were in a context with it imported, but we keep imports
    // minimal here. Callers who need caching can use ImageMessageBubble directly.
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, url, e) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

class _NetworkThumbnail extends StatelessWidget {
  const _NetworkThumbnail({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, url, error) => Container(
        width: width,
        height: height,
        color: const Color(0xFFEEEEEE),
        child: const Icon(Icons.broken_image_outlined, size: 40),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFEEEEEE),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

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
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, url, error) => const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 64,
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
