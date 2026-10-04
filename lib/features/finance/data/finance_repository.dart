import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/constants.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Draft object used to create a new Transaction through the repository.
class TxDraft {
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String mode;
  final String icon;
  final String? kind;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? merchant;
  final String? paymentMethod;
  final String? notes;
  final List<String>? tags;
  final String? splits;
  final List<String>? receiptPaths;
  final String? recurringRuleId;
  final String? sourceRef;
  final String? goalId;
  final double? interestAmount;
  final String? refundOfId;

  TxDraft({
    required this.title,
    required this.amount,
    this.category = 'Other',
    required this.date,
    this.mode = 'expense',
    this.icon = 'expense',
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
    this.goalId,
    this.interestAmount,
    this.refundOfId,
  });
}

/// Central repository managing all financial entity operations, validation rules,
/// undo actions, and XP hooks.
class FinanceRepository {
  final FinanceStorage storage;
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Transaction? _lastDeletedTx;
  int? _lastDeletedKey;

  FinanceRepository({FinanceStorage? storage})
      : storage = storage ?? FinanceStorage();

  void _notify() {
    changes.value++;
  }

  String _generateId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_$now';
  }

  // ---------------------------------------------------------------------------
  // TRANSACTIONS
  // ---------------------------------------------------------------------------

  List<Transaction> getAllTransactions() {
    return storage.transactionBox.values.toList();
  }

  Future<Transaction> addTransaction(TxDraft draft) async {
    final effectiveKind = draft.kind ??
        ((draft.mode.toLowerCase() == 'expense' || draft.amount < 0)
            ? 'expense'
            : 'income');

    final magnitude = Money.r2(draft.amount.abs());
    if (magnitude <= 0 && effectiveKind != 'adjustment') {
      throw ArgumentError(
          'Transaction amount must be strictly greater than zero.');
    }

    // Invariant I6 Validation
    if (effectiveKind == 'transfer') {
      if (draft.accountId == null || draft.toAccountId == null) {
        throw ArgumentError(
            'Transfer requires both source and destination accounts.');
      }
      if (draft.accountId == draft.toAccountId) {
        throw ArgumentError(
            'Source and destination accounts must be different.');
      }
    }

    if (effectiveKind == 'investment') {
      if (draft.accountId == null || draft.toAccountId == null) {
        throw ArgumentError(
            'Investment requires both funding and investment accounts.');
      }
      if (draft.accountId == draft.toAccountId) {
        throw ArgumentError(
            'Source and investment accounts must be different.');
      }
    }

    if (draft.splits != null && draft.splits!.isNotEmpty) {
      _validateSplits(draft.splits!, magnitude);
    }

    // Legacy compatibility: negative amount for expenses, positive for income
    final storedAmount = (effectiveKind == 'expense') ? -magnitude : magnitude;

    final id = _generateId('tx');
    final tx = Transaction(
      title: draft.title.trim().isEmpty ? draft.category : draft.title.trim(),
      amount: storedAmount,
      category: draft.category,
      date: draft.date,
      mode: draft.mode,
      icon: draft.icon,
      id: id,
      kind: effectiveKind,
      accountId: draft.accountId ?? FinanceConstants.defaultAccountId,
      toAccountId: draft.toAccountId,
      categoryId: draft.categoryId,
      merchant: draft.merchant,
      paymentMethod: draft.paymentMethod,
      notes: draft.notes,
      tags: draft.tags,
      splits: draft.splits,
      receiptPaths: draft.receiptPaths,
      recurringRuleId: draft.recurringRuleId,
      sourceRef: draft.sourceRef,
      createdAt: DateTime.now(),
      goalId: draft.goalId,
      interestAmount: draft.interestAmount,
      refundOfId: draft.refundOfId,
    );

    await storage.transactionBox.add(tx);
    _notify();
    return tx;
  }

  void _validateSplits(String splitsJson, double expectedTotal) {
    try {
      final List parsed = jsonDecode(splitsJson);
      double splitSum = 0.0;
      for (final item in parsed) {
        if (item is Map) {
          splitSum += Money.asDouble(item['amount']);
        }
      }
      if ((Money.r2(splitSum) - Money.r2(expectedTotal)).abs() > 0.01) {
        throw ArgumentError(
          'Split parts sum (₹${Money.r2(splitSum)}) must match total (₹$expectedTotal).',
        );
      }
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Invalid split JSON structure: $e');
    }
  }

  Future<void> updateTransaction(Transaction tx) async {
    final effectiveKind = tx.effectiveKind;
    if (tx.splits != null && tx.splits!.isNotEmpty) {
      _validateSplits(tx.splits!, tx.amount.abs());
    }
    if (effectiveKind == 'transfer' && tx.accountId == tx.toAccountId) {
      throw ArgumentError('Source and destination accounts must be different.');
    }
    await tx.save();
    _notify();
  }

  Future<void> deleteTransaction(dynamic txOrKeyOrId) async {
    Transaction? target;
    int? targetKey;

    if (txOrKeyOrId is Transaction) {
      target = txOrKeyOrId;
      targetKey = txOrKeyOrId.key as int?;
    } else if (txOrKeyOrId is int) {
      targetKey = txOrKeyOrId;
      target = storage.transactionBox.get(targetKey);
    } else if (txOrKeyOrId is String) {
      for (final t in storage.transactionBox.values) {
        if (t.id == txOrKeyOrId) {
          target = t;
          targetKey = t.key as int?;
          break;
        }
      }
    }

    if (target != null) {
      _lastDeletedTx = Transaction(
        title: target.title,
        amount: target.amount,
        category: target.category,
        date: target.date,
        mode: target.mode,
        icon: target.icon,
        id: target.id,
        kind: target.kind,
        accountId: target.accountId,
        toAccountId: target.toAccountId,
        categoryId: target.categoryId,
        merchant: target.merchant,
        paymentMethod: target.paymentMethod,
        notes: target.notes,
        tags: target.tags,
        splits: target.splits,
        receiptPaths: target.receiptPaths,
        recurringRuleId: target.recurringRuleId,
        sourceRef: target.sourceRef,
        createdAt: target.createdAt,
        goalId: target.goalId,
        interestAmount: target.interestAmount,
        refundOfId: target.refundOfId,
      );
      _lastDeletedKey = targetKey;
      await target.delete();
      _notify();
    }
  }

  /// Restores the last deleted transaction in the session.
  Future<Transaction?> undoDelete() async {
    if (_lastDeletedTx == null) return null;
    final restored = _lastDeletedTx!;
    if (_lastDeletedKey != null) {
      await storage.transactionBox.put(_lastDeletedKey, restored);
    } else {
      await storage.transactionBox.add(restored);
    }
    _lastDeletedTx = null;
    _lastDeletedKey = null;
    _notify();
    return restored;
  }

  // ---------------------------------------------------------------------------
  // TRANSFERS & REFUNDS
  // ---------------------------------------------------------------------------

  Future<Transaction> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    return addTransaction(TxDraft(
      title: 'Transfer',
      amount: amount,
      category: 'Transfer',
      date: date,
      mode: 'transfer',
      icon: 'transfer',
      kind: 'transfer',
      accountId: fromAccountId,
      toAccountId: toAccountId,
      notes: note,
    ));
  }

  Future<Transaction> refund({
    required String accountId,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? title,
    String? originalTxId,
  }) async {
    return addTransaction(TxDraft(
      title: title ?? 'Refund',
      amount: amount,
      category: 'Refund',
      date: date,
      mode: 'income',
      icon: 'income',
      kind: 'refund',
      accountId: accountId,
      categoryId: categoryId,
      refundOfId: originalTxId,
    ));
  }

  // ---------------------------------------------------------------------------
  // ACCOUNTS
  // ---------------------------------------------------------------------------

  List<Account> getAllAccounts() {
    return storage.accountBox.values.toList();
  }

  Future<Account> addAccount(Account account) async {
    await storage.accountBox.put(account.id, account);
    GlobalXPService.addXP(15);
    _notify();
    return account;
  }

  Future<void> updateAccount(Account account) async {
    await storage.accountBox.put(account.id, account);
    _notify();
  }

  Future<void> deleteAccount(String id) async {
    await storage.accountBox.delete(id);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  List<Category> getAllCategories() {
    return storage.categoryBox.values.toList();
  }

  Future<Category> addCategory(Category category) async {
    await storage.categoryBox.put(category.id, category);
    _notify();
    return category;
  }

  Future<void> updateCategory(Category category) async {
    await storage.categoryBox.put(category.id, category);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // RECURRING RULES & SIPS
  // ---------------------------------------------------------------------------

  List<RecurringRule> getAllRecurringRules() {
    return storage.recurringBox.values.toList();
  }

  Future<RecurringRule> addRecurringRule(RecurringRule rule) async {
    await storage.recurringBox.put(rule.id, rule);
    _notify();
    return rule;
  }

  Future<void> updateRecurringRule(RecurringRule rule) async {
    await storage.recurringBox.put(rule.id, rule);
    _notify();
  }

  Future<void> deleteRecurringRule(String id) async {
    await storage.recurringBox.delete(id);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // GOALS & CONTRIBUTIONS
  // ---------------------------------------------------------------------------

  List<SavingsGoal> getAllGoals() {
    return storage.goalBox.values.toList();
  }

  Future<SavingsGoal> addGoal(SavingsGoal goal) async {
    await storage.goalBox.put(goal.id, goal);
    _notify();
    return goal;
  }

  Future<GoalEntry> addGoalContribution({
    required String goalId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    final entry = GoalEntry(
      id: _generateId('ge'),
      goalId: goalId,
      date: date ?? DateTime.now(),
      amount: amount,
      note: note,
    );
    await storage.goalEntryBox.put(entry.id, entry);
    GlobalXPService.addXP(20);
    _notify();
    return entry;
  }

  List<GoalEntry> getGoalEntries(String goalId) {
    return storage.goalEntryBox.values
        .where((e) => e.goalId == goalId)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // BUDGET LINES
  // ---------------------------------------------------------------------------

  List<BudgetLine> getAllBudgetLines() {
    return storage.budgetLineBox.values.toList();
  }

  Future<BudgetLine> setBudgetLine(BudgetLine line) async {
    await storage.budgetLineBox.put(line.id, line);
    _notify();
    return line;
  }

  Future<void> deleteBudgetLine(String id) async {
    await storage.budgetLineBox.delete(id);
    _notify();
  }
}
