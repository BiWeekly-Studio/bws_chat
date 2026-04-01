import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/chat_config.dart';
import '../models/chat_room.dart';
import '../providers/chat_providers.dart';
import '../utils/date_formatter.dart';
import 'chat_room_screen.dart';

// ---------------------------------------------------------------------------
// Chat List Screen
// ---------------------------------------------------------------------------

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(chatConfigProvider);
    final roomsAsync = ref.watch(chatRoomsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: config.backgroundColor,
      appBar: _buildAppBar(config),
      body: Column(
        children: [
          _buildSearchBar(config),
          Expanded(
            child: roomsAsync.when(
              data: (rooms) {
                final filtered = _filterRooms(rooms, currentUserId);
                if (filtered.isEmpty) return _buildEmptyState(config);
                return _buildRoomList(filtered, currentUserId, config);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildErrorState(err),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onNewChatPressed(context),
        backgroundColor: config.primaryColor,
        foregroundColor: _contrastColor(config.primaryColor),
        child: const Icon(Icons.edit_outlined),
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
      centerTitle: false,
      title: const Text(
        '채팅',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF1A1A1A)),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE5E5E5), height: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(ChatConfig config) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: '채팅방 검색',
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.clear, color: Color(0xFF9E9E9E), size: 18),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Room list
  // ---------------------------------------------------------------------------

  List<ChatRoom> _filterRooms(List<ChatRoom> rooms, String currentUserId) {
    if (_searchQuery.isEmpty) return rooms;
    final q = _searchQuery.toLowerCase();
    return rooms.where((room) {
      final name = room.displayName(currentUserId).toLowerCase();
      final last = (room.lastMessage ?? '').toLowerCase();
      return name.contains(q) || last.contains(q);
    }).toList();
  }

  Widget _buildRoomList(
    List<ChatRoom> rooms,
    String currentUserId,
    ChatConfig config,
  ) {
    return RefreshIndicator(
      color: config.primaryColor,
      onRefresh: () async {
        ref.invalidate(chatRoomsProvider);
        // Allow the stream to re-emit.
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 76,
          endIndent: 0,
          color: Color(0xFFEEEEEE),
        ),
        itemBuilder: (context, index) {
          final room = rooms[index];
          return _ChatRoomTile(
            room: room,
            currentUserId: currentUserId,
            config: config,
            onTap: () => _openRoom(context, room, currentUserId),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty / error states
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(ChatConfig config) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 72,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '아직 채팅방이 없어요' : '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '오른쪽 아래 버튼을 눌러 대화를 시작해보세요',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('채팅방을 불러오지 못했습니다', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(chatRoomsProvider),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openRoom(BuildContext context, ChatRoom room, String currentUserId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: room.id,
          roomName: room.displayName(currentUserId),
        ),
      ),
    );
  }

  void _onNewChatPressed(BuildContext context) {
    // Host app can overlay its own user-picker on top of this callback by
    // wrapping ChatListScreen and overriding this navigation.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('새 채팅 시작 기능을 연결해 주세요')),
    );
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.4 ? const Color(0xFF1A1A1A) : Colors.white;
  }
}

// ---------------------------------------------------------------------------
// ChatRoomTile
// ---------------------------------------------------------------------------

class _ChatRoomTile extends ConsumerWidget {
  const _ChatRoomTile({
    required this.room,
    required this.currentUserId,
    required this.config,
    required this.onTap,
  });

  final ChatRoom room;
  final String currentUserId;
  final ChatConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = room.unreadCount[currentUserId] ?? 0;
    final lastTime = room.lastMessageTime;
    final isGroup = room.type == ChatRoomType.group;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _RoomAvatar(
              room: room,
              currentUserId: currentUserId,
              isGroup: isGroup,
              size: 52,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.displayName(currentUserId),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isGroup)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${room.participantIds.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (lastTime != null)
                        Text(
                          ChatDateFormatter.formatRoomListTime(lastTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.lastMessage ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: unread, config: config),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room avatar (supports group: stacked thumbnails)
// ---------------------------------------------------------------------------

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({
    required this.room,
    required this.currentUserId,
    required this.isGroup,
    required this.size,
  });

  final ChatRoom room;
  final String currentUserId;
  final bool isGroup;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isGroup) {
      // Single profile image
      final url = room.displayImageUrl(currentUserId);
      return _CircleAvatar(url: url, size: size, label: room.displayName(currentUserId));
    }

    // Group: show up to 4 thumbnails in a 2x2 grid
    final otherIds = room.participantIds.where((id) => id != currentUserId).toList();
    final displayIds = otherIds.take(4).toList();

    if (displayIds.length == 1) {
      final url = room.participantProfiles[displayIds[0]]?.profileImageUrl;
      return _CircleAvatar(
        url: url,
        size: size,
        label: room.participantProfiles[displayIds[0]]?.displayName ?? '',
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _GroupAvatarGrid(
          ids: displayIds,
          profiles: room.participantProfiles,
          cellSize: size / 2,
        ),
      ),
    );
  }
}

class _GroupAvatarGrid extends StatelessWidget {
  const _GroupAvatarGrid({
    required this.ids,
    required this.profiles,
    required this.cellSize,
  });

  final List<String> ids;
  final Map<String, dynamic> profiles;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final cells = ids.take(4).toList();
    final rows = <Widget>[];

    for (var r = 0; r < 2; r++) {
      final cols = <Widget>[];
      for (var c = 0; c < 2; c++) {
        final idx = r * 2 + c;
        if (idx < cells.length) {
          final profile = profiles[cells[idx]];
          final url = profile?.profileImageUrl as String?;
          final label = (profile?.displayName as String?) ?? '';
          cols.add(_MiniAvatar(url: url, label: label, size: cellSize));
        } else {
          cols.add(SizedBox(width: cellSize, height: cellSize));
        }
      }
      rows.add(Row(mainAxisSize: MainAxisSize.min, children: cols));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.url, required this.label, required this.size});

  final String? url;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _fallback(),
        placeholder: (_, __) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initials = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: _colorFor(label),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _colorFor(String s) {
    final colors = [
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
      const Color(0xFFEC407A),
      const Color(0xFFFF7043),
      const Color(0xFF8D6E63),
      const Color(0xFF42A5F5),
    ];
    if (s.isEmpty) return colors[0];
    return colors[s.codeUnitAt(0) % colors.length];
  }
}

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({required this.url, required this.size, required this.label});

  final String? url;
  final double size;
  final String label;

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
    final initials = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colorFor(label),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _colorFor(String s) {
    const colors = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFEC407A),
      Color(0xFFFF7043),
      Color(0xFF8D6E63),
      Color(0xFF42A5F5),
    ];
    if (s.isEmpty) return colors[0];
    return colors[s.codeUnitAt(0) % colors.length];
  }
}

// ---------------------------------------------------------------------------
// Unread badge
// ---------------------------------------------------------------------------

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.config});

  final int count;
  final ChatConfig config;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '999+' : '$count';
    final wide = count > 99;
    return Container(
      constraints: BoxConstraints(minWidth: wide ? 36 : 20, minHeight: 20),
      padding: EdgeInsets.symmetric(horizontal: wide ? 6 : 4),
      decoration: BoxDecoration(
        color: config.unreadBadgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: config.unreadBadgeTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

