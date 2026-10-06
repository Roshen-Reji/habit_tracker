import 'package:habit_tracker/core/progression/progression_engine.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/user_rank.dart';
import 'package:hive_flutter/hive_flutter.dart';

class RankService {
  /// Calculates the user's service record using the unified [ProgressionEngine]
  /// and the category-specialization position derived from goals.
  static UserRank calculateServiceRecord(List<Goal> goals) {
    int totalXp = 0;
    if (Hive.isBoxOpen('settings')) {
      totalXp = Hive.box('settings').get('global_xp', defaultValue: 0) as int;
    } else {
      // Fallback if settings box is not open
      for (var goal in goals) {
        double weight = goal.type == GoalType.monthly
            ? 50.0
            : (goal.type == GoalType.weekly ? 20.0 : 5.0);
        if (goal.isCompleted) totalXp += weight.toInt();
        totalXp += (goal.streakCount * (weight * 0.1)).toInt();
      }
    }

    final progression = ProgressionEngine.calculate(totalXp);

    // Determine "Position" (Specialization) based on max points in a category
    Map<GoalCategory, int> categoryPoints = {};
    for (var goal in goals) {
      double weight = goal.type == GoalType.monthly
          ? 50.0
          : (goal.type == GoalType.weekly ? 20.0 : 5.0);

      if (goal.isCompleted) {
        categoryPoints[goal.category] =
            (categoryPoints[goal.category] ?? 0) + weight.toInt();
      }
      categoryPoints[goal.category] = (categoryPoints[goal.category] ?? 0) +
          (goal.streakCount * (weight * 0.1)).toInt();
    }

    String position = "UNASSIGNED";
    if (categoryPoints.isNotEmpty) {
      final bestCategory = categoryPoints.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      switch (bestCategory) {
        case GoalCategory.learning:
          position = "LEAD RESEARCHER";
          break;
        case GoalCategory.fitness:
          position = "TACTICAL ATHLETE";
          break;
        case GoalCategory.productivity:
          position = "OPERATIONS CHIEF";
          break;
        case GoalCategory.health:
          position = "BIO-SECURITY OFFICER";
          break;
        case GoalCategory.hobby:
          position = "CREATIVE DIRECTOR";
          break;
      }
    }

    return UserRank(
      title: progression.rankTitle,
      position: position,
      level: progression.level,
      progressToNext: progression.progress,
      totalXp: progression.totalXp,
    );
  }
}
