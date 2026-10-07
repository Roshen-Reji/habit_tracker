import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/models/budget_line.dart';
import 'package:habit_tracker/features/finance/engine/budget_engine.dart';

void main() {
  group('Phase 4 BudgetEngine Unit Tests', () {
    test('Rollover vector matching spec: Jan spent 4200 -> Feb eff 5800; Feb spent 6000 -> Mar eff 5000 (carry neg off) vs 4800 (carry neg on)', () {
      final line = BudgetLine(
        id: 'bl_food',
        categoryId: 'cat_food',
        amount: 5000.0,
        rollover: true,
        essential: true,
        startMonth: '2026-01',
      );

      final transactions = <Transaction>[
        // January 2026: spent 4200
        Transaction(
          id: 'tx_jan',
          title: 'Jan Groceries',
          amount: -4200.0,
          category: 'Food',
          categoryId: 'cat_food',
          date: DateTime(2026, 1, 15),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
        ),
        // February 2026: spent 6000
        Transaction(
          id: 'tx_feb',
          title: 'Feb Groceries',
          amount: -6000.0,
          category: 'Food',
          categoryId: 'cat_food',
          date: DateTime(2026, 2, 10),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
        ),
      ];

      // 1. January effective budget: 5000 (start month)
      final janEff = BudgetEngine.effectiveBudget(
        line: line,
        monthKey: '2026-01',
        transactions: transactions,
      );
      expect(janEff, equals(5000.0));

      // 2. February effective budget: 5000 + (5000 - 4200) = 5800
      final febEff = BudgetEngine.effectiveBudget(
        line: line,
        monthKey: '2026-02',
        transactions: transactions,
      );
      expect(febEff, equals(5800.0));

      // 3. March with rolloverCarryNegative = false (default)
      // Leftover in Feb = 5800 - 6000 = -200 => max(0, -200) = 0
      // March effective = 5000 + 0 = 5000.0
      final marEffWithoutNeg = BudgetEngine.effectiveBudget(
        line: line,
        monthKey: '2026-03',
        transactions: transactions,
        rolloverCarryNegative: false,
      );
      expect(marEffWithoutNeg, equals(5000.0));

      // 4. March with rolloverCarryNegative = true
      // Leftover in Feb = 5800 - 6000 = -200
      // March effective = 5000 - 200 = 4800.0
      final marEffWithNeg = BudgetEngine.effectiveBudget(
        line: line,
        monthKey: '2026-03',
        transactions: transactions,
        rolloverCarryNegative: true,
      );
      expect(marEffWithNeg, equals(4800.0));
    });

    test('Month override takes precedence over base budget', () {
      final line = BudgetLine(
        id: 'bl_shopping',
        categoryId: 'cat_shopping',
        amount: 3000.0,
        rollover: false,
        essential: false,
        startMonth: '2026-01',
      );

      final overrides = {'bl_shopping_2026-05': 8000.0};

      final aprEff = BudgetEngine.effectiveBudget(
        line: line,
        monthKey: '2026-04',
        transactions: [],
        overrides: overrides,
      );
      expect(aprEff, equals(3000.0));

      final mayEff = BudgetEngine.effectiveBudget(
        line: line,
        monthKey: '2026-05',
        transactions: [],
        overrides: overrides,
      );
      expect(mayEff, equals(8000.0));
    });

    test('Spend projection formula: w * pace + (1-w) * avg3', () {
      // April 15, 2026: 30 days total, 15 elapsed => w = 0.5
      final evalDate = DateTime(2026, 4, 15);

      final transactions = <Transaction>[
        // Jan: 4000
        Transaction(
          id: 'tx_j',
          title: 'Food Jan',
          amount: -4000.0,
          category: 'Food',
          categoryId: 'cat_food',
          date: DateTime(2026, 1, 20),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
        ),
        // Feb: 5000
        Transaction(
          id: 'tx_f',
          title: 'Food Feb',
          amount: -5000.0,
          category: 'Food',
          categoryId: 'cat_food',
          date: DateTime(2026, 2, 20),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
        ),
        // Mar: 6000
        Transaction(
          id: 'tx_m',
          title: 'Food Mar',
          amount: -6000.0,
          category: 'Food',
          categoryId: 'cat_food',
          date: DateTime(2026, 3, 20),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
        ),
        // Apr 1-15: 3000
        Transaction(
          id: 'tx_a',
          title: 'Food Apr',
          amount: -3000.0,
          category: 'Food',
          categoryId: 'cat_food',
          date: DateTime(2026, 4, 10),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
        ),
      ];

      // avg3 = (4000 + 5000 + 6000) / 3 = 5000
      // pace = (3000 / 15) * 30 = 6000
      // projected = 0.5 * 6000 + 0.5 * 5000 = 5500.0
      final proj = BudgetEngine.projectedCategorySpend(
        categoryId: 'cat_food',
        currentDate: evalDate,
        transactions: transactions,
      );

      expect(proj, equals(5500.0));

      // Recommended weekly cut:
      // overspend = 5500 - 5000 = 500
      // daysLeft = 30 - 15 = 15 => weeksLeft = 15 / 7
      // cut = 500 / (15 / 7) = 233.33
      final cut = BudgetEngine.recommendedWeeklyCut(
        projectedSpend: proj,
        budgetLimit: 5000.0,
        currentDate: evalDate,
      );
      expect(cut, equals(233.33));
    });

    test('50/30/20 arithmetic breakdown', () {
      final categories = <String, Category>{
        'cat_rent': Category(
          id: 'cat_rent',
          name: 'Rent',
          kind: 'expense',
          group: 'needs',
          iconKey: 'home',
          colorValue: 0xFF000000,
          essential: true,
        ),
        'cat_dining': Category(
          id: 'cat_dining',
          name: 'Dining',
          kind: 'expense',
          group: 'wants',
          iconKey: 'utensils',
          colorValue: 0xFF000000,
          essential: false,
        ),
      };

      final txs = <Transaction>[
        Transaction(
          id: 'tx_1',
          title: 'Rent',
          amount: -25000.0,
          category: 'Rent',
          categoryId: 'cat_rent',
          date: DateTime(2026, 5, 2),
          mode: 'expense',
          icon: 'home',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_2',
          title: 'Dinner',
          amount: -5000.0,
          category: 'Dining',
          categoryId: 'cat_dining',
          date: DateTime(2026, 5, 10),
          mode: 'expense',
          icon: 'utensils',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_3',
          title: 'Mutual Fund SIP',
          amount: 10000.0,
          category: 'Investment',
          date: DateTime(2026, 5, 5),
          mode: 'expense',
          icon: 'trending-up',
          kind: 'investment',
          accountId: 'acc_bank',
          toAccountId: 'acc_mf',
        ),
      ];

      final res = BudgetEngine.compute50_30_20(
        expectedIncome: 80000.0,
        monthTransactions: txs,
        categories: categories,
        goalSavingsActual: 2000.0, // goal contributions
      );

      // Needs: 50% of 80000 = 40000 target; spent = 25000
      expect(res['needs']!.target, equals(40000.0));
      expect(res['needs']!.actual, equals(25000.0));

      // Wants: 30% of 80000 = 24000 target; spent = 5000
      expect(res['wants']!.target, equals(24000.0));
      expect(res['wants']!.actual, equals(5000.0));

      // Savings: 20% of 80000 = 16000 target; actual = 10000 (inv) + 2000 (goal) = 12000
      expect(res['savings']!.target, equals(16000.0));
      expect(res['savings']!.actual, equals(12000.0));
    });

    test('Zero-based budgeting left to assign arithmetic', () {
      final lines = [
        BudgetLine(
          id: 'bl_1',
          categoryId: 'cat_rent',
          amount: 25000.0,
          startMonth: '2026-01',
        ),
        BudgetLine(
          id: 'bl_2',
          categoryId: 'cat_food',
          amount: 10000.0,
          startMonth: '2026-01',
        ),
      ];

      final extraBuckets = [5000.0, 5000.0]; // emergency fund & laptop goal

      final left = BudgetEngine.zeroBasedLeftToAssign(
        expectedIncome: 50000.0,
        lines: lines,
        extraBuckets: extraBuckets,
      );

      // 50000 - (25000 + 10000) - (5000 + 5000) = 5000.0
      expect(left, equals(5000.0));
    });
  });
}
