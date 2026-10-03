import 'package:hive/hive.dart';

part 'finance_model.g.dart';

@HiveType(typeId: 10)
class Transaction extends HiveObject {
  @HiveField(0)
  String title;
  @HiveField(1)
  double amount;
  @HiveField(2)
  String category;
  @HiveField(3)
  DateTime date;
  @HiveField(4)
  String mode;
  @HiveField(5)
  String icon;

  Transaction(
      {required this.title,
      required this.amount,
      required this.category,
      required this.date,
      required this.mode,
      required this.icon});
}

@HiveType(typeId: 11)
class AssetVault extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  double balance;
  @HiveField(2)
  String bank;
  @HiveField(3)
  String type;
  @HiveField(4)
  int colorValue;

  AssetVault(
      {required this.name,
      required this.balance,
      required this.bank,
      required this.type,
      required this.colorValue});
}

class FinanceSnapshot {
  final double totalBalance;
  final double monthIncome;
  final double monthExpense;
  final double monthNet;
  final double savingsRate;
  final double vaultTotal;
  final double goalsSaved;
  final double goalsTarget;
  final double fixedTotal;
  final double sipTotal;
  final double budgetLimit;
  final double budgetSpent;
  final Map<String, double> categorySpent;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Transaction> monthTransactions;
  final List budgets;
  final List goals;
  final Map planner;
  final List<Map<String, dynamic>> cashFlowTrend;

  const FinanceSnapshot({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthNet,
    required this.savingsRate,
    required this.vaultTotal,
    required this.goalsSaved,
    required this.goalsTarget,
    required this.fixedTotal,
    required this.sipTotal,
    required this.budgetLimit,
    required this.budgetSpent,
    required this.categorySpent,
    required this.categoryBreakdown,
    required this.monthTransactions,
    required this.budgets,
    required this.goals,
    required this.planner,
    required this.cashFlowTrend,
  });
}
