import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/animated_metric_ticker.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';

/// Concentric rings widget for the Biometric Instrument Cluster.
/// Renders 3 concentric circular arcs:
/// - Outer: Steps (Cyan Telemetry)
/// - Middle: Sleep (Violet Ink)
/// - Inner: Energy Score (Crimson Pulse)
class ConcentricBiometricRings extends StatelessWidget {
  final double stepsProgress; // 0.0 to 1.0+
  final double sleepProgress; // 0.0 to 1.0
  final double energyProgress; // 0.0 to 1.0
  final double size;

  const ConcentricBiometricRings({
    super.key,
    required this.stepsProgress,
    required this.sleepProgress,
    required this.energyProgress,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ConcentricRingsPainter(
            stepsProgress: stepsProgress.clamp(0.0, 1.5),
            sleepProgress: sleepProgress.clamp(0.0, 1.0),
            energyProgress: energyProgress.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  final double stepsProgress;
  final double sleepProgress;
  final double energyProgress;

  _ConcentricRingsPainter({
    required this.stepsProgress,
    required this.sleepProgress,
    required this.energyProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.082;
    final ringSpacing = strokeWidth * 1.35;

    final outerRadius = (size.width / 2) - (strokeWidth / 2);
    final middleRadius = outerRadius - ringSpacing;
    final innerRadius = middleRadius - ringSpacing;

    // Outer: Steps (Cyan Telemetry)
    _drawRing(
      canvas: canvas,
      center: center,
      radius: outerRadius,
      progress: stepsProgress,
      color: TactileTokens.accentCyan,
      strokeWidth: strokeWidth,
    );

    // Middle: Sleep (Violet Ink)
    _drawRing(
      canvas: canvas,
      center: center,
      radius: middleRadius,
      progress: sleepProgress,
      color: TactileTokens.accentViolet,
      strokeWidth: strokeWidth,
    );

    // Inner: Energy (Crimson Pulse)
    _drawRing(
      canvas: canvas,
      center: center,
      radius: innerRadius,
      progress: energyProgress,
      color: TactileTokens.accentPulse,
      strokeWidth: strokeWidth,
    );
  }

  void _drawRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double progress,
    required Color color,
    required double strokeWidth,
  }) {
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final sweepAngle = (progress * 2 * math.pi).clamp(0.0, 2 * math.pi);
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) {
    return oldDelegate.stepsProgress != stepsProgress ||
        oldDelegate.sleepProgress != sleepProgress ||
        oldDelegate.energyProgress != energyProgress;
  }
}

/// Live sync status pill with glowing telemetry indicator dot.
class BiometricSyncPill extends StatelessWidget {
  final bool isConnected;
  final String label;

  const BiometricSyncPill({
    super.key,
    required this.isConnected,
    this.label = 'SYNCED',
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? TactileTokens.accentCyan
        : Colors.white.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dual-bar or split meter reconciling dietary intake vs wearable workout burn.
class CalorieDualMeter extends StatelessWidget {
  final double intakeKcal;
  final double burnKcal;
  final double targetKcal;

  const CalorieDualMeter({
    super.key,
    required this.intakeKcal,
    required this.burnKcal,
    required this.targetKcal,
  });

  @override
  Widget build(BuildContext context) {
    final netKcal = intakeKcal - burnKcal;
    final intakeRatio = targetKcal > 0 ? (intakeKcal / targetKcal).clamp(0.0, 1.0) : 0.0;
    final burnRatio = targetKcal > 0 ? (burnKcal / targetKcal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visual Split Bars
        Row(
          children: [
            // Intake Meter
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INTAKE',
                        style: TextStyle(
                          color: TactileTokens.accentMint,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      AnimatedMetricTicker(
                        value: intakeKcal,
                        suffix: ' kcal',
                        style: const TextStyle(
                          color: TactileTokens.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: intakeRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: TactileTokens.accentMint,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: TactileTokens.accentMint.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Reconciled Watch Burn Meter
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'WATCH BURN',
                        style: TextStyle(
                          color: TactileTokens.accentPulse,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      AnimatedMetricTicker(
                        value: burnKcal,
                        suffix: ' kcal',
                        style: const TextStyle(
                          color: TactileTokens.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: burnRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: TactileTokens.accentPulse,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: TactileTokens.accentPulse.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NET EXPENDITURE',
              style: TextStyle(
                color: TactileTokens.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${netKcal.toStringAsFixed(0)} / ${targetKcal.toStringAsFixed(0)} kcal',
              style: TextStyle(
                color: netKcal > targetKcal
                    ? TactileTokens.accentPulse
                    : TactileTokens.accentLime,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
