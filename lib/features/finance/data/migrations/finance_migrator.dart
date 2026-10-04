import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:habit_tracker/features/finance/data/backup/finance_backup_service.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/constants.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Migrator implementing idempotent v1 -> v2 schema migration and Invariant I5 validation.
class FinanceMigrator {
  final FinanceStorage storage;

  FinanceMigrator({FinanceStorage? storage})
      : storage = storage ?? FinanceStorage();

  Future<bool> migrateIfNeeded() async {
    final settingsBox = storage.settingsBox;
    final currentVersion =
        settingsBox.get('fin_schema_version', defaultValue: 1);
    if (currentVersion >= 2) {
      debugPrint(
          '[FinanceMigrator] Schema is already v$currentVersion. Skipping migration.');
      return true;
    }

    debugPrint('[FinanceMigrator] Starting v1 -> v2 migration...');

    // P1-0: Safety net automatic backup before migration
    try {
      await FinanceBackupService.exportJson();
    } catch (e) {
      debugPrint('[FinanceMigrator] Pre-migration backup warning: $e');
    }

    // Capture pre-migration balance
    final oldVaultTotal = storage.vaultBox.values.fold<double>(
      0.0,
      (sum, v) => sum + v.balance,
    );

    double oldAllTimeNet = 0.0;
    for (final tx in storage.transactionBox.values) {
      final isExp = tx.mode.toLowerCase() == 'expense' || tx.amount < 0;
      oldAllTimeNet += (isExp ? -tx.amount.abs() : tx.amount.abs());
    }

    final rawGoals = List.from(settingsBox.get('goals', defaultValue: []));
    final oldGoalsSaved = rawGoals.fold<double>(
      0.0,
      (sum, g) => sum + Money.asDouble((g as Map)['saved']),
    );

    final preMigrationTotal =
        Money.r2(oldVaultTotal + oldAllTimeNet + oldGoalsSaved);
    debugPrint(
        '[FinanceMigrator] Pre-migration total balance: $preMigrationTotal');

    final steps = <String>[];

    try {
      // 1. Seed Categories
      await _seedCategories();
      steps.add('categories');

      // 2. Backfill Transactions
      await _backfillTransactions();
      steps.add('transactions');

      // 3. Migrate Vaults to Accounts
      await _migrateAccounts(oldGoalsSaved);
      steps.add('accounts');

      // 4. Migrate Budgets to BudgetLines
      await _migrateBudgets();
      steps.add('budgets');

      // 5. Migrate Goals to SavingsGoals & GoalEntries
      await _migrateGoals(rawGoals);
      steps.add('goals');

      // 6. Migrate Planner (fixed expenses & sips) to RecurringRules
      await _migratePlanner();
      steps.add('planner');

      // 7. Verify Invariant I5 (zero balance delta)
      final allAccounts = storage.accountBox.values;
      final allTx = storage.transactionBox.values;
      final allValuations = storage.valuationBox.values;

      double postMigrationTotal = 0.0;
      for (final acc in allAccounts) {
        postMigrationTotal += LedgerEngine.balance(acc, allTx, allValuations);
      }
      postMigrationTotal = Money.r2(postMigrationTotal);

      final diff = (preMigrationTotal - postMigrationTotal).abs();
      if (diff > 0.01) {
        throw StateError(
          'Invariant I5 violated! Pre-migration total ($preMigrationTotal) != Post-migration total ($postMigrationTotal)',
        );
      }

      steps.add('verified_i5');
      await settingsBox.put('fin_schema_version', 2);
      await settingsBox.put('fin_migrated_steps', steps);

      debugPrint(
          '[FinanceMigrator] Migration successfully completed and verified.');
      return true;
    } catch (e, st) {
      debugPrint('[FinanceMigrator] Migration failed with error: $e\n$st');
      rethrow;
    }
  }

  Future<void> _seedCategories() async {
    final catBox = storage.categoryBox;
    if (catBox.isNotEmpty) return;

    final defaults = <Category>[
      // Needs (essential = true)
      Category(
        id: FinanceConstants.catFood,
        name: 'Food',
        kind: 'expense',
        group: 'needs',
        iconKey: 'utensils',
        colorValue: 0xFFFF5722,
        essential: true,
        sortOrder: 1,
      ),
      Category(
        id: FinanceConstants.catGroceries,
        name: 'Groceries',
        kind: 'expense',
        group: 'needs',
        iconKey: 'shopping_basket',
        colorValue: 0xFF4CAF50,
        essential: true,
        sortOrder: 2,
      ),
      Category(
        id: FinanceConstants.catTransport,
        name: 'Transport',
        kind: 'expense',
        group: 'needs',
        iconKey: 'car',
        colorValue: 0xFF2196F3,
        essential: true,
        sortOrder: 3,
      ),
      Category(
        id: FinanceConstants.catUtilities,
        name: 'Utilities',
        kind: 'expense',
        group: 'needs',
        iconKey: 'zap',
        colorValue: 0xFFFF9800,
        essential: true,
        sortOrder: 4,
      ),
      Category(
        id: FinanceConstants.catHealth,
        name: 'Health',
        kind: 'expense',
        group: 'needs',
        iconKey: 'activity',
        colorValue: 0xFFE91E63,
        essential: true,
        sortOrder: 5,
      ),
      Category(
        id: FinanceConstants.catRent,
        name: 'Rent',
        kind: 'expense',
        group: 'needs',
        iconKey: 'home',
        colorValue: 0xFF9C27B0,
        essential: true,
        sortOrder: 6,
      ),
      Category(
        id: FinanceConstants.catEducation,
        name: 'Education',
        kind: 'expense',
        group: 'needs',
        iconKey: 'book',
        colorValue: 0xFF3F51B5,
        essential: true,
        sortOrder: 7,
      ),
      Category(
        id: FinanceConstants.catEmi,
        name: 'EMI',
        kind: 'expense',
        group: 'needs',
        iconKey: 'credit_card',
        colorValue: 0xFF607D8B,
        essential: true,
        sortOrder: 8,
      ),
      Category(
        id: FinanceConstants.catInsurance,
        name: 'Insurance',
        kind: 'expense',
        group: 'needs',
        iconKey: 'shield',
        colorValue: 0xFF009688,
        essential: true,
        sortOrder: 9,
      ),

      // Wants (essential = false)
      Category(
        id: FinanceConstants.catShopping,
        name: 'Shopping',
        kind: 'expense',
        group: 'wants',
        iconKey: 'shopping_bag',
        colorValue: 0xFFE040FB,
        essential: false,
        sortOrder: 10,
      ),
      Category(
        id: FinanceConstants.catEntertainment,
        name: 'Entertainment',
        kind: 'expense',
        group: 'wants',
        iconKey: 'film',
        colorValue: 0xFFFF4081,
        essential: false,
        sortOrder: 11,
      ),
      Category(
        id: FinanceConstants.catOtt,
        name: 'OTT',
        kind: 'expense',
        group: 'wants',
        iconKey: 'tv',
        colorValue: 0xFF7C4DFF,
        essential: false,
        sortOrder: 12,
      ),
      Category(
        id: FinanceConstants.catTravel,
        name: 'Travel',
        kind: 'expense',
        group: 'wants',
        iconKey: 'compass',
        colorValue: 0xFF00BCD4,
        essential: false,
        sortOrder: 13,
      ),
      Category(
        id: FinanceConstants.catSubscriptions,
        name: 'Subscriptions',
        kind: 'expense',
        group: 'wants',
        iconKey: 'calendar',
        colorValue: 0xFF536DFE,
        essential: false,
        sortOrder: 14,
      ),
      Category(
        id: FinanceConstants.catGifts,
        name: 'Gifts',
        kind: 'expense',
        group: 'wants',
        iconKey: 'gift',
        colorValue: 0xFFFF5252,
        essential: false,
        sortOrder: 15,
      ),
      Category(
        id: FinanceConstants.catPersonalCare,
        name: 'Personal Care',
        kind: 'expense',
        group: 'wants',
        iconKey: 'smile',
        colorValue: 0xFFFFAB40,
        essential: false,
        sortOrder: 16,
      ),
      Category(
        id: FinanceConstants.catOther,
        name: 'Other',
        kind: 'expense',
        group: 'wants',
        iconKey: 'more_horizontal',
        colorValue: 0xFF9E9E9E,
        essential: false,
        sortOrder: 17,
      ),

      // Savings & Settlements
      Category(
        id: FinanceConstants.catInterestFees,
        name: 'Interest & fees',
        kind: 'expense',
        group: 'needs',
        iconKey: 'percent',
        colorValue: 0xFF795548,
        essential: true,
        sortOrder: 18,
      ),
      Category(
        id: FinanceConstants.catReimbursement,
        name: 'Reimbursement',
        kind: 'income',
        group: 'savings',
        iconKey: 'repeat',
        colorValue: 0xFF00E676,
        essential: false,
        sortOrder: 19,
      ),

      // Income
      Category(
        id: FinanceConstants.catIncome,
        name: 'Income',
        kind: 'income',
        group: 'savings',
        iconKey: 'dollar_sign',
        colorValue: 0xFF4CAF50,
        essential: false,
        sortOrder: 20,
      ),
      Category(
        id: FinanceConstants.catSalary,
        name: 'Salary',
        kind: 'income',
        group: 'savings',
        iconKey: 'briefcase',
        colorValue: 0xFF2E7D32,
        essential: false,
        sortOrder: 21,
      ),
      Category(
        id: 'cat_refund',
        name: 'Refund',
        kind: 'income',
        group: 'savings',
        iconKey: 'arrow_left',
        colorValue: 0xFF00BCD4,
        essential: false,
        sortOrder: 22,
      ),
    ];

    for (final cat in defaults) {
      await catBox.put(cat.id, cat);
    }
  }

  Future<void> _backfillTransactions() async {
    final txBox = storage.transactionBox;
    final catList = storage.categoryBox.values.toList();

    for (var i = 0; i < txBox.length; i++) {
      final tx = txBox.getAt(i);
      if (tx == null) continue;

      bool modified = false;

      if (tx.id == null || tx.id!.isEmpty) {
        tx.id = 'legacy-${tx.key ?? i}';
        modified = true;
      }

      if (tx.createdAt == null) {
        tx.createdAt = tx.date;
        modified = true;
      }

      if (tx.kind == null || tx.kind!.isEmpty) {
        tx.kind = tx.mode.toLowerCase() == 'expense' || tx.amount < 0
            ? 'expense'
            : 'income';
        modified = true;
      }

      if (tx.categoryId == null) {
        final catMatch = catList.firstWhere(
          (c) => c.name.toLowerCase() == tx.category.toLowerCase(),
          orElse: () => catList.firstWhere(
            (c) => c.id == FinanceConstants.catOther,
            orElse: () => catList.first,
          ),
        );
        tx.categoryId = catMatch.id;
        modified = true;
      }

      if (tx.accountId == null) {
        tx.accountId = FinanceConstants.defaultAccountId;
        modified = true;
      }

      if (modified) {
        await tx.save();
      }
    }
  }

  Future<void> _migrateAccounts(double oldGoalsSaved) async {
    final accBox = storage.accountBox;

    // 1. Create Main Account
    if (!accBox.containsKey(FinanceConstants.defaultAccountId)) {
      final mainAccount = Account(
        id: FinanceConstants.defaultAccountId,
        name: 'Main Account',
        kind: 'bank',
        institution: null,
        openingBalance: 0.0,
        openingDate: DateTime(2020, 1, 1),
        colorValue: 0xFF2196F3,
        spendable: true,
      );
      await accBox.put(mainAccount.id, mainAccount);
    }

    // 2. Migrate Vaults to Accounts
    for (final v in storage.vaultBox.values) {
      final accId =
          'acc_vault_${v.key ?? v.name.replaceAll(' ', '_').toLowerCase()}';
      if (!accBox.containsKey(accId)) {
        String kind = 'bank';
        final t = v.type.toLowerCase();
        if (t.contains('wallet')) {
          kind = 'wallet';
        } else if (t.contains('cash')) {
          kind = 'cash';
        } else if (t.contains('invest') || t.contains('sip')) {
          kind = 'investment';
        }

        final acc = Account(
          id: accId,
          name: v.name,
          kind: kind,
          institution: null,
          openingBalance: v.balance,
          openingDate: DateTime(2020, 1, 1),
          colorValue: v.colorValue,
          spendable: kind != 'investment',
        );
        await accBox.put(acc.id, acc);
      }
    }

    // 3. Goal Savings Migrated Account (to preserve Invariant I5)
    if (oldGoalsSaved > 0 &&
        !accBox.containsKey(FinanceConstants.migratedGoalsAccountId)) {
      final goalsAccount = Account(
        id: FinanceConstants.migratedGoalsAccountId,
        name: 'Goal savings (migrated)',
        kind: 'bank',
        institution: null,
        openingBalance: oldGoalsSaved,
        openingDate: DateTime(2020, 1, 1),
        colorValue: 0xFF4CAF50,
        spendable: false,
      );
      await accBox.put(goalsAccount.id, goalsAccount);
    }
  }

  Future<void> _migrateBudgets() async {
    final settingsBox = storage.settingsBox;
    final rawBudgets = List.from(settingsBox.get('budgets', defaultValue: []));
    final catList = storage.categoryBox.values.toList();
    final budgetLineBox = storage.budgetLineBox;
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    for (final b in rawBudgets) {
      if (b is! Map) continue;
      final catName = b['category']?.toString() ?? '';
      final cat = catList.firstWhere(
        (c) => c.name.toLowerCase() == catName.toLowerCase(),
        orElse: () => catList.firstWhere(
          (c) => c.id == FinanceConstants.catOther,
          orElse: () => catList.first,
        ),
      );

      final lineId = 'b_${cat.id}';
      if (!budgetLineBox.containsKey(lineId)) {
        final line = BudgetLine(
          id: lineId,
          categoryId: cat.id,
          amount: Money.asDouble(b['total']),
          rollover: false,
          essential: cat.essential,
          startMonth: currentMonth,
        );
        await budgetLineBox.put(line.id, line);
      }
    }
  }

  Future<void> _migrateGoals(List rawGoals) async {
    final goalBox = storage.goalBox;
    final entryBox = storage.goalEntryBox;

    for (var i = 0; i < rawGoals.length; i++) {
      final g = rawGoals[i];
      if (g is! Map) continue;

      final goalId = 'goal_$i';
      if (!goalBox.containsKey(goalId)) {
        DateTime? deadline;
        final dStr = g['deadline']?.toString();
        if (dStr != null) {
          deadline = DateTime.tryParse(dStr);
        }

        final goal = SavingsGoal(
          id: goalId,
          name: g['name']?.toString() ?? 'Goal',
          kind: 'goal',
          targetAmount: Money.asDouble(g['target']),
          deadline: deadline,
          colorValue:
              (g['color'] is num) ? (g['color'] as num).toInt() : 0xFF4CAF50,
        );
        await goalBox.put(goal.id, goal);

        final saved = Money.asDouble(g['saved']);
        if (saved > 0) {
          final entry = GoalEntry(
            id: 'ge_migrated_$i',
            goalId: goalId,
            date: DateTime.now(),
            amount: saved,
            note: 'Initial migrated balance',
          );
          await entryBox.put(entry.id, entry);
        }
      }
    }
  }

  Future<void> _migratePlanner() async {
    final settingsBox = storage.settingsBox;
    final recurringBox = storage.recurringBox;
    final planner = Map<String, dynamic>.from(
      settingsBox
          .get('planner', defaultValue: {'fixedExpenses': [], 'sips': []}),
    );

    final fixedList = List.from(planner['fixedExpenses'] ?? []);
    final sipList = List.from(planner['sips'] ?? []);
    final now = DateTime.now();

    // Migrate fixed expenses (reminder-only: autoPost = false)
    for (var i = 0; i < fixedList.length; i++) {
      final f = fixedList[i];
      if (f is! Map) continue;
      final ruleId = 'rec_fixed_$i';
      if (!recurringBox.containsKey(ruleId)) {
        final rule = RecurringRule(
          id: ruleId,
          name: f['name']?.toString() ?? 'Fixed Expense',
          kind: 'bill',
          amount: Money.asDouble(f['amount']),
          frequency: 'monthly',
          dayOfMonth: (f['due'] is num) ? (f['due'] as num).toInt() : 1,
          startDate: now,
          autoPost: false,
          createdAt: now,
        );
        await recurringBox.put(rule.id, rule);
      }
    }

    // Migrate SIPs (autoPost = true)
    for (var i = 0; i < sipList.length; i++) {
      final s = sipList[i];
      if (s is! Map) continue;
      final rawId = s['id']?.toString();
      final ruleId = (rawId != null && rawId.isNotEmpty) ? rawId : 'rec_sip_$i';

      if (!recurringBox.containsKey(ruleId)) {
        final createdAt =
            DateTime.tryParse(s['createdAt']?.toString() ?? '') ?? now;
        final rule = RecurringRule(
          id: ruleId,
          name: s['name']?.toString() ?? 'SIP',
          kind: 'sip',
          amount: Money.asDouble(s['amount']),
          frequency: 'monthly',
          dayOfMonth: (s['due'] is num) ? (s['due'] as num).toInt() : 5,
          startDate: createdAt,
          autoPost: true,
          folio: s['folio']?.toString(),
          createdAt: createdAt,
        );
        await recurringBox.put(rule.id, rule);
      }
    }
  }
}
