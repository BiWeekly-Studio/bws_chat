import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// FullScreenImage
//
// Full-screen image viewer with:
//   • Hero animation from the chat thumbnail (heroTag must match the tag used
//     on the GestureDetector/Hero in the chat list)
//   • Pinch-to-zoom via InteractiveViewer
//   • Black background
//   • Close button (back navigation)
//   • Share / save action buttons in the app bar actions
// ---------------------------------------------------------------------------

class FullScreenImage extends StatefulWidget {
  const FullScreenImage({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.onShare,
    this.onSave,
  });

  /// URL of the full-resolution image.
  final String imageUrl;

  /// Optional hero tag – must match the tag used on the source thumbnail Hero.
  final String? heroTag;

  /// Optional callback for the share action. If null the share button is hidden.
  final VoidCallback? onShare;

  /// Optional callback for the save action. If null the save button is hidden.
  final VoidCallback? onSave;

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  bool _showControls = true;

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    // Force dark system UI while viewing
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: _showControls ? _buildAppBar(context) : null,
        body: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              clipBehavior: Clip.none,
              child: widget.heroTag != null
                  ? Hero(
                      tag: widget.heroTag!,
                      child: _image(),
                    )
                  : _image(),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: '닫기',
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (widget.onSave != null)
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: '저장',
            onPressed: widget.onSave,
          ),
        if (widget.onShare != null)
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: '공유',
            onPressed: widget.onShare,
          ),
      ],
    );
  }

  Widget _image() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
