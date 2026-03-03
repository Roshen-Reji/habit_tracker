import 'package:hive/hive.dart';

part 'goals.g.dart';

@HiveType(typeId: 0)
enum GoalType {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
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
  });

  double get completionPercentage => (currentValue / targetValue * 100).clamp(0, 100);

  void updateProgress(double value) {
    currentValue = value;
    progress = completionPercentage / 100;
    if (currentValue >= targetValue) {
      isCompleted = true;
    }
    save();
  }

  void incrementProgress(double value) {
    updateProgress(currentValue + value);
  }

  void complete() {
    isCompleted = true;
    currentValue = targetValue;
    progress = 1.0;
    streakCount++;
    save();
  }

  void reset() {
    isCompleted = false;
    currentValue = 0;
    progress = 0.0;
    save();
  }
}