import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/chat_config.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../providers/chat_providers.dart';
import '../utils/date_formatter.dart';

// ---------------------------------------------------------------------------
// Chat Room Info Screen
// ---------------------------------------------------------------------------

class ChatRoomInfoScreen extends ConsumerStatefulWidget {
  const ChatRoomInfoScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ChatRoomInfoScreen> createState() => _ChatRoomInfoScreenState();
}

class _ChatRoomInfoScreenState extends ConsumerState<ChatRoomInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Message> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(chatConfigProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final roomsAsync = ref.watch(chatRoomsProvider);

    final _matchedRooms = roomsAsync.value?.where((r) => r.id == widget.roomId).toList();
    final room = (_matchedRooms != null && _matchedRooms.isNotEmpty) ? _matchedRooms.first : null;

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('채팅방 정보')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isGroup = room.type == ChatRoomType.group;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(config),
      body: Column(
        children: [
          Expanded(
            child: isGroup
                ? _buildGroupLayout(room, currentUserId, config)
                : _buildOneToOneLayout(room, currentUserId, config),
          ),
          _buildLeaveButton(context, room, currentUserId, config),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(ChatConfig config) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A1A1A), size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        '채팅방 정보',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE5E5E5), height: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // One-to-one layout
  // ---------------------------------------------------------------------------

  Widget _buildOneToOneLayout(
      ChatRoom room, String currentUserId, ChatConfig config) {
    final _otherIds = room.participantIds.where((id) => id != currentUserId).toList();
    final otherId = _otherIds.isNotEmpty ? _otherIds.first : null;
    final other = otherId != null ? room.participantProfiles[otherId] : null;
    final isOnlineAsync = otherId != null
        ? ref.watch(userPresenceProvider(otherId))
        : null;
    final isOnline = isOnlineAsync?.valueOrNull ?? other?.isOnline ?? false;

    return ListView(
      children: [
        const SizedBox(height: 24),
        _buildRoomHeader(
          name: room.displayName(currentUserId),
          imageUrl: room.displayImageUrl(currentUserId),
          subtitle: isOnline
              ? '온라인'
              : other?.lastSeen != null
                  ? '마지막 접속: ${ChatDateFormatter.formatLastSeen(other!.lastSeen!)}'
                  : null,
          subtitleColor: isOnline
              ? config.onlineIndicatorColor
              : const Color(0xFF9E9E9E),
        ),
        const SizedBox(height: 16),
        _buildSearchSection(config),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Group layout
  // ---------------------------------------------------------------------------

  Widget _buildGroupLayout(
      ChatRoom room, String currentUserId, ChatConfig config) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildRoomHeader(
                name: room.displayName(currentUserId),
                imageUrl: room.imageUrl,
                subtitle: '${room.participantIds.length}명',
                subtitleColor: const Color(0xFF9E9E9E),
              ),
              const SizedBox(height: 20),
              _buildTabBar(config),
            ],
          ),
        ),
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildParticipantList(room, currentUserId, config),
              _buildSearchSection(config),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Room header (avatar + name + subtitle)
  // ---------------------------------------------------------------------------

  Widget _buildRoomHeader({
    required String name,
    String? imageUrl,
    String? subtitle,
    Color subtitleColor = const Color(0xFF9E9E9E),
  }) {
    return Column(
      children: [
        _RoomHeaderAvatar(url: imageUrl, label: name, size: 80),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: subtitleColor),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bar (group only)
  // ---------------------------------------------------------------------------

  Widget _buildTabBar(ChatConfig config) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: config.primaryColor,
        unselectedLabelColor: const Color(0xFF9E9E9E),
        indicatorColor: config.primaryColor,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: '참여자'),
          Tab(text: '메시지 검색'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Participant list
  // ---------------------------------------------------------------------------

  Widget _buildParticipantList(
      ChatRoom room, String currentUserId, ChatConfig config) {
    final participants = room.participantIds.map((id) {
      return room.participantProfiles[id] ??
          ChatUser(uid: id, displayName: id);
    }).toList();

    // Sort: current user first, then alphabetical
    participants.sort((a, b) {
      if (a.uid == currentUserId) return -1;
      if (b.uid == currentUserId) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: participants.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 70, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final user = participants[index];
        return _ParticipantTile(
          user: user,
          isCurrentUser: user.uid == currentUserId,
          config: config,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Search section
  // ---------------------------------------------------------------------------

  Widget _buildSearchSection(ChatConfig config) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '메시지 내용 검색',
                    hintStyle: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 15),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF9E9E9E), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _searchResults = [];
                              });
                            },
                            child: const Icon(Icons.clear,
                                color: Color(0xFF9E9E9E), size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _searchQuery.isNotEmpty ? _runSearch : null,
                style: TextButton.styleFrom(
                  foregroundColor: config.primaryColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                child: const Text('검색',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )
        else if (_searchResults.isNotEmpty)
          ..._searchResults.map((msg) => _SearchResultTile(message: msg))
        else if (_searchQuery.isNotEmpty && !_isSearching)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('검색 결과가 없습니다',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14)),
          ),
      ],
    );
  }

  Future<void> _runSearch() async {
    if (_searchQuery.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(chatServiceProvider).searchMessages(
            roomId: widget.roomId,
            query: _searchQuery.trim(),
          );
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 중 오류가 발생했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Leave button
  // ---------------------------------------------------------------------------

  Widget _buildLeaveButton(
      BuildContext context, ChatRoom room, String currentUserId, ChatConfig config) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmLeave(context, room, currentUserId),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE53935),
            side: const BorderSide(color: Color(0xFFE53935)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.exit_to_app_rounded, size: 18),
          label: const Text(
            '채팅방 나가기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave(
      BuildContext context, ChatRoom room, String currentUserId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('정말 채팅방에서 나가시겠습니까?\n나간 후에는 대화 내용을 볼 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF757575))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('나가기',
                style: TextStyle(
                    color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(chatServiceProvider).leaveRoom(
            roomId: widget.roomId,
            userId: currentUserId,
          );
      if (mounted) {
        // Pop both info screen and room screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅방 나가기 실패: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Room header avatar
// ---------------------------------------------------------------------------

class _RoomHeaderAvatar extends StatelessWidget {
  const _RoomHeaderAvatar({
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
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Participant tile
// ---------------------------------------------------------------------------

class _ParticipantTile extends ConsumerWidget {
  const _ParticipantTile({
    required this.user,
    required this.isCurrentUser,
    required this.config,
  });

  final ChatUser user;
  final bool isCurrentUser;
  final ChatConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(userPresenceProvider(user.uid));
    final isOnline = presenceAsync.valueOrNull ?? user.isOnline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Stack(
            children: [
              _RoomHeaderAvatar(
                url: user.profileImageUrl,
                label: user.displayName,
                size: 44,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: config.onlineIndicatorColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '나',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? '온라인'
                      : user.lastSeen != null
                          ? ChatDateFormatter.formatLastSeen(user.lastSeen!)
                          : '오프라인',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline
                        ? config.onlineIndicatorColor
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search result tile
// ---------------------------------------------------------------------------

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF555555),
                ),
              ),
              const Spacer(),
              Text(
                ChatDateFormatter.formatMessageTime(message.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.isDeleted ? '삭제된 메시지입니다.' : message.content,
            style: TextStyle(
              fontSize: 14,
              color: message.isDeleted
                  ? const Color(0xFF9E9E9E)
                  : const Color(0xFF1A1A1A),
              fontStyle:
                  message.isDeleted ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }
}
