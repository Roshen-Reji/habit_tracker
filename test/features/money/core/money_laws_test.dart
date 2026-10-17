import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/money/core/account_group.dart';
import 'package:habit_tracker/features/money/core/entry.dart';
import 'package:habit_tracker/features/money/core/free_to_spend.dart';
import 'package:habit_tracker/features/money/core/ledger.dart';
import 'package:habit_tracker/features/money/core/minor.dart';
import 'package:habit_tracker/features/money/core/plan_engine.dart';

void main() {
  group('Money v2 Core Laws (L1 - L7)', () {
    // -------------------------------------------------------------------------
    // Minor Units Math
    // -------------------------------------------------------------------------
    test('Minor units conversion and Indian formatting', () {
      expect(Minor.toMinor(100.50), equals(10050));
      expect(Minor.toMinor(0.0), equals(0));
      expect(Minor.toMinor(-50.25), equals(-5025));
      expect(Minor.fromMinor(10050), equals(100.50));

      expect(Minor.format(100050), equals('₹1,000.50'));
      expect(Minor.format(10000000), equals('₹1,00,000'));
      expect(Minor.format(1500000000, compact: true), equals('₹1.5Cr'));
      expect(Minor.format(150000000, compact: true), equals('₹15L'));
      expect(Minor.format(2500000, compact: true), equals('₹25k'));
    });

    // -------------------------------------------------------------------------
    // Law L1: Immediate Effects
    // -------------------------------------------------------------------------
    test(
        'L1: Spent X from A lowers A; Received X into A raises A; Moved X lowers A and raises B',
        () {
      final now = DateTime(2026, 10, 7, 12, 0);
      final accA = CoreAccount(
        id: 'acc_a',
        name: 'Main Account',
        group: AccountGroup.main,
        rawKind: 'checking',
        openingBalanceMinor: Minor.toMinor(1000.0),
        openingDate: DateTime(2026, 1, 1),
      );

      final accB = CoreAccount(
        id: 'acc_b',
        name: 'Savings',
        group: AccountGroup.main,
        rawKind: 'savings',
        openingBalanceMinor: Minor.toMinor(500.0),
        openingDate: DateTime(2026, 1, 1),
      );

      // Spend 200 from A
      final spend = Entry(
        id: 'e1',
        kind: EntryKind.spent,
        amountMinor: Minor.toMinor(200.0),
        fromAccountId: 'acc_a',
        date: now,
        title: 'Lunch',
        category: 'Food',
      );

      var balA = CoreLedger.balance(account: accA, entries: [spend], asOf: now);
      expect(balA, equals(Minor.toMinor(800.0)));

      // Receive 300 into A
      final receive = Entry(
        id: 'e2',
        kind: EntryKind.received,
        amountMinor: Minor.toMinor(300.0),
        toAccountId: 'acc_a',
        date: now,
        title: 'Freelance',
        category: 'Income',
      );

      balA = CoreLedger.balance(
          account: accA, entries: [spend, receive], asOf: now);
      expect(balA, equals(Minor.toMinor(1100.0)));

      // Move 400 from A to B
      final move = Entry(
        id: 'e3',
        kind: EntryKind.moved,
        amountMinor: Minor.toMinor(400.0),
        fromAccountId: 'acc_a',
        toAccountId: 'acc_b',
        date: now,
        title: 'Transfer to savings',
        category: 'Transfer',
      );

      balA = CoreLedger.balance(
          account: accA, entries: [spend, receive, move], asOf: now);
      final balB =
          CoreLedger.balance(account: accB, entries: [move], asOf: now);

      expect(balA, equals(Minor.toMinor(700.0)));
      expect(balB, equals(Minor.toMinor(900.0)));
    });

    // -------------------------------------------------------------------------
    // Law L2: No Ignored Entries (RC1 Fix)
    // -------------------------------------------------------------------------
    test(
        'L2: Backdated entries and entries dated before openingDate count towards balance',
        () {
      final accountCreated = DateTime(2026, 10, 7, 14, 0, 0); // 2 PM today
      final account = CoreAccount(
        id: 'acc_main',
        name: 'Main',
        group: AccountGroup.main,
        rawKind: 'checking',
        openingBalanceMinor: Minor.toMinor(1000.0),
        openingDate: accountCreated,
      );

      // Spend logged earlier today at 10 AM (before creation time)
      final earlierTodaySpend = Entry(
        id: 'e_earlier',
        kind: EntryKind.spent,
        amountMinor: Minor.toMinor(200.0),
        fromAccountId: 'acc_main',
        date: DateTime(2026, 10, 7, 10, 0, 0),
        title: 'Coffee',
        category: 'Food',
      );

      // Backdated spend from yesterday
      final yesterdaySpend = Entry(
        id: 'e_yesterday',
        kind: EntryKind.spent,
        amountMinor: Minor.toMinor(300.0),
        fromAccountId: 'acc_main',
        date: DateTime(2026, 10, 6, 12, 0, 0),
        title: 'Groceries',
        category: 'Food',
      );

      final balance = CoreLedger.balance(
        account: account,
        entries: [earlierTodaySpend, yesterdaySpend],
        asOf: DateTime(2026, 10, 7, 23, 59, 59),
      );

      // In Money v2, no entry is ignored! 1000 - 200 - 300 = 500
      expect(balance, equals(Minor.toMinor(500.0)));
    });

    // -------------------------------------------------------------------------
    // Law L3: One Internal Representation
    // -------------------------------------------------------------------------
    test(
        'L3: Entry is strictly non-negative amountMinor; derived legacy storage is correct',
        () {
      final spend = Entry(
        id: 'e_spend',
        kind: EntryKind.spent,
        amountMinor: Minor.toMinor(150.0),
        fromAccountId: 'acc_main',
        date: DateTime(2026, 10, 7),
        title: 'Book',
        category: 'Education',
      );

      expect(spend.amountMinor, equals(15000));
      final legacy = spend.toLegacyStorage();
      expect(legacy.amount, equals(-150.0));
      expect(legacy.mode, equals('Expense'));
      expect(legacy.kind, equals('expense'));

      // Reconstitute from raw legacy storage
      final reconstituted = Entry.fromRaw(
        id: 'e_legacy',
        rawAmount: -150.0,
        rawMode: 'Expense',
        rawKind: 'expense',
        accountId: 'acc_main',
        date: DateTime(2026, 10, 7),
        title: 'Book',
        category: 'Education',
      );

      expect(reconstituted.kind, equals(EntryKind.spent));
      expect(reconstituted.amountMinor, equals(15000));
      expect(reconstituted.fromAccountId, equals('acc_main'));
    });

    // -------------------------------------------------------------------------
    // Law L4: Funds Math (Invested, Value, Gain)
    // -------------------------------------------------------------------------
    test('L4: Fund without valuation shows Value = Invested and Gain = 0', () {
      final fund = CoreAccount(
        id: 'fund_nifty',
        name: 'Nifty 50 Index Fund',
        group: AccountGroup.funds,
        rawKind: 'mutual_fund',
        openingBalanceMinor: Minor.toMinor(1000.0),
        openingDate: DateTime(2026, 1, 1),
      );

      final deposit = Entry(
        id: 'e_sip1',
        kind: EntryKind.moved,
        amountMinor: Minor.toMinor(2000.0),
        fromAccountId: 'acc_main',
        toAccountId: 'fund_nifty',
        date: DateTime(2026, 2, 5),
        title: 'SIP Deposit',
        category: 'Investment',
      );

      final summary = CoreLedger.fundSummary(
        account: fund,
        entries: [deposit],
        valuations: const [],
        asOf: DateTime(2026, 3, 1),
      );

      expect(summary.investedMinor, equals(Minor.toMinor(3000.0)));
      expect(summary.valueMinor, equals(Minor.toMinor(3000.0)));
      expect(summary.gainMinor, equals(0));
      expect(summary.hasValuationUpdate, isFalse);
    });

    test(
        'L4: Fund with valuation update: Value = valuation + subsequent deposits; Gain = Value - Invested',
        () {
      final fund = CoreAccount(
        id: 'fund_nifty',
        name: 'Nifty 50 Index Fund',
        group: AccountGroup.funds,
        rawKind: 'mutual_fund',
        openingBalanceMinor: Minor.toMinor(1000.0),
        openingDate: DateTime(2026, 1, 1),
      );

      // SIP deposit on Jan 5: 1000 (Invested = 2000)
      final sip1 = Entry(
        id: 'sip1',
        kind: EntryKind.moved,
        amountMinor: Minor.toMinor(1000.0),
        fromAccountId: 'acc_main',
        toAccountId: 'fund_nifty',
        date: DateTime(2026, 1, 5),
        title: 'SIP 1',
        category: 'Investment',
      );

      // Value update on Jan 20: market value is 2300 (Gain = 300)
      final valuation = CoreValuation(
        id: 'val1',
        accountId: 'fund_nifty',
        valueMinor: Minor.toMinor(2300.0),
        date: DateTime(2026, 1, 20),
      );

      // Next SIP deposit on Feb 5: 1000
      final sip2 = Entry(
        id: 'sip2',
        kind: EntryKind.moved,
        amountMinor: Minor.toMinor(1000.0),
        fromAccountId: 'acc_main',
        toAccountId: 'fund_nifty',
        date: DateTime(2026, 2, 5),
        title: 'SIP 2',
        category: 'Investment',
      );

      final summary = CoreLedger.fundSummary(
        account: fund,
        entries: [sip1, sip2],
        valuations: [valuation],
        asOf: DateTime(2026, 2, 10),
      );

      // Total Invested = 1000 (opening) + 1000 (sip1) + 1000 (sip2) = 3000
      expect(summary.investedMinor, equals(Minor.toMinor(3000.0)));
      // Value = 2300 (val1) + 1000 (sip2 made after val1) = 3300
      expect(summary.valueMinor, equals(Minor.toMinor(3300.0)));
      // Gain = Value (3300) - Invested (3000) = 300
      expect(summary.gainMinor, equals(Minor.toMinor(300.0)));
      expect(summary.hasValuationUpdate, isTrue);
    });

    // -------------------------------------------------------------------------
    // Law L5: Loans Math
    // -------------------------------------------------------------------------
    test(
        'L5: Loan payment splits into interest and principal; principal reduces outstanding',
        () {
      // 100,000 outstanding loan at 12% annual interest (1% monthly)
      // Monthly interest = 1,000. Payment = 3,000.
      // Principal = 2,000. Interest = 1,000.
      final split = CoreLedger.splitPayment(
        currentOutstandingMinor: Minor.toMinor(100000.0),
        annualRatePct: 12.0,
        paymentAmountMinor: Minor.toMinor(3000.0),
      );

      expect(split.interestMinor, equals(Minor.toMinor(1000.0)));
      expect(split.principalMinor, equals(Minor.toMinor(2000.0)));

      final loan = CoreAccount(
        id: 'acc_car_loan',
        name: 'Car Loan',
        group: AccountGroup.loans,
        rawKind: 'loan',
        openingBalanceMinor: -Minor.toMinor(100000.0), // -100,000 liability
        openingDate: DateTime(2026, 1, 1),
        annualRatePct: 12.0,
      );

      final emiEntry = Entry(
        id: 'emi_1',
        kind: EntryKind.moved,
        amountMinor: Minor.toMinor(3000.0),
        fromAccountId: 'acc_main',
        toAccountId: 'acc_car_loan',
        date: DateTime(2026, 1, 10),
        title: 'Car Loan EMI',
        category: 'Debt',
      );

      final summary = CoreLedger.loanSummary(
        account: loan,
        entries: [emiEntry],
        asOf: DateTime(2026, 1, 15),
      );

      expect(summary.totalPrincipalPaidMinor, equals(Minor.toMinor(2000.0)));
      expect(summary.totalInterestPaidMinor, equals(Minor.toMinor(1000.0)));
      expect(summary.outstandingMinor, equals(Minor.toMinor(98000.0)));
    });

    // -------------------------------------------------------------------------
    // Law L6: Plan Automation & Idempotency
    // -------------------------------------------------------------------------
    test(
        'L6: Plan occurrences clamp days 29-31 on shorter months; keys are idempotent',
        () {
      final sipPlan = CorePlan(
        id: 'sip_tax_saver',
        title: 'ELSS Tax Saver',
        kind: PlanKind.sip,
        amountMinor: Minor.toMinor(5000.0),
        dayOfMonth: 31, // Set to 31st
        fromAccountId: 'acc_main',
        toAccountId: 'fund_elss',
        startDate: DateTime(2026, 1, 1),
      );

      // Check date clamping for Feb 2026 (non-leap year, 28 days) and April (30 days)
      final febDate =
          PlanEngine.resolveOccurrenceDate(2026, 2, sipPlan.dayOfMonth);
      expect(febDate.day, equals(28));
      expect(febDate.month, equals(2));

      final aprDate =
          PlanEngine.resolveOccurrenceDate(2026, 4, sipPlan.dayOfMonth);
      expect(aprDate.day, equals(30));
      expect(aprDate.month, equals(4));

      // Key format: plan:id:yyyy-MM-dd
      final key = CorePlan.formatKey(sipPlan.id, febDate);
      expect(key, equals('plan:sip_tax_saver:2026-02-28'));

      // Test evaluation when key already exists
      final due = PlanEngine.evaluateDue(
        plan: sipPlan,
        effectiveStartDate: DateTime(2026, 2, 1),
        clock: DateTime(2026, 2, 28, 23, 59, 59),
        existingKeys: {key}, // Already posted
        mainBalanceMinor: Minor.toMinor(10000.0),
      );

      expect(due, isEmpty); // Idempotent: does not post again!
    });

    test(
        'L6: Plan flags "Needs funds" when Main account balance cannot cover outflow',
        () {
      final emiPlan = CorePlan(
        id: 'plan_home_emi',
        title: 'Home Loan EMI',
        kind: PlanKind.emi,
        amountMinor: Minor.toMinor(25000.0),
        dayOfMonth: 5,
        fromAccountId: 'acc_main',
        toAccountId: 'acc_home_loan',
        startDate: DateTime(2026, 10, 1),
      );

      final due = PlanEngine.evaluateDue(
        plan: emiPlan,
        effectiveStartDate: DateTime(2026, 10, 1),
        clock: DateTime(2026, 10, 5, 12, 0, 0),
        existingKeys: const {},
        mainBalanceMinor:
            Minor.toMinor(10000.0), // Only 10,000 available for 25,000 EMI
      );

      expect(due.length, equals(1));
      expect(due.first.needsFunds, isTrue);
    });

    // -------------------------------------------------------------------------
    // Law L7: Free to Spend Breakdown
    // -------------------------------------------------------------------------
    test('L7: Free to spend = Main balance - Plans due before month end', () {
      final bill1 = CorePlan(
        id: 'bill_wifi',
        title: 'Fiber Internet',
        kind: PlanKind.bill,
        amountMinor: Minor.toMinor(1000.0),
        dayOfMonth: 15,
        fromAccountId: 'acc_main',
        startDate: DateTime(2026, 10, 1),
      );

      final bill2 = CorePlan(
        id: 'bill_rent',
        title: 'Apartment Rent',
        kind: PlanKind.bill,
        amountMinor: Minor.toMinor(15000.0),
        dayOfMonth: 25,
        fromAccountId: 'acc_main',
        startDate: DateTime(2026, 10, 1),
      );

      final result = FreeToSpendCalculator.calculate(
        mainBalanceMinor: Minor.toMinor(20000.0), // 20,000 Available
        plans: [bill1, bill2],
        postedKeys: const {},
        clock: DateTime(2026, 10,
            10), // Oct 10: both bills (1,000 + 15,000 = 16,000) are upcoming
      );

      expect(result.availableMinor, equals(Minor.toMinor(20000.0)));
      expect(result.comingUpMinor, equals(Minor.toMinor(16000.0)));
      expect(result.freeToSpendMinor, equals(Minor.toMinor(4000.0)));
      expect(result.isShort, isFalse);
    });

    test(
        'L7: Free to spend reports shortBy calmly when upcoming plans exceed balance',
        () {
      final bill = CorePlan(
        id: 'bill_insurance',
        title: 'Health Insurance',
        kind: PlanKind.bill,
        amountMinor: Minor.toMinor(12000.0),
        dayOfMonth: 20,
        fromAccountId: 'acc_main',
        startDate: DateTime(2026, 10, 1),
      );

      final result = FreeToSpendCalculator.calculate(
        mainBalanceMinor: Minor.toMinor(5000.0), // Only 5,000 available
        plans: [bill],
        postedKeys: const {},
        clock: DateTime(2026, 10, 10),
      );

      expect(result.availableMinor, equals(Minor.toMinor(5000.0)));
      expect(result.comingUpMinor, equals(Minor.toMinor(12000.0)));
      expect(result.freeToSpendMinor, equals(-Minor.toMinor(7000.0)));
      expect(result.isShort, isTrue);
      expect(result.shortByMinor, equals(Minor.toMinor(7000.0)));
      expect(result.shortByRupees, equals(7000.0));
    });
  });
}
