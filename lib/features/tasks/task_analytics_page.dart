import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';

class TaskAnalyticsPage extends StatelessWidget {
  const TaskAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "MISSION ANALYTICS",
          style: TextStyle(color: AppColors.textPrimary, letterSpacing: 2, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
        builder: (context, Box<Goal> box, _) {
          final goals = box.values.toList();
          
          if (goals.isEmpty) {
            return const Center(
              child: Text(
                "No missions to analyze.",
                style: TextStyle(color: AppColors.textTertiary),
              ),
            );
          }

          int completedCount = goals.where((g) => g.isCompleted).length;
          double completionRate = goals.isEmpty ? 0 : completedCount / goals.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallProgressCard(completionRate, completedCount, goals.length),
                const SizedBox(height: 24),
                const Text(
                  "CATEGORY FOCUS",
                  style: TextStyle(color: AppColors.primary, letterSpacing: 1.5, fontWeight: bold),
                ),
                const SizedBox(height: 16),
                _buildCategoryBreakdown(goals),
                const SizedBox(height: 24),
                const Text(
                  "STREAK MASTERS",
                  style: TextStyle(color: AppColors.primary, letterSpacing: 1.5, fontWeight: bold),
                ),
                const SizedBox(height: 16),
                _buildTopStreaks(goals),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallProgressCard(double rate, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 100,
            width: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Center(
                  child: Text(
                    "${(rate * 100).toInt()}%",
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Completion",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  "$completed of $total Missions",
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rate == 1.0 ? "Perfect execution. Standby for next cycle." : "Keep pushing forward.",
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<Goal> goals) {
    Map<GoalCategory, int> categoryCounts = {};
    for (var cat in GoalCategory.values) {
      categoryCounts[cat] = 0;
    }
    for (var g in goals) {
      categoryCounts[g.category] = (categoryCounts[g.category] ?? 0) + 1;
    }
    
    int maxCount = categoryCounts.values.reduce(math.max);
    if (maxCount == 0) maxCount = 1;

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              radarBorderData: const BorderSide(color: AppColors.glassBorder),
              tickBorderData: const BorderSide(color: Colors.transparent),
              gridBorderData: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
              titlePositionPercentageOffset: 0.1,
              getTitle: (index, angle) {
                final cat = GoalCategory.values[index];
                return RadarChartTitle(
                  text: cat.name.toUpperCase(),
                  angle: angle,
                  positionPercentageOffset: 0.2,
                );
              },
              titleTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
              dataSets: [
                RadarDataSet(
                  fillColor: AppColors.primary.withValues(alpha: 0.3),
                  borderColor: AppColors.primary,
                  entryRadius: 3,
                  dataEntries: GoalCategory.values.map((cat) {
                    return RadarEntry(value: (categoryCounts[cat] ?? 0).toDouble());
                  }).toList(),
                  borderWidth: 2,
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 400),
          ),
        ),
        const SizedBox(height: 16),
        ...GoalCategory.values.map((cat) {
          int count = categoryCounts[cat] ?? 0;
          if (count == 0) return const SizedBox.shrink();

          double percent = count / goals.length;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(cat).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getCategoryIcon(cat), color: _getCategoryColor(cat), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat.name.toUpperCase(),
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "$count (${(percent * 100).toInt()}%)",
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(cat)),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTopStreaks(List<Goal> goals) {
    final sortedGoals = List<Goal>.from(goals)..sort((a, b) => b.streakCount.compareTo(a.streakCount));
    final topGoals = sortedGoals.take(3).toList();

    if (topGoals.isEmpty || topGoals.first.streakCount == 0) {
      return const Text("No streaks established yet.", style: TextStyle(color: AppColors.textTertiary));
    }

    return Column(
      children: topGoals.where((g) => g.streakCount > 0).map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  g.title,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "${g.streakCount} days",
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return AppColors.health;
      case GoalCategory.productivity: return AppColors.productivity;
      case GoalCategory.learning: return AppColors.learning;
      case GoalCategory.fitness: return AppColors.fitness;
      case GoalCategory.hobby: return AppColors.hobby;
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return Icons.favorite;
      case GoalCategory.productivity: return Icons.bolt;
      case GoalCategory.learning: return Icons.menu_book;
      case GoalCategory.fitness: return Icons.fitness_center;
      case GoalCategory.hobby: return Icons.extension;
    }
  }
}

const FontWeight bold = FontWeight.bold;
