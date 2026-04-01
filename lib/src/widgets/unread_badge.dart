import 'package:flutter/material.dart';

import '../config/chat_config.dart';

// ---------------------------------------------------------------------------
// UnreadBadge
//
// Red pill/circle showing the unread message count.
//   •  1–9   → small circle (20 px diameter)
//   • 10–99  → wider pill
//   • 100–999 → wider pill
//   • 1000+  → "999+"
//
// Animates in with a scale + fade when count goes from 0 → non-zero.
// ---------------------------------------------------------------------------

class UnreadBadge extends StatefulWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    required this.config,
  });

  final int count;
  final ChatConfig config;

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    if (widget.count > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(UnreadBadge old) {
    super.didUpdateWidget(old);
    if (old.count == 0 && widget.count > 0) {
      _controller.forward(from: 0);
    } else if (widget.count == 0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();

    final label = widget.count > 999 ? '999+' : '${widget.count}';
    final isWide = widget.count > 9;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          constraints: BoxConstraints(
            minWidth: isWide ? 26 : 20,
            minHeight: 20,
          ),
          padding: EdgeInsets.symmetric(horizontal: isWide ? 6 : 4),
          decoration: BoxDecoration(
            color: widget.config.unreadBadgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: widget.config.unreadBadgeTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
