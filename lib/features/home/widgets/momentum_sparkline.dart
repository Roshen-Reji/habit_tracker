import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:intl/intl.dart';

/// Smooth cubic-bezier sparkline with gradient fill and glowing current-day node (AGENTS.md Phase 3.1).
class MomentumSparkline extends StatelessWidget {
  final List<int> values;
  final double height;
  final Color? lineColor;
  final Color? fillColor;
  final bool showLabels;

  const MomentumSparkline({
    super.key,
    required this.values,
    this.height = 110.0,
    this.lineColor,
    this.fillColor,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(height: height);
    }

    final strokeColor = lineColor ?? TactileTokens.vermilion;
    final areaColor = fillColor ?? TactileTokens.vermilion;

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: values,
                lineColor: strokeColor,
                fillColor: areaColor,
              ),
            ),
          ),
          if (showLabels) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(values.length, (index) {
                final isToday = index == values.length - 1;
                final date =
                    DateTime.now().subtract(Duration(days: values.length - 1 - index));
                final label = isToday
                    ? 'NOW'
                    : DateFormat('EE').format(date).toUpperCase();

                return Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? TactileTokens.textPrimary
                        : TactileTokens.textMuted,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color lineColor;
  final Color fillColor;

  const _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxVal = math.max(1, values.reduce(math.max)).toDouble();
    final minVal = 0.0;
    final range = maxVal - minVal;

    final dx = size.width / (values.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final normY = (values[i] - minVal) / range;
      // Invert Y and leave padding for the glowing node
      final y = size.height - (normY * (size.height - 20.0)) - 10.0;
      points.add(Offset(i * dx, y));
    }

    // Build smooth cubic bezier curve
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2.0;

      path.cubicTo(
        controlX,
        p0.dy,
        controlX,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Draw Gradient Area under the curve
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          fillColor.withValues(alpha: 0.32),
          fillColor.withValues(alpha: 0.0),
        ],
      );

    canvas.drawPath(fillPath, fillPaint);

    // Draw Sparkline Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Draw Subtle Grid Pips / Dots for past days
    final pipPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawCircle(points[i], 2.2, pipPaint);
    }

    // Glowing Current-Day Node on the last point
    final lastPoint = points.last;

    // Outer glow halo
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(lastPoint, 8, glowPaint);

    // Mid halo ring
    final ringPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(lastPoint, 5, ringPaint);

    // White core dot
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 3.2, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}
