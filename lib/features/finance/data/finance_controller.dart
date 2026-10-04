import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/budget_engine.dart';
import 'package:habit_tracker/features/finance/engine/goal_planner_engine.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Reactive controller that exposes memoised financial data, month indexes,
/// and reactive updates for the UI.
class FinanceController extends ChangeNotifier {
  static final FinanceController _instance = FinanceController._internal();
  factory FinanceController() => _instance;

  final FinanceStorage storage;
  final FinanceRepository repository;

  final Map<String, List<Transaction>> _monthIndex = {};
  bool _isIndexDirty = true;

  FinanceController._internal(
      {FinanceStorage? storage, FinanceRepository? repository})
      : storage = storage ?? FinanceStorage(),
        repository = repository ??
            FinanceRepository(storage: storage ?? FinanceStorage()) {
    this.repository.changes.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    _isIndexDirty = true;
    notifyListeners();
  }

  void rebuildIndexIfNeeded() {
    if (!_isIndexDirty) return;
    _monthIndex.clear();

    final allTx = storage.transactionBox.values.toList();
    for (final tx in allTx) {
      final key = DateFormat('yyyy-MM').format(tx.date);
      _monthIndex.putIfAbsent(key, () => []).add(tx);
    }

    // Sort each month by date descending
    for (final list in _monthIndex.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }

    _isIndexDirty = false;
  }

  List<Transaction> getTransactionsForMonth(DateTime month) {
    rebuildIndexIfNeeded();
    final key = DateFormat('yyyy-MM').format(month);
    return _monthIndex[key] ?? [];
  }

  /// Computes the net worth as of [asOf].
  double getNetWorth({DateTime? asOf}) {
    final accounts = storage.accountBox.values;
    final transactions = storage.transactionBox.values;
    final valuations = storage.valuationBox.values;
    final receivables = LedgerEngine.receivablesFromSplits(transactions);

    return LedgerEngine.netWorth(
      accounts,
      transactions,
      valuations,
      asOf: asOf,
      unsettledReceivables: receivables,
    );
  }

  /// Computes month income for [month].
  double getMonthIncome(DateTime month) {
    final txs = getTransactionsForMonth(month);
    return LedgerEngine.income(txs);
  }

  /// Computes month spending for [month].
  double getMonthSpending(DateTime month) {
    final txs = getTransactionsForMonth(month);
    return LedgerEngine.spending(txs);
  }

  /// Category breakdown for [month].
  Map<String, double> getCategoryBreakdown(DateTime month) {
    final txs = getTransactionsForMonth(month);
    return LedgerEngine.categorySpending(txs);
  }

  /// Computes total balance across all spendable liquid accounts.
  double getLiquidBalance({DateTime? asOf}) {
    final accounts = storage.accountBox.values
        .where((a) => a.spendable && !a.archived && !a.isLiability);
    final transactions = storage.transactionBox.values;
    final valuations = storage.valuationBox.values;

    double sum = 0.0;
    for (final acc in accounts) {
      sum += LedgerEngine.balance(acc, transactions, valuations, asOf: asOf);
    }
    return Money.r2(sum);
  }

  /// Returns all transactions sorted by date descending.
  List<Transaction> get allTransactions {
    rebuildIndexIfNeeded();
    final list = storage.transactionBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Returns all active (non-archived) accounts.
  List<Account> get activeAccounts =>
      storage.accountBox.values.where((a) => !a.archived).toList();

  /// Returns all active (non-archived) categories.
  List<Category> get activeCategories =>
      storage.categoryBox.values.where((c) => !c.archived).toList();

  /// Map of category ID to Category model.
  Map<String, Category> get categoriesMap => {
        for (final c in storage.categoryBox.values) c.id: c,
      };

  /// Map of account ID to Account model.
  Map<String, Account> get accountsMap => {
        for (final a in storage.accountBox.values) a.id: a,
      };

  /// Set of distinct merchants recorded in history (for autocomplete).
  Set<String> get allMerchants {
    final set = <String>{};
    for (final tx in storage.transactionBox.values) {
      final m = tx.merchant?.trim();
      if (m != null && m.isNotEmpty) {
        set.add(m);
      }
    }
    return set;
  }

  /// Set of distinct tags used in transactions.
  Set<String> get allTags {
    final set = <String>{};
    for (final tx in storage.transactionBox.values) {
      if (tx.tags != null) {
        for (final t in tx.tags!) {
          final trimmed = t.trim();
          if (trimmed.isNotEmpty) set.add(trimmed);
        }
      }
    }
    return set;
  }

  /// The most recent transaction, if any.
  Transaction? get lastTransaction {
    final all = allTransactions;
    return all.isEmpty ? null : all.first;
  }

  /// Looks up a category by ID.
  Category? getCategory(String? id) {
    if (id == null) return null;
    return categoriesMap[id];
  }

  /// Looks up an account by ID.
  Account? getAccount(String? id) {
    if (id == null) return null;
    return accountsMap[id];
  }

  /// Computes the balance of a specific [account] as of [asOf].
  double getAccountBalance(Account account, {DateTime? asOf}) {
    return LedgerEngine.balance(
      account,
      storage.transactionBox.values,
      storage.valuationBox.values,
      asOf: asOf,
    );
  }

  /// Returns all active asset accounts.
  List<Account> get assetAccounts =>
      activeAccounts.where((a) => !a.isLiability).toList();

  /// Returns all active liability accounts.
  List<Account> get liabilityAccounts =>
      activeAccounts.where((a) => a.isLiability).toList();

  /// Sum of all active asset accounts.
  double get totalAssets {
    double sum = 0.0;
    for (final a in assetAccounts) {
      sum += getAccountBalance(a);
    }
    return Money.r2(sum);
  }

  /// Sum of all active liability accounts (positive magnitude).
  double get totalLiabilities {
    double sum = 0.0;
    for (final a in liabilityAccounts) {
      final bal = getAccountBalance(a);
      sum += bal.abs();
    }
    return Money.r2(sum);
  }

  /// Net worth change vs end of previous month.
  double getNetWorthChangeVsLastMonth() {
    final now = DateTime.now();
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final current = getNetWorth(asOf: now);
    final last = getNetWorth(asOf: lastMonthEnd);
    return Money.r2(current - last);
  }

  /// Net worth percentage change vs end of previous month.
  double getNetWorthChangePercentVsLastMonth() {
    final now = DateTime.now();
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final current = getNetWorth(asOf: now);
    final last = getNetWorth(asOf: lastMonthEnd);
    if (last == 0) return 0.0;
    return Money.r2(((current - last) / last.abs()) * 100);
  }

  /// Net worth history points over the last [months] months.
  List<MapEntry<DateTime, double>> getNetWorthHistory(
      {int months = 12, DateTime? asOf}) {
    return LedgerEngine.netWorthHistory(
      accounts: storage.accountBox.values,
      transactions: storage.transactionBox.values,
      valuations: storage.valuationBox.values,
      months: months,
      asOf: asOf,
    );
  }

  /// Account balance history over the last [months] months.
  List<MapEntry<DateTime, double>> getAccountBalanceHistory(Account account,
      {int months = 6, DateTime? asOf}) {
    return LedgerEngine.accountBalanceHistory(
      account: account,
      transactions: storage.transactionBox.values,
      valuations: storage.valuationBox.values,
      months: months,
      asOf: asOf,
    );
  }

  /// Filtered transactions for a given account ID.
  List<Transaction> getTransactionsForAccount(String accountId) {
    return allTransactions
        .where(
            (tx) => tx.accountId == accountId || tx.toAccountId == accountId)
        .toList();
  }

  /// Valuations for an account sorted descending by date.
  List<Valuation> getValuationsForAccount(String accountId) {
    return repository.getValuations(accountId);
  }

  /// Total invested amount in a valued asset.
  double getInvestedAmount(Account account, {DateTime? asOf}) {
    return LedgerEngine.investedAmount(
      account,
      storage.transactionBox.values,
      asOf: asOf,
    );
  }

  /// Gain or loss on a valued asset.
  double getGainLoss(Account account, {DateTime? asOf}) {
    final cur = getAccountBalance(account, asOf: asOf);
    final inv = getInvestedAmount(account, asOf: asOf);
    return Money.r2(cur - inv);
  }

  /// Return percentage on a valued asset.
  double getReturnPct(Account account, {DateTime? asOf}) {
    final inv = getInvestedAmount(account, asOf: asOf);
    if (inv <= 0) return 0.0;
    final gl = getGainLoss(account, asOf: asOf);
    return Money.r2((gl / inv) * 100);
  }

  // ---------------------------------------------------------------------------
  // BUDGETING (P4)
  // ---------------------------------------------------------------------------

  List<BudgetLine> get allBudgetLines => repository.getAllBudgetLines();

  BudgetLine? getBudgetLineForCategory(String categoryId) {
    for (final line in allBudgetLines) {
      if (line.categoryId == categoryId) return line;
    }
    return null;
  }

  double getEffectiveBudget(BudgetLine line, String monthKey) {
    return BudgetEngine.effectiveBudget(
      line: line,
      monthKey: monthKey,
      transactions: storage.transactionBox.values,
      overrides: repository.getAllBudgetOverrides(),
      rolloverCarryNegative: repository.getRolloverCarryNegative(),
    );
  }

  double getCategoryMonthSpent(String categoryId, DateTime month) {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return LedgerEngine.spending(
      storage.transactionBox.values,
      from: from,
      to: to,
      categoryId: categoryId,
    );
  }

  double getCategoryProjectedSpend(String categoryId, DateTime currentDate) {
    return BudgetEngine.projectedCategorySpend(
      categoryId: categoryId,
      currentDate: currentDate,
      transactions: storage.transactionBox.values,
    );
  }

  double getRecommendedWeeklyCut(double projectedSpend, double budgetLimit, DateTime currentDate) {
    return BudgetEngine.recommendedWeeklyCut(
      projectedSpend: projectedSpend,
      budgetLimit: budgetLimit,
      currentDate: currentDate,
    );
  }

  BudgetStatus getBudgetStatus(BudgetLine line, DateTime currentDate) {
    final monthKey = DateFormat('yyyy-MM').format(currentDate);
    final eff = getEffectiveBudget(line, monthKey);
    final spent = getCategoryMonthSpent(line.categoryId ?? '', currentDate);
    final proj = getCategoryProjectedSpend(line.categoryId ?? '', currentDate);
    return BudgetEngine.evaluateStatus(
      effectiveBudget: eff,
      spent: spent,
      projectedSpend: proj,
      currentDate: currentDate,
    );
  }

  String get budgetMode => repository.getBudgetMode();
  Future<void> setBudgetMode(String mode) => repository.setBudgetMode(mode);

  double? get expectedIncome => repository.getExpectedIncome();
  Future<void> setExpectedIncome(double income) => repository.setExpectedIncome(income);

  bool get rolloverCarryNegative => repository.getRolloverCarryNegative();
  Future<void> setRolloverCarryNegative(bool val) => repository.setRolloverCarryNegative(val);

  Map<String, double> get budgetOverrides => repository.getAllBudgetOverrides();
  Future<void> setBudgetOverride(String lineId, String monthKey, double amount) =>
      repository.setBudgetOverride(lineId, monthKey, amount);
  Future<void> removeBudgetOverride(String lineId, String monthKey) =>
      repository.removeBudgetOverride(lineId, monthKey);

  Future<BudgetLine> setBudgetLine(BudgetLine line) => repository.setBudgetLine(line);
  Future<void> deleteBudgetLine(String id) => repository.deleteBudgetLine(id);

  Map<String, BudgetGroupProgress> get50_30_20Breakdown(DateTime month, {double? expectedIncome}) {
    final income = expectedIncome ?? this.expectedIncome ?? _estimateIncome(month);
    final txs = getTransactionsForMonth(month);
    final categories = {for (var c in storage.categoryBox.values) c.id: c};

    double goalSavings = 0.0;
    for (final ge in storage.goalEntryBox.values) {
      if (ge.date.year == month.year && ge.date.month == month.month) {
        goalSavings += ge.amount;
      }
    }

    return BudgetEngine.compute50_30_20(
      expectedIncome: income,
      monthTransactions: txs,
      categories: categories,
      goalSavingsActual: goalSavings > 0 ? goalSavings : 0.0,
    );
  }

  double _estimateIncome(DateTime month) {
    // 3-month average income
    double sum = 0.0;
    for (int i = 1; i <= 3; i++) {
      final m = DateTime(month.year, month.month - i, 1);
      final from = DateTime(m.year, m.month, 1);
      final to = DateTime(m.year, m.month + 1, 0, 23, 59, 59);
      sum += LedgerEngine.income(storage.transactionBox.values, from: from, to: to);
    }
    final avg = sum / 3.0;
    return avg > 0 ? avg : 50000.0; // Sensible default if no data
  }

  double getZeroBasedLeftToAssign(DateTime month, {double? expectedIncome}) {
    final income = expectedIncome ?? this.expectedIncome ?? _estimateIncome(month);
    final lines = allBudgetLines;
    final extraBuckets = <double>[];
    for (final goal in storage.goalBox.values) {
      if (!goal.archived && goal.plannedMonthly != null && goal.plannedMonthly! > 0) {
        extraBuckets.add(goal.plannedMonthly!);
      }
    }
    return BudgetEngine.zeroBasedLeftToAssign(
      expectedIncome: income,
      lines: lines,
      extraBuckets: extraBuckets,
    );
  }

  Future<void> checkAndTriggerBudgetAlerts({DateTime? currentDate}) async {
    final now = currentDate ?? DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final monthKey = DateFormat('yyyy-MM').format(now);
    final alertsEnabled = storage.settingsBox.get('budget_alerts_enabled', defaultValue: true);
    if (!alertsEnabled) return;

    for (final line in allBudgetLines) {
      if (line.categoryId == null) continue;
      final category = storage.categoryBox.get(line.categoryId);
      final catName = category?.name ?? 'Category';
      final eff = getEffectiveBudget(line, monthKey);
      if (eff <= 0) continue;

      final spent = getCategoryMonthSpent(line.categoryId!, now);
      final proj = getCategoryProjectedSpend(line.categoryId!, now);

      // Check 100% overspend
      if (spent >= eff) {
        final alertKey = 'alert_100_${line.id}_$monthKey';
        if (storage.settingsBox.get(alertKey) == null) {
          await storage.settingsBox.put(alertKey, todayKey);
          await NotificationService().showInstantNotification(
            id: line.id.hashCode & 0x7FFFFFFF,
            title: 'Budget Exceeded: $catName',
            body: 'You have spent ${FormatUtils.formatMoney(spent)} of your ${FormatUtils.formatMoney(eff)} budget.',
          );
        }
      } else if (spent >= eff * 0.8) {
        // Check 80% threshold
        final alertKey = 'alert_80_${line.id}_$monthKey';
        if (storage.settingsBox.get(alertKey) == null) {
          await storage.settingsBox.put(alertKey, todayKey);
          await NotificationService().showInstantNotification(
            id: (line.id.hashCode + 80) & 0x7FFFFFFF,
            title: 'Budget Alert: $catName',
            body: 'You have used 80% of your ${FormatUtils.formatMoney(eff)} budget (${FormatUtils.formatMoney(spent)} spent).',
          );
        }
      }

      // Check Pace alert (at most once per day globally)
      if (proj > eff && spent < eff) {
        final lastPaceAlert = storage.settingsBox.get('last_pace_alert_date');
        if (lastPaceAlert != todayKey) {
          await storage.settingsBox.put('last_pace_alert_date', todayKey);
          final over = proj - eff;
          await NotificationService().showInstantNotification(
            id: (line.id.hashCode + 999) & 0x7FFFFFFF,
            title: 'Pace Warning: $catName',
            body: 'At your current pace, you are projected to exceed your budget by ${FormatUtils.formatMoney(over)}.',
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GOALS & SINKING FUNDS (P5)
  // ---------------------------------------------------------------------------

  List<SavingsGoal> get allGoals => repository.getAllGoals();

  List<SavingsGoal> get activeGoals =>
      allGoals.where((g) => !g.archived && g.kind != 'sinking_fund').toList();

  List<SavingsGoal> get activeSinkingFunds =>
      allGoals.where((g) => !g.archived && g.kind == 'sinking_fund').toList();

  double getGoalSaved(String goalId) {
    return GoalPlannerEngine.totalSaved(repository.getGoalEntries(goalId));
  }

  List<GoalEntry> getGoalEntries(String goalId) {
    return repository.getGoalEntries(goalId);
  }

  Future<SavingsGoal> addGoal(SavingsGoal goal) => repository.addGoal(goal);

  Future<void> updateGoal(SavingsGoal goal) => repository.updateGoal(goal);

  Future<void> deleteGoal(String id) => repository.deleteGoal(id);

  Future<GoalEntry> addGoalContribution({
    required String goalId,
    required double amount,
    DateTime? date,
    String? note,
  }) =>
      repository.addGoalContribution(
        goalId: goalId,
        amount: amount,
        date: date,
        note: note,
      );

  Future<void> deleteGoalEntry(String id) => repository.deleteGoalEntry(id);

  Future<List<GoalEntry>> runAutoContribute({DateTime? now}) =>
      repository.runAutoContribute(now: now);

  GoalPlan planGoal(SavingsGoal goal, {DateTime? currentDate}) {
    final budgetLineMap = <String, BudgetLine>{};
    for (final l in allBudgetLines) {
      if (l.categoryId != null) {
        budgetLineMap[l.categoryId!] = l;
      }
    }

    final catMap = {for (var c in storage.categoryBox.values) c.id: c};

    return GoalPlannerEngine.planGoal(
      goal: goal,
      goalEntries: storage.goalEntryBox.values,
      transactions: storage.transactionBox.values,
      categories: catMap,
      budgetLines: budgetLineMap,
      currentDate: currentDate ?? DateTime.now(),
    );
  }

  Future<void> applyTrimSuggestions(List<TrimSuggestion> suggestions) async {
    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);

    for (final s in suggestions) {
      final existing = getBudgetLineForCategory(s.categoryId);
      if (existing != null) {
        final updated = BudgetLine(
          id: existing.id,
          categoryId: existing.categoryId,
          bucketRef: existing.bucketRef,
          amount: s.newBudget,
          rollover: existing.rollover,
          essential: existing.essential,
          startMonth: existing.startMonth,
        );
        await setBudgetLine(updated);
      } else {
        final newLine = BudgetLine(
          id: 'bl_${DateTime.now().millisecondsSinceEpoch}_${s.categoryId}',
          categoryId: s.categoryId,
          amount: s.newBudget,
          rollover: false,
          essential: false,
          startMonth: monthKey,
        );
        await setBudgetLine(newLine);
      }
    }
    notifyListeners();
  }
}

