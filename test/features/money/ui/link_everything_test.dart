import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/data/services/ai_context.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/home/cards/safe_to_spend_card.dart';
import 'package:habit_tracker/features/home/cards/finance_card.dart';
import 'package:habit_tracker/features/home/cards/net_worth_card.dart';
import 'package:habit_tracker/features/home/cards/upcoming_bills_card.dart';
import 'package:habit_tracker/features/money/data/money_service.dart';
import 'package:habit_tracker/features/money/data/money_store.dart';
import 'package:habit_tracker/features/money/core/plan_engine.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/money/ui/shell/money_shell.dart';
import 'package:habit_tracker/features/money/ui/today/today_tab.dart';
import 'package:habit_tracker/features/money/ui/activity/activity_tab.dart';
import 'package:habit_tracker/features/money/ui/plans/plans_tab.dart';
import 'package:habit_tracker/features/money/ui/accounts/accounts_tab.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late MoneyStore store;
  late MoneyState state;
  late MoneyService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('money_m7_test_');
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
      openingBalance: 10000.0, // ₹10,000.00 = 1,000,000 paise
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF1E88E5,
    );
    await storage.accountBox.put(mainAcc.id, mainAcc);

    final savingsAcc = Account(
      id: 'acc_savings',
      name: 'Savings',
      kind: 'savings',
      openingBalance: 5000.0, // ₹5,000.00
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF43A047,
    );
    await storage.accountBox.put(savingsAcc.id, savingsAcc);

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

  group('Milestone M7: Home Cards Read MoneySnapshot (Acceptance Scenario 11)',
      () {
    testWidgets(
        'SafeToSpendCard displays exact Free to Spend from MoneySnapshot',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeToSpendCard(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fts = state.value.freeToSpend;
      expect(find.text('SAFE TO SPEND'), findsOneWidget);
      // Per day or formatted text matches snapshot
      final expectedText = FormatUtils.formatMoney(
        fts.freeToSpendRupees /
            (DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day -
                    DateTime.now().day)
                .clamp(1, 31),
        decimals: 0,
      );
      expect(find.text(expectedText), findsWidgets);
    });

    testWidgets(
        'FinanceCard displays Main balance from MoneySnapshot and reacts to spend',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceCard(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('FINANCE SUMMARY'), findsOneWidget);
      expect(find.text('MONEY LEFT'), findsOneWidget);
      expect(
        find.text(FormatUtils.formatMoney(state.value.mainBalanceRupees,
            decimals: 0)),
        findsOneWidget,
      );

      // Spend ₹1,000 via service
      await tester.runAsync(() async {
        await service.spend(
          amountMinor: 100000,
          accountId: 'acc_main',
          title: 'Dinner',
          category: 'Food',
        );
      });

      await tester.pump();
      await tester.pumpAndSettle();

      // Balance immediately drops from ₹10,000 to ₹9,000
      expect(
        find.text(FormatUtils.formatMoney(state.value.mainBalanceRupees,
            decimals: 0)),
        findsOneWidget,
      );
    });

    testWidgets('NetWorthHomeCard displays net worth from MoneySnapshot',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NetWorthHomeCard(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('NET WORTH'), findsOneWidget);
      expect(
        find.text(FormatUtils.formatMoney(state.value.netWorthRupees)),
        findsOneWidget,
      );
    });

    testWidgets('UpcomingBillsCard displays upcoming plans from MoneySnapshot',
        (tester) async {
      // Add a plan
      await tester.runAsync(() async {
        await service.addPlan(
          CorePlan(
            id: 'plan_fiber',
            title: 'Internet Fiber',
            kind: PlanKind.bill,
            amountMinor: 150000, // ₹1,500
            dayOfMonth: 15,
            fromAccountId: 'acc_main',
            startDate: DateTime(2026, 1, 1),
          ),
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpcomingBillsCard(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('UPCOMING BILLS'), findsOneWidget);
      expect(find.text('Total Due'), findsOneWidget);
      expect(find.text('1 due'), findsOneWidget);
      expect(find.textContaining('Internet Fiber'), findsOneWidget);
    });
  });

  group('Milestone M7: AI Context Reads MoneySnapshot', () {
    test(
        'AiContext.buildFinanceContext produces accurate summary from snapshot',
        () {
      final contextStr = AiContext.buildFinanceContext();
      expect(contextStr, startsWith('[FIN]'));
      expect(contextStr,
          contains('Main:${state.value.mainBalanceRupees.toStringAsFixed(0)}'));
      expect(contextStr, contains('Exp:1000'));
    });
  });

  group('Milestone M7: Deep Linking & Static Analysis Checks', () {
    testWidgets('MoneyShell responds to deep links for all main tabs',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShell(deepLink: 'activity'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ActivityTab), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShell(deepLink: 'plans'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PlansTab), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShell(deepLink: 'accounts'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AccountsTab), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShell(deepLink: 'today'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TodayTab), findsOneWidget);
    });

    test('Static checks: No Hive.box, shrinkWrap: true, Border.all in money UI',
        () {
      final moneyUiDir = Directory('lib/features/money/ui');
      expect(moneyUiDir.existsSync(), isTrue);

      final dartFiles = moneyUiDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains('Hive.box('),
          isFalse,
          reason: 'Hive.box found in ${file.path}',
        );
        expect(
          content.contains('shrinkWrap: true'),
          isFalse,
          reason: 'shrinkWrap: true found in ${file.path}',
        );
        expect(
          content.contains('Border.all('),
          isFalse,
          reason: 'Border.all found in ${file.path}',
        );
        expect(
          content.contains('BackdropFilter'),
          isFalse,
          reason: 'BackdropFilter found in ${file.path}',
        );
      }
    });
  });
}
