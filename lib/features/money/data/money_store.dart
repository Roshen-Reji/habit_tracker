import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/recurring_rule.dart';
import 'package:habit_tracker/features/finance/models/valuation.dart';
import 'package:habit_tracker/models/finance_model.dart';
import '../core/account_group.dart';
import '../core/entry.dart';
import '../core/ledger.dart';
import '../core/minor.dart';
import '../core/plan_engine.dart';

/// Storage adapter interfacing with existing Hive boxes.
///
/// Preserves existing schemas, Hive field indices, and type IDs without changes.
/// Converts between floating-point storage representation and pure integer minor units.
class MoneyStore {
  final FinanceStorage storage;

  MoneyStore({FinanceStorage? storage}) : storage = storage ?? FinanceStorage();

  // ---------------------------------------------------------------------------
  // READS
  // ---------------------------------------------------------------------------

  /// Loads all transactions converted to immutable [Entry] objects.
  List<Entry> loadEntries() {
    final list = <Entry>[];
    for (final tx in storage.transactionBox.values) {
      final id =
          tx.id ?? tx.key?.toString() ?? 'tx_${tx.date.millisecondsSinceEpoch}';
      list.add(Entry.fromRaw(
        id: id,
        rawAmount: tx.amount,
        rawMode: tx.mode,
        rawKind: tx.kind,
        accountId: tx.accountId,
        toAccountId: tx.toAccountId,
        date: tx.date,
        title: tx.title,
        category: tx.category,
        categoryId: tx.categoryId,
        notes: tx.notes,
        sourceRef: tx.sourceRef,
        createdAt: tx.createdAt,
        rawInterest: tx.interestAmount,
        icon: tx.icon,
      ));
    }
    return list;
  }

  /// Loads all accounts converted to [CoreAccount] instances.
  List<CoreAccount> loadAccounts(String mainAccountId) {
    final list = <CoreAccount>[];
    for (final acc in storage.accountBox.values) {
      list.add(CoreAccount.fromRaw(
        id: acc.id,
        name: acc.name,
        rawKind: acc.kind,
        openingBalance: acc.openingBalance,
        openingDate: acc.openingDate,
        mainAccountId: mainAccountId,
        annualRate: acc.annualRate,
        emi: acc.emi,
        tenureMonths: acc.tenureMonths,
        colorValue: acc.colorValue,
        archived: acc.archived,
      ));
    }
    return list;
  }

  /// Loads all automation plans converted to [CorePlan] instances.
  List<CorePlan> loadPlans() {
    final list = <CorePlan>[];
    for (final r in storage.recurringBox.values) {
      PlanKind kind;
      final k = r.kind.toLowerCase();
      if (k == 'sip') {
        kind = PlanKind.sip;
      } else if (k == 'emi') {
        kind = PlanKind.emi;
      } else if (k == 'income') {
        kind = PlanKind.income;
      } else {
        kind = PlanKind.bill;
      }

      final day = r.dayOfMonth ?? (r.anchorDate?.day ?? r.startDate.day);

      list.add(CorePlan(
        id: r.id,
        title: r.name,
        kind: kind,
        amountMinor: Minor.toMinor(r.amount),
        dayOfMonth: day,
        fromAccountId: r.accountId,
        toAccountId: r.toAccountId,
        startDate: r.startDate,
        endDate: r.endDate,
        autoPost: r.autoPost,
        isPaused: r.status == 'paused',
        categoryId: r.categoryId,
      ));
    }
    return list;
  }

  /// Loads all valuations converted to [CoreValuation] instances.
  List<CoreValuation> loadValuations() {
    final list = <CoreValuation>[];
    for (final v in storage.valuationBox.values) {
      list.add(CoreValuation(
        id: v.id,
        accountId: v.accountId,
        valueMinor: Minor.toMinor(v.value),
        date: v.date,
      ));
    }
    return list;
  }

  /// Reads a setting from `finance_settings`.
  T getSetting<T>(String key, {required T defaultValue}) {
    return storage.settingsBox.get(key, defaultValue: defaultValue) as T;
  }

  /// Writes a setting to `finance_settings`.
  Future<void> setSetting(String key, dynamic value) async {
    await storage.settingsBox.put(key, value);
  }

  // ---------------------------------------------------------------------------
  // WRITES (Persisting into existing Hive boxes)
  // ---------------------------------------------------------------------------

  /// Persists an [Entry] into `finance_transactions`.
  Future<void> saveEntry(Entry entry) async {
    final legacy = entry.toLegacyStorage();
    Transaction? existing;

    for (final tx in storage.transactionBox.values) {
      if (tx.id == entry.id) {
        existing = tx;
        break;
      }
    }

    if (existing != null) {
      existing.title = entry.title;
      existing.amount = legacy.amount;
      existing.category = entry.category;
      existing.date = entry.date;
      existing.mode = legacy.mode;
      existing.kind = legacy.kind;
      existing.accountId = entry.fromAccountId ?? entry.toAccountId;
      existing.toAccountId = entry.toAccountId;
      existing.categoryId = entry.categoryId;
      existing.notes = entry.notes;
      existing.sourceRef = entry.sourceRef;
      existing.interestAmount = entry.interestMinor != null
          ? Minor.fromMinor(entry.interestMinor!)
          : null;
      if (entry.icon != null) existing.icon = entry.icon!;
      await existing.save();
    } else {
      final newTx = Transaction(
        id: entry.id,
        title: entry.title,
        amount: legacy.amount,
        category: entry.category,
        date: entry.date,
        mode: legacy.mode,
        icon: entry.icon ?? 'circle-dollar-sign',
        kind: legacy.kind,
        accountId: entry.fromAccountId ?? entry.toAccountId,
        toAccountId: entry.toAccountId,
        categoryId: entry.categoryId,
        notes: entry.notes,
        sourceRef: entry.sourceRef,
        createdAt: entry.createdAt,
        interestAmount: entry.interestMinor != null
            ? Minor.fromMinor(entry.interestMinor!)
            : null,
      );
      await storage.transactionBox.put(entry.id, newTx);
    }
  }

  /// Deletes an entry from `finance_transactions`.
  Future<void> deleteEntry(String id) async {
    dynamic targetKey;
    for (final tx in storage.transactionBox.values) {
      if (tx.id == id) {
        targetKey = tx.key;
        break;
      }
    }
    if (targetKey != null) {
      await storage.transactionBox.delete(targetKey);
    } else {
      await storage.transactionBox.delete(id);
    }
  }

  /// Persists a plan into `fin_recurring`.
  Future<void> savePlan(CorePlan plan) async {
    String kindStr;
    switch (plan.kind) {
      case PlanKind.sip:
        kindStr = 'sip';
        break;
      case PlanKind.emi:
        kindStr = 'emi';
        break;
      case PlanKind.income:
        kindStr = 'income';
        break;
      case PlanKind.bill:
        kindStr = 'bill';
        break;
    }

    final rule = RecurringRule(
      id: plan.id,
      name: plan.title,
      kind: kindStr,
      amount: Minor.fromMinor(plan.amountMinor),
      amountIsVariable: false,
      categoryId: plan.categoryId,
      accountId: plan.fromAccountId,
      toAccountId: plan.toAccountId,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: plan.dayOfMonth,
      startDate: plan.startDate,
      endDate: plan.endDate,
      autoPost: plan.autoPost,
      reminderDaysBefore: 1,
      status: plan.isPaused ? 'paused' : 'active',
      createdAt: DateTime.now(),
    );

    await storage.recurringBox.put(plan.id, rule);
  }

  /// Deletes a plan from `fin_recurring`.
  Future<void> deletePlan(String id) async {
    await storage.recurringBox.delete(id);
  }

  /// Saves a valuation into `fin_valuations`.
  Future<void> saveValuation(CoreValuation valuation) async {
    final v = Valuation(
      id: valuation.id,
      accountId: valuation.accountId,
      date: valuation.date,
      value: Minor.fromMinor(valuation.valueMinor),
    );
    await storage.valuationBox.put(valuation.id, v);
  }

  /// Saves an account into `fin_accounts`.
  Future<void> saveAccount(CoreAccount account) async {
    final acc = Account(
      id: account.id,
      name: account.name,
      kind: account.rawKind,
      openingBalance: Minor.fromMinor(account.openingBalanceMinor),
      openingDate: account.openingDate,
      colorValue: account.colorValue,
      archived: account.archived,
      annualRate: account.annualRatePct,
      emi: account.emiMinor != null ? Minor.fromMinor(account.emiMinor!) : null,
      tenureMonths: account.tenureMonths,
    );
    await storage.accountBox.put(account.id, acc);
  }
}
