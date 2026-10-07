import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/health_calculator.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:habit_tracker/features/home/cards/home_card.dart';

class HealthSummaryCard extends StatelessWidget {
  final HomeCardSize size;

  const HealthSummaryCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF43F5E); // Rose accent

    return ValueListenableBuilder(
      valueListenable: Hive.box<DietDayLog>('diet_logs').listenable(),
      builder: (context, Box<DietDayLog> dietBox, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<Medicine>('medicines').listenable(),
          builder: (context, Box<Medicine> medBox, __) {
            return ValueListenableBuilder(
              valueListenable:
                  Hive.box<MedicineLog>('medicine_logs').listenable(),
              builder: (context, Box<MedicineLog> logBox, ___) {
                return ValueListenableBuilder(
                  valueListenable:
                      Hive.box<WeightEntry>('weight_entries').listenable(),
                  builder: (context, Box<WeightEntry> weightBox, ____) {
                    return ValueListenableBuilder(
                      valueListenable:
                          Hive.box<Goal>('mission_box_v4').listenable(),
                      builder: (context, Box<Goal> goalBox, _____) {
                        return ValueListenableBuilder(
                          valueListenable: Hive.box('settings').listenable(),
                          builder: (context, Box settingsBox, ______) {
                            final todayKey =
                                DateFormat('yyyy-MM-dd').format(DateTime.now());
                            final dietLog = dietBox.get(todayKey);

                            final summary = HealthCalculator.computeSummary(
                              weights: weightBox.values.toList(),
                              dietLog: dietLog,
                              goals: goalBox.values.toList(),
                              settingsMap: settingsBox.toMap(),
                            );

                            final score = summary.compositeScore.round();
                            Color scoreColor = BentoTheme.positive;
                            if (score < 50) {
                              scoreColor = BentoTheme.negative;
                            } else if (score < 80) {
                              scoreColor = BentoTheme.warning;
                            }

                            return HomeCardFrame(
                              icon: LucideIcons.heartPulse,
                              title: 'Health Summary',
                              accentColor: accent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HealthPage(),
                                  ),
                                );
                              },
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$score / 100',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              child: size == HomeCardSize.hero
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 76,
                                              height: 76,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 76,
                                                    height: 76,
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: (score / 100)
                                                          .clamp(0.0, 1.0),
                                                      strokeWidth: 7,
                                                      backgroundColor:
                                                          BentoTheme.textPrimary
                                                              .withValues(
                                                                  alpha: 0.08),
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              scoreColor),
                                                      strokeCap:
                                                          StrokeCap.round,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$score',
                                                    style: TextStyle(
                                                      color: BentoTheme
                                                          .textPrimary,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFeatures: const [
                                                        FontFeature
                                                            .tabularFigures()
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'HEALTH COMPOSITE',
                                                    style: TextStyle(
                                                      color: BentoTheme
                                                          .textSecondary,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    score >= 80
                                                        ? 'Optimal Performance'
                                                        : (score >= 50
                                                            ? 'Steady Progress'
                                                            : 'Needs Attention'),
                                                    style: TextStyle(
                                                      color: BentoTheme
                                                          .textPrimary,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Aggregated across diet, medicines, habits & weight',
                                                    style: TextStyle(
                                                      color: BentoTheme
                                                          .textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildMetricTile(
                                                icon: LucideIcons.utensils,
                                                iconColor:
                                                    BentoTheme.textPrimary,
                                                title: 'CALORIES',
                                                value:
                                                    '${summary.netCalories.round()} kcal',
                                                subtitle: summary
                                                            .calorieTarget >
                                                        0
                                                    ? 'Target: ${summary.calorieTarget.round()}'
                                                    : 'No target set',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildMetricTile(
                                                icon: LucideIcons.pill,
                                                iconColor: BentoTheme.accent,
                                                title: 'MEDICINE',
                                                value: summary
                                                            .medicineTotalToday >
                                                        0
                                                    ? '${summary.medicineTakenToday}/${summary.medicineTotalToday}'
                                                    : 'None',
                                                subtitle: summary
                                                            .medicineTotalToday >
                                                        0
                                                    ? (summary.medicineTakenToday >=
                                                            summary
                                                                .medicineTotalToday
                                                        ? 'All taken'
                                                        : 'Pending')
                                                    : 'No meds',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildMetricTile(
                                                icon: LucideIcons.checkSquare,
                                                iconColor: BentoTheme.positive,
                                                title: 'HEALTH HABITS',
                                                value:
                                                    '${summary.healthMissionsCompletedToday}/${summary.healthMissionsTotalToday}',
                                                subtitle: summary
                                                            .healthMissionsTotalToday >
                                                        0
                                                    ? '${((summary.healthMissionsCompletedToday / summary.healthMissionsTotalToday) * 100).toInt()}% completed'
                                                    : 'No habits',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildMetricTile(
                                                icon: LucideIcons.scale,
                                                iconColor:
                                                    BentoTheme.textSecondary,
                                                title: 'WEIGHT',
                                                value: summary.latestWeightKg !=
                                                        null
                                                    ? '${summary.latestWeightKg!.toStringAsFixed(1)} ${summary.weightUnit}'
                                                    : '--',
                                                subtitle: summary
                                                            .goalWeightKg !=
                                                        null
                                                    ? 'Goal: ${summary.goalWeightKg!.toStringAsFixed(1)}'
                                                    : 'No goal set',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildMetricTile(
                                                icon: LucideIcons.utensils,
                                                iconColor:
                                                    BentoTheme.textPrimary,
                                                title: 'CALORIES',
                                                value:
                                                    '${summary.netCalories.round()} kcal',
                                                subtitle: summary
                                                            .calorieTarget >
                                                        0
                                                    ? 'Target: ${summary.calorieTarget.round()}'
                                                    : 'No target set',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildMetricTile(
                                                icon: LucideIcons.pill,
                                                iconColor: BentoTheme.accent,
                                                title: 'MEDICINE',
                                                value: summary
                                                            .medicineTotalToday >
                                                        0
                                                    ? '${summary.medicineTakenToday}/${summary.medicineTotalToday}'
                                                    : 'None',
                                                subtitle: summary
                                                            .medicineTotalToday >
                                                        0
                                                    ? (summary.medicineTakenToday >=
                                                            summary
                                                                .medicineTotalToday
                                                        ? 'All taken'
                                                        : 'Pending')
                                                    : 'No meds',
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (size == HomeCardSize.large) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: LucideIcons.checkSquare,
                                                  iconColor:
                                                      BentoTheme.positive,
                                                  title: 'HEALTH HABITS',
                                                  value:
                                                      '${summary.healthMissionsCompletedToday}/${summary.healthMissionsTotalToday}',
                                                  subtitle: summary
                                                              .healthMissionsTotalToday >
                                                          0
                                                      ? '${((summary.healthMissionsCompletedToday / summary.healthMissionsTotalToday) * 100).toInt()}% completed'
                                                      : 'No habits',
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: LucideIcons.scale,
                                                  iconColor:
                                                      BentoTheme.textSecondary,
                                                  title: 'WEIGHT',
                                                  value: summary
                                                              .latestWeightKg !=
                                                          null
                                                      ? '${summary.latestWeightKg!.toStringAsFixed(1)} ${summary.weightUnit}'
                                                      : '--',
                                                  subtitle: summary
                                                              .goalWeightKg !=
                                                          null
                                                      ? 'Goal: ${summary.goalWeightKg!.toStringAsFixed(1)}'
                                                      : 'No goal set',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 9,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
