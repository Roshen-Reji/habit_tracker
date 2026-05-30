import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';

class TaskResetService {
  static void checkAndResetTasks() {
    final box = Hive.box<Goal>('mission_box_v4'); // Note: changed to v4 since model changed drastically
    final now = DateTime.now();

    for (var goal in box.values) {
      if (!goal.isCompleted) continue;

      if (goal.lastCompletedDate == null) {
        goal.reset();
        continue;
      }

      bool shouldReset = false;
      
      switch (goal.type) {
        case GoalType.today:
          // Today tasks disappear or reset next day
          shouldReset = !_isSameDay(now, goal.lastCompletedDate!);
          break;
        case GoalType.daily:
          shouldReset = !_isSameDay(now, goal.lastCompletedDate!);
          break;
        case GoalType.weekly:
          shouldReset = _isDifferentWeek(now, goal.lastCompletedDate!);
          break;
        case GoalType.monthly:
          shouldReset = _isDifferentMonth(now, goal.lastCompletedDate!);
          break;
      }

      if (shouldReset) {
        goal.reset();
      }
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isDifferentWeek(DateTime now, DateTime lastCompleted) {
    // Assuming week starts on Monday
    final daysSinceLastCompleted = now.difference(lastCompleted).inDays;
    if (daysSinceLastCompleted >= 7) return true;

    // Check if we crossed a Monday boundary
    if (now.weekday < lastCompleted.weekday) return true;
    return false;
  }

  static bool _isDifferentMonth(DateTime now, DateTime lastCompleted) {
    return now.year > lastCompleted.year || now.month > lastCompleted.month;
  }
}
