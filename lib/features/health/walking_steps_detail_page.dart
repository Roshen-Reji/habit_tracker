import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';

/// Walking Steps Detail Screen matching Dribbble spec (AGENTS.md Phase 3.2).
///
/// Features:
/// 1. Top bar with circular back button and options button.
/// 2. Header card: soft green circular icon + "Walking steps" + "See your Walking Statistics".
/// 3. Main Spline Chart Card:
///    - Total Distance + Total Steps metrics.
///    - Smooth cubic Bézier emerald curve with gradient fill.
///    - Floating peak callout (2400) with coral circle and drop-line.
///    - Horizontal row of time pills (05:00, 06:00 [active], 07:00, 08:00).
/// 4. Bottom 2-Column Summary Row:
///    - Burnt Calories (957 kCal) + coral wave chart.
///    - Speed Average (6.2 Km/h) + 4-row dashed multi-segment track indicator.
class WalkingStepsDetailPage extends StatefulWidget {
  final int totalSteps;
  final double totalDistanceKm;

  const WalkingStepsDetailPage({
    super.key,
    this.totalSteps = 4754,
    this.totalDistanceKm = 3.65,
  });

  @override
  State<WalkingStepsDetailPage> createState() => _WalkingStepsDetailPageState();
}

class _WalkingStepsDetailPageState extends State<WalkingStepsDetailPage> {
  int _selectedTimeIndex = 1; // 06:00 selected by default
  final List<String> _timeLabels = const ['05:00', '06:00', '07:00', '08:00'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phase 3 Palette
    final bgColor = isDark ? const Color(0xFF0D1014) : const Color(0xFFF8F9FA);
    final cardSurface = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final secondarySurface = isDark ? const Color(0xFF1F2630) : const Color(0xFFF3F5F7);
    final primaryTextColor = isDark ? const Color(0xFFF0F4F8) : const Color(0xFF111417);
    final subtitleTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF8A929A);

    final emeraldAccent = AppColors.resolveAccent(
      context,
      isDark ? const Color(0xFF10B981) : const Color(0xFF05B87C),
    );
    final coralAccent = AppColors.resolveAccent(
      context,
      isDark ? const Color(0xFFFF6B6B) : const Color(0xFFFF6E6E),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).padding.bottom + 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircularButton(
                    context,
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                    surfaceColor: cardSurface,
                    iconColor: primaryTextColor,
                  ),
                  _buildCircularButton(
                    context,
                    icon: Icons.more_horiz_rounded,
                    onTap: () {},
                    surfaceColor: cardSurface,
                    iconColor: primaryTextColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Header Card
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: emeraldAccent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_walk_rounded,
                      color: emeraldAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Walking steps',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'See your Walking Statistics',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 3. Main Spline Chart Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(32.0),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Metrics Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Distance',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.totalDistanceKm.toStringAsFixed(2)} Km',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Steps',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.totalSteps}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Interactive Spline Area Chart
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _SplineAreaChartPainter(
                          curveColor: emeraldAccent,
                          peakCircleColor: coralAccent,
                          peakLabel: '2400',
                          selectedIndex: _selectedTimeIndex,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom Time Axis
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_timeLabels.length, (index) {
                        final isSelected = _selectedTimeIndex == index;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTimeIndex = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? emeraldAccent : secondarySurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _timeLabels[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : subtitleTextColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Bottom 2-Column Summary Row
              Row(
                children: [
                  // Left Card (Burnt Calories)
                  Expanded(
                    child: Container(
                      height: 170,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(28.0),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: coralAccent.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(LucideIcons.flame, color: coralAccent, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Burnt\nCalories',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color: subtitleTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '957 kCal',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          // Bottom filled coral wave chart
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _CoralWavePainter(waveColor: coralAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right Card (Speed Average)
                  Expanded(
                    child: Container(
                      height: 170,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(28.0),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: coralAccent.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(LucideIcons.gauge, color: coralAccent, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Speed\nAverage',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color: subtitleTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '6.2 Km/h',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          // 4-row dashed horizontal multi-segment track indicator
                          _buildSpeedTracks(coralAccent, subtitleTextColor),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: surfaceColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildSpeedTracks(Color activeColor, Color inactiveColor) {
    return Column(
      children: [
        _buildTrackRow([1.0, 1.0, 1.0, 0.4], activeColor, inactiveColor),
        const SizedBox(height: 4),
        _buildTrackRow([1.0, 1.0, 0.3, 0.0], activeColor, inactiveColor),
        const SizedBox(height: 4),
        _buildTrackRow([1.0, 0.8, 0.0, 0.0], activeColor, inactiveColor),
        const SizedBox(height: 4),
        _buildTrackRow([0.6, 0.0, 0.0, 0.0], activeColor, inactiveColor),
      ],
    );
  }

  Widget _buildTrackRow(List<double> intensities, Color active, Color inactive) {
    return Row(
      children: intensities.map((val) {
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: val > 0 ? active.withOpacity(val) : inactive.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Painters for Walking Steps Spline Chart & Wave
// ---------------------------------------------------------------------------

class _SplineAreaChartPainter extends CustomPainter {
  final Color curveColor;
  final Color peakCircleColor;
  final String peakLabel;
  final int selectedIndex;

  const _SplineAreaChartPainter({
    required this.curveColor,
    required this.peakCircleColor,
    required this.peakLabel,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Define curve control points
    final p0 = Offset(0, h * 0.78);
    final p1 = Offset(w * 0.22, h * 0.60);
    final p2 = Offset(w * 0.44, h * 0.22); // Peak point at ~06:00
    final p3 = Offset(w * 0.72, h * 0.55);
    final p4 = Offset(w, h * 0.38);

    final path = Path();
    path.moveTo(p0.dx, p0.dy);

    // Cubic Béziers for smooth spline
    path.cubicTo(
      w * 0.11, h * 0.72,
      w * 0.15, h * 0.60,
      p1.dx, p1.dy,
    );
    path.cubicTo(
      w * 0.30, h * 0.60,
      w * 0.36, h * 0.22,
      p2.dx, p2.dy,
    );
    path.cubicTo(
      w * 0.52, h * 0.22,
      w * 0.62, h * 0.55,
      p3.dx, p3.dy,
    );
    path.cubicTo(
      w * 0.82, h * 0.55,
      w * 0.90, h * 0.38,
      p4.dx, p4.dy,
    );

    // Gradient fill under curve
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          curveColor.withOpacity(0.35),
          curveColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Spline curve stroke
    final strokePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Active Peak Callout at p2
    final peakPoint = p2;

    // Vertical dashed dropline down to bottom
    final dropLinePaint = Paint()
      ..color = peakCircleColor.withOpacity(0.65)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double curY = peakPoint.dy + 8;
    while (curY < h) {
      canvas.drawLine(
        Offset(peakPoint.dx, curY),
        Offset(peakPoint.dx, math.min(curY + 4, h)),
        dropLinePaint,
      );
      curY += 8;
    }

    // Coral peak circle
    final outerGlowPaint = Paint()
      ..color = peakCircleColor.withOpacity(0.24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(peakPoint, 11, outerGlowPaint);

    final circlePaint = Paint()
      ..color = peakCircleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(peakPoint, 6, circlePaint);

    final innerWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(peakPoint, 2.5, innerWhitePaint);

    // Floating bold label above peak circle
    final textSpan = TextSpan(
      text: peakLabel,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(peakPoint.dx, peakPoint.dy - 20),
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      ),
      const Radius.circular(10),
    );

    final pillPaint = Paint()
      ..color = peakCircleColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pillRect, pillPaint);

    textPainter.paint(
      canvas,
      Offset(
        peakPoint.dx - (textPainter.width / 2),
        peakPoint.dy - 20 - (textPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SplineAreaChartPainter oldDelegate) {
    return oldDelegate.curveColor != curveColor ||
        oldDelegate.peakCircleColor != peakCircleColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _CoralWavePainter extends CustomPainter {
  final Color waveColor;

  const _CoralWavePainter({required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.7);
    path.cubicTo(w * 0.25, h * 0.2, w * 0.45, h * 0.9, w * 0.7, h * 0.35);
    path.cubicTo(w * 0.85, h * 0.1, w * 0.95, h * 0.4, w, h * 0.2);

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          waveColor.withOpacity(0.38),
          waveColor.withOpacity(0.04),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CoralWavePainter oldDelegate) =>
      oldDelegate.waveColor != waveColor;
}
