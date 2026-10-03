import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/user_rank.dart';

class RankService {
  static final List<String> _ranks = [
    "RECRUIT",
    "OPERATIVE",
    "SPECIALIST",
    "VETERAN",
    "LEADER",
    "LEGEND"
  ];

  static UserRank calculateServiceRecord(List<Goal> goals) {
    double totalXp = 0;
    Map<GoalCategory, int> categoryPoints = {};

    for (var goal in goals) {
      double weight = goal.type == GoalType.monthly
          ? 50.0
          : (goal.type == GoalType.weekly ? 20.0 : 5.0);

      if (goal.isCompleted) {
        totalXp += weight;
        categoryPoints[goal.category] =
            (categoryPoints[goal.category] ?? 0) + weight.toInt();
      }
      totalXp += (goal.streakCount * (weight * 0.1));
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

    int level = (totalXp / 100).floor();
    int rankIndex = level.clamp(0, _ranks.length - 1);
    double progressToNext = (totalXp % 100) / 100;

    return UserRank(
      title: _ranks[rankIndex],
      position: position,
      level: level + 1,
      progressToNext: progressToNext,
      totalXp: totalXp.toInt(),
    );
  }
}
