import 'package:hive/hive.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';

part 'goal.g.dart';

@HiveType(typeId: 0)
enum GoalType {
  @HiveField(0)
  today,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  monthly
}

@HiveType(typeId: 2)
enum GoalCategory {
  @HiveField(0)
  health,
  @HiveField(1)
  productivity,
  @HiveField(2)
  learning,
  @HiveField(3)
  fitness,
  @HiveField(4)
  hobby
}

@HiveType(typeId: 1)
class Goal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final GoalType type;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  double progress;

  @HiveField(5)
  final GoalCategory category;

  @HiveField(6)
  final double targetValue;

  @HiveField(7)
  double currentValue;

  @HiveField(8)
  final String unit;

  @HiveField(9)
  final String description;

  @HiveField(10)
  int streakCount;

  @HiveField(11)
  bool isArchived;

  @HiveField(12)
  DateTime? createdDate;

  @HiveField(13)
  DateTime? lastCompletedDate;

  @HiveField(14)
  DateTime? reminderTime;

  @HiveField(15)
  DateTime? endDate;

  @HiveField(16)
  DateTime? lastReset;

  int get xpValue {
    switch (type) {
      case GoalType.monthly:
        return 50;
      case GoalType.weekly:
        return 20;
      default:
        return 5;
    }
  }

  Goal({
    required this.id,
    required this.title,
    required this.type,
    required this.category,
    required this.targetValue,
    this.currentValue = 0.0,
    required this.unit,
    this.description = '',
    this.isCompleted = false,
    this.progress = 0.0,
    this.streakCount = 0,
    this.isArchived = false,
    this.createdDate,
    this.lastCompletedDate,
    this.reminderTime,
    this.endDate,
    this.lastReset,
  });

  double get completionPercentage =>
      (targetValue > 0) ? (currentValue / targetValue * 100).clamp(0, 100) : 0;

  void updateProgress(double value) {
    currentValue = value;
    if (targetValue > 0) {
      progress = completionPercentage / 100;
    }
    if (currentValue >= targetValue) {
      complete();
    } else {
      isCompleted = false;
      save();
    }
  }

  void incrementProgress(double value) {
    updateProgress(currentValue + value);
  }

  void complete() {
    if (!isCompleted) {
      GlobalXPService.addXP(xpValue);
    }
    isCompleted = true;
    currentValue = targetValue;
    progress = 1.0;

    // Only increment streak if it hasn't been completed today
    final now = DateTime.now();
    if (lastCompletedDate == null || !_isSameDay(now, lastCompletedDate!)) {
      streakCount++;
    }

    lastCompletedDate = now;
    save();
  }

  void reset() {
    isCompleted = false;
    currentValue = 0;
    progress = 0.0;
    save();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
