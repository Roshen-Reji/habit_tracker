import 'package:hive/hive.dart';

part 'budget_line.g.dart';

@HiveType(typeId: 44)
class BudgetLine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? categoryId;

  @HiveField(2)
  String? bucketRef; // goalId for zero-based buckets

  @HiveField(3)
  double amount;

  @HiveField(4)
  bool rollover;

  @HiveField(5)
  bool essential;

  /// Start month in 'yyyy-MM'
  @HiveField(6)
  String startMonth;

  BudgetLine({
    required this.id,
    this.categoryId,
    this.bucketRef,
    required this.amount,
    this.rollover = false,
    this.essential = false,
    required this.startMonth,
  });
}
