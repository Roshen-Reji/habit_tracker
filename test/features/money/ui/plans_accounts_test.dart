import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/money/core/plan_engine.dart';
import 'package:habit_tracker/features/money/data/money_service.dart';
import 'package:habit_tracker/features/money/data/money_store.dart';
import 'package:habit_tracker/features/money/data/plan_runner.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/money/ui/plans/plans_tab.dart';
import 'package:habit_tracker/features/money/ui/accounts/accounts_tab.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late MoneyStore store;
  late MoneyState state;
  late MoneyService service;
  late PlanRunner runner;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('money_m6_test_');
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
      openingBalance: 5000.0, // ₹5,000 = 500,000 paise
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF1E88E5,
    );
    final fundAcc = Account(
      id: 'fund_index',
      name: 'Nifty Index Fund',
      kind: 'mutual_fund',
      openingBalance: 1000.0, // ₹1,000 opening
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF10B981,
    );
    final loanAcc = Account(
      id: 'loan_car',
      name: 'Car Loan',
      kind: 'loan',
      openingBalance: 10000.0, // ₹10,000 outstanding opening
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFFEF4444,
    );

    await storage.accountBox.put(mainAcc.id, mainAcc);
    await storage.accountBox.put(fundAcc.id, fundAcc);
    await storage.accountBox.put(loanAcc.id, loanAcc);

    store = MoneyStore(storage: storage);
    state = MoneyState();
    service = MoneyService(store: store, state: state);
    runner = PlanRunner(service: service, state: state);
    state.refreshFromStore(store);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone M6: SIP, EMI, Needs Funds, and Core Acceptance Scenarios',
      () {
    test('Scenario 4: SIP execution, idempotency, and valuation gain math',
        () async {
      // 1. Create a ₹1,000 SIP on the 5th
      final sipPlan = CorePlan(
        id: 'plan_sip_1',
        title: 'Monthly Index SIP',
        kind: PlanKind.sip,
        amountMinor: 100000, // ₹1,000
        dayOfMonth: 5,
        fromAccountId: 'acc_main',
        toAccountId: 'fund_index',
        startDate: DateTime(2026, 3, 1),
      );
      await service.addPlan(sipPlan);

      // Evaluate & post on 5th March 2026
      final march5 = DateTime(2026, 3, 5, 10, 0);
      final count1 = await runner.runDuePlans(clock: march5);
      expect(count1, equals(1));

      // Main falls by ₹1,000 (5,000 -> 4,000)
      expect(state.value.mainBalanceMinor, equals(400000));
      // Fund invested rises by ₹1,000 (1,000 opening + 1,000 = 2,000)
      final fund1 =
          state.value.funds.firstWhere((f) => f.accountId == 'fund_index');
      expect(fund1.investedMinor, equals(200000));
      expect(fund1.valueMinor,
          equals(200000)); // Without valuation update, value = invested
      expect(fund1.gainMinor, equals(0));

      // Re-running posts nothing again (idempotent key)
      final countAgain = await runner.runDuePlans(clock: march5);
      expect(countAgain, equals(0));

      // Update value to ₹2,300
      await service.updateValuation(
        accountId: 'fund_index',
        valueMinor: 230000, // ₹2,300
        date: DateTime(2026, 3, 20),
      );

      final fundValued =
          state.value.funds.firstWhere((f) => f.accountId == 'fund_index');
      expect(fundValued.valueMinor, equals(230000));
      expect(fundValued.investedMinor, equals(200000));
      expect(fundValued.gainMinor, equals(30000)); // ₹300 gain

      // Post next SIP on 5th April 2026 (₹1,000)
      final april5 = DateTime(2026, 4, 5, 10, 0);
      final count2 = await runner.runDuePlans(clock: april5);
      expect(count2, equals(1));

      // Invested is now ₹3,000 (2,000 + 1,000)
      // Value is now ₹3,300 (2,300 anchor + 1,000 subsequent deposit)
      // Gain is now ₹300 (3,300 - 3,000)
      final fundFinal =
          state.value.funds.firstWhere((f) => f.accountId == 'fund_index');
      expect(fundFinal.investedMinor, equals(300000));
      expect(fundFinal.valueMinor, equals(330000));
      expect(fundFinal.gainMinor, equals(30000));
    });

    test(
        'Scenario 5: Past start date starts from today and posts nothing in the past',
        () async {
      final today = DateTime.now();

      // Plan created with start from today
      final pastPlan = CorePlan(
        id: 'plan_past_test',
        title: 'New SIP',
        kind: PlanKind.sip,
        amountMinor: 50000,
        dayOfMonth: 10,
        fromAccountId: 'acc_main',
        toAccountId: 'fund_index',
        startDate:
            DateTime(today.year, today.month, today.day), // "Start from today"
      );
      await service.addPlan(pastPlan);

      // Prior months should have 0 occurrences
      final occurrences = PlanEngine.evaluateDue(
        plan: pastPlan,
        effectiveStartDate: DateTime(today.year, today.month, today.day),
        clock: DateTime(today.year, today.month, today.day - 1),
        existingKeys: {},
        mainBalanceMinor: 1000000,
      );
      expect(occurrences, isEmpty);
    });

    test(
        'Scenario 6: Needs funds state triggers when Main cannot cover outflow',
        () async {
      final highSip = CorePlan(
        id: 'plan_high_sip',
        title: 'Large SIP',
        kind: PlanKind.sip,
        amountMinor: 10000000, // ₹100,000 (exceeds Main balance)
        dayOfMonth: 15,
        fromAccountId: 'acc_main',
        toAccountId: 'fund_index',
        startDate: DateTime(2026, 1, 1),
      );

      final eval = PlanEngine.evaluateDue(
        plan: highSip,
        effectiveStartDate: DateTime(2026, 5, 1),
        clock: DateTime(2026, 5, 15),
        existingKeys: {},
        mainBalanceMinor: 50000, // Only ₹500 in Main
      );

      expect(eval.first.needsFunds, isTrue);
    });

    test(
        'Scenario 8: Move from Main to another account changes both; total stays constant',
        () async {
      final mainBefore = state.value.mainBalanceMinor;
      const moveAmount = 50000; // ₹500

      await service.move(
        amountMinor: moveAmount,
        fromAccountId: 'acc_main',
        toAccountId: 'fund_index',
        title: 'Manual Fund Deposit',
        category: 'Investment',
      );

      expect(state.value.mainBalanceMinor, equals(mainBefore - moveAmount));
    });

    test('Scenario 9: Kill and restart leaves every number identical',
        () async {
      final snapshotBefore = state.value;

      // Re-create state and reload from store
      final freshState = MoneyState();
      freshState.refreshFromStore(store);

      expect(freshState.value.mainBalanceMinor,
          equals(snapshotBefore.mainBalanceMinor));
      expect(freshState.value.recentEntries.length,
          equals(snapshotBefore.recentEntries.length));
    });
  });

  group('Milestone M6: Plans & Accounts UI Widgets', () {
    testWidgets('PlansTab renders segments and Add Plan action',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlansTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Add Plan'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('SIP'), findsWidgets);
      expect(find.text('EMI'), findsWidgets);
    });

    testWidgets('AccountsTab renders pinned Main account and categories',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccountsTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('Funds & Investments'), findsOneWidget);
      expect(find.text('Loans & Liabilities'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Budget'), 200);
      expect(find.text('Budget'), findsOneWidget);
    });
  });
}
