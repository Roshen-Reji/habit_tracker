import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/finance/engine/report_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

void main() {
  group('Phase 9 - Reports Engine', () {
    test('P9-1: Generates monthly summary with income, spending, saved, invested, and net worth change', () {
      final month = DateTime(2026, 10, 15);
      final acc = Account(id: 'acc_bank', name: 'Bank', kind: 'bank', openingBalance: 50000.0);

      final txs = [
        Transaction(title: 'Salary', amount: 80000.0, category: 'Income', date: DateTime(2026, 10, 1), kind: 'income', accountId: 'acc_bank'),
        Transaction(title: 'Groceries', amount: -15000.0, category: 'Groceries', date: DateTime(2026, 10, 5), kind: 'expense', accountId: 'acc_bank'),
        Transaction(title: 'Mutual Fund SIP', amount: -10000.0, category: 'Investments', date: DateTime(2026, 10, 10), kind: 'investment', accountId: 'acc_bank'),
      ];

      final goalEntry = GoalEntry(id: 'ge_1', goalId: 'goal_car', date: DateTime(2026, 10, 8), amount: 5000.0);

      final report = ReportEngine.generateMonthlySummary(
        month: month,
        transactions: txs,
        accounts: [acc],
        valuations: [],
        goalEntries: [goalEntry],
      );

      expect(report.income, 80000.0);
      expect(report.spending, 15000.0);
      expect(report.net, 65000.0);
      expect(report.invested, 10000.0);
      // Saved = goal savings (5,000) + invested (10,000) = 15,000
      expect(report.saved, 15000.0);
      expect(report.savingsRate, closeTo(65000.0 / 80000.0, 0.01));
    });

    test('P9-1: Generates category spending report with % and month-over-month change', () {
      final octMonth = DateTime(2026, 10, 15);
      final categories = [
        Category(id: 'cat_food', name: 'Food'),
        Category(id: 'cat_rent', name: 'Rent'),
      ];

      final txs = [
        // September (last month)
        Transaction(title: 'Food Sept', amount: -4000.0, categoryId: 'cat_food', category: 'Food', date: DateTime(2026, 9, 10), kind: 'expense'),
        Transaction(title: 'Rent Sept', amount: -20000.0, categoryId: 'cat_rent', category: 'Rent', date: DateTime(2026, 9, 5), kind: 'expense'),
        // October (current month)
        Transaction(title: 'Food Oct', amount: -6000.0, categoryId: 'cat_food', category: 'Food', date: DateTime(2026, 10, 12), kind: 'expense'),
        Transaction(title: 'Rent Oct', amount: -20000.0, categoryId: 'cat_rent', category: 'Rent', date: DateTime(2026, 10, 5), kind: 'expense'),
      ];

      final items = ReportEngine.generateCategoryReport(
        month: octMonth,
        transactions: txs,
        categories: categories,
      );

      // Total October spending = 26,000 (Rent: 20k = 76.9%, Food: 6k = 23.1%)
      expect(items.length, 2);

      final rentItem = items.firstWhere((i) => i.categoryId == 'cat_rent');
      expect(rentItem.amount, 20000.0);
      expect(rentItem.lastMonthAmount, 20000.0);
      expect(rentItem.changePct, 0.0);

      final foodItem = items.firstWhere((i) => i.categoryId == 'cat_food');
      expect(foodItem.amount, 6000.0);
      expect(foodItem.lastMonthAmount, 4000.0);
      // Change = (6000 - 4000) / 4000 = +50.0%
      expect(foodItem.changePct, 50.0);
    });

    test('P9-1: Generates merchant report grouped and sorted by spend', () {
      final month = DateTime(2026, 10, 15);
      final txs = [
        Transaction(title: 'Amazon shopping', merchant: 'Amazon', amount: -2500.0, date: DateTime(2026, 10, 2), kind: 'expense'),
        Transaction(title: 'Amazon books', merchant: 'Amazon', amount: -1500.0, date: DateTime(2026, 10, 8), kind: 'expense'),
        Transaction(title: 'Swiggy dinner', merchant: 'Swiggy', amount: -800.0, date: DateTime(2026, 10, 4), kind: 'expense'),
      ];

      final items = ReportEngine.generateMerchantReport(month: month, transactions: txs);
      expect(items.length, 2);
      expect(items.first.merchant, 'Amazon');
      expect(items.first.totalSpent, 4000.0);
      expect(items.first.transactionCount, 2);
      expect(items.first.avgAmount, 2000.0);

      expect(items[1].merchant, 'Swiggy');
      expect(items[1].totalSpent, 800.0);
    });

    test('P9-1: Compares two calendar months side-by-side', () {
      final sep = DateTime(2026, 9, 15);
      final oct = DateTime(2026, 10, 15);

      final txs = [
        Transaction(title: 'Salary Sept', amount: 50000.0, date: DateTime(2026, 9, 1), kind: 'income'),
        Transaction(title: 'Spend Sept', amount: -30000.0, date: DateTime(2026, 9, 10), kind: 'expense'),
        Transaction(title: 'Salary Oct', amount: 55000.0, date: DateTime(2026, 10, 1), kind: 'income'),
        Transaction(title: 'Spend Oct', amount: -25000.0, date: DateTime(2026, 10, 10), kind: 'expense'),
      ];

      final comp = ReportEngine.compareMonths(
        month1: sep,
        month2: oct,
        transactions: txs,
        categories: [],
      );

      expect(comp.month1Income, 50000.0);
      expect(comp.month2Income, 55000.0);
      expect(comp.month1Spending, 30000.0);
      expect(comp.month2Spending, 25000.0);
      expect(comp.month1Net, 20000.0);
      expect(comp.month2Net, 30000.0);
    });
  });

  group('Phase 9 - CSV Exporter (RFC 4180)', () {
    test('P9-2: Correctly escapes commas, quotes, and newlines in CSV cells', () {
      expect(CsvExporter.escapeCell('Normal text'), 'Normal text');
      expect(CsvExporter.escapeCell('Text, with comma'), '"Text, with comma"');
      expect(CsvExporter.escapeCell('Text with "quotes"'), '"Text with ""quotes"""');
      expect(CsvExporter.escapeCell('Multi\nline'), '"Multi\nline"');
    });

    test('P9-2: Exports transactions to standard CSV with headers', () {
      final tx = Transaction(
        id: 'tx_123',
        title: 'Dinner at "Bistro, Cafe"',
        merchant: 'Bistro, Cafe',
        amount: -1250.0,
        category: 'Food',
        date: DateTime(2026, 10, 4, 19, 30, 0),
        kind: 'expense',
        paymentMethod: 'UPI',
        tags: ['dinner', 'friends'],
      );

      final csv = CsvExporter.exportTransactionsToCsv([tx], {}, {});
      expect(csv, contains('ID,Date,Time,Title,Merchant,Kind,Amount,Category,Account,ToAccount,PaymentMethod,Notes,Tags,RecurringRuleID'));
      expect(csv, contains('tx_123,2026-10-04,19:30:00'));
      expect(csv, contains('"Dinner at ""Bistro, Cafe"""'));
      expect(csv, contains('"Bistro, Cafe"'));
      expect(csv, contains('dinner;friends'));
    });
  });
}
