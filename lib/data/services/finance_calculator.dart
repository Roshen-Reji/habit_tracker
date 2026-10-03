import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/models/finance_model.dart';

/// Pure calculation service for finance snapshots and totals.
class FinanceCalculator {
  static double asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static bool isExpense(Transaction tx) {
    final mode = tx.mode.toLowerCase();
    return mode == 'expense' || tx.amount < 0;
  }

  static bool sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// Calculates the full FinanceSnapshot from transaction, vault, and settings boxes.
  static FinanceSnapshot calculate({
    Iterable<Transaction>? transactions,
    Iterable<AssetVault>? vaults,
    Box? settings,
    DateTime? selectedMonth,
  }) {
    final txList = transactions ??
        (Hive.isBoxOpen('finance_transactions')
            ? Hive.box<Transaction>('finance_transactions').values
            : <Transaction>[]);
    final vaultList = vaults ??
        (Hive.isBoxOpen('finance_vaults')
            ? Hive.box<AssetVault>('finance_vaults').values
            : <AssetVault>[]);
    final settingsBox = settings ??
        (Hive.isBoxOpen('finance_settings')
            ? Hive.box('finance_settings')
            : null);

    final targetMonth = selectedMonth ?? DateTime.now();

    double allTimeNet = 0;
    double monthIncome = 0;
    double monthExpense = 0;
    final categorySpent = <String, double>{};
    final monthTransactions = <Transaction>[];

    for (final tx in txList) {
      final expense = isExpense(tx);
      final signedAmount = expense ? -tx.amount.abs() : tx.amount.abs();
      allTimeNet += signedAmount;

      if (sameMonth(tx.date, targetMonth)) {
        monthTransactions.add(tx);
        if (expense) {
          final amount = tx.amount.abs();
          monthExpense += amount;
          categorySpent[tx.category] =
              (categorySpent[tx.category] ?? 0) + amount;
        } else {
          monthIncome += tx.amount.abs();
        }
      }
    }

    monthTransactions.sort((a, b) => b.date.compareTo(a.date));

    final budgets = settingsBox != null
        ? List.from(settingsBox.get('budgets', defaultValue: []))
        : [];
    final goals = settingsBox != null
        ? List.from(settingsBox.get('goals', defaultValue: []))
        : [];
    final planner = settingsBox != null
        ? Map.from(settingsBox.get(
            'planner',
            defaultValue: {'fixedExpenses': [], 'sips': []},
          ))
        : {'fixedExpenses': [], 'sips': []};

    final fixed = List.from(planner['fixedExpenses'] ?? []);
    final sips = List.from(planner['sips'] ?? []);

    final vaultTotal =
        vaultList.fold<double>(0, (sum, vault) => sum + vault.balance);
    final goalsSaved = goals.fold<double>(
        0, (sum, item) => sum + asDouble((item as Map)['saved']));
    final goalsTarget = goals.fold<double>(
        0, (sum, item) => sum + asDouble((item as Map)['target']));
    final fixedTotal = fixed.fold<double>(
        0, (sum, item) => sum + asDouble((item as Map)['amount']));
    final sipTotal = sips.fold<double>(
        0, (sum, item) => sum + asDouble((item as Map)['amount']));
    final budgetLimit = budgets.fold<double>(
        0, (sum, item) => sum + asDouble((item as Map)['total']));
    final budgetSpent = budgets.fold<double>(0, (sum, item) {
      final category = (item as Map)['category']?.toString() ?? 'Other';
      return sum + (categorySpent[category] ?? 0);
    });

    final categoryBreakdown = categorySpent.entries
        .map((entry) => {'name': entry.key, 'value': entry.value})
        .toList()
      ..sort((a, b) => asDouble(b['value']).compareTo(asDouble(a['value'])));

    final savingsRate = monthIncome <= 0
        ? 0.0
        : ((monthIncome - monthExpense) / monthIncome).clamp(0.0, 1.0);

    // Cash flow trend for past 6 months
    final buckets = <String, Map<String, double>>{};
    for (var i = 5; i >= 0; i--) {
      final date = DateTime(targetMonth.year, targetMonth.month - i, 1);
      buckets[DateFormat('MMM').format(date)] = {'income': 0, 'expense': 0};
    }

    for (final tx in txList) {
      final key =
          DateFormat('MMM').format(DateTime(tx.date.year, tx.date.month, 1));
      final bucket = buckets[key];
      if (bucket == null) continue;
      if (isExpense(tx)) {
        bucket['expense'] = bucket['expense']! + tx.amount.abs();
      } else {
        bucket['income'] = bucket['income']! + tx.amount.abs();
      }
    }

    final cashFlowTrend = buckets.entries
        .map((entry) => {
              'month': entry.key,
              'income': entry.value['income'] ?? 0.0,
              'expense': entry.value['expense'] ?? 0.0,
            })
        .toList();

    return FinanceSnapshot(
      totalBalance: vaultTotal + allTimeNet + goalsSaved,
      monthIncome: monthIncome,
      monthExpense: monthExpense,
      monthNet: monthIncome - monthExpense,
      savingsRate: savingsRate,
      vaultTotal: vaultTotal,
      goalsSaved: goalsSaved,
      goalsTarget: goalsTarget,
      fixedTotal: fixedTotal,
      sipTotal: sipTotal,
      budgetLimit: budgetLimit,
      budgetSpent: budgetSpent,
      categorySpent: categorySpent,
      categoryBreakdown: categoryBreakdown,
      monthTransactions: monthTransactions,
      budgets: budgets,
      goals: goals,
      planner: planner,
      cashFlowTrend: cashFlowTrend,
    );
  }
}
