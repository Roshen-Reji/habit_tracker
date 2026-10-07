import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WeightCard extends StatelessWidget {
  final HomeCardSize size;

  const WeightCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFA855F7); // Purple accent

    return ValueListenableBuilder(
      valueListenable: Hive.box<WeightEntry>('weight_entries').listenable(),
      builder: (context, Box<WeightEntry> weightBox, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box('settings').listenable(),
          builder: (context, Box settingsBox, __) {
            final entries = weightBox.values.toList();
            entries.sort((a, b) => a.date.compareTo(b.date));

            final unit = settingsBox.get('weight_unit', defaultValue: 'kg');
            final startKg =
                (settingsBox.get('weight_start') as num?)?.toDouble();
            final goalKg = (settingsBox.get('weight_goal') as num?)?.toDouble();

            final currentKg = entries.isNotEmpty ? entries.last.kg : startKg;
            double? delta;
            if (currentKg != null && startKg != null) {
              delta = currentKg - startKg;
            }

            final trailingText = currentKg != null
                ? '${currentKg.toStringAsFixed(1)} $unit'
                : 'No logs';

            return HomeCardFrame(
              icon: LucideIcons.scale,
              title: 'Weight Journey',
              accentColor: accent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HealthPage(initialTab: 1),
                  ),
                );
              },
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailingText,
                  style: const TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Three-stat summary row (Start, Current, Goal)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          label: 'START',
                          value: startKg != null
                              ? '${startKg.toStringAsFixed(1)} $unit'
                              : '--',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          label: 'CURRENT',
                          value: currentKg != null
                              ? '${currentKg.toStringAsFixed(1)} $unit'
                              : '--',
                          highlightColor: accent,
                          subValue: delta != null
                              ? '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          label: 'GOAL',
                          value: goalKg != null
                              ? '${goalKg.toStringAsFixed(1)} $unit'
                              : '--',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Sparkline graph or prompt
                  if (entries.length >= 2) ...[
                    SizedBox(
                      height: size == HomeCardSize.large ? 75 : 54,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                entries.length,
                                (i) => FlSpot(i.toDouble(), entries[i].kg),
                              ),
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: accent,
                              barWidth: 2.5,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.25),
                                    accent.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (size == HomeCardSize.large) ...[
                      const SizedBox(height: 12),
                      Text(
                        'RECENT WEIGH-INS',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...entries.reversed.take(3).map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                () {
                                  final d = DateTime.tryParse(e.date);
                                  return d != null
                                      ? DateFormat('d MMM yyyy').format(d)
                                      : e.date;
                                }(),
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${e.kg.toStringAsFixed(1)} $unit',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(ExpressiveTokens.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.activity,
                              color: BentoTheme.textSecondary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Log 2+ weigh-ins to see your weight trend curve.',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    Color? highlightColor,
    String? subValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: highlightColor ?? BentoTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subValue != null)
            Text(
              subValue,
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
