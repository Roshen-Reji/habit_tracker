import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/valuation.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:intl/intl.dart';

void main() {
  group('M0 Baseline Audit & Root Cause Verification', () {
    test('Reproduce RC1: LedgerEngine ignores spends dated before openingDate',
        () {
      final accountOpening = DateTime(2026, 10, 7, 14, 0, 0); // 2:00 PM today
      final account = Account(
        id: 'acc_test_rc1',
        name: 'Test Checking',
        kind: 'checking',
        openingBalance: 1000.0,
        openingDate: accountOpening,
        colorValue: 0xFF1E88E5,
      );

      // Spend logged earlier today (e.g. 10:00 AM)
      final earlierTodaySpend = Transaction(
        id: 'tx_earlier_today',
        title: 'Morning Coffee',
        amount: -200.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 10, 0, 0),
        mode: 'Expense',
        icon: 'coffee',
        accountId: 'acc_test_rc1',
        kind: 'expense',
      );

      // Backdated spend from yesterday
      final yesterdaySpend = Transaction(
        id: 'tx_yesterday',
        title: 'Groceries',
        amount: -300.0,
        category: 'Groceries',
        date: DateTime(2026, 10, 6, 18, 0, 0),
        mode: 'Expense',
        icon: 'shopping-cart',
        accountId: 'acc_test_rc1',
        kind: 'expense',
      );

      // Spend logged after opening date (e.g. 3:00 PM)
      final afterOpeningSpend = Transaction(
        id: 'tx_after_opening',
        title: 'Snack',
        amount: -100.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 15, 0, 0),
        mode: 'Expense',
        icon: 'utensils',
        accountId: 'acc_test_rc1',
        kind: 'expense',
      );

      final transactions = [
        earlierTodaySpend,
        yesterdaySpend,
        afterOpeningSpend,
      ];
      final valuations = <Valuation>[];

      // Execute current LedgerEngine.balance
      final balance = LedgerEngine.balance(
        account,
        transactions,
        valuations,
        asOf: DateTime(2026, 10, 7, 23, 59, 59),
      );

      // PROOF OF RC1:
      // The user spent 200 (earlier today) + 300 (yesterday) + 100 (afternoon) = 600 total.
      // Expected real balance: 1000 - 600 = 400.
      // But LedgerEngine.balance returns 900 because earlierTodaySpend and yesterdaySpend
      // are skipped by `!tx.date.isBefore(account.openingDate)`.
      expect(balance, equals(900.0));
      expect(earlierTodaySpend.date.isBefore(account.openingDate), isTrue);
      expect(yesterdaySpend.date.isBefore(account.openingDate), isTrue);
    });

    test(
        'Audit screen logic identifies skipped entries and matches LedgerEngine',
        () {
      final accountOpening = DateTime(2026, 10, 7, 14, 0, 0);
      final account = Account(
        id: 'acc_audit',
        name: 'Audit Account',
        kind: 'checking',
        openingBalance: 1000.0,
        openingDate: accountOpening,
        colorValue: 0xFF1E88E5,
      );

      final tx1 = Transaction(
        id: 'tx_1',
        title: 'Morning Coffee',
        amount: -200.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 10, 0, 0),
        mode: 'Expense',
        icon: 'coffee',
        accountId: 'acc_audit',
        kind: 'expense',
      );

      final tx2 = Transaction(
        id: 'tx_2',
        title: 'Afternoon Snack',
        amount: -100.0,
        category: 'Food',
        date: DateTime(2026, 10, 7, 15, 0, 0),
        mode: 'Expense',
        icon: 'utensils',
        accountId: 'acc_audit',
        kind: 'expense',
      );

      final cutoff = DateTime(2026, 10, 7, 23, 59, 59);
      final ledgerBal = LedgerEngine.balance(
        account,
        [tx1, tx2],
        [],
        asOf: cutoff,
      );

      // Emulate audit calculation
      double running = account.openingBalance;
      final skipped = <String>[];

      for (final tx in [tx1, tx2]) {
        if (tx.date.isBefore(account.openingDate)) {
          skipped.add(
            '${tx.id}: Dated before opening date (${DateFormat('yyyy-MM-dd').format(account.openingDate)})',
          );
          continue;
        }
        running -= tx.amount.abs();
      }

      expect(running, equals(ledgerBal));
      expect(skipped.length, equals(1));
      expect(skipped.first, contains('Dated before opening date'));
    });
  });
}
