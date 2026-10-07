import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/data/services/finance_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('finance_calc_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('finance_settings_test');
  });

  tearDownAll(() async {
    await settingsBox.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await settingsBox.clear();
  });

  group('FinanceCalculator Unit Tests (P2-3)', () {
    test('Calculates balance, month income, expense, and net correctly', () {
      final selectedMonth = DateTime(2026, 10, 1);

      final transactions = [
        Transaction(
          title: 'Salary',
          amount: 5000.0,
          category: 'Income',
          date: DateTime(2026, 10, 5),
          mode: 'income',
          icon: 'briefcase',
        ),
        Transaction(
          title: 'Groceries',
          amount: -250.0,
          category: 'Food',
          date: DateTime(2026, 10, 6),
          mode: 'expense',
          icon: 'utensils',
        ),
        Transaction(
          title: 'Prior month bonus',
          amount: 1000.0,
          category: 'Income',
          date: DateTime(2026, 9, 20),
          mode: 'income',
          icon: 'gift',
        ),
      ];

      final vaults = <AssetVault>[
        AssetVault(
          name: 'Emergency Fund',
          balance: 10000.0,
          bank: 'HDFC',
          type: 'Savings',
          colorValue: 0xFF4CAF50,
        ),
      ];

      final snapshot = FinanceCalculator.calculate(
        transactions: transactions,
        vaults: vaults,
        settings: settingsBox,
        selectedMonth: selectedMonth,
      );

      // Month stats
      expect(snapshot.monthIncome, 5000.0);
      expect(snapshot.monthExpense, 250.0);
      expect(snapshot.monthNet, 4750.0);

      // All time net = 5000 - 250 + 1000 = 5750
      // Total balance = vault (10000) + allTimeNet (5750) = 15750
      expect(snapshot.totalBalance, 15750.0);
      expect(snapshot.vaultTotal, 10000.0);
    });

    test('Category breakdown and budget limits calculated accurately', () {
      final selectedMonth = DateTime(2026, 10, 1);

      final transactions = [
        Transaction(
          title: 'Dinner',
          amount: 100.0,
          category: 'Food',
          date: DateTime(2026, 10, 2),
          mode: 'expense',
          icon: 'utensils',
        ),
        Transaction(
          title: 'Uber',
          amount: 50.0,
          category: 'Transport',
          date: DateTime(2026, 10, 3),
          mode: 'expense',
          icon: 'car',
        ),
      ];

      settingsBox.put('budgets', [
        {'category': 'Food', 'total': 300.0},
        {'category': 'Transport', 'total': 150.0},
      ]);

      final snapshot = FinanceCalculator.calculate(
        transactions: transactions,
        vaults: <AssetVault>[],
        settings: settingsBox,
        selectedMonth: selectedMonth,
      );

      expect(snapshot.categorySpent['Food'], 100.0);
      expect(snapshot.categorySpent['Transport'], 50.0);
      expect(snapshot.budgetSpent, 150.0);
      expect(snapshot.budgetLimit, 450.0);
    });
  });
}
