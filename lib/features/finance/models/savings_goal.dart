import 'package:hive/hive.dart';

part 'savings_goal.g.dart';

@HiveType(typeId: 46)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// kind: 'goal', 'sinking_fund'
  @HiveField(2)
  String kind;

  @HiveField(3)
  double targetAmount;

  @HiveField(4)
  DateTime? deadline;

  @HiveField(5)
  DateTime? dueDate;

  @HiveField(6)
  String? accountId; // earmark account

  @HiveField(7)
  int colorValue;

  @HiveField(8)
  int priority;

  @HiveField(9)
  bool autoContribute;

  @HiveField(10)
  double? plannedMonthly;

  @HiveField(11)
  String? linkedCategoryId;

  @HiveField(12)
  bool archived;

  SavingsGoal({
    required this.id,
    required this.name,
    this.kind = 'goal',
    required this.targetAmount,
    this.deadline,
    this.dueDate,
    this.accountId,
    required this.colorValue,
    this.priority = 1,
    this.autoContribute = false,
    this.plannedMonthly,
    this.linkedCategoryId,
    this.archived = false,
  });

  bool get isSinkingFund => kind == 'sinking_fund';
}
