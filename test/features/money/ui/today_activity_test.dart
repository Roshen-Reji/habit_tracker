import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/money/data/money_service.dart';
import 'package:habit_tracker/features/money/data/money_store.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/money/ui/today/today_tab.dart';
import 'package:habit_tracker/features/money/ui/activity/activity_tab.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late MoneyStore store;
  late MoneyState state;
  late MoneyService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('money_m5_test_');
    Hive.init(tempDir.path);
    FinanceStorage.registerAdapters();
    await Hive.openBox('settings');
    storage = FinanceStorage();
    await storage.init();
    await storage.clearAll();

    final mainAcc = Account(
      id: 'acc_main',
      name: 'Main Checking',
      kind: 'checking',
      openingBalance: 1000.0, // ₹1,000.00 = 100,000 paise
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF1E88E5,
    );
    await storage.accountBox.put(mainAcc.id, mainAcc);

    store = MoneyStore(storage: storage);
    state = MoneyState();
    service = MoneyService(store: store, state: state);
    state.refreshFromStore(store);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone M5: Acceptance Scenarios (Owner Use Cases)', () {
    test(
        'Scenario 1: Spent ₹200 from Main lowers balance immediately; Undo restores it',
        () async {
      expect(state.value.mainBalanceMinor, equals(100000));

      // 1. Record spend
      final entry = await service.spend(
        amountMinor: 20000, // ₹200.00
        title: 'Lunch',
        category: 'Food',
      );

      expect(state.value.mainBalanceMinor, equals(80000));
      expect(state.value.recentEntries.first.id, equals(entry.id));

      // 2. Undo restores balance
      final undone = await service.undo();
      expect(undone, isTrue);
      expect(state.value.mainBalanceMinor, equals(100000));
      expect(state.value.recentEntries, isEmpty);
    });

    test(
        'Scenario 2: Backdated spend and pre-opening spend both reduce balance (Law L2)',
        () async {
      expect(state.value.mainBalanceMinor, equals(100000));

      // Spend dated yesterday
      await service.spend(
        amountMinor: 15000, // ₹150
        title: 'Yesterday Coffee',
        category: 'Food',
        date: DateTime.now().subtract(const Duration(days: 1)),
      );

      // Spend dated in 2025 (before account opening date 2026-01-01)
      await service.spend(
        amountMinor: 10000, // ₹100
        title: 'Old Expense',
        category: 'Shopping',
        date: DateTime(2025, 12, 15),
      );

      // Both must count: 1000 - 150 - 100 = 750
      expect(state.value.mainBalanceMinor, equals(75000));
    });

    test(
        'Scenario 3: Edit and delete old entry updates every balance immediately',
        () async {
      final entry = await service.spend(
        amountMinor: 20000, // ₹200
        title: 'Dinner',
        category: 'Food',
      );

      expect(state.value.mainBalanceMinor, equals(55000));

      // Edit from ₹200 to ₹250
      final updated = entry.copyWith(amountMinor: 25000);
      await service.editEntry(updated);

      expect(state.value.mainBalanceMinor, equals(50000));

      // Delete entry
      await service.deleteEntry(entry.id);
      expect(state.value.mainBalanceMinor, equals(75000));
    });
  });

  group('Milestone M5: Today & Activity UI Rendering', () {
    testWidgets('Today tab renders Hero balance and Free to Spend card',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodayTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check Hero Main balance
      expect(find.text('MAIN CHECKING'), findsOneWidget);
      expect(find.text('FREE TO SPEND'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Moved'), findsOneWidget);
    });

    testWidgets('Activity tab displays transactions grouped by day with search',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivityTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Transactions from Scenario 2 are present
      expect(find.text('Yesterday Coffee'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);

      // Search filtering
      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Yesterday Coffee'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No matching transactions'), findsOneWidget);
    });
  });
}
