import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';

/// Shame-free Progress Tab with 7-Day EWMA Smoothed Weight Trend,
/// Waist Tracker, Habit Adherence Consistency, and Data Export.
class DietProgressTab extends StatelessWidget {
  const DietProgressTab({super.key});

  void _openLogWeightSheet(BuildContext context) {
    final repo = DietRepository.instance;
    final weightCtrl = TextEditingController(
      text: repo.weightEntries.isNotEmpty
          ? repo.weightEntries.last.weightKg.toStringAsFixed(1)
          : repo.profile.currentWeightKg.toStringAsFixed(1),
    );
    final waistCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    SpringSheet.show(
      context: context,
      title: 'Log Weight Check-In',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weigh-ins are recorded once daily under consistent morning conditions.',
            style: TextStyle(
              color: BentoTheme.isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: waistCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Waist (cm, optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Notes (e.g. Post-workout, high sodium dinner)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          PressScale(
            onTap: () async {
              final w = double.tryParse(weightCtrl.text);
              if (w != null && w > 0) {
                final waist = double.tryParse(waistCtrl.text);
                await repo.logWeight(w, waistCm: waist, notes: notesCtrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: BentoTheme.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Record Weigh-In',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final trend = repo.weightTrend;
        final entries = repo.weightEntries;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // Top Action: Log Weight Button
            Row(
              children: [
                Expanded(
                  child: PressScale(
                    onTap: () => _openLogWeightSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.scale, size: 16, color: Colors.black),
                          SizedBox(width: 6),
                          Text(
                            'Log Today\'s Weight',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // EWMA Trend Chart Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries.isEmpty ? 'Baseline Profile Weight' : '7-Day EWMA Trend',
                            style: TextStyle(
                              color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entries.isEmpty
                                ? '${repo.profile.currentWeightKg.toStringAsFixed(1)} kg'
                                : '${trend.currentEwmaKg.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              color: BentoTheme.isDark ? Colors.white : Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (entries.isNotEmpty) _trendPill(trend, accent),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Custom-painted smooth curve or empty state
                  if (entries.isEmpty)
                    Container(
                      height: 120,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.scale, size: 24, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'No weigh-ins logged yet',
                            style: TextStyle(
                              color: BentoTheme.isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log your morning weight above to begin generating your smoothed 7-day trend.',
                            style: TextStyle(
                              color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _EwmaChartPainter(
                          entries: entries,
                          smoothedMap: trend.smoothedSeries,
                          accentColor: accent,
                          isDark: BentoTheme.isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chart Legend & Shame-Free Education
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(Colors.grey, 'Raw Weigh-ins'),
                        const SizedBox(width: 16),
                        _legendDot(accent, '7-Day Smooth EWMA'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Daily scale weights fluctuate due to water retention and glycogen. The smoothed EWMA curve reveals true tissue trends without false alarms.',
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Habit Adherence & Health Consistency Strip
            _buildHabitConsistencyCard(repo, accent),
            const SizedBox(height: 16),

            // Weigh-in History List
            Text(
              'Past Check-Ins (${entries.length})',
              style: TextStyle(
                color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'No check-ins recorded yet. Tap "Log Today\'s Weight" to add your first check-in.',
                  style: TextStyle(
                    color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              )
            else
              ...entries.reversed.take(10).map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(DateTime.parse(entry.dateIso)),
                      style: TextStyle(
                        color: BentoTheme.isDark ? Colors.white70 : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.weightKg.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (entry.waistCm != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${entry.waistCm!.round()} cm)',
                        style: TextStyle(
                          color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => repo.deleteWeightEntry(entry.id),
                      child: const Icon(LucideIcons.trash2, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _trendPill(EWMAWeightTrend trend, Color accent) {
    Color pillColor = Colors.grey;
    String label = 'Stable Rate';

    if (trend.trendDirection == 'losing') {
      pillColor = AppColors.success;
      label = '${trend.weeklyRateOfChangeKg.toStringAsFixed(2)} kg/wk';
    } else if (trend.trendDirection == 'gaining') {
      pillColor = AppColors.warning;
      label = '+${trend.weeklyRateOfChangeKg.toStringAsFixed(2)} kg/wk';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend.trendDirection == 'losing'
                ? LucideIcons.trendingDown
                : (trend.trendDirection == 'gaining'
                    ? LucideIcons.trendingUp
                    : LucideIcons.minus),
            size: 13,
            color: pillColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: pillColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildHabitConsistencyCard(DietRepository repo, Color accent) {
    final targets = repo.dailyTargets;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final water = repo.waterDrankMl(today);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habit Consistency & Adherence',
            style: TextStyle(
              color: BentoTheme.isDark ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _habitStat(
                  'Hydration',
                  '${(water / 1000).toStringAsFixed(1)}L / ${(targets.waterMl / 1000).toStringAsFixed(1)}L',
                  LucideIcons.droplet,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _habitStat(
                  'Daily Targets',
                  'Clinical Floor Verified',
                  LucideIcons.shieldCheck,
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _habitStat(String title, String val, IconData icon, Color c) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BentoTheme.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: c),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              color: BentoTheme.isDark ? Colors.white : Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for rendering smoothed EWMA curve alongside raw weigh-in points.
class _EwmaChartPainter extends CustomPainter {
  final List<WeightProgressEntry> entries;
  final Map<String, double> smoothedMap;
  final Color accentColor;
  final bool isDark;

  _EwmaChartPainter({
    required this.entries,
    required this.smoothedMap,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final sorted = List<WeightProgressEntry>.from(entries)
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    // Determine min/max Y with padding
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final e in sorted) {
      if (e.weightKg < minY) minY = e.weightKg;
      if (e.weightKg > maxY) maxY = e.weightKg;
      final sm = smoothedMap[e.dateIso];
      if (sm != null) {
        if (sm < minY) minY = sm;
        if (sm > maxY) maxY = sm;
      }
    }

    minY = (minY - 1.0).floorToDouble();
    maxY = (maxY + 1.0).ceilToDouble();
    if (maxY <= minY) maxY = minY + 2.0;

    final double width = size.width;
    final double height = size.height;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black12
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = height * (i / 3.0);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final double stepX = sorted.length > 1 ? width / (sorted.length - 1) : width / 2;

    // 1. Draw raw weigh-in points
    final rawPointPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < sorted.length; i++) {
      final x = sorted.length > 1 ? i * stepX : width / 2;
      final y = height - ((sorted[i].weightKg - minY) / (maxY - minY)) * height;
      canvas.drawCircle(Offset(x, y), 3.0, rawPointPaint);
    }

    // 2. Draw smooth EWMA curve
    final ewmaPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < sorted.length; i++) {
      final x = sorted.length > 1 ? i * stepX : width / 2;
      final val = smoothedMap[sorted[i].dateIso] ?? sorted[i].weightKg;
      final y = height - ((val - minY) / (maxY - minY)) * height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevVal = smoothedMap[sorted[i - 1].dateIso] ?? sorted[i - 1].weightKg;
        final prevY = height - ((prevVal - minY) / (maxY - minY)) * height;

        // Smooth cubic bezier
        final controlX1 = prevX + (x - prevX) / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + (x - prevX) / 2;
        final controlY2 = y;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    canvas.drawPath(path, ewmaPaint);
  }

  @override
  bool shouldRepaint(covariant _EwmaChartPainter oldDelegate) => true;
}
