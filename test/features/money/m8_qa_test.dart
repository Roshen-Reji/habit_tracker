import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/money/core/plan_engine.dart';
import 'package:habit_tracker/features/money/data/balance_check.dart';
import 'package:habit_tracker/features/money/data/money_service.dart';
import 'package:habit_tracker/features/money/data/money_store.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/money/ui/accounts/balance_review_dialog.dart';
import 'package:habit_tracker/features/money/ui/activity/activity_tab.dart';
import 'package:habit_tracker/features/money/ui/motion/animated_money_text.dart';
import 'package:habit_tracker/features/money/ui/plans/add_plan_sheet.dart';
import 'package:habit_tracker/features/money/ui/plans/plans_tab.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late MoneyStore store;
  late MoneyState state;
  late MoneyService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('money_m8_test_');
    Hive.init(tempDir.path);
    FinanceStorage.registerAdapters();
    await Hive.openBox('settings');
    await Hive.openBox('finance_settings');
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
    service.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone M8: Widget Tests (Section 10 Test Plan)', () {
    testWidgets(
        'AnimatedMoneyText reaches final value and respects reduced motion',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: AnimatedMoneyText(
                amountMinor: 100000,
                decimals: 0,
              ),
            ),
          ),
        ),
      );

      // Initial value
      expect(find.text('₹1,000'), findsOneWidget);

      // Update to ₹5,000 with animations disabled
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: AnimatedMoneyText(
                amountMinor: 500000,
                decimals: 0,
              ),
            ),
          ),
        ),
      );

      // Should immediately jump to ₹5,000 without requiring 450ms animation
      await tester.pump();
      expect(find.text('₹5,000'), findsOneWidget);
    });

    testWidgets('AddPlanSheet blocks a SIP without a destination fund',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddPlanSheet(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter plan name
      await tester.enterText(
        find.widgetWithText(TextField, 'Plan Name'),
        'Retirement Index SIP',
      );

      // Enter amount
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'),
        '2500',
      );

      // Switch segment to SIP
      await tester.tap(find.text('SIP'));
      await tester.pumpAndSettle();

      // Tap Save Plan button
      await tester.tap(find.text('Save Plan'));
      await tester.pumpAndSettle();

      // Verify validation snackbar appears blocking save
      expect(
        find.text('A SIP requires a destination fund. Create one inline.'),
        findsOneWidget,
      );
    });

    testWidgets('ActivityTab: Insert, swipe to delete, and Undo restores entry',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Add an entry via service
      await tester.runAsync(() async {
        await service.spend(
          amountMinor: 12000, // ₹120.00
          title: 'Morning Matcha',
          category: 'Food',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivityTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Morning Matcha'), findsOneWidget);

      // 2. Swipe to delete
      await tester.drag(find.text('Morning Matcha'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Verify SnackBar with Undo action appears
      expect(find.text('Deleted "Morning Matcha"'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // 4. Execute Undo
      await tester.runAsync(() async {
        await service.undo();
      });
      await tester.pump();
      await tester.pumpAndSettle();

      // 5. Entry is restored
      expect(find.text('Morning Matcha'), findsOneWidget);
    });

    testWidgets(
        'PlansTab displays "Needs funds" when account cannot cover due plan',
        (tester) async {
      // Add a plan for ₹5,000 when balance is ₹1,000
      await tester.runAsync(() async {
        await service.addPlan(
          CorePlan(
            id: 'plan_huge_bill',
            title: 'Annual Insurance',
            kind: PlanKind.bill,
            amountMinor: 500000, // ₹5,000 (exceeds ₹1,000 balance)
            dayOfMonth: DateTime.now().day,
            fromAccountId: 'acc_main',
            startDate: DateTime(2026, 1, 1),
          ),
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlansTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Annual Insurance'), findsOneWidget);
      expect(find.text('Needs funds'), findsOneWidget);
    });

    testWidgets(
        'BalanceReviewDialog renders both "Use new balances" and "Keep today\'s balances"',
        (tester) async {
      final sampleDiscrepancy = AccountDiscrepancy(
        account: Account(
          id: 'acc_main',
          name: 'Main Checking',
          kind: 'checking',
          openingBalance: 1000.0,
          openingDate: DateTime(2026, 1, 1),
          colorValue: 0xFF1E88E5,
        ),
        oldBalance: 1000.0,
        newBalance: 800.0,
        ignoredTransactions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceReviewDialog(
              discrepancies: [sampleDiscrepancy],
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Balance Verification'), findsOneWidget);
      expect(find.text('Use new balances'), findsOneWidget);
      expect(find.text("Keep today's balances"), findsOneWidget);
    });
  });

  group('Milestone M8: Section 10 Static Checks (Must All Pass Empty)', () {
    test('Static check: No Hive.box in lib/features/money/ui', () {
      final dir = Directory('lib/features/money/ui');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final f in files) {
        final content = f.readAsStringSync();
        expect(
          content.contains('Hive.box('),
          isFalse,
          reason: 'Hive.box found in ${f.path}',
        );
      }
    });

    test('Static check: No BackdropFilter in lib/features/money', () {
      final dir = Directory('lib/features/money');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final f in files) {
        final content = f.readAsStringSync();
        expect(
          content.contains('BackdropFilter'),
          isFalse,
          reason: 'BackdropFilter found in ${f.path}',
        );
      }
    });

    test('Static check: No shrinkWrap: true in lib/features/money/ui', () {
      final dir = Directory('lib/features/money/ui');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final f in files) {
        final content = f.readAsStringSync();
        expect(
          content.contains('shrinkWrap: true'),
          isFalse,
          reason: 'shrinkWrap: true found in ${f.path}',
        );
      }
    });

    test('Static check: No Border.all in lib/features/money/ui cards', () {
      final dir = Directory('lib/features/money/ui');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final f in files) {
        final content = f.readAsStringSync();
        expect(
          content.contains('Border.all('),
          isFalse,
          reason: 'Border.all found in ${f.path}',
        );
      }
    });

    test('Static check: No .listenable() without keys: in lib/features/money',
        () {
      final dir = Directory('lib/features/money');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final f in files) {
        final content = f.readAsStringSync();
        if (content.contains('.listenable(')) {
          expect(
            content.contains('keys:'),
            isTrue,
            reason: '.listenable() without keys: in ${f.path}',
          );
        }
      }
    });
  });
}
