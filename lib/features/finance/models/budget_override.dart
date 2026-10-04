import 'package:hive/hive.dart';

part 'budget_override.g.dart';

@HiveType(typeId: 45)
class BudgetOverride extends HiveObject {
  @HiveField(0)
  String lineId;

  /// Month key in 'yyyy-MM'
  @HiveField(1)
  String monthKey;

  @HiveField(2)
  double amount;

  BudgetOverride({
    required this.lineId,
    required this.monthKey,
    required this.amount,
  });
}
