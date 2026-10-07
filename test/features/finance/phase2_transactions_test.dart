import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/shell/money_shell_page.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late FinanceRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fin_p2_test_');
    Hive.init(tempDir.path);

    // Register all adapters
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(AssetVaultAdapter());
    if (!Hive.isAdapterRegistered(40)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(41)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(42)) Hive.registerAdapter(CategoryRuleAdapter());
    if (!Hive.isAdapterRegistered(43)) Hive.registerAdapter(RecurringRuleAdapter());
    if (!Hive.isAdapterRegistered(44)) Hive.registerAdapter(BudgetLineAdapter());
    if (!Hive.isAdapterRegistered(45)) Hive.registerAdapter(BudgetOverrideAdapter());
    if (!Hive.isAdapterRegistered(46)) Hive.registerAdapter(SavingsGoalAdapter());
    if (!Hive.isAdapterRegistered(47)) Hive.registerAdapter(GoalEntryAdapter());
    if (!Hive.isAdapterRegistered(48)) Hive.registerAdapter(ValuationAdapter());
    if (!Hive.isAdapterRegistered(49)) Hive.registerAdapter(SplitGroupAdapter());
    if (!Hive.isAdapterRegistered(50)) Hive.registerAdapter(SplitEntryAdapter());

    await Hive.openBox('settings');
    await FinanceStorage.openAllBoxes();
    storage = FinanceStorage();
    repository = FinanceRepository(storage: storage);

    // Create 2 sample accounts and categories
    await repository.addAccount(Account(
      id: 'acc_bank',
      name: 'Main Bank',
      kind: 'bank',
      openingBalance: 10000.0,
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF22C55E,
      spendable: true,
    ));
    await repository.addAccount(Account(
      id: 'acc_card',
      name: 'Credit Card',
      kind: 'credit_card',
      openingBalance: 0.0,
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF3B82F6,
      spendable: true,
    ));

    await repository.addCategory(Category(
      id: 'cat_food',
      name: 'Food',
      kind: 'expense',
      group: 'needs',
      iconKey: 'tag',
      colorValue: 0xFF22C55E,
      essential: true,
    ));
    await repository.addCategory(Category(
      id: 'cat_dining',
      name: 'Dining Out',
      kind: 'expense',
      group: 'wants',
      iconKey: 'tag',
      colorValue: 0xFFF59E0B,
      essential: false,
    ));
  });

  tearDown(() async {
    await Hive.close();
    FinanceStorage.resetForTesting();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 2 Transactions & Kinds Verification', () {
    test('persists paymentMethod and non-now date (fixes Defect 1 and Defect 2)', () async {
      final customDate = DateTime(2026, 4, 15, 14, 30);
      final draft = TxDraft(
        title: 'Lunch at Cafe',
        amount: 320.0,
        kind: 'expense',
        category: 'Food',
        categoryId: 'cat_food',
        accountId: 'acc_bank',
        paymentMethod: 'UPI',
        date: customDate,
        merchant: 'Cafe Blue',
      );

      final tx = await repository.addTransaction(draft);

      expect(tx.paymentMethod, equals('UPI'));
      expect(tx.date, equals(customDate));

      // Retrieve directly from box to ensure persistence
      final stored = storage.transactionBox.get(tx.key);
      expect(stored, isNotNull);
      expect(stored!.paymentMethod, equals('UPI'));
      expect(stored.date, equals(customDate));
      expect(stored.merchant, equals('Cafe Blue'));
    });

    test('validates transfer: rejects identical source and destination accounts', () async {
      expect(
        () => repository.transfer(
          fromAccountId: 'acc_bank',
          toAccountId: 'acc_bank',
          amount: 500.0,
          date: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates split transaction sums to total', () async {
      // Splits sum to 800 but total is 1000 -> must throw
      final invalidSplits = '[{"categoryId": "cat_food", "amount": 500.0}, {"categoryId": "cat_dining", "amount": 300.0}]';
      expect(
        () => repository.addTransaction(TxDraft(
          title: 'Dinner with friends',
          amount: 1000.0,
          kind: 'expense',
          category: 'Food',
          date: DateTime.now(),
          splits: invalidSplits,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('split transactions ₹1,200 example: 700 food, 300 entertainment, 200 owed yields 1,000 spending & 200 receivables', () async {
      final splitsJson = '''[
        {"categoryId": "cat_food", "amount": 700.0, "note": "Food share", "isOwed": false},
        {"categoryId": "cat_dining", "amount": 300.0, "note": "Movie ticket", "isOwed": false},
        {"categoryId": null, "amount": 200.0, "note": "Rahul share", "isOwed": true, "counterparty": "Rahul"}
      ]''';

      final tx = await repository.addTransaction(TxDraft(
        title: 'Group Outing',
        amount: 1200.0,
        kind: 'expense',
        category: 'Food',
        accountId: 'acc_bank',
        splits: splitsJson,
        date: DateTime(2026, 9, 20),
      ));

      expect(tx.amount, equals(-1200.0));

      final allTxs = storage.transactionBox.values.toList();

      // Check spending calculation
      final spending = LedgerEngine.spending(allTxs);
      expect(spending, equals(1000.0)); // 700 + 300, excluding the 200 owed line!

      // Check receivables calculation
      final receivables = LedgerEngine.receivablesFromSplits(allTxs);
      expect(receivables, equals(200.0));
    });

    test('bulk deletion with in-session undo', () async {
      await repository.addTransaction(TxDraft(
        title: 'Item 1',
        amount: 100,
        category: 'Food',
        date: DateTime.now(),
      ));
      final tx2 = await repository.addTransaction(TxDraft(
        title: 'Item 2',
        amount: 200,
        category: 'Food',
        date: DateTime.now(),
      ));

      expect(storage.transactionBox.length, equals(2));

      await repository.deleteTransaction(tx2.id!);
      expect(storage.transactionBox.length, equals(1));

      // Undo deletion
      final restored = await repository.undo();
      expect(restored, isNotNull);
      expect(restored!.title, equals('Item 2'));
      expect(storage.transactionBox.length, equals(2));
    });

    test('category merge updates all transactions and archives source category', () async {
      final tx = await repository.addTransaction(TxDraft(
        title: 'Fine Dining',
        amount: 1500.0,
        categoryId: 'cat_dining',
        category: 'Dining Out',
        date: DateTime.now(),
      ));

      expect(tx.categoryId, equals('cat_dining'));

      // Merge cat_dining into cat_food
      await repository.mergeCategory('cat_dining', 'cat_food');

      // Verify transaction is updated
      final updatedTx = storage.transactionBox.get(tx.key)!;
      expect(updatedTx.categoryId, equals('cat_food'));
      expect(updatedTx.category, equals('Food'));

      // Verify cat_dining is archived
      final sourceCat = storage.categoryBox.get('cat_dining')!;
      expect(sourceCat.archived, isTrue);
    });
  });

  group('Phase 2 MoneyShellPage Widget & DeepLink Tests', () {
    testWidgets('renders MoneyShellPage with 5 navigation destinations and responds to tab tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShellPage(initialTab: 0),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Overview, Transactions, Budget, Goals, More are present
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Tap on Transactions tab
      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle();

      // Verify Transactions tab content is displayed
      expect(find.text('Add Transaction'), findsOneWidget);
    });

    testWidgets('handles deep-link to transactions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShellPage(deepLink: 'transactions'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Transaction'), findsOneWidget);
    });
  });
}
