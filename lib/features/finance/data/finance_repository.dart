import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/constants.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/engine/loan_engine.dart';
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

  int _counter = 0;
  String _generateId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    _counter++;
    return '${prefix}_${now}_$_counter';
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

    // P1-5: EMI Interest Split
    // If this is a transfer to a loan account, automatically split the interest portion.
    if (effectiveKind == 'transfer' && tx.toAccountId != null) {
      final toAcc = storage.accountBox.get(tx.toAccountId);
      if (toAcc != null && toAcc.kind.toLowerCase() == 'loan' && toAcc.annualRate != null) {
        // Calculate the balance of the loan right before this payment
        final cutoff = tx.date.subtract(const Duration(seconds: 1));
        final prePaymentBalance = LedgerEngine.balance(
          toAcc,
          storage.transactionBox.values,
          storage.valuationBox.values,
          asOf: cutoff,
        );

        final split = LoanEngine.splitPayment(
          currentBalance: prePaymentBalance.abs(),
          annualRatePct: toAcc.annualRate!,
          paymentAmount: magnitude,
        );

        if (split.interest > 0) {
          final interestId = _generateId('tx');
          final interestTx = Transaction(
            title: ' Interest',
            amount: split.interest,
            category: 'Interest Expense',
            date: tx.date,
            mode: 'expense',
            icon: 'percentage',
            id: interestId,
            kind: 'expense',
            accountId: toAcc.id,
            sourceRef: 'emi_split_',
            createdAt: DateTime.now(),
          );
          await storage.transactionBox.add(interestTx);
        }
      }
    }

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

  Future<void> updateTransaction(dynamic txOrId, [TxDraft? draft]) async {
    Transaction? target;
    if (txOrId is Transaction) {
      target = txOrId;
    } else if (txOrId is String) {
      for (final t in storage.transactionBox.values) {
        if (t.id == txOrId || t.key.toString() == txOrId) {
          target = t;
          break;
        }
      }
    }

    if (target == null) throw ArgumentError('Transaction not found: $txOrId');

    if (draft != null) {
      final effectiveKind = draft.kind ?? target.effectiveKind;
      final magnitude = Money.r2(draft.amount.abs());
      final storedAmount = (effectiveKind == 'expense') ? -magnitude : magnitude;

      target.title = draft.title.trim().isEmpty ? draft.category : draft.title.trim();
      target.amount = storedAmount;
      target.kind = effectiveKind;
      target.accountId = draft.accountId ?? target.accountId;
      target.toAccountId = draft.toAccountId;
      target.categoryId = draft.categoryId;
      target.category = draft.category;
      target.date = draft.date;
      target.merchant = draft.merchant;
      target.paymentMethod = draft.paymentMethod;
      target.notes = draft.notes;
      target.tags = draft.tags;
      target.splits = draft.splits;
      target.interestAmount = draft.interestAmount;
      target.refundOfId = draft.refundOfId;
    }

    final effectiveKind = target.effectiveKind;
    if (target.splits != null && target.splits!.isNotEmpty) {
      _validateSplits(target.splits!, target.amount.abs());
    }
    if (effectiveKind == 'transfer' && target.accountId == target.toAccountId) {
      throw ArgumentError('Source and destination accounts must be different.');
    }
    await target.save();
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

  /// Alias for in-session undo.
  Future<Transaction?> undo() => undoDelete();

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

  Future<Transaction?> reconcileAccount({
    required String accountId,
    required double realBalance,
    DateTime? date,
    String? notes,
  }) async {
    final account = storage.accountBox.get(accountId);
    if (account == null) {
      throw ArgumentError('Account not found: $accountId');
    }

    final effectiveDate = date ?? DateTime.now();
    final currentBalance = LedgerEngine.balance(
      account,
      storage.transactionBox.values,
      storage.valuationBox.values,
      asOf: effectiveDate,
    );

    final diff = Money.r2(realBalance - currentBalance);
    if (diff.abs() < 0.01) {
      return null;
    }

    return addTransaction(TxDraft(
      title: 'Reconciliation adjustment',
      amount: diff,
      category: 'Adjustment',
      date: effectiveDate,
      mode: diff >= 0 ? 'income' : 'expense',
      icon: 'sliders',
      kind: 'adjustment',
      accountId: accountId,
      notes: notes ?? 'Reconciliation to real balance: ${FormatUtils.formatMoney(realBalance)}',
    ));
  }

  // ---------------------------------------------------------------------------
  // VALUATIONS
  // ---------------------------------------------------------------------------

  List<Valuation> getValuations(String accountId) {
    final list = storage.valuationBox.values
        .where((v) => v.accountId == accountId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<Valuation> addValuation({
    required String accountId,
    required double value,
    double? units,
    double? unitPrice,
    DateTime? date,
  }) async {
    final val = Valuation(
      id: _generateId('val'),
      accountId: accountId,
      date: date ?? DateTime.now(),
      value: Money.r2(value),
      units: units,
      unitPrice: unitPrice,
    );
    await storage.valuationBox.put(val.id, val);
    _notify();
    return val;
  }

  Future<void> deleteValuation(String id) async {
    await storage.valuationBox.delete(id);
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

  Future<void> saveCategory(Category category) async {
    await storage.categoryBox.put(category.id, category);
    _notify();
  }

  Future<void> mergeCategory(String sourceCategoryId, String targetCategoryId) async {
    final targetCategory = storage.categoryBox.get(targetCategoryId);
    if (targetCategory == null) {
      throw ArgumentError('Target category not found: $targetCategoryId');
    }

    for (final tx in storage.transactionBox.values) {
      if (tx.categoryId == sourceCategoryId) {
        tx.categoryId = targetCategoryId;
        tx.category = targetCategory.name;
        await tx.save();
      }
    }

    final sourceCategory = storage.categoryBox.get(sourceCategoryId);
    if (sourceCategory != null) {
      sourceCategory.archived = true;
      await sourceCategory.save();
    }

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

  /// P6-1: Posts due auto-post recurring rules up to [now].
  /// Idempotent via sourceRef: 'rec:{id}:{yyyy-MM-dd}'.
  Future<List<Transaction>> postRecurringDue({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final rules = storage.recurringBox.values.where((r) => r.status == 'active' && r.autoPost).toList();
    final posted = <Transaction>[];

    final existingRefs = storage.transactionBox.values
        .map((tx) => tx.sourceRef)
        .where((ref) => ref != null)
        .cast<String>()
        .toSet();

    for (final rule in rules) {
      final allDates = RecurringEngine.occurrences(rule, rule.startDate, clock);
      // Catch up at most 60 months per rule per run
      final dates = allDates.length > 60 ? allDates.sublist(allDates.length - 60) : allDates;

      for (final dueDate in dates) {
        final dateKey = DateFormat('yyyy-MM-dd').format(dueDate);
        final sourceRef = 'rec:${rule.id}:$dateKey';

        if (existingRefs.contains(sourceRef)) continue;

        final estimatedAmt = RecurringEngine.estimateAmount(rule, storage.transactionBox.values);
        final isIncome = rule.kind == 'income';
        final isTransfer = rule.kind == 'transfer';
        final isInvestment = rule.kind == 'investment' || rule.kind == 'sip';
        final isDebt = rule.kind == 'emi' || rule.kind == 'debt_payment';

        String effectiveKind = 'expense';
        if (isIncome) effectiveKind = 'income';
        else if (isTransfer) effectiveKind = 'transfer';
        else if (isInvestment) effectiveKind = 'investment';
        else if (isDebt) effectiveKind = 'debt_payment';

        final cat = rule.categoryId != null ? storage.categoryBox.get(rule.categoryId!) : null;

        final srcAccId = rule.accountId ?? 'acc_main';
        final srcAcc = storage.accountBox.get(srcAccId);
        final bal = srcAcc != null ? LedgerEngine.balance(srcAcc, storage.transactionBox.values, storage.valuationBox.values, asOf: clock) : 0.0;
        final isLowBalance = !isIncome && bal < estimatedAmt;

        double? interestAmount;
        bool missingLoanFields = false;
        bool loanCompleted = false;

        if (rule.kind == 'emi' && rule.toAccountId != null) {
          final loanAcc = storage.accountBox.get(rule.toAccountId!);
          if (loanAcc != null) {
            if (loanAcc.principal != null && loanAcc.annualRate != null) {
              // Calculate remaining balance before this payment
              final loanBal = LedgerEngine.balance(loanAcc, storage.transactionBox.values, storage.valuationBox.values, asOf: dueDate.subtract(const Duration(seconds: 1)));
              
              if (loanBal.abs() <= 0.01) {
                loanCompleted = true;
                rule.status = 'ended';
                await rule.save();
                break; // Stop posting further occurrences
              }
              
              final split = LoanEngine.splitPayment(
                currentBalance: loanBal.abs(),
                annualRatePct: loanAcc.annualRate!,
                paymentAmount: estimatedAmt,
              );
              interestAmount = split.interest;
              
              // If this payment covers the last bit of principal, the next one shouldn't post
              if (split.principal >= loanBal.abs() - 0.01) {
                 loanCompleted = true; // Will end it on next iteration or we can end it here, but it's okay, next iteration will break.
              }
            } else {
              missingLoanFields = true;
            }
          }
        }

        final tx = await addTransaction(TxDraft(
          title: rule.name,
          amount: isIncome ? estimatedAmt : -estimatedAmt,
          category: cat?.name ?? 'Recurring',
          date: dueDate,
          mode: isIncome ? 'income' : 'expense',
          icon: cat?.iconKey ?? 'repeat',
          kind: effectiveKind,
          accountId: srcAccId,
          toAccountId: rule.toAccountId,
          categoryId: rule.categoryId,
          recurringRuleId: rule.id,
          sourceRef: sourceRef,
          interestAmount: interestAmount,
          notes: rule.notes ?? 'Auto-posted recurring ${rule.kind}',
        ));

        posted.add(tx);
        existingRefs.add(sourceRef);

        String msg = '${rule.kind == "sip" || rule.kind == "emi" ? rule.kind.toUpperCase() : "Recurring"} ${FormatUtils.formatMoney(estimatedAmt)} posted';
        if (rule.toAccountId != null) {
          final toAcc = storage.accountBox.get(rule.toAccountId!);
          if (toAcc != null) {
            msg += ': ${srcAcc?.name ?? "Main"} → ${toAcc.name}';
          }
        }
        if (isLowBalance) {
          msg += ' (balance low)';
        }
        if (missingLoanFields) {
          msg += '\nAdd rate and tenure for the interest split';
        }
        
        NotificationService().showInstantNotification(
          id: (rule.id.hashCode & 0x7FFFFFFF),
          title: 'Auto-post: ${rule.name}',
          body: msg,
        );
        
        if (loanCompleted) {
          rule.status = 'ended';
          await rule.save();
          break; // Stop if it's the last payment
        }
      }
    }

    return posted;
  }

  /// P6-1: Gets unposted due items for non-autoPost recurring rules up to [now].
  List<DueItem> getUnpostedDueItems({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final rules = storage.recurringBox.values.where((r) => r.status == 'active' && !r.autoPost).toList();
    final dueItems = <DueItem>[];

    final existingRefs = storage.transactionBox.values
        .map((tx) => tx.sourceRef)
        .where((ref) => ref != null)
        .cast<String>()
        .toSet();

    for (final rule in rules) {
      final dates = RecurringEngine.occurrences(rule, rule.startDate, clock);

      for (final dueDate in dates) {
        final dateKey = DateFormat('yyyy-MM-dd').format(dueDate);
        final sourceRef = 'rec:${rule.id}:$dateKey';

        if (existingRefs.contains(sourceRef)) continue;

        final estAmt = RecurringEngine.estimateAmount(rule, storage.transactionBox.values);
        dueItems.add(DueItem(
          rule: rule,
          dueDate: dueDate,
          estimatedAmount: estAmt,
          isVariable: rule.amountIsVariable,
        ));
      }
    }

    dueItems.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return dueItems;
  }

  /// P6-2: Marks a due item as Paid with user-confirmed date, amount, and account.
  Future<Transaction> markRecurringPaid(
    DueItem item, {
    DateTime? paidDate,
    String? accountId,
    double? amount,
  }) async {
    final rule = item.rule;
    final effDate = paidDate ?? item.dueDate;
    final finalAmt = amount ?? item.estimatedAmount;
    final finalAccId = accountId ?? rule.accountId ?? 'acc_main';

    final isIncome = rule.kind == 'income';
    final isTransfer = rule.kind == 'transfer';
    final isInvestment = rule.kind == 'investment' || rule.kind == 'sip';
    final isDebt = rule.kind == 'emi' || rule.kind == 'debt_payment';

    String effectiveKind = 'expense';
    if (isIncome) effectiveKind = 'income';
    else if (isTransfer) effectiveKind = 'transfer';
    else if (isInvestment) effectiveKind = 'investment';
    else if (isDebt) effectiveKind = 'debt_payment';

    final cat = rule.categoryId != null ? storage.categoryBox.get(rule.categoryId!) : null;

    double? interestAmount;
    bool loanCompleted = false;

    if (rule.kind == 'emi' && rule.toAccountId != null) {
      final loanAcc = storage.accountBox.get(rule.toAccountId!);
      if (loanAcc != null && loanAcc.principal != null && loanAcc.annualRate != null) {
        final loanBal = LedgerEngine.balance(
          loanAcc, 
          storage.transactionBox.values, 
          storage.valuationBox.values, 
          asOf: effDate.subtract(const Duration(seconds: 1)),
        );
        
        final split = LoanEngine.splitPayment(
          currentBalance: loanBal.abs(),
          annualRatePct: loanAcc.annualRate!,
          paymentAmount: finalAmt,
        );
        interestAmount = split.interest;
        
        if (split.principal >= loanBal.abs() - 0.01) {
          loanCompleted = true;
        }
      }
    }

    final tx = await addTransaction(TxDraft(
      title: rule.name,
      amount: isIncome ? finalAmt : -finalAmt,
      category: cat?.name ?? 'Recurring',
      date: effDate,
      mode: isIncome ? 'income' : 'expense',
      icon: cat?.iconKey ?? 'check-circle',
      kind: effectiveKind,
      accountId: finalAccId,
      toAccountId: rule.toAccountId,
      categoryId: rule.categoryId,
      recurringRuleId: rule.id,
      sourceRef: item.sourceRef,
      interestAmount: interestAmount,
      notes: rule.notes ?? 'Confirmed payment for ${rule.name}',
    ));

    if (loanCompleted) {
      rule.status = 'ended';
      await rule.save();
    }

    return tx;
  }

  /// P6-3: Schedules notifications for upcoming recurring rules at 09:00 local time.
  Future<void> scheduleRecurringReminders({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final horizon = clock.add(const Duration(days: 14));
    final rules = storage.recurringBox.values.where((r) => r.status == 'active').toList();

    for (final rule in rules) {
      final dates = RecurringEngine.occurrences(rule, clock, horizon);

      for (final d in dates) {
        final reminderDate = d.subtract(Duration(days: rule.reminderDaysBefore));
        final scheduledTime = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          9,
          0,
        );

        if (scheduledTime.isAfter(clock)) {
          final id = (rule.id.hashCode + d.day + d.month * 100) & 0x7FFFFFFF;
          await NotificationService().schedule(
            id: id,
            when: scheduledTime,
            title: 'Upcoming ${rule.kind}: ${rule.name}',
            body: '${FormatUtils.formatMoney(rule.amount)} due on ${DateFormat('dd MMM').format(d)}',
            payload: 'rec:${rule.id}',
          );
        }
      }
    }
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
    final list = storage.goalEntryBox.values
        .where((e) => e.goalId == goalId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    await storage.goalBox.put(goal.id, goal);
    _notify();
  }

  Future<void> deleteGoal(String id) async {
    await storage.goalBox.delete(id);
    // Delete associated entries
    final entries = storage.goalEntryBox.values.where((e) => e.goalId == id).map((e) => e.id).toList();
    for (final eid in entries) {
      await storage.goalEntryBox.delete(eid);
    }
    _notify();
  }

  Future<void> deleteGoalEntry(String id) async {
    await storage.goalEntryBox.delete(id);
    _notify();
  }

  /// P5-4 Auto-contribute:
  /// When autoContribute is on, creates the month's GoalEntry on first open of each month
  /// (idempotent via sourceRef: 'autogoal:{goal.id}:{yyyy-MM}').
  Future<List<GoalEntry>> runAutoContribute({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(current);
    final firstOfMonth = DateTime(current.year, current.month, 1);
    final createdEntries = <GoalEntry>[];

    for (final goal in storage.goalBox.values) {
      if (goal.archived || !goal.autoContribute) continue;
      final monthly = goal.plannedMonthly;
      if (monthly == null || monthly <= 0) continue;

      final sourceRef = 'autogoal:${goal.id}:$monthKey';

      // Check if entry already exists
      final alreadyPosted = storage.goalEntryBox.values.any((e) => e.sourceRef == sourceRef);
      if (alreadyPosted) continue;

      final entry = GoalEntry(
        id: _generateId('ge'),
        goalId: goal.id,
        date: firstOfMonth,
        amount: monthly,
        note: 'Auto contribution ($monthKey)',
        sourceRef: sourceRef,
      );

      await storage.goalEntryBox.put(entry.id, entry);
      createdEntries.add(entry);
    }

    if (createdEntries.isNotEmpty) {
      _notify();
    }

    return createdEntries;
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

  // ---------------------------------------------------------------------------
  // BUDGET OVERRIDES & SETTINGS
  // ---------------------------------------------------------------------------

  Map<String, double> getAllBudgetOverrides() {
    final map = <String, double>{};
    for (final ov in storage.budgetOverrideBox.values) {
      map['${ov.lineId}_${ov.monthKey}'] = ov.amount;
    }
    return map;
  }

  Future<void> setBudgetOverride(String lineId, String monthKey, double amount) async {
    final key = '${lineId}_$monthKey';
    final override = BudgetOverride(
      lineId: lineId,
      monthKey: monthKey,
      amount: Money.r2(amount),
    );
    await storage.budgetOverrideBox.put(key, override);
    _notify();
  }

  Future<void> removeBudgetOverride(String lineId, String monthKey) async {
    final key = '${lineId}_$monthKey';
    await storage.budgetOverrideBox.delete(key);
    _notify();
  }

  String getBudgetMode() {
    return storage.settingsBox.get('budget_mode', defaultValue: 'simple');
  }

  Future<void> setBudgetMode(String mode) async {
    await storage.settingsBox.put('budget_mode', mode);
    _notify();
  }

  double? getExpectedIncome() {
    final val = storage.settingsBox.get('expected_income');
    if (val is num) return val.toDouble();
    return null;
  }

  Future<void> setExpectedIncome(double income) async {
    await storage.settingsBox.put('expected_income', Money.r2(income));
    _notify();
  }

  bool getRolloverCarryNegative() {
    return storage.settingsBox.get('rollover_carry_negative', defaultValue: false);
  }

  Future<void> setRolloverCarryNegative(bool value) async {
    await storage.settingsBox.put('rollover_carry_negative', value);
    _notify();
  }

  // --- Split Groups and Entries (Phase 12) ---

  Map<dynamic, SplitGroup> get splitGroups => storage.splitGroupBox.toMap();
  Map<dynamic, SplitEntry> get splitEntries => storage.splitEntryBox.toMap();

  Future<SplitGroup> addSplitGroup(SplitGroup group) async {
    await storage.splitGroupBox.put(group.id, group);
    _notify();
    return group;
  }

  Future<void> updateSplitGroup(SplitGroup group) async {
    await storage.splitGroupBox.put(group.id, group);
    _notify();
  }

  Future<void> deleteSplitGroup(String groupId) async {
    await storage.splitGroupBox.delete(groupId);
    final entriesToDelete = storage.splitEntryBox.values.where((e) => e.groupId == groupId).map((e) => e.id).toList();
    for (final id in entriesToDelete) {
      await storage.splitEntryBox.delete(id);
    }
    _notify();
  }

  Future<SplitEntry> addSplitEntry(SplitEntry entry) async {
    await storage.splitEntryBox.put(entry.id, entry);
    _notify();
    return entry;
  }

  Future<void> updateSplitEntry(SplitEntry entry) async {
    await storage.splitEntryBox.put(entry.id, entry);
    _notify();
  }

  Future<void> deleteSplitEntry(String entryId) async {
    await storage.splitEntryBox.delete(entryId);
    _notify();
  }

  /// Settle a split entry.
  /// If targetAccountId is available:
  /// - Receiving money creates a `reimbursement` transaction (not income) per P12-2.
  /// - Paying money creates an `expense` transaction.
  Future<void> settleSplitEntry({
    required String entryId,
    required bool isReimbursement,
    double? settlementAmount,
    String? accountId,
    String? note,
  }) async {
    final entry = storage.splitEntryBox.get(entryId);
    if (entry == null) throw ArgumentError('SplitEntry not found: $entryId');

    final amt = settlementAmount ?? entry.amount;
    final targetAccountId = accountId ?? storage.accountBox.values.where((a) => a.spendable && !a.archived).firstOrNull?.id;

    if (targetAccountId != null && amt > 0) {
      if (isReimbursement) {
        await addTransaction(TxDraft(
          title: 'Settlement: ${entry.title}',
          amount: amt,
          kind: 'reimbursement',
          mode: 'income',
          category: 'Reimbursement',
          accountId: targetAccountId,
          date: DateTime.now(),
          notes: note ?? 'Split settlement reimbursement',
        ));
      } else {
        await addTransaction(TxDraft(
          title: 'Settlement: ${entry.title}',
          amount: amt,
          kind: 'expense',
          mode: 'expense',
          category: 'Other',
          accountId: targetAccountId,
          date: DateTime.now(),
          notes: note ?? 'Split settlement payment',
        ));
      }
    }

    entry.settled = true;
    await entry.save();
    _notify();
  }
}
