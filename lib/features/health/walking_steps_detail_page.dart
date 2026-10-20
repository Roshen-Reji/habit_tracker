import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';

/// Walking Steps Detail Screen matching Dribbble spec (AGENTS.md Section 2.2).
///
/// Features:
/// 1. Top bar with circular back button and options button.
/// 2. Header card: soft green circular icon + "Walking steps" + "See your Walking Statistics".
/// 3. Main Spline Chart Card:
///    - Total Distance in km (calculated from DailyActivity.distanceM or steps * 0.000762, NEVER fake speed).
///    - Total Steps vs Goal.
///    - Interactive Emerald Area Spline Chart driven by real 7-day progression.
///    - Peak callout bubble positioned dynamically at the active/peak data point with vertical dropline.
///    - Bottom 7-day pills with active/peak slot highlighted in solid emerald.
/// 4. Bottom 2-Column Summary Row:
///    - Burnt Calories: Real active calories from DailyActivity.activeKcal + coral wave graphic.
///    - Active Pace / Goal Progress: Real active minutes or step goal completion % + 4-row dashed track graphic.
class WalkingStepsDetailPage extends StatefulWidget {
  final int totalSteps;
  final double totalDistanceKm;
  final DateTime? selectedDate;
  final double? activeKcal;
  final int? activeMinutes;
  final int stepGoal;

  const WalkingStepsDetailPage({
    super.key,
    this.totalSteps = 0,
    this.totalDistanceKm = 0.0,
    this.selectedDate,
    this.activeKcal,
    this.activeMinutes,
    this.stepGoal = 8000,
  });

  @override
  State<WalkingStepsDetailPage> createState() => _WalkingStepsDetailPageState();
}

class _WalkingStepsDetailPageState extends State<WalkingStepsDetailPage> {
  late int _selectedDayIndex;
  late List<DateTime> _weekDays;
  late List<int> _dailySteps;

  @override
  void initState() {
    super.initState();
    final anchor = widget.selectedDate ?? DateTime.now();
    _weekDays = List.generate(7, (i) => anchor.subtract(Duration(days: 6 - i)));
    _dailySteps = _weekDays.map((d) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      return WearableRepository.instance.dayView(key).totalSteps;
    }).toList();

    _selectedDayIndex = 6;
    if (_dailySteps[_selectedDayIndex] == 0 && widget.totalSteps > 0) {
      _dailySteps[_selectedDayIndex] = widget.totalSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phase 3 Palette & Tokens from AGENTS.md Section 2.3
    final bgColor = isDark ? const Color(0xFF0B0E11) : const Color(0xFFF6F7F9);
    final cardSurface = isDark ? const Color(0xFF15191E) : const Color(0xFFFFFFFF);
    final secondarySurface = isDark ? const Color(0xFF1F2630) : const Color(0xFFF3F5F7);
    final primaryTextColor = isDark ? const Color(0xFFF3F6F9) : const Color(0xFF111417);
    final subtitleTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF8A929A);

    final emeraldAccent = AppColors.resolveAccent(
      context,
      isDark ? const Color(0xFF10B981) : const Color(0xFF05B87C),
    );
    final coralAccent = AppColors.resolveAccent(
      context,
      isDark ? const Color(0xFFFF6B6B) : const Color(0xFFFF6E6E),
    );

    final selectedDate = _weekDays[_selectedDayIndex];
    final selectedDayKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayView = WearableRepository.instance.dayView(selectedDayKey);

    final currentSteps = dayView.totalSteps > 0
        ? dayView.totalSteps
        : (_dailySteps[_selectedDayIndex] > 0
            ? _dailySteps[_selectedDayIndex]
            : (widget.totalSteps > 0 ? widget.totalSteps : 0));

    final distanceMeters = dayView.activity?.distanceM ??
        (widget.totalDistanceKm > 0
            ? (widget.totalDistanceKm * 1000.0)
            : (currentSteps * 0.762));
    final distanceKm = distanceMeters / 1000.0;

    final burntKcal = dayView.activity?.activeKcal ??
        widget.activeKcal ??
        (currentSteps * 0.04);

    final activeMins = dayView.activeMinutes > 0
        ? dayView.activeMinutes
        : widget.activeMinutes;

    final goalPercent = widget.stepGoal > 0
        ? ((currentSteps / widget.stepGoal) * 100).clamp(0, 999).round()
        : 0;

    final peakLabel = NumberFormat('#,###').format(currentSteps);

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

              // 3. Main Spline Chart Card (BorderRadius.circular(32))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(32.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF222831) : Colors.transparent,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A000000),
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
                              '${distanceKm.toStringAsFixed(2)} km',
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
                            RichText(
                              text: TextSpan(
                                text: NumberFormat('#,###').format(currentSteps),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                                children: [
                                  TextSpan(
                                    text: ' / ${NumberFormat('#,###').format(widget.stepGoal)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: subtitleTextColor,
                                    ),
                                  ),
                                ],
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
                          peakLabel: peakLabel,
                          selectedIndex: _selectedDayIndex,
                          values: _dailySteps.map((s) => s.toDouble()).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom 7-Day Axis Pills
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_weekDays.length, (index) {
                        final isSelected = _selectedDayIndex == index;
                        final dayName = DateFormat('E').format(_weekDays[index]);

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDayIndex = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? emeraldAccent : secondarySurface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              dayName,
                              style: TextStyle(
                                fontSize: 12,
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
                          color: isDark ? const Color(0xFF222831) : Colors.transparent,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A000000),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                            '${burntKcal.round()} kcal',
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

                  // Right Card (Active Pace / Goal Progress)
                  Expanded(
                    child: Container(
                      height: 170,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(28.0),
                        border: Border.all(
                          color: isDark ? const Color(0xFF222831) : Colors.transparent,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A000000),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                                  color: emeraldAccent.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(LucideIcons.target, color: emeraldAccent, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Pace /\nGoal Progress',
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
                            activeMins != null && activeMins > 0
                                ? '$activeMins min'
                                : '$goalPercent% Goal',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          // 4-row dashed horizontal multi-segment track indicator
                          _buildSpeedTracks(emeraldAccent, subtitleTextColor, goalPercent),
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

  Widget _buildSpeedTracks(Color activeColor, Color inactiveColor, int goalPercent) {
    final double fraction = (goalPercent / 100.0).clamp(0.0, 1.0);
    return Column(
      children: [
        _buildTrackRow([
          fraction > 0.0 ? 1.0 : 0.0,
          fraction > 0.1 ? 1.0 : 0.0,
          fraction > 0.2 ? 1.0 : 0.0,
          fraction > 0.25 ? 0.7 : 0.0,
        ], activeColor, inactiveColor),
        const SizedBox(height: 4),
        _buildTrackRow([
          fraction > 0.3 ? 1.0 : 0.0,
          fraction > 0.4 ? 1.0 : 0.0,
          fraction > 0.5 ? 0.6 : 0.0,
          0.0,
        ], activeColor, inactiveColor),
        const SizedBox(height: 4),
        _buildTrackRow([
          fraction > 0.6 ? 1.0 : 0.0,
          fraction > 0.75 ? 0.8 : 0.0,
          0.0,
          0.0,
        ], activeColor, inactiveColor),
        const SizedBox(height: 4),
        _buildTrackRow([
          fraction > 0.9 ? 1.0 : 0.0,
          0.0,
          0.0,
          0.0,
        ], activeColor, inactiveColor),
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
  final List<double> values;

  const _SplineAreaChartPainter({
    required this.curveColor,
    required this.peakCircleColor,
    required this.peakLabel,
    required this.selectedIndex,
    required this.values,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (values.isEmpty) return;

    final n = values.length;
    final maxVal = values.reduce(math.max);

    final chartTop = 46.0;
    final chartHeight = h - chartTop - 20.0;

    final offsets = List.generate(n, (i) {
      final x = (i / (n - 1).clamp(1, double.infinity)) * (w - 32.0) + 16.0;
      final norm = maxVal > 0 ? (values[i] / (maxVal * 1.15)) : 0.20;
      final y = (chartTop + chartHeight) - (norm * chartHeight);
      return Offset(x, y.clamp(chartTop, h - 10.0));
    });

    final path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < n - 1; i++) {
      final pCurr = offsets[i];
      final pNext = offsets[i + 1];
      final cx1 = pCurr.dx + (pNext.dx - pCurr.dx) / 2;
      final cy1 = pCurr.dy;
      final cx2 = pCurr.dx + (pNext.dx - pCurr.dx) / 2;
      final cy2 = pNext.dy;
      path.cubicTo(cx1, cy1, cx2, cy2, pNext.dx, pNext.dy);
    }

    // Gradient fill under curve
    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, h)
      ..lineTo(offsets.first.dx, h)
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

    final strokePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Dynamic Peak Callout at selectedIndex
    final safeIndex = selectedIndex.clamp(0, n - 1);
    final peakPoint = offsets[safeIndex];

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
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.peakLabel != peakLabel ||
        oldDelegate.values != values;
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
