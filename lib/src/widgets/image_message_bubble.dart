import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/chat_config.dart';
import '../models/message.dart';
import '../utils/date_formatter.dart';
import 'full_screen_image.dart';

// ---------------------------------------------------------------------------
// ImageMessageBubble
//
// Renders an image message using cached_network_image.
// Mirrors the left/right alignment logic from MessageBubble but is dedicated
// to image-type messages so thumbnails and hero tags are handled cleanly.
//
// Tapping the thumbnail pushes FullScreenImage with a hero animation.
// ---------------------------------------------------------------------------

class ImageMessageBubble extends StatelessWidget {
  const ImageMessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.config,
    this.participantCount = 1,
    this.showAvatar = true,
    this.showName = false,
    this.showTime = true,
    this.thumbnailSize = 200,
  });

  final Message message;
  final String currentUserId;
  final ChatConfig config;
  final int participantCount;
  final bool showAvatar;
  final bool showName;
  final bool showTime;

  /// Width and height of the inline thumbnail (square).
  final double thumbnailSize;

  bool get _isSent => message.senderId == currentUserId;

  String get _heroTag => 'img_bubble_${message.id}';

  BorderRadius get _sentRadius => const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(18),
      );

  BorderRadius get _receivedRadius => const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(18),
      );

  @override
  Widget build(BuildContext context) {
    if (_isSent) return _buildSent(context);
    return _buildReceived(context);
  }

  // ---------------------------------------------------------------------------
  // Sent layout
  // ---------------------------------------------------------------------------

  Widget _buildSent(BuildContext context) {
    final unreadCount = participantCount - message.readBy.length;
    final showUnread = config.readReceiptsEnabled && unreadCount > 0;

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
                  if (showUnread)
                    Text(
                      '$unreadCount',
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
          _thumbnail(context, radius: _sentRadius),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Received layout
  // ---------------------------------------------------------------------------

  Widget _buildReceived(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 60, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
                  _thumbnail(context, radius: _receivedRadius),
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

  // ---------------------------------------------------------------------------
  // Thumbnail widget shared between sent/received
  // ---------------------------------------------------------------------------

  Widget _thumbnail(BuildContext context, {required BorderRadius radius}) {
    final thumbUrl = message.imageThumbnailUrl ?? message.imageUrl;
    if (thumbUrl == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: message.imageUrl != null
          ? () => _openFullscreen(context, message.imageUrl!)
          : null,
      child: Hero(
        tag: _heroTag,
        child: ClipRRect(
          borderRadius: radius,
          child: CachedNetworkImage(
            imageUrl: thumbUrl,
            width: thumbnailSize,
            height: thumbnailSize,
            fit: BoxFit.cover,
            placeholder: (context, url) => _loadingPlaceholder(),
            errorWidget: (context, url, error) => _errorPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      width: thumbnailSize,
      height: thumbnailSize,
      color: const Color(0xFFEEEEEE),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      width: thumbnailSize,
      height: thumbnailSize,
      color: const Color(0xFFEEEEEE),
      child: const Icon(Icons.broken_image_outlined, size: 40),
    );
  }

  void _openFullscreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          imageUrl: imageUrl,
          heroTag: _heroTag,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal profile avatar (cached)
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

  Color get _color {
    if (label.isEmpty) return _colors[0];
    return _colors[label.codeUnitAt(0) % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
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
