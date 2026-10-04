import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/budget_engine.dart';
import 'package:habit_tracker/features/finance/engine/goal_planner_engine.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/loan_engine.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/engine/constants.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/health_score_engine.dart';
import 'package:habit_tracker/features/finance/engine/insights_engine.dart';
import 'package:habit_tracker/features/finance/engine/report_engine.dart';
import 'package:habit_tracker/features/finance/engine/what_if_engine.dart';
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

  // ---------------------------------------------------------------------------
  // RECURRING, BILLS & SUBSCRIPTIONS (P6)
  // ---------------------------------------------------------------------------

  List<RecurringRule> get allRecurringRules => repository.getAllRecurringRules();

  List<RecurringRule> get activeRecurringRules =>
      allRecurringRules.where((r) => r.status == 'active').toList();

  Future<RecurringRule> addRecurringRule(RecurringRule rule) =>
      repository.addRecurringRule(rule);

  Future<void> updateRecurringRule(RecurringRule rule) =>
      repository.updateRecurringRule(rule);

  Future<void> deleteRecurringRule(String id) =>
      repository.deleteRecurringRule(id);

  Future<List<Transaction>> postRecurringDue({DateTime? now}) =>
      repository.postRecurringDue(now: now);

  List<DueItem> getUnpostedDueItems({DateTime? now}) =>
      repository.getUnpostedDueItems(now: now);

  Future<Transaction> markRecurringPaid(
    DueItem item, {
    DateTime? paidDate,
    String? accountId,
    double? amount,
  }) =>
      repository.markRecurringPaid(
        item,
        paidDate: paidDate,
        accountId: accountId,
        amount: amount,
      );

  Future<void> scheduleRecurringReminders({DateTime? now}) =>
      repository.scheduleRecurringReminders(now: now);

  List<DetectedSubscription> getDetectedSubscriptions({DateTime? currentDate}) {
    final rawDismissed = storage.settingsBox.get('dismissed_sub_suggestions');
    final dismissed = rawDismissed is List
        ? rawDismissed.cast<String>().toSet()
        : <String>{};

    return RecurringEngine.detectSubscriptions(
      transactions: storage.transactionBox.values,
      currentDate: currentDate ?? DateTime.now(),
      dismissedSuggestions: dismissed,
    );
  }

  Future<void> dismissSubscriptionSuggestion(String normMerchant) async {
    final raw = storage.settingsBox.get('dismissed_sub_suggestions');
    final list = raw is List ? List<String>.from(raw) : <String>[];
    if (!list.contains(normMerchant)) {
      list.add(normMerchant);
      await storage.settingsBox.put('dismissed_sub_suggestions', list);
      notifyListeners();
    }
  }

  double getMonthlyRecurringTotal() {
    double total = 0.0;
    for (final rule in activeRecurringRules) {
      if (rule.kind == 'income') continue;
      final amt = rule.amount;
      if (rule.frequency == 'weekly') {
        total += amt * 4.33;
      } else if (rule.frequency == 'quarterly') {
        total += amt / 3.0;
      } else if (rule.frequency == 'yearly') {
        total += amt / 12.0;
      } else {
        total += amt;
      }
    }
    return Money.r2(total);
  }

  // ---------------------------------------------------------------------------
  // DEBT & CREDIT CARDS (P7)
  // ---------------------------------------------------------------------------

  List<Account> get loanAccounts => allAccounts
      .where((a) =>
          !a.archived &&
          (a.kind == 'loan' || a.kind == 'bnpl' || a.kind == 'other_debt'))
      .toList();

  List<Account> get creditCardAccounts => allAccounts
      .where((a) => !a.archived && a.kind == 'credit_card')
      .toList();

  double getTotalDebt({DateTime? asOf}) => totalLiabilities.abs();

  double getWeightedAverageInterestRate() {
    double totalBal = 0.0;
    double weightedRateSum = 0.0;

    for (final l in loanAccounts) {
      final bal = getAccountBalance(l).abs();
      final rate = l.annualRate ?? 10.0;
      if (bal > 0) {
        totalBal += bal;
        weightedRateSum += bal * rate;
      }
    }

    if (totalBal <= 0) return 0.0;
    return Money.r2(weightedRateSum / totalBal);
  }

  double getTotalMonthlyEmiObligation() {
    double total = 0.0;
    for (final l in loanAccounts) {
      if (l.emi != null && l.emi! > 0) {
        total += l.emi!;
      } else {
        final bal = getAccountBalance(l).abs();
        if (bal > 0) {
          total += LoanEngine.calculateEmi(
            principal: bal,
            annualRatePct: l.annualRate ?? 10.0,
            tenureMonths: l.tenureMonths ?? 60,
          );
        }
      }
    }
    return Money.r2(total);
  }

  ({PayoffComparison avalanche, PayoffComparison snowball}) comparePayoffStrategies({
    double? totalMonthlyBudget,
    DateTime? startDate,
  }) {
    final balances = <String, double>{
      for (final l in loanAccounts) l.id: getAccountBalance(l).abs(),
    };

    final budget = totalMonthlyBudget ?? (getTotalMonthlyEmiObligation() * 1.2);

    return LoanEngine.comparePayoffStrategies(
      loans: loanAccounts,
      currentBalances: balances,
      totalMonthlyBudget: budget > 0 ? budget : 10000.0,
      startDate: startDate ?? DateTime.now(),
    );
  }

  ExtraPaymentSimulation simulateExtraPayment(
    Account loan,
    double extraPayment,
  ) {
    final bal = getAccountBalance(loan).abs();
    final rate = loan.annualRate ?? 10.0;
    final emi = loan.emi ??
        LoanEngine.calculateEmi(
          principal: bal,
          annualRatePct: rate,
          tenureMonths: loan.tenureMonths ?? 60,
        );

    return LoanEngine.simulateExtraPayment(
      principal: bal,
      annualRatePct: rate,
      emi: emi,
      extraPaymentPerMonth: extraPayment,
    );
  }

  LoanSchedule getAmortizationSchedule(Account loan, {double extraPayment = 0.0}) {
    final bal = getAccountBalance(loan).abs();
    final rate = loan.annualRate ?? 10.0;
    final emi = loan.emi ??
        LoanEngine.calculateEmi(
          principal: bal,
          annualRatePct: rate,
          tenureMonths: loan.tenureMonths ?? 60,
        );

    return LoanEngine.generateSchedule(
      principal: bal,
      annualRatePct: rate,
      emi: emi,
      extraPayment: extraPayment,
    );
  }

  // ==========================================
  // PHASE 8: INTELLIGENCE & FORECAST
  // ==========================================

  /// P8-3: Safe to spend calculation
  /// S = liquid - O - G - P - C
  SafeToSpendResult getSafeToSpend({DateTime? asOf, DateTime? horizon}) {
    final today = asOf ?? DateTime.now();
    final effectiveHorizon = horizon ?? DateTime(today.year, today.month + 1, 0);
    final liquid = getLiquidBalance(asOf: today);

    // O: obligations in (today, horizon]
    // Unposted active non-income recurring rules, excluding card payment transfers
    double obligations = 0.0;
    final cardAccountIds = creditCardAccounts.map((a) => a.id).toSet();
    final activeRules = storage.recurringBox.values.where((r) => r.status == 'active');

    for (final rule in activeRules) {
      if (rule.kind == 'income') continue;
      if (rule.kind == 'transfer' && rule.toAccountId != null && cardAccountIds.contains(rule.toAccountId)) {
        continue;
      }
      final occurrences = RecurringEngine.occurrences(
        rule: rule,
        from: today.add(const Duration(days: 1)),
        to: effectiveHorizon,
      );
      for (final occ in occurrences) {
        final dateKey = DateFormat('yyyy-MM-dd').format(occ);
        final sourceRef = 'rec:${rule.id}:$dateKey';
        final isPosted = storage.transactionBox.values.any((t) => t.sourceRef == sourceRef);
        if (!isPosted) {
          obligations += rule.amount;
        }
      }
    }

    // G: goals/fund contributions not yet contributed this month
    double goalsEarmark = 0.0;
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0, 23, 59, 59);

    for (final goal in activeGoals) {
      final planned = goal.plannedMonthly ??
          GoalPlannerEngine.calculateRequiredMonthly(
            target: goal.targetAmount,
            saved: getGoalSavedAmount(goal),
            deadline: goal.deadlineDate,
            asOf: today,
          );

      final thisMonthContributions = storage.goalEntryBox.values
          .where((e) =>
              e.goalId == goal.id &&
              e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(monthEnd.add(const Duration(seconds: 1))))
          .fold(0.0, (sum, e) => sum + e.amount);

      final remainingGoalNeed = (planned - thisMonthContributions).clamp(0.0, double.infinity);
      goalsEarmark += remainingGoalNeed;
    }

    // P: planned essential budget lines
    // max(0, effective - spent - unpostedRecurringInThatCategory)
    double plannedEssential = 0.0;
    final budgetLines = storage.budgetLineBox.values.where((b) => b.essential);
    for (final line in budgetLines) {
      if (line.categoryId == null) continue;
      final effective = BudgetEngine.effectiveBudget(
        line: line,
        month: today,
        overrides: storage.budgetOverrideBox.values.toList(),
        spentProvider: (l, m) => getCategorySpendingForMonth(l.categoryId, m),
      );
      final spent = getCategorySpendingForMonth(line.categoryId, today);

      double unpostedCatRecurring = 0.0;
      for (final rule in activeRules) {
        if (rule.categoryId == line.categoryId && rule.kind != 'income') {
          final occs = RecurringEngine.occurrences(
            rule: rule,
            from: today.add(const Duration(days: 1)),
            to: effectiveHorizon,
          );
          for (final occ in occs) {
            final dateKey = DateFormat('yyyy-MM-dd').format(occ);
            final sourceRef = 'rec:${rule.id}:$dateKey';
            final isPosted = storage.transactionBox.values.any((t) => t.sourceRef == sourceRef);
            if (!isPosted) {
              unpostedCatRecurring += rule.amount;
            }
          }
        }
      }

      final remaining = (effective - spent - unpostedCatRecurring).clamp(0.0, double.infinity);
      plannedEssential += remaining;
    }

    // C: card statement balances falling due by horizon
    double cardDues = 0.0;
    for (final card in creditCardAccounts) {
      final bal = getAccountBalance(card, asOf: today);
      if (bal < 0) {
        cardDues += bal.abs();
      }
    }

    return ForecastEngine.calculateSafeToSpend(
      liquid: liquid,
      obligations: obligations,
      goalsEarmark: goalsEarmark,
      plannedEssential: plannedEssential,
      cardDues: cardDues,
      today: today,
      horizon: effectiveHorizon,
    );
  }

  /// P8-2: Month-end forecast of liquid balance
  ForecastResult getMonthEndForecast({DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    final liquid = getLiquidBalance(asOf: today);

    // Expected income remaining
    double expectedIncomeRemaining = 0.0;
    final activeRules = storage.recurringBox.values.where((r) => r.status == 'active');
    for (final rule in activeRules) {
      if (rule.kind == 'income') {
        final occurrences = RecurringEngine.occurrences(
          rule: rule,
          from: today.add(const Duration(days: 1)),
          to: monthEnd,
        );
        for (final occ in occurrences) {
          final dateKey = DateFormat('yyyy-MM-dd').format(occ);
          final sourceRef = 'rec:${rule.id}:$dateKey';
          final isPosted = storage.transactionBox.values.any((t) => t.sourceRef == sourceRef);
          if (!isPosted) {
            expectedIncomeRemaining += rule.amount;
          }
        }
      }
    }

    final manualIncome = storage.settingsBox.get('expected_income');
    if (manualIncome is num && manualIncome > 0) {
      final currentInc = getMonthIncome(today);
      if (manualIncome > currentInc) {
        final manualRemaining = manualIncome - currentInc;
        if (manualRemaining > expectedIncomeRemaining) {
          expectedIncomeRemaining = manualRemaining.toDouble();
        }
      }
    }

    final safeToSpend = getSafeToSpend(asOf: today, horizon: monthEnd);
    final obligations = safeToSpend.obligations;
    final cardDues = safeToSpend.cardDues;

    final daysElapsed = today.day;
    final daysInMonth = monthEnd.day;
    final currentCatBreakdown = getCategoryBreakdown(today);

    final cat3mTotals = <String, double>{};
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      final mBreakdown = getCategoryBreakdown(m);
      for (final e in mBreakdown.entries) {
        cat3mTotals[e.key] = (cat3mTotals[e.key] ?? 0.0) + e.value;
      }
    }
    final cat3mAvg = {for (final e in cat3mTotals.entries) e.key: e.value / 3.0};

    final recurringCovered = activeRules
        .where((r) => r.categoryId != null && r.kind != 'income')
        .map((r) => r.categoryId!)
        .toSet();

    final remainingVariable = ForecastEngine.calculateTotalRemainingVariable(
      currentCategorySpend: currentCatBreakdown,
      category3MonthAvg: cat3mAvg,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      recurringCoveredCategories: recurringCovered,
    );

    final pastSpendList = <double>[];
    for (var i = 1; i <= 6; i++) {
      final m = DateTime(today.year, today.month - i);
      final txs = getTransactionsForMonth(m);
      if (txs.isNotEmpty) {
        pastSpendList.add(getMonthSpending(m));
      }
    }

    return ForecastEngine.calculateMonthEndForecast(
      liquid: liquid,
      expectedIncomeRemaining: expectedIncomeRemaining,
      obligations: obligations,
      cardDues: cardDues,
      remainingVariable: remainingVariable,
      pastMonthlyVariableSpend: pastSpendList,
    );
  }

  /// P8-1: Cash flow analysis and next-30-days projection
  CashFlowResult getCashFlowAnalysis({DateTime? month}) {
    final m = month ?? DateTime.now();
    final today = DateTime.now();
    final income = getMonthIncome(m);
    final spending = getMonthSpending(m);
    final net = income - spending;
    final savingsRate = income > 0 ? (net / income).clamp(0.0, 1.0) : 0.0;

    final catBreakdown = getCategoryBreakdown(m);
    final txs = getTransactionsForMonth(m);
    final merchantBreakdown = <String, double>{};
    for (final tx in txs) {
      if (tx.effectiveKind == 'expense' && tx.merchant != null && tx.merchant!.isNotEmpty) {
        merchantBreakdown[tx.merchant!] = (merchantBreakdown[tx.merchant!] ?? 0.0) + tx.amount.abs();
      }
    }

    final horizon30 = today.add(const Duration(days: 30));
    double expectedIncomeNext30 = 0.0;
    double billsDueNext30 = 0.0;
    final activeRules = storage.recurringBox.values.where((r) => r.status == 'active');

    for (final rule in activeRules) {
      final occurrences = RecurringEngine.occurrences(rule: rule, from: today, to: horizon30);
      for (final occ in occurrences) {
        final dateKey = DateFormat('yyyy-MM-dd').format(occ);
        final sourceRef = 'rec:${rule.id}:$dateKey';
        final isPosted = storage.transactionBox.values.any((t) => t.sourceRef == sourceRef);
        if (!isPosted) {
          if (rule.kind == 'income') {
            expectedIncomeNext30 += rule.amount;
          } else {
            billsDueNext30 += rule.amount;
          }
        }
      }
    }

    double past3mSpending = 0.0;
    int monthsCounted = 0;
    for (var i = 1; i <= 3; i++) {
      final pastM = DateTime(today.year, today.month - i);
      final s = getMonthSpending(pastM);
      if (s > 0) {
        past3mSpending += s;
        monthsCounted++;
      }
    }
    final expectedVariableNext30 = monthsCounted > 0 ? (past3mSpending / monthsCounted) : spending;
    final liquid = getLiquidBalance(asOf: today);
    final remainingNext30 = liquid + expectedIncomeNext30 - billsDueNext30 - expectedVariableNext30;

    return CashFlowResult(
      income: income,
      spending: spending,
      net: net,
      savingsRate: savingsRate,
      categoryBreakdown: catBreakdown,
      merchantBreakdown: merchantBreakdown,
      expectedIncomeNext30: Money.r2(expectedIncomeNext30),
      billsDueNext30: Money.r2(billsDueNext30),
      expectedVariableNext30: Money.r2(expectedVariableNext30),
      remainingNext30: Money.r2(remainingNext30),
    );
  }

  /// P8-4: Financial Health Score (0 - 100)
  HealthScoreResult getHealthScore({DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    final lastMonth = DateTime(today.year, today.month - 1);

    double lastMonthBudgetLimit = 0.0;
    double lastMonthBudgetOverspend = 0.0;
    for (final line in storage.budgetLineBox.values) {
      if (line.categoryId == null) continue;
      final limit = BudgetEngine.effectiveBudget(
        line: line,
        month: lastMonth,
        overrides: storage.budgetOverrideBox.values.toList(),
        spentProvider: (l, m) => getCategorySpendingForMonth(l.categoryId, m),
      );
      final spent = getCategorySpendingForMonth(line.categoryId, lastMonth);
      lastMonthBudgetLimit += limit;
      if (spent > limit) {
        lastMonthBudgetOverspend += (spent - limit);
      }
    }

    double inc3m = 0.0;
    double sp3m = 0.0;
    int valid3m = 0;
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      final inc = getMonthIncome(m);
      final sp = getMonthSpending(m);
      if (inc > 0 || sp > 0) {
        inc3m += inc;
        sp3m += sp;
        valid3m++;
      }
    }
    final savingsRate3m = inc3m > 0 ? ((inc3m - sp3m) / inc3m).clamp(-1.0, 1.0) : null;

    final monthlyDebtObligations = getTotalMonthlyEmiObligation();
    final monthlyIncome = inc3m > 0 && valid3m > 0 ? (inc3m / valid3m) : getMonthIncome(today);
    double totalCardBalance = 0.0;
    double totalCardLimit = 0.0;
    for (final card in creditCardAccounts) {
      final bal = getAccountBalance(card, asOf: today);
      if (bal < 0) totalCardBalance += bal.abs();
      totalCardLimit += card.creditLimit ?? 0.0;
    }
    final hasNoDebt = loanAccounts.isEmpty && totalCardBalance == 0;

    final liquid = getLiquidBalance(asOf: today);
    double essential3m = 0.0;
    final essentialCatIds = activeCategories.where((c) => c.essential).map((c) => c.id).toSet();
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      final breakdown = getCategoryBreakdown(m);
      for (final e in breakdown.entries) {
        if (essentialCatIds.contains(e.key)) {
          essential3m += e.value;
        }
      }
    }
    final avgMonthlyEssential3m = valid3m > 0 ? (essential3m / valid3m) : (sp3m > 0 ? sp3m / 3 : 0.0);

    final last6mSpend = <double>[];
    for (var i = 1; i <= 6; i++) {
      final m = DateTime(today.year, today.month - i);
      final s = getMonthSpending(m);
      if (s > 0) last6mSpend.add(s);
    }

    return HealthScoreEngine.calculate(
      lastMonthBudgetLimit: lastMonthBudgetLimit > 0 ? lastMonthBudgetLimit : null,
      lastMonthBudgetOverspend: lastMonthBudgetOverspend,
      savingsRate3m: savingsRate3m,
      monthlyDebtObligations: monthlyDebtObligations > 0 ? monthlyDebtObligations : null,
      monthlyIncome: monthlyIncome > 0 ? monthlyIncome : null,
      totalCardBalance: totalCardBalance > 0 ? totalCardBalance : null,
      totalCardLimit: totalCardLimit > 0 ? totalCardLimit : null,
      hasNoDebt: hasNoDebt,
      liquidBalance: liquid,
      avgMonthlyEssential3m: avgMonthlyEssential3m,
      last6MonthsSpending: last6mSpend,
    );
  }

  /// P8-6: What-If expense simulator
  WhatIfResult simulateWhatIf(double amount, {DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    final forecast = getMonthEndForecast(asOf: today);

    double essential3m = 0.0;
    final essentialCatIds = activeCategories.where((c) => c.essential).map((c) => c.id).toSet();
    int valid3m = 0;
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      final breakdown = getCategoryBreakdown(m);
      for (final e in breakdown.entries) {
        if (essentialCatIds.contains(e.key)) {
          essential3m += e.value;
        }
      }
      if (breakdown.isNotEmpty) valid3m++;
    }
    final avgEssential = valid3m > 0 ? (essential3m / valid3m) : getMonthSpending(today);

    double totalSurplus = 0.0;
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      totalSurplus += (getMonthIncome(m) - getMonthSpending(m));
    }
    final avgSurplus = valid3m > 0 ? (totalSurplus / valid3m) : 0.0;

    return WhatIfEngine.canAfford(
      amount: amount,
      forecastMonthEnd: forecast.projectedMonthEnd,
      emergencyBuffer: avgEssential > 0 ? avgEssential : 10000.0,
      avgMonthlySurplus3m: avgSurplus,
    );
  }

  /// P8-5: Insights Generator
  List<FinanceInsight> getInsights({DateTime? asOf}) {
    final today = asOf ?? DateTime.now();
    final liquid = getLiquidBalance(asOf: today);

    final currentMonthTxs = getTransactionsForMonth(today);
    final past3mTxs = <Transaction>[];
    for (var i = 1; i <= 3; i++) {
      past3mTxs.addAll(getTransactionsForMonth(DateTime(today.year, today.month - i)));
    }

    final budgetLines = storage.budgetLineBox.values.toList();
    final budgetLineSpent = <String, double>{
      for (final b in budgetLines)
        if (b.categoryId != null) b.id: getCategorySpendingForMonth(b.categoryId, today),
    };

    final savedAmounts = {for (final g in activeGoals) g.id: getGoalSavedAmount(g)};
    final goalRates = {for (final g in activeGoals) g.id: getGoalThreeMonthRate(g)};

    final currentNetWorth = getNetWorth(asOf: today);
    final lastMonth = DateTime(today.year, today.month - 1);
    final lastMonthNetWorth = getNetWorth(asOf: lastMonth);

    final inc = getMonthIncome(today);
    final sp = getMonthSpending(today);
    final currentSavingsRate = inc > 0 ? (inc - sp) / inc : 0.0;

    double inc3m = 0.0;
    double sp3m = 0.0;
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      inc3m += getMonthIncome(m);
      sp3m += getMonthSpending(m);
    }
    final pastSavingsRate3m = inc3m > 0 ? (inc3m - sp3m) / inc3m : 0.0;

    double essential3m = 0.0;
    final essentialCatIds = activeCategories.where((c) => c.essential).map((c) => c.id).toSet();
    for (var i = 1; i <= 3; i++) {
      final m = DateTime(today.year, today.month - i);
      final breakdown = getCategoryBreakdown(m);
      for (final e in breakdown.entries) {
        if (essentialCatIds.contains(e.key)) {
          essential3m += e.value;
        }
      }
    }
    final avgMonthlyEssential3m = essential3m > 0 ? (essential3m / 3.0) : 10000.0;

    final rawDismissed = storage.settingsBox.get('dismissed_insights');
    final dismissedSet = <String>{};
    if (rawDismissed is List) {
      dismissedSet.addAll(rawDismissed.map((e) => e.toString()));
    }

    return InsightsEngine.generateInsights(
      today: today,
      liquidBalance: liquid,
      currentMonthTransactions: currentMonthTxs,
      past3MonthsTransactions: past3mTxs,
      categories: activeCategories,
      budgetLines: budgetLines,
      budgetLineSpent: budgetLineSpent,
      activeGoals: activeGoals,
      goalSavedAmounts: savedAmounts,
      goal3mMonthlyRates: goalRates,
      recurringRules: storage.recurringBox.values.toList(),
      currentNetWorth: currentNetWorth,
      lastMonthNetWorth: lastMonthNetWorth,
      currentSavingsRate: currentSavingsRate,
      pastSavingsRate3m: pastSavingsRate3m,
      avgMonthlyEssential3m: avgMonthlyEssential3m,
      dismissedKeys: dismissedSet,
    );
  }

  /// Dismiss an insight by stableKey
  Future<void> dismissInsight(String stableKey) async {
    final raw = storage.settingsBox.get('dismissed_insights');
    final list = <String>[];
    if (raw is List) {
      list.addAll(raw.map((e) => e.toString()));
    }
    if (!list.contains(stableKey)) {
      list.add(stableKey);
      await storage.settingsBox.put('dismissed_insights', list);
      notifyListeners();
    }
  }

  /// P8-7: Cockpit layout registry
  List<String> getHomeLayout() {
    final raw = storage.settingsBox.get('fin_home_layout');
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [
      'net_worth',
      'safe_to_spend',
      'cash_flow',
      'insights',
      'upcoming',
      'goals',
      'budgets',
      'health_score',
      'what_if',
    ];
  }

  Future<void> updateHomeLayout(List<String> layout) async {
    await storage.settingsBox.put('fin_home_layout', layout);
    notifyListeners();
  }

  // ==========================================
  // PHASE 9: REPORTS & EXPORT
  // ==========================================

  MonthlySummaryReport getMonthlySummaryReport(DateTime month) {
    return ReportEngine.generateMonthlySummary(
      month: month,
      transactions: storage.transactionBox.values.toList(),
      accounts: storage.accountBox.values.toList(),
      valuations: storage.valuationBox.values.toList(),
      goalEntries: storage.goalEntryBox.values.toList(),
    );
  }

  List<CategoryReportItem> getCategoryReport(DateTime month) {
    return ReportEngine.generateCategoryReport(
      month: month,
      transactions: storage.transactionBox.values.toList(),
      categories: storage.categoryBox.values.toList(),
    );
  }

  List<MerchantReportItem> getMerchantReport(DateTime month) {
    return ReportEngine.generateMerchantReport(
      month: month,
      transactions: storage.transactionBox.values.toList(),
    );
  }

  MonthComparisonReport compareMonths(DateTime month1, DateTime month2) {
    return ReportEngine.compareMonths(
      month1: month1,
      month2: month2,
      transactions: storage.transactionBox.values.toList(),
      categories: storage.categoryBox.values.toList(),
    );
  }

  List<TrendPoint> getTrendReport(int monthsBack, {DateTime? currentMonth}) {
    return ReportEngine.generateTrends(
      monthsBack: monthsBack,
      currentMonth: currentMonth ?? DateTime.now(),
      transactions: storage.transactionBox.values.toList(),
      accounts: storage.accountBox.values.toList(),
      valuations: storage.valuationBox.values.toList(),
    );
  }

  String exportTransactionsToCsv() {
    return CsvExporter.exportTransactionsToCsv(
      allTransactions,
      categoriesMap,
      accountsMap,
    );
  }

  String exportMonthlyReportToCsv({int monthsBack = 12}) {
    final now = DateTime.now();
    final list = <MonthlySummaryReport>[];
    for (var i = monthsBack - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      list.add(getMonthlySummaryReport(m));
    }
    return CsvExporter.exportMonthlySummaryToCsv(list);
  }

  String exportCategoryReportToCsv(DateTime month) {
    final items = getCategoryReport(month);
    return CsvExporter.exportCategoryReportToCsv(month, items);
  }
}



