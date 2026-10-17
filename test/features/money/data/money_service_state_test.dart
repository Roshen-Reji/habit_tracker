import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/money/core/minor.dart';
import 'package:habit_tracker/features/money/core/plan_engine.dart';
import 'package:habit_tracker/features/money/data/money_service.dart';
import 'package:habit_tracker/features/money/data/money_store.dart';
import 'package:habit_tracker/features/money/data/plan_runner.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late MoneyStore store;
  late MoneyState state;
  late MoneyService service;
  late PlanRunner runner;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('money_m2_test_');
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

    // Create Main and Fund test accounts
    final mainAcc = Account(
      id: 'acc_main',
      name: 'Main Bank Account',
      kind: 'checking',
      openingBalance: 10000.0,
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF1E88E5,
    );

    final fundAcc = Account(
      id: 'fund_sip',
      name: 'Index Fund',
      kind: 'mutual_fund',
      openingBalance: 0.0,
      openingDate: DateTime(2026, 1, 1),
      colorValue: 0xFF10B981,
    );

    await storage.accountBox.put(mainAcc.id, mainAcc);
    await storage.accountBox.put(fundAcc.id, fundAcc);
    await storage.settingsBox.put('money2_main_account_id', 'acc_main');

    store = MoneyStore(storage: storage);
    state = MoneyState();
    service = MoneyService(store: store, state: state);
    runner = PlanRunner(service: service, state: state);

    service.init();
  });

  group('Milestone M2: Store, Service, State, Runner', () {
    test('Spend reduces Main balance immediately; Undo restores it', () async {
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(10000.0)));

      // Spend 500
      final entry = await service.spend(
        amountMinor: Minor.toMinor(500.0),
        title: 'Dinner',
        category: 'Food',
      );

      // Law L1: immediate update on snapshot
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(9500.0)));
      expect(state.value.monthSpentMinor, equals(Minor.toMinor(500.0)));
      expect(storage.transactionBox.containsKey(entry.id), isTrue);

      // Undo last action (Law L8)
      final undone = await service.undoLastAction();
      expect(undone, isTrue);
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(10000.0)));
      expect(state.value.monthSpentMinor, equals(0));
      expect(storage.transactionBox.containsKey(entry.id), isFalse);
    });

    test('Edit and delete entry recomputes snapshot immediately', () async {
      final entry = await service.spend(
        amountMinor: Minor.toMinor(200.0),
        title: 'Snack',
        category: 'Food',
      );
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(9800.0)));

      // Edit to 350
      final updated = entry.copyWith(amountMinor: Minor.toMinor(350.0));
      await service.editEntry(updated);
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(9650.0)));

      // Delete entry
      await service.deleteEntry(entry.id, recordUndo: false);
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(10000.0)));
    });

    test('Legacy FinanceRepository write synchronizes MoneyState', () async {
      final repo = FinanceRepository(storage: storage);

      await repo.addTransaction(TxDraft(
        title: 'Legacy Spend',
        amount: 400.0,
        category: 'Transport',
        date: DateTime.now(),
        mode: 'Expense',
        icon: 'bus',
        accountId: 'acc_main',
      ));

      // MoneyState snapshot recomputes automatically
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(9600.0)));
    });

    test('PlanRunner posts due SIP once; never posts the same key twice',
        () async {
      final now = DateTime(2026, 10, 5, 12, 0);

      // Create a ₹1,000 SIP plan due on the 5th
      final plan = CorePlan(
        id: 'plan_sip_oct',
        title: 'Monthly SIP',
        kind: PlanKind.sip,
        amountMinor: Minor.toMinor(1000.0),
        dayOfMonth: 5,
        fromAccountId: 'acc_main',
        toAccountId: 'fund_sip',
        startDate: DateTime(2026, 10, 1),
        autoPost: true,
      );

      await service.addPlan(plan);

      // Run due plans on the 5th
      await runner.runDuePlans(clock: now);

      // Main drops 1000, Fund invested rises 1000
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(9000.0)));
      final fund =
          state.value.funds.firstWhere((f) => f.accountId == 'fund_sip');
      expect(fund.investedMinor, equals(Minor.toMinor(1000.0)));

      final initialTxCount = storage.transactionBox.length;
      expect(initialTxCount, equals(1));

      // Re-running PlanRunner on the same day must NOT post again (Idempotency)
      await runner.runDuePlans(clock: now);
      expect(storage.transactionBox.length, equals(initialTxCount));
      expect(state.value.mainBalanceMinor, equals(Minor.toMinor(9000.0)));
    });
  });
}
