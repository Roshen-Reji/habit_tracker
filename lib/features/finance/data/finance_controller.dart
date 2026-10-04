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
}

