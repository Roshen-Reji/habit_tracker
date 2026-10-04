import 'package:hive/hive.dart';

part 'goal_entry.g.dart';

@HiveType(typeId: 47)
class GoalEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String goalId;

  @HiveField(2)
  DateTime date;

  /// Positive for contribution, negative for withdrawal
  @HiveField(3)
  double amount;

  @HiveField(4)
  String? note;

  @HiveField(5)
  String? sourceRef;

  GoalEntry({
    required this.id,
    required this.goalId,
    required this.date,
    required this.amount,
    this.note,
    this.sourceRef,
  });
}
