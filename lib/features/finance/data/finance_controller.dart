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
}
