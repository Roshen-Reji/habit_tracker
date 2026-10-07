import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/money/data/balance_check.dart';
import 'package:habit_tracker/features/money/data/money_store.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/money/core/minor.dart';
import 'package:habit_tracker/models/finance_model.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late MoneyStore store;
  late BalanceCheckService balanceCheckService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('balance_check_test_');
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
    FinanceStorage.resetForTesting();
    storage = FinanceStorage();
    await storage.init();
    await storage.clearAll();

    store = MoneyStore(storage: storage);
    balanceCheckService = BalanceCheckService(storage: storage, store: store);
  });

  group('Milestone M3: Balance Check & Migration Safety', () {
    test('Safety backup is written before any migration action', () async {
      // Create a sample transaction
      final tx = Transaction(
        id: 'tx_backup_sample',
        title: 'Salary',
        amount: 50000.0,
        category: 'Income',
        date: DateTime.now(),
        mode: 'Income',
        icon: 'wallet',
        accountId: 'acc_main',
        kind: 'income',
      );
      await storage.transactionBox.put(tx.id, tx);

      final backupJson = await balanceCheckService.takeSafetyBackup();
      expect(backupJson.isNotEmpty, isTrue);
      expect(backupJson, contains('tx_backup_sample'));
      expect(backupJson, contains('Salary'));
    });

    test(
        'Discrepancy detected when transactions were ignored before openingDate',
        () async {
      final accountOpening = DateTime(2026, 10, 7, 14, 0, 0); // 2:00 PM
      final account = Account(
        id: 'acc_checking',
        name: 'Checking Account',
        kind: 'checking',
        openingBalance: 1000.0,
        openingDate: accountOpening,
        colorValue: 0xFF1E88E5,
      );
      await storage.accountBox.put(account.id, account);

      // Spend logged earlier today at 10:00 AM (ignored by old rule)
      final earlierSpend = Transaction(
        id: 'tx_earlier',
        title: 'Coffee',
        amount: -200.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 10, 0, 0),
        mode: 'Expense',
        icon: 'coffee',
        accountId: 'acc_checking',
        kind: 'expense',
      );
      await storage.transactionBox.put(earlierSpend.id, earlierSpend);

      final discrepancies = balanceCheckService.computeDiscrepancies(
        asOf: DateTime(2026, 10, 7, 23, 59, 59),
      );

      expect(discrepancies.length, equals(1));
      final d = discrepancies.first;
      expect(d.hasDiscrepancy, isTrue);
      expect(d.oldBalance, equals(1000.0)); // Old rule ignored the 200 spend!
      expect(
          d.newBalance, equals(800.0)); // New L2 rule includes the 200 spend!
      expect(d.ignoredTransactions.length, equals(1));
    });

    test('Keep today\'s balances leaves every displayed balance unchanged',
        () async {
      final accountOpening = DateTime(2026, 10, 7, 14, 0, 0);
      final account = Account(
        id: 'acc_checking',
        name: 'Checking Account',
        kind: 'checking',
        openingBalance: 1000.0,
        openingDate: accountOpening,
        colorValue: 0xFF1E88E5,
      );
      await storage.accountBox.put(account.id, account);

      final earlierSpend = Transaction(
        id: 'tx_earlier',
        title: 'Coffee',
        amount: -200.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 10, 0, 0),
        mode: 'Expense',
        icon: 'coffee',
        accountId: 'acc_checking',
        kind: 'expense',
      );
      await storage.transactionBox.put(earlierSpend.id, earlierSpend);

      final cutoff = DateTime(2026, 10, 7, 23, 59, 59);

      // User selects "Keep today's balances"
      await balanceCheckService.applyKeepTodayBalances(asOf: cutoff);

      expect(balanceCheckService.isMigrationDone, isTrue);

      // Re-query: opening balance should be calibrated so displayed balance matches oldBalance exactly
      final recomputed = balanceCheckService.computeDiscrepancies(asOf: cutoff);
      final adjusted = recomputed.first;

      // Displayed balance under Law L2 matches the previous displayed balance (1000.0) exactly!
      expect(adjusted.newBalance, equals(1000.0));
      expect(MoneyState().value.balancesByAccountMinor[account.id],
          equals(Minor.toMinor(1000.0)));
    });

    test('Use new balances directly adopts corrected L2 balances', () async {
      final accountOpening = DateTime(2026, 10, 7, 14, 0, 0);
      final account = Account(
        id: 'acc_checking',
        name: 'Checking Account',
        kind: 'checking',
        openingBalance: 1000.0,
        openingDate: accountOpening,
        colorValue: 0xFF1E88E5,
      );
      await storage.accountBox.put(account.id, account);

      final earlierSpend = Transaction(
        id: 'tx_earlier',
        title: 'Coffee',
        amount: -200.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 10, 0, 0),
        mode: 'Expense',
        icon: 'coffee',
        accountId: 'acc_checking',
        kind: 'expense',
      );
      await storage.transactionBox.put(earlierSpend.id, earlierSpend);

      await balanceCheckService.applyUseNewBalances();
      expect(balanceCheckService.isMigrationDone, isTrue);

      // MoneyState snapshot should now reflect 800.0
      MoneyState().refreshFromStore(store);
      expect(MoneyState().value.mainBalanceMinor, equals(80000));
    });

    test('Legacy duplicate detection finds duplicate SIP entries', () async {
      final tx1 = Transaction(
        id: 'tx_sip_1',
        title: 'Mutual Fund SIP',
        amount: 2000.0,
        category: 'Investment',
        date: DateTime(2026, 5, 5),
        mode: 'Transfer',
        icon: 'trending-up',
        accountId: 'acc_main',
        toAccountId: 'fund_sip',
        sourceRef: 'sip_rule_1_2026-05',
      );

      final tx2 = Transaction(
        id: 'tx_sip_2',
        title: 'Mutual Fund SIP',
        amount: 2000.0,
        category: 'Investment',
        date: DateTime(2026, 5, 5),
        mode: 'Transfer',
        icon: 'trending-up',
        accountId: 'acc_main',
        toAccountId: 'fund_sip',
        sourceRef: 'rec:rule_1:2026-05-05',
      );

      await storage.transactionBox.put(tx1.id, tx1);
      await storage.transactionBox.put(tx2.id, tx2);

      final duplicates = balanceCheckService.checkLegacyDuplicates();
      expect(duplicates.length, equals(2));
      expect(duplicates.first.reason, contains('Duplicate SIP references'));
    });
  });
}
