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

  // MVP 3 additions (typeId 10, fields 6-22)
  @HiveField(6)
  String? id;
  @HiveField(7)
  String?
      kind; // expense, income, transfer, refund, investment, debt_payment, adjustment, reimbursement
  @HiveField(8)
  String? accountId;
  @HiveField(9)
  String? toAccountId;
  @HiveField(10)
  String? categoryId;
  @HiveField(11)
  String? merchant;
  @HiveField(12)
  String? paymentMethod; // UPI, Card, Cash, NetBanking, Other
  @HiveField(13)
  String? notes;
  @HiveField(14)
  List<String>? tags;
  @HiveField(15)
  String?
      splits; // JSON: [{"categoryId": "...", "amount": 100.0, "note": "...", "isOwed": false, "counterparty": "Alice"}]
  @HiveField(16)
  List<String>? receiptPaths;
  @HiveField(17)
  String? recurringRuleId;
  @HiveField(18)
  String? sourceRef; // rec:{ruleId}:{yyyy-MM-dd} or import:{hash}
  @HiveField(19)
  DateTime? createdAt;
  @HiveField(20)
  String? goalId;
  @HiveField(21)
  double? interestAmount; // principal vs interest in debt payments
  @HiveField(22)
  String? refundOfId;

  Transaction({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.mode,
    required this.icon,
    this.id,
    this.kind,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.merchant,
    this.paymentMethod,
    this.notes,
    this.tags,
    this.splits,
    this.receiptPaths,
    this.recurringRuleId,
    this.sourceRef,
    this.createdAt,
    this.goalId,
    this.interestAmount,
    this.refundOfId,
  });

  /// Resolves the effective kind, falling back to legacy mode / amount sign if kind is null.
  String get effectiveKind {
    if (kind != null && kind!.isNotEmpty) return kind!;
    final m = mode.toLowerCase();
    if (m == 'expense' || amount < 0) return 'expense';
    return 'income';
  }

  bool get isExpenseKind => effectiveKind == 'expense';
  bool get isIncomeKind => effectiveKind == 'income';
  bool get isTransferKind => effectiveKind == 'transfer';
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

  AssetVault({
    required this.name,
    required this.balance,
    required this.bank,
    required this.type,
    required this.colorValue,
  });
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
