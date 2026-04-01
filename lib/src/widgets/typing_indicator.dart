import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// TypingIndicator
//
// Shows three bouncing dots with a label ("상대방이 입력중...").
// Designed to sit in the chat room above the input bar, matching the
// in-screen implementation in chat_room_screen.dart but as a reusable widget.
// ---------------------------------------------------------------------------

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    super.key,
    this.label = '상대방이 입력중...',
    this.dotColor = const Color(0xFF4F86F7),
    this.backgroundColor = Colors.white,
  });

  /// Text shown beside the animated dots.
  final String label;

  /// Colour of the three bouncing dots (defaults to the package primary blue).
  final Color dotColor;

  /// Background colour of the indicator row.
  final Color backgroundColor;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: widget.backgroundColor,
      child: Row(
        children: [
          _BouncingDots(controller: _controller, color: widget.dotColor),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Three bouncing dots driven by a shared AnimationController
// ---------------------------------------------------------------------------

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({
    required this.controller,
    required this.color,
  });

  final Animation<double> controller;
  final Color color;

  static const double _dotSize = 6;
  static const double _maxBounce = 4;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 1/3 of the cycle
            final phase = (controller.value - i / 3) % 1.0;
            // Bounce: up in first half, down in second half
            final bounce =
                _maxBounce * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -bounce),
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: color,
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
