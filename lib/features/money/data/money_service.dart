import 'dart:async';
import '../core/account_group.dart';
import '../core/entry.dart';
import '../core/ledger.dart';
import '../core/minor.dart';
import '../core/plan_engine.dart';
import '../state/money_state.dart';
import 'money_store.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/services/xp_ledger.dart';

/// Descriptor for the previous action to support 5-second Undo (Law L8).
class UndoAction {
  final String description;
  final Future<void> Function() onUndo;
  final DateTime timestamp;

  UndoAction({
    required this.description,
    required this.onUndo,
  }) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMilliseconds > 5000;
}

/// The single writer service for all Money mutations (Law L9).
///
/// UI and legacy controllers call this service exclusively.
/// Applies optimistic updates to [MoneyState] immediately, writes to Hive via [MoneyStore],
/// and automatically offers a 5-second Undo capability.
class MoneyService {
  static final MoneyService _instance = MoneyService._internal();
  factory MoneyService({MoneyStore? store, MoneyState? state}) {
    if (store != null) _instance._store = store;
    if (state != null) _instance._state = state;
    return _instance;
  }

  MoneyService._internal()
      : _store = MoneyStore(),
        _state = MoneyState();

  MoneyStore _store;
  MoneyState _state;

  UndoAction? _lastUndoAction;
  Timer? _undoExpiryTimer;

  UndoAction? get lastUndoAction {
    if (_lastUndoAction == null || _lastUndoAction!.isExpired) return null;
    return _lastUndoAction;
  }

  void _setUndoAction(String description, Future<void> Function() onUndo) {
    _undoExpiryTimer?.cancel();
    _lastUndoAction = UndoAction(description: description, onUndo: onUndo);
    _undoExpiryTimer = Timer(const Duration(seconds: 5), () {
      _lastUndoAction = null;
    });
  }

  /// Cancels any active timers and cleans up resources.
  void dispose() {
    _undoExpiryTimer?.cancel();
    _undoExpiryTimer = null;
  }

  int _counter = 0;
  String _generateId(String prefix) {
    _counter++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  /// Initializes money state from persistent storage.
  void init() {
    _state.refreshFromStore(_store);
  }

  // ---------------------------------------------------------------------------
  // ENTRIES (Spent, Received, Moved, Edit, Delete, Undo)
  // ---------------------------------------------------------------------------

  /// Records a Spend entry from an account to an external merchant/category.
  Future<Entry> spend({
    required int amountMinor,
    required String title,
    required String category,
    String? accountId,
    DateTime? date,
    String? categoryId,
    String? notes,
    String? icon,
    String? sourceRef,
  }) async {
    final effectiveAccountId = accountId ?? _state.mainAccountId;
    final entry = Entry(
      id: _generateId('tx'),
      kind: EntryKind.spent,
      amountMinor: amountMinor,
      fromAccountId: effectiveAccountId,
      date: date ?? DateTime.now(),
      title: title.trim().isEmpty ? category : title.trim(),
      category: category,
      categoryId: categoryId,
      notes: notes,
      icon: icon,
      sourceRef: sourceRef,
    );

    // Optimistic UI update (Law L1)
    _state.optimisticUpsertEntry(entry);

    try {
      await _store.saveEntry(entry);
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.date);
      await XpLedger.set(dayKey, 'fin_log_day', 5);
    } catch (e) {
      // Rollback on failure
      _state.optimisticDeleteEntry(entry.id);
      rethrow;
    }

    _setUndoAction('Spent ${Minor.format(amountMinor)}', () async {
      await deleteEntry(entry.id, recordUndo: false);
    });

    return entry;
  }

  /// Records a Receive entry into an account from an external source.
  Future<Entry> receive({
    required int amountMinor,
    required String title,
    required String category,
    String? accountId,
    DateTime? date,
    String? categoryId,
    String? notes,
    String? icon,
    String? sourceRef,
  }) async {
    final effectiveAccountId = accountId ?? _state.mainAccountId;
    final entry = Entry(
      id: _generateId('tx'),
      kind: EntryKind.received,
      amountMinor: amountMinor,
      toAccountId: effectiveAccountId,
      date: date ?? DateTime.now(),
      title: title.trim().isEmpty ? category : title.trim(),
      category: category,
      categoryId: categoryId,
      notes: notes,
      icon: icon,
      sourceRef: sourceRef,
    );

    _state.optimisticUpsertEntry(entry);

    try {
      await _store.saveEntry(entry);
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.date);
      await XpLedger.set(dayKey, 'fin_log_day', 5);
    } catch (e) {
      _state.optimisticDeleteEntry(entry.id);
      rethrow;
    }

    _setUndoAction('Received ${Minor.format(amountMinor)}', () async {
      await deleteEntry(entry.id, recordUndo: false);
    });

    return entry;
  }

  /// Records a Move entry from one account to another (e.g. Main to Fund, Main to Loan).
  Future<Entry> move({
    required int amountMinor,
    required String fromAccountId,
    required String toAccountId,
    required String title,
    required String category,
    DateTime? date,
    String? notes,
    int? interestMinor,
    String? icon,
    String? sourceRef,
  }) async {
    final entry = Entry(
      id: _generateId('tx'),
      kind: EntryKind.moved,
      amountMinor: amountMinor,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      date: date ?? DateTime.now(),
      title: title.trim().isEmpty ? category : title.trim(),
      category: category,
      notes: notes,
      interestMinor: interestMinor,
      icon: icon,
      sourceRef: sourceRef,
    );

    _state.optimisticUpsertEntry(entry);

    try {
      await _store.saveEntry(entry);
    } catch (e) {
      _state.optimisticDeleteEntry(entry.id);
      rethrow;
    }

    _setUndoAction('Moved ${Minor.format(amountMinor)}', () async {
      await deleteEntry(entry.id, recordUndo: false);
    });

    return entry;
  }

  /// Updates an existing entry (Law L8).
  Future<void> editEntry(Entry updated) async {
    final oldEntry = _state.entries.firstWhere((e) => e.id == updated.id);

    _state.optimisticUpsertEntry(updated);

    try {
      await _store.saveEntry(updated);
    } catch (e) {
      _state.optimisticUpsertEntry(oldEntry);
      rethrow;
    }

    _setUndoAction('Edited ${updated.title}', () async {
      await editEntry(oldEntry);
    });
  }

  /// Deletes an entry (Law L8).
  Future<void> deleteEntry(String id, {bool recordUndo = true}) async {
    final existingIndex = _state.entries.indexWhere((e) => e.id == id);
    if (existingIndex < 0) return;
    final existing = _state.entries[existingIndex];

    _state.optimisticDeleteEntry(id);

    try {
      await _store.deleteEntry(id);
    } catch (e) {
      _state.optimisticUpsertEntry(existing);
      rethrow;
    }

    if (recordUndo) {
      _setUndoAction('Deleted ${existing.title}', () async {
        await _store.saveEntry(existing);
        _state.optimisticUpsertEntry(existing);
      });
    }
  }

  /// Executes the 5-second undo action if active (Law L8).
  Future<bool> undo() => undoLastAction();

  /// Executes the 5-second undo action if active (Law L8).
  Future<bool> undoLastAction() async {
    final action = lastUndoAction;
    if (action != null) {
      _lastUndoAction = null;
      _undoExpiryTimer?.cancel();
      await action.onUndo();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // VALUATIONS (Law L4)
  // ---------------------------------------------------------------------------

  /// Updates the market value of a fund account.
  Future<void> updateValuation({
    required String accountId,
    required int valueMinor,
    DateTime? date,
  }) async {
    final valuation = CoreValuation(
      id: _generateId('val'),
      accountId: accountId,
      valueMinor: valueMinor,
      date: date ?? DateTime.now(),
    );

    _state.optimisticUpsertValuation(valuation);

    try {
      await _store.saveValuation(valuation);
    } catch (e) {
      _state.refreshFromStore(_store);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // PLANS (Law L6)
  // ---------------------------------------------------------------------------

  /// Adds a new automation plan.
  Future<CorePlan> addPlan(CorePlan plan) async {
    _state.optimisticUpsertPlan(plan);
    try {
      await _store.savePlan(plan);
    } catch (e) {
      _state.optimisticDeletePlan(plan.id);
      rethrow;
    }
    return plan;
  }

  /// Updates an automation plan.
  Future<void> updatePlan(CorePlan plan) async {
    final oldPlan = _state.plans.firstWhere((p) => p.id == plan.id);
    _state.optimisticUpsertPlan(plan);
    try {
      await _store.savePlan(plan);
    } catch (e) {
      _state.optimisticUpsertPlan(oldPlan);
      rethrow;
    }
  }

  /// Pauses an automation plan.
  Future<void> pausePlan(String planId) async {
    final plan = _state.plans.firstWhere((p) => p.id == planId);
    final updated = CorePlan(
      id: plan.id,
      title: plan.title,
      kind: plan.kind,
      amountMinor: plan.amountMinor,
      dayOfMonth: plan.dayOfMonth,
      fromAccountId: plan.fromAccountId,
      toAccountId: plan.toAccountId,
      startDate: plan.startDate,
      endDate: plan.endDate,
      autoPost: plan.autoPost,
      isPaused: true,
      category: plan.category,
      categoryId: plan.categoryId,
    );
    await updatePlan(updated);
  }

  /// Resumes a paused automation plan.
  Future<void> resumePlan(String planId) async {
    final plan = _state.plans.firstWhere((p) => p.id == planId);
    final updated = CorePlan(
      id: plan.id,
      title: plan.title,
      kind: plan.kind,
      amountMinor: plan.amountMinor,
      dayOfMonth: plan.dayOfMonth,
      fromAccountId: plan.fromAccountId,
      toAccountId: plan.toAccountId,
      startDate: plan.startDate,
      endDate: plan.endDate,
      autoPost: plan.autoPost,
      isPaused: false,
      category: plan.category,
      categoryId: plan.categoryId,
    );
    await updatePlan(updated);
  }

  /// Ends and deletes a plan.
  Future<void> endPlan(String planId) async {
    final oldPlan = _state.plans.firstWhere((p) => p.id == planId);
    _state.optimisticDeletePlan(planId);
    try {
      await _store.deletePlan(planId);
    } catch (e) {
      _state.optimisticUpsertPlan(oldPlan);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ACCOUNTS
  // ---------------------------------------------------------------------------

  /// Creates a new account (e.g. inline Fund creation for SIP).
  Future<CoreAccount> createAccount({
    required String name,
    required String rawKind,
    required int openingBalanceMinor,
    DateTime? openingDate,
    int? colorValue,
    double? annualRate,
    int? emiMinor,
    int? tenureMonths,
  }) async {
    final acc = CoreAccount(
      id: _generateId('acc'),
      name: name,
      group: AccountClassifier.classify(
        accountId: '',
        mainAccountId: _state.mainAccountId,
        rawKind: rawKind,
      ),
      rawKind: rawKind,
      openingBalanceMinor: openingBalanceMinor,
      openingDate: openingDate ?? DateTime.now(),
      colorValue: colorValue ?? 0xFF1E88E5,
      annualRatePct: annualRate,
      emiMinor: emiMinor,
      tenureMonths: tenureMonths,
    );

    await _store.saveAccount(acc);
    _state.refreshFromStore(_store);
    return acc;
  }
}
