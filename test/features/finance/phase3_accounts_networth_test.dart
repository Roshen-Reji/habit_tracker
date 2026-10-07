import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';

void main() {
  late Directory tempDir;
  late FinanceStorage storage;
  late FinanceRepository repository;
  late FinanceController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fin_p3_test_');
    Hive.init(tempDir.path);

    // Register all adapters
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(AssetVaultAdapter());
    if (!Hive.isAdapterRegistered(40)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(41)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(48)) Hive.registerAdapter(ValuationAdapter());

    storage = FinanceStorage();
    await storage.init();
    repository = FinanceRepository(storage: storage);
    controller = FinanceController();
  });

  tearDown(() async {
    await storage.closeAll();
    await tempDir.delete(recursive: true);
  });

  group('P3-1: Accounts & Reconciliation', () {
    test('creates account with kind-specific fields and preserves institution (Defect 3)', () async {
      final card = Account(
        id: 'acc_cc_1',
        name: 'Regalia Gold',
        kind: 'credit_card',
        institution: 'HDFC Bank', // Defect 3 fix: institution is kept!
        openingBalance: 0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4A90E2,
        creditLimit: 300000,
        statementDay: 15,
        dueDay: 5,
      );

      await repository.addAccount(card);

      final fetched = storage.accountBox.get('acc_cc_1')!;
      expect(fetched.name, equals('Regalia Gold'));
      expect(fetched.institution, equals('HDFC Bank'));
      expect(fetched.isCreditCard, isTrue);
      expect(fetched.isLiability, isTrue);
      expect(fetched.creditLimit, equals(300000));
      expect(fetched.statementDay, equals(15));
      expect(fetched.dueDay, equals(5));
    });

    test('creates loan account with principal, rate, emi and tenure', () async {
      final loan = Account(
        id: 'acc_loan_1',
        name: 'Home Loan',
        kind: 'loan',
        institution: 'SBI',
        openingBalance: -5000000,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFFD0021B,
        principal: 5000000,
        annualRate: 8.5,
        emi: 43391,
        tenureMonths: 240,
        startDate: DateTime(2026, 1, 1),
      );

      await repository.addAccount(loan);

      final fetched = storage.accountBox.get('acc_loan_1')!;
      expect(fetched.isLoan, isTrue);
      expect(fetched.isLiability, isTrue);
      expect(fetched.principal, equals(5000000));
      expect(fetched.annualRate, equals(8.5));
      expect(fetched.emi, equals(43391));
      expect(fetched.tenureMonths, equals(240));
    });

    test('reconciles account with difference generating adjustment transaction', () async {
      final bank = Account(
        id: 'acc_bank_test',
        name: 'Salary Bank',
        kind: 'bank',
        institution: 'ICICI Bank',
        openingBalance: 10000,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4A90E2,
      );
      await repository.addAccount(bank);

      // Add transaction that spends 2,000 -> Ledger balance should be 8,000
      await repository.addTransaction(TxDraft(
        title: 'Grocery',
        amount: 2000,
        category: 'Food',
        date: DateTime.now(),
        accountId: 'acc_bank_test',
        kind: 'expense',
      ));

      final preReconcileBal = controller.getAccountBalance(bank);
      expect(preReconcileBal, equals(8000.0));

      // Reconcile to real balance 8,500 (e.g. interest credit +500)
      final adjTx = await repository.reconcileAccount(
        accountId: 'acc_bank_test',
        realBalance: 8500.0,
        notes: 'Interest credited',
      );

      expect(adjTx, isNotNull);
      expect(adjTx!.effectiveKind, equals('adjustment'));
      expect(adjTx.amount, equals(500.0));

      // Check new ledger balance matches real balance exactly
      final postReconcileBal = controller.getAccountBalance(bank);
      expect(postReconcileBal, equals(8500.0));
    });

    test('reconcile with no difference returns null without creating adjustment', () async {
      final bank = Account(
        id: 'acc_exact',
        name: 'Cash',
        kind: 'cash',
        openingBalance: 500,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF7ED321,
      );
      await repository.addAccount(bank);

      final adj = await repository.reconcileAccount(
        accountId: 'acc_exact',
        realBalance: 500.0,
      );
      expect(adj, isNull);
    });
  });

  group('P3-2: Net Worth & 12-Month History', () {
    test('computes net worth, assets, liabilities, and month change', () async {
      final bank = Account(
        id: 'acc_asset',
        name: 'Checking',
        kind: 'bank',
        openingBalance: 150000,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4A90E2,
      );
      final card = Account(
        id: 'acc_debt',
        name: 'Credit Card',
        kind: 'credit_card',
        openingBalance: 0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFFD0021B,
      );

      await repository.addAccount(bank);
      await repository.addAccount(card);

      // Spend 30,000 on credit card
      await repository.addTransaction(TxDraft(
        title: 'Laptop purchase',
        amount: 30000,
        category: 'Shopping',
        date: DateTime.now(),
        accountId: 'acc_debt',
        kind: 'expense',
      ));

      expect(controller.totalAssets, equals(150000.0));
      expect(controller.totalLiabilities, equals(30000.0));
      // Net worth = 150,000 - 30,000 = 120,000
      expect(controller.getNetWorth(), equals(120000.0));
    });

    test('netWorthHistory returns exactly 12 month-end points', () {
      final bank = Account(
        id: 'acc_nw_hist',
        name: 'Savings',
        kind: 'bank',
        openingBalance: 100000,
        openingDate: DateTime(2025, 1, 1),
        colorValue: 0xFF4A90E2,
      );

      final points = LedgerEngine.netWorthHistory(
        accounts: [bank],
        transactions: [],
        valuations: [],
        asOf: DateTime(2026, 10, 4),
        months: 12,
      );

      expect(points.length, equals(12));
      for (final p in points) {
        expect(p.value, equals(100000.0));
      }
    });

    test('accountBalanceHistory returns 6 historical points', () {
      final bank = Account(
        id: 'acc_bal_hist',
        name: 'Savings',
        kind: 'bank',
        openingBalance: 50000,
        openingDate: DateTime(2025, 1, 1),
        colorValue: 0xFF4A90E2,
      );

      final points = LedgerEngine.accountBalanceHistory(
        account: bank,
        transactions: [],
        valuations: [],
        months: 6,
      );

      expect(points.length, equals(6));
      expect(points.last.value, equals(50000.0));
    });
  });

  group('P3-3: Valued Assets & Holdings', () {
    test('valued account falls back to invested capital before first valuation', () async {
      final stockAcc = Account(
        id: 'acc_stocks',
        name: 'Zerodha Kite',
        kind: 'investment',
        openingBalance: 0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF50E3C2,
      );
      await repository.addAccount(stockAcc);

      final bankAcc = Account(
        id: 'acc_bank_source',
        name: 'Bank',
        kind: 'bank',
        openingBalance: 100000,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4A90E2,
      );
      await repository.addAccount(bankAcc);

      // Buy shares worth 50,000
      await repository.addTransaction(TxDraft(
        title: 'Nifty 50 Index Fund',
        amount: 50000,
        category: 'Investment',
        date: DateTime(2026, 2, 1),
        accountId: 'acc_bank_source',
        toAccountId: 'acc_stocks',
        kind: 'investment',
      ));

      expect(controller.getInvestedAmount(stockAcc), equals(50000.0));
      expect(controller.getAccountBalance(stockAcc), equals(50000.0));
      expect(controller.getGainLoss(stockAcc), equals(0.0));
      expect(controller.getReturnPct(stockAcc), equals(0.0));

      // Log manual valuation: market value grew to 57,500 (+15%)
      await repository.addValuation(
        accountId: 'acc_stocks',
        value: 57500,
        units: 250,
        unitPrice: 230,
        date: DateTime(2026, 3, 1),
      );

      expect(controller.getAccountBalance(stockAcc), equals(57500.0));
      expect(controller.getGainLoss(stockAcc), equals(7500.0));
      expect(controller.getReturnPct(stockAcc), equals(15.0));

      // Valuations history
      final valList = controller.getValuationsForAccount('acc_stocks');
      expect(valList.length, equals(1));
      expect(valList.first.units, equals(250));
      expect(valList.first.unitPrice, equals(230));

      // Deleting valuation reverts to invested amount
      await repository.deleteValuation(valList.first.id);
      expect(controller.getAccountBalance(stockAcc), equals(50000.0));
    });
  });

  group('P3-4: UI Widget Tests', () {
    testWidgets('renders AccountsPage with assets and liabilities', (tester) async {
      final bank = Account(
        id: 'acc_ui_bank',
        name: 'HDFC Savings',
        kind: 'bank',
        institution: 'HDFC Bank',
        openingBalance: 45000,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4A90E2,
      );
      final card = Account(
        id: 'acc_ui_card',
        name: 'Amazon ICICI Card',
        kind: 'credit_card',
        institution: 'ICICI Bank',
        openingBalance: 0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFFD0021B,
        creditLimit: 100000,
      );

      await repository.addAccount(bank);
      await repository.addAccount(card);

      await tester.pumpWidget(
        MaterialApp(
          home: AccountsPage(
            controller: controller,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('HDFC Savings'), findsOneWidget);
      expect(find.text('Amazon ICICI Card'), findsOneWidget);
      expect(find.text('Total Assets'), findsOneWidget);
      expect(find.text('Total Liabilities'), findsOneWidget);
    });

    testWidgets('renders AccountDetailPage with balance and action buttons', (tester) async {
      final card = Account(
        id: 'acc_detail_card',
        name: 'SBI Cashback Card',
        kind: 'credit_card',
        institution: 'State Bank of India',
        openingBalance: 0,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFFD0021B,
        creditLimit: 75000,
        statementDay: 12,
        dueDay: 2,
      );
      await repository.addAccount(card);

      await tester.pumpWidget(
        MaterialApp(
          home: AccountDetailPage(
            accountId: 'acc_detail_card',
            controller: controller,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SBI Cashback Card'), findsWidgets);
      expect(find.text('Credit Utilization'), findsOneWidget);
      expect(find.text('Pay Credit Card'), findsOneWidget);
      expect(find.text('Balance Trend (6M)'), findsOneWidget);
    });

    testWidgets('renders NetWorthPage with 12-month history and composition', (tester) async {
      final bank = Account(
        id: 'acc_nw_ui',
        name: 'Salary Account',
        kind: 'bank',
        openingBalance: 250000,
        openingDate: DateTime(2026, 1, 1),
        colorValue: 0xFF4A90E2,
      );
      await repository.addAccount(bank);

      await tester.pumpWidget(
        MaterialApp(
          home: NetWorthPage(
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Net Worth'), findsOneWidget);
      expect(find.text('TOTAL NET WORTH'), findsOneWidget);
      expect(find.text('12-Month History'), findsOneWidget);
      expect(find.text('Assets (1)'), findsOneWidget);
    });
  });
}
