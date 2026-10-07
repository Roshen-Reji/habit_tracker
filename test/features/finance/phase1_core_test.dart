import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/backup/finance_backup_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/data/migrations/finance_migrator.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late FinanceRepository repository;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('finance_test_');
    Hive.init(tempDir.path);
    FinanceStorage.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    storage = FinanceStorage();
    await storage.init();
    await storage.clearAll();
    repository = FinanceRepository(storage: storage);
  });

  group('P1-4: Money and Formatting', () {
    test('Money.r2 rounds half away from zero to 2 decimal places', () {
      expect(Money.r2(0.1 + 0.2), equals(0.3));
      expect(Money.r2(123.456), equals(123.46));
      expect(Money.r2(123.454), equals(123.45));
      expect(Money.r2(-123.456), equals(-123.46));
      expect(Money.r2(-123.454), equals(-123.45));
    });

    test(
        'FormatUtils.formatMoney formats with Indian grouping and compact forms',
        () {
      expect(FormatUtils.formatMoney(142850, decimals: 0), equals('₹1,42,850'));
      expect(FormatUtils.formatMoney(280000, compact: true), equals('₹2.8L'));
      expect(
          FormatUtils.formatMoney(15000000, compact: true), equals('₹1.5Cr'));
      expect(FormatUtils.formatMoney(5000, compact: true), equals('₹5K'));
      expect(FormatUtils.formatMoney(-4500, compact: true), equals('-₹4.5K'));
    });
  });

  group('P1-5: Ledger Engine & Invariants (I1-I4)', () {
    test('I1: Transfers and investments do not alter Net Worth', () {
      final checking = Account(
        id: 'acc_bank',
        name: 'Bank',
        kind: 'bank',
        openingBalance: 10000.0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF2196F3,
      );
      final savings = Account(
        id: 'acc_savings',
        name: 'Savings',
        kind: 'bank',
        openingBalance: 5000.0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4CAF50,
      );
      final accounts = [checking, savings];
      final valuations = <Valuation>[];

      final initialNW = LedgerEngine.netWorth(accounts, [], valuations);
      expect(initialNW, equals(15000.0));

      // Perform a transfer of 2000 from Bank to Savings
      final txTransfer = Transaction(
        title: 'Transfer to savings',
        amount: 2000.0,
        category: 'Transfer',
        date: DateTime(2026, 1, 10),
        mode: 'transfer',
        icon: 'transfer',
        kind: 'transfer',
        accountId: checking.id,
        toAccountId: savings.id,
      );

      final nwAfterTransfer =
          LedgerEngine.netWorth(accounts, [txTransfer], valuations);
      expect(nwAfterTransfer, equals(15000.0));
      expect(LedgerEngine.balance(checking, [txTransfer], valuations),
          equals(8000.0));
      expect(LedgerEngine.balance(savings, [txTransfer], valuations),
          equals(7000.0));
    });

    test('I2 & I3: Split transaction with owed line expands correctly', () {
      // Example from spec: ₹1,200 total (700 food, 300 entertainment, 200 owed)
      // yields spending = 1,000, receivable = 200
      final splitJson = jsonEncode([
        {'categoryId': 'cat_food', 'amount': 700.0, 'isOwed': false},
        {'categoryId': 'cat_ent', 'amount': 300.0, 'isOwed': false},
        {
          'categoryId': 'cat_other',
          'amount': 200.0,
          'isOwed': true,
          'counterparty': 'Bob'
        },
      ]);

      final tx = Transaction(
        title: 'Dinner & Movie with Bob',
        amount: -1200.0,
        category: 'Food',
        date: DateTime(2026, 2, 1),
        mode: 'expense',
        icon: 'expense',
        kind: 'expense',
        accountId: 'acc_main',
        splits: splitJson,
      );

      final totalSpent = LedgerEngine.spending([tx]);
      expect(totalSpent, equals(1000.0));

      final receivables = LedgerEngine.receivablesFromSplits([tx]);
      expect(receivables, equals(200.0));

      final catBreakdown = LedgerEngine.categorySpending([tx]);
      expect(catBreakdown['cat_food'], equals(700.0));
      expect(catBreakdown['cat_ent'], equals(300.0));
      expect(catBreakdown['cat_other'],
          isNull); // Owed line excluded from spending
    });

    test('I3: Refunds subtract from category spending', () {
      final txExpense = Transaction(
        title: 'Shoes',
        amount: -2500.0,
        category: 'Shopping',
        date: DateTime(2026, 3, 1),
        mode: 'expense',
        icon: 'expense',
        kind: 'expense',
        categoryId: 'cat_shopping',
        accountId: 'acc_main',
      );

      final txRefund = Transaction(
        title: 'Shoes Return Refund',
        amount: 1000.0,
        category: 'Shopping',
        date: DateTime(2026, 3, 5),
        mode: 'income',
        icon: 'income',
        kind: 'refund',
        categoryId: 'cat_shopping',
        accountId: 'acc_main',
      );

      final netShoppingSpend = LedgerEngine.spending([txExpense, txRefund],
          categoryId: 'cat_shopping');
      expect(netShoppingSpend, equals(1500.0));
    });

    test('Valued accounts fallback to latest valuation <= asOf', () {
      final stockAcc = Account(
        id: 'acc_stocks',
        name: 'Mutual Funds',
        kind: 'investment',
        openingBalance: 0.0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF9C27B0,
      );

      final v1 = Valuation(
        id: 'v1',
        accountId: stockAcc.id,
        date: DateTime(2026, 1, 15),
        value: 50000.0,
      );
      final v2 = Valuation(
        id: 'v2',
        accountId: stockAcc.id,
        date: DateTime(2026, 2, 15),
        value: 54000.0,
      );

      final balJan = LedgerEngine.balance(
        stockAcc,
        [],
        [v1, v2],
        asOf: DateTime(2026, 1, 31),
      );
      expect(balJan, equals(50000.0));

      final balFeb = LedgerEngine.balance(
        stockAcc,
        [],
        [v1, v2],
        asOf: DateTime(2026, 2, 28),
      );
      expect(balFeb, equals(54000.0));
    });
  });

  group('P1-1: FinanceRepository & Invariant I6', () {
    test(
        'I6: Transfer validation prevents identical source & destination accounts',
        () async {
      expect(
        () => repository.transfer(
          fromAccountId: 'acc_same',
          toAccountId: 'acc_same',
          amount: 500.0,
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('I6: Split validation fails when parts do not sum to total', () async {
      final invalidSplits = jsonEncode([
        {'categoryId': 'cat_food', 'amount': 400.0},
        {'categoryId': 'cat_travel', 'amount': 400.0},
      ]);

      expect(
        () => repository.addTransaction(TxDraft(
          title: 'Lunch & Taxi',
          amount: 1000.0,
          date: DateTime.now(),
          kind: 'expense',
          splits: invalidSplits,
        )),
        throwsArgumentError,
      );
    });

    test('Transaction deletion and in-session undo works', () async {
      final tx = await repository.addTransaction(TxDraft(
        title: 'Coffee',
        amount: 150.0,
        date: DateTime.now(),
        kind: 'expense',
      ));

      expect(storage.transactionBox.length, equals(1));

      await repository.deleteTransaction(tx.id);
      expect(storage.transactionBox.length, equals(0));

      final restored = await repository.undoDelete();
      expect(restored, isNotNull);
      expect(restored!.title, equals('Coffee'));
      expect(storage.transactionBox.length, equals(1));
    });
  });

  group('P1-0 & P1-3: Backup and Migration v1 -> v2 (Invariant I5)', () {
    test('Migration preserves total balance exactly (Invariant I5)', () async {
      // 1. Populate legacy v1 state:
      // Vault 1: 25,000
      // Vault 2: 10,000
      final v1 = AssetVault(
        name: 'HDFC Bank',
        balance: 25000.0,
        bank: 'Savings',
        type: 'Savings',
        colorValue: 0xFF2196F3,
      );
      final v2 = AssetVault(
        name: 'Cash In Hand',
        balance: 10000.0,
        bank: 'Cash',
        type: 'Cash',
        colorValue: 0xFF4CAF50,
      );
      await storage.vaultBox.add(v1);
      await storage.vaultBox.add(v2);

      // Legacy transactions:
      // Salary: +50,000
      // Rent: -15,000
      // Groceries: -5,000
      // Net transactions = +30,000
      await storage.transactionBox.add(Transaction(
        title: 'Salary',
        amount: 50000.0,
        category: 'Salary',
        date: DateTime(2026, 1, 1),
        mode: 'income',
        icon: 'income',
      ));
      await storage.transactionBox.add(Transaction(
        title: 'Rent',
        amount: -15000.0,
        category: 'Rent',
        date: DateTime(2026, 1, 2),
        mode: 'expense',
        icon: 'expense',
      ));
      await storage.transactionBox.add(Transaction(
        title: 'Groceries',
        amount: -5000.0,
        category: 'Groceries',
        date: DateTime(2026, 1, 3),
        mode: 'expense',
        icon: 'expense',
      ));

      // Legacy goal saved: 8,000
      await storage.settingsBox.put('goals', [
        {
          'name': 'Laptop Fund',
          'target': 80000.0,
          'saved': 8000.0,
          'deadline': '2026-12-31',
          'color': 0xFF9C27B0,
        }
      ]);

      // Pre-migration total:
      // Vaults (35,000) + Transactions (30,000) + Goals Saved (8,000) = 73,000
      final migrator = FinanceMigrator(storage: storage);
      final success = await migrator.migrateIfNeeded();
      expect(success, isTrue);

      // Post-migration accounts sum
      double postMigrationTotal = 0.0;
      final txs = storage.transactionBox.values;
      final vals = storage.valuationBox.values;

      for (final acc in storage.accountBox.values) {
        postMigrationTotal += LedgerEngine.balance(acc, txs, vals);
      }

      expect(Money.r2(postMigrationTotal), equals(73000.0));

      // Idempotency: running a second time changes nothing
      final secondRun = await migrator.migrateIfNeeded();
      expect(secondRun, isTrue);
      expect(storage.settingsBox.get('fin_schema_version'), equals(2));
    });

    test('P1-0: FinanceBackupService round-trips export, wipe and import',
        () async {
      await repository.addAccount(Account(
        id: 'acc_test',
        name: 'Test Bank',
        kind: 'bank',
        openingBalance: 12000.0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF00BCD4,
      ));

      await repository.addTransaction(TxDraft(
        title: 'Test Coffee',
        amount: 200.0,
        date: DateTime(2026, 1, 1),
        kind: 'expense',
        accountId: 'acc_test',
      ));

      final exportedJson = await FinanceBackupService.exportJson();
      expect(exportedJson, isNotEmpty);

      // Wipe all boxes
      await storage.clearAll();
      expect(storage.accountBox.isEmpty, isTrue);
      expect(storage.transactionBox.isEmpty, isTrue);

      // Import back
      final summary = await FinanceBackupService.importJson(exportedJson);
      expect(summary['accounts'], equals(1));
      expect(summary['transactions'], equals(1));
      expect(storage.accountBox.get('acc_test')?.name, equals('Test Bank'));
      expect(storage.transactionBox.values.first.title, equals('Test Coffee'));
    });
  });
}
