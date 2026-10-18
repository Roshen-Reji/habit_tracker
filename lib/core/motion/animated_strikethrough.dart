import 'package:flutter/material.dart';
import 'motion_tokens.dart';

/// Animated strikethrough text widget that sweeps a crisp physical line
/// across the text from 0% to 100% width over 240ms on completion.
///
/// Adheres strictly to Section 3.3 of AGENTS.md.
class AnimatedStrikethroughText extends StatelessWidget {
  final String text;
  final bool isDone;
  final TextStyle style;
  final Color strikeColor;
  final double strokeWidth;
  final Duration duration;
  final Curve curve;

  const AnimatedStrikethroughText({
    super.key,
    required this.text,
    required this.isDone,
    required this.style,
    this.strikeColor = const Color(0xFF84CC16), // Lime accent
    this.strokeWidth = 1.8,
    this.duration = const Duration(milliseconds: 240),
    this.curve = MotionTokens.fastOutExtraSlowIn,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: isDone ? 1.0 : 0.0, end: isDone ? 1.0 : 0.0),
      duration: duration,
      curve: curve,
      builder: (context, progress, child) {
        return CustomPaint(
          foregroundPainter: progress > 0
              ? _StrikethroughPainter(
                  progress: progress,
                  color: strikeColor,
                  strokeWidth: strokeWidth,
                )
              : null,
          child: child,
        );
      },
      child: Text(
        text,
        style: style.copyWith(
          color: isDone ? (style.color?.withValues(alpha: 0.55) ?? Colors.white54) : style.color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StrikethroughPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _StrikethroughPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.54;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * progress, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StrikethroughPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
