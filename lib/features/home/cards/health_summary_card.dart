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

class HealthSummaryCard extends StatelessWidget {
  const HealthSummaryCard({super.key});

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
                            Color scoreColor = Colors.greenAccent;
                            if (score < 50) {
                              scoreColor = Colors.redAccent;
                            } else if (score < 80) {
                              scoreColor = Colors.amberAccent;
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Metric tiles row
                                  Row(
                                    children: [
                                      // Calories
                                      Expanded(
                                        child: _buildMetricTile(
                                          icon: LucideIcons.utensils,
                                          iconColor: Colors.orangeAccent,
                                          title: 'CALORIES',
                                          value:
                                              '${summary.netCalories.round()} kcal',
                                          subtitle: summary.calorieTarget > 0
                                              ? 'Target: ${summary.calorieTarget.round()}'
                                              : 'No target set',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Medicine
                                      Expanded(
                                        child: _buildMetricTile(
                                          icon: LucideIcons.pill,
                                          iconColor: const Color(0xFF2DD4BF),
                                          title: 'MEDICINE',
                                          value: summary.medicineTotalToday > 0
                                              ? '${summary.medicineTakenToday}/${summary.medicineTotalToday}'
                                              : 'None',
                                          subtitle: summary.medicineTotalToday >
                                                  0
                                              ? (summary.medicineTakenToday >=
                                                      summary.medicineTotalToday
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
                                      // Health Missions
                                      Expanded(
                                        child: _buildMetricTile(
                                          icon: LucideIcons.checkSquare,
                                          iconColor: Colors.lightBlueAccent,
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
                                      // Weight
                                      Expanded(
                                        child: _buildMetricTile(
                                          icon: LucideIcons.scale,
                                          iconColor: const Color(0xFFA855F7),
                                          title: 'WEIGHT',
                                          value: summary.latestWeightKg != null
                                              ? '${summary.latestWeightKg!.toStringAsFixed(1)} ${summary.weightUnit}'
                                              : '--',
                                          subtitle: summary.goalWeightKg != null
                                              ? 'Goal: ${summary.goalWeightKg!.toStringAsFixed(1)}'
                                              : 'No goal set',
                                        ),
                                      ),
                                    ],
                                  ),
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
