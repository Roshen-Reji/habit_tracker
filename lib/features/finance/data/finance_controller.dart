import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
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
}

