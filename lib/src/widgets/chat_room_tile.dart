import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/chat_config.dart';
import '../models/chat_room.dart';
import '../utils/date_formatter.dart';
import 'unread_badge.dart';

// ---------------------------------------------------------------------------
// ChatRoomTile
//
// List tile for the chat room list screen. Renders:
//   • Circular profile image for 1:1 rooms, 2×2 grid for group rooms
//   • Room name (bold) + participant count for groups
//   • Last message preview (truncated, gray)
//   • Last message timestamp (right side)
//   • Animated unread count badge
// ---------------------------------------------------------------------------

class ChatRoomTile extends StatelessWidget {
  const ChatRoomTile({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.config,
    required this.onTap,
  });

  final ChatRoom room;
  final String currentUserId;
  final ChatConfig config;
  final VoidCallback onTap;

  static const double _avatarSize = 52;

  @override
  Widget build(BuildContext context) {
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
              size: _avatarSize,
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                room.displayName(currentUserId),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isGroup) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${room.participantIds.length}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (lastTime != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          ChatDateFormatter.formatRoomListTime(lastTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
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
                        UnreadBadge(count: unread, config: config),
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
// Room avatar – single circle or 2×2 group grid
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
      final url = room.displayImageUrl(currentUserId);
      return _CircleAvatar(
        url: url,
        size: size,
        label: room.displayName(currentUserId),
      );
    }

    // Group: up to 4 thumbnails from other participants
    final otherIds =
        room.participantIds.where((id) => id != currentUserId).toList();
    final displayIds = otherIds.take(4).toList();

    if (displayIds.length == 1) {
      final url =
          room.participantProfiles[displayIds[0]]?.profileImageUrl;
      return _CircleAvatar(
        url: url,
        size: size,
        label:
            room.participantProfiles[displayIds[0]]?.displayName ?? '',
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
  const _MiniAvatar({
    required this.url,
    required this.label,
    required this.size,
  });

  final String? url;
  final String label;
  final double size;

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

  @override
  Widget build(BuildContext context) {
    final initials = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final fallback = Container(
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

    if (url == null || url!.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({
    required this.url,
    required this.size,
    required this.label,
  });

  final String? url;
  final double size;
  final String label;

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

  @override
  Widget build(BuildContext context) {
    final initials = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final fallback = Container(
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

    if (url == null || url!.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
