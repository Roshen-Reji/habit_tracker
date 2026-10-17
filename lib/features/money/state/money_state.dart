import 'package:flutter/foundation.dart';
import '../core/account_group.dart';
import '../core/entry.dart';
import '../core/free_to_spend.dart';
import '../core/ledger.dart';
import '../core/plan_engine.dart';
import '../core/snapshot.dart';
import '../data/money_store.dart';

/// Single reactive state container holding the current [MoneySnapshot].
///
/// Implements Law L1 (Immediate effect) and Law L9 (Single reader):
/// Screens listen to slices of this state or this notifier directly.
class MoneyState extends ValueNotifier<MoneySnapshot> {
  static final MoneyState _instance = MoneyState._internal();
  factory MoneyState() => _instance;

  MoneyState._internal() : super(MoneySnapshot.empty());

  String _mainAccountId = 'acc_main';
  final List<CoreAccount> _accounts = [];
  final List<Entry> _entries = [];
  final List<CorePlan> _plans = [];
  final List<CoreValuation> _valuations = [];

  String get mainAccountId => _mainAccountId;
  List<CoreAccount> get accounts => List.unmodifiable(_accounts);
  List<Entry> get entries => List.unmodifiable(_entries);
  List<CorePlan> get plans => List.unmodifiable(_plans);
  List<CoreValuation> get valuations => List.unmodifiable(_valuations);

  /// Reloads all data from [MoneyStore] and recomputes the snapshot.
  void refreshFromStore(MoneyStore store) {
    _mainAccountId = store.getSetting<String>(
      'money2_main_account_id',
      defaultValue: 'acc_main',
    );

    final loadedAccounts = store.loadAccounts(_mainAccountId);
    _accounts
      ..clear()
      ..addAll(loadedAccounts);

    // Fallback if configured mainAccountId does not exist in accounts
    if (_accounts.isNotEmpty && !_accounts.any((a) => a.id == _mainAccountId)) {
      _mainAccountId = _accounts.first.id;
    }

    _entries
      ..clear()
      ..addAll(store.loadEntries());

    _plans
      ..clear()
      ..addAll(store.loadPlans());

    _valuations
      ..clear()
      ..addAll(store.loadValuations());

    recomputeSnapshot();
  }

  /// Synchronously recomputes the [MoneySnapshot] and notifies listeners.
  void recomputeSnapshot({DateTime? clock}) {
    final now = clock ?? DateTime.now();

    // 1. Calculate per-account balances
    final balances = <String, int>{};
    for (final acc in _accounts) {
      balances[acc.id] = CoreLedger.balance(
        account: acc,
        entries: _entries,
        valuations: _valuations,
        asOf: now,
      );
    }

    // 2. Main account balance
    final mainBal = balances[_mainAccountId] ?? 0;

    // 3. Collect posted plan keys
    final postedKeys = <String>{};
    for (final e in _entries) {
      if (e.sourceRef != null && e.sourceRef!.startsWith('plan:')) {
        postedKeys.add(e.sourceRef!);
      }
    }

    // 4. Free to spend calculation (Law L7)
    final freeToSpend = FreeToSpendCalculator.calculate(
      mainBalanceMinor: mainBal,
      plans: _plans,
      postedKeys: postedKeys,
      clock: now,
    );

    // 5. Month spent and received for current calendar month
    int monthSpent = 0;
    int monthReceived = 0;
    for (final e in _entries) {
      if (e.date.year == now.year && e.date.month == now.month) {
        if (e.kind == EntryKind.spent) {
          monthSpent += e.amountMinor;
        } else if (e.kind == EntryKind.received) {
          monthReceived += e.amountMinor;
        }
      }
    }

    // 6. Fund summaries (Law L4)
    final funds = <FundSummary>[];
    for (final acc in _accounts.where((a) => a.isFund)) {
      funds.add(CoreLedger.fundSummary(
        account: acc,
        entries: _entries,
        valuations: _valuations,
        asOf: now,
      ));
    }

    // 7. Loan summaries (Law L5)
    final loans = <LoanSummary>[];
    for (final acc in _accounts.where((a) => a.isLoan)) {
      loans.add(CoreLedger.loanSummary(
        account: acc,
        entries: _entries,
        asOf: now,
      ));
    }

    // 8. Upcoming plans (next 10) & Plans needing funds (Law L6)
    final upcoming = <PlanOccurrence>[];
    final needingFunds = <PlanOccurrence>[];

    for (final plan in _plans) {
      if (plan.isPaused) continue;
      final due = PlanEngine.evaluateDue(
        plan: plan,
        effectiveStartDate: DateTime(now.year, now.month, 1),
        clock: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        existingKeys: postedKeys,
        mainBalanceMinor: mainBal,
      );

      for (final occ in due) {
        if (occ.needsFunds) {
          needingFunds.add(occ);
        } else {
          upcoming.add(occ);
        }
      }
    }

    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextTenUpcoming = upcoming.take(10).toList();

    // 9. Recent entries (sorted descending)
    final sortedRecent = List<Entry>.from(_entries)
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        if (d != 0) return d;
        return b.createdAt.compareTo(a.createdAt);
      });

    value = MoneySnapshot(
      asOf: now,
      mainAccountId: _mainAccountId,
      mainBalanceMinor: mainBal,
      balancesByAccountMinor: balances,
      freeToSpend: freeToSpend,
      monthSpentMinor: monthSpent,
      monthReceivedMinor: monthReceived,
      funds: funds,
      loans: loans,
      upcomingPlans: nextTenUpcoming,
      plansNeedingFunds: needingFunds,
      recentEntries: sortedRecent.take(50).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // OPTIMISTIC MUTATIONS
  // ---------------------------------------------------------------------------

  /// Adds or updates an entry in local state immediately.
  void optimisticUpsertEntry(Entry entry) {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    recomputeSnapshot();
  }

  /// Removes an entry from local state immediately.
  void optimisticDeleteEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    recomputeSnapshot();
  }

  /// Adds or updates a valuation immediately.
  void optimisticUpsertValuation(CoreValuation val) {
    final idx = _valuations.indexWhere((v) => v.id == val.id);
    if (idx >= 0) {
      _valuations[idx] = val;
    } else {
      _valuations.add(val);
    }
    recomputeSnapshot();
  }

  /// Adds or updates a plan immediately.
  void optimisticUpsertPlan(CorePlan plan) {
    final idx = _plans.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      _plans[idx] = plan;
    } else {
      _plans.add(plan);
    }
    recomputeSnapshot();
  }

  /// Deletes a plan immediately.
  void optimisticDeletePlan(String id) {
    _plans.removeWhere((p) => p.id == id);
    recomputeSnapshot();
  }
}
