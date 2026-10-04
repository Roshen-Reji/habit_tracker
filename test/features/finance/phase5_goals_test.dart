import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/models/budget_line.dart';
import 'package:habit_tracker/features/finance/models/savings_goal.dart';
import 'package:habit_tracker/features/finance/models/goal_entry.dart';
import 'package:habit_tracker/features/finance/engine/goal_planner_engine.dart';

void main() {
  group('Phase 5 Goals and Planner Unit Tests', () {
    test('Planner vector matching spec: 60,000 in 6 months -> 10,000/mo; rate 6,500 -> shortfall 3,500', () {
      final now = DateTime(2026, 7, 1);
      final deadline = now.add(const Duration(days: 183)); // ~6 months

      final goal = SavingsGoal(
        id: 'goal_vacation',
        name: 'Europe Vacation',
        targetAmount: 60000.0,
        deadline: deadline,
        colorValue: 0xFF38BDF8,
      );

      // Past 3 months entries: June, May, April, each 6500
      final entries = [
        GoalEntry(
          id: 'ge_1',
          goalId: 'goal_vacation',
          date: DateTime(2026, 6, 15),
          amount: 6500.0,
        ),
        GoalEntry(
          id: 'ge_2',
          goalId: 'goal_vacation',
          date: DateTime(2026, 5, 15),
          amount: 6500.0,
        ),
        GoalEntry(
          id: 'ge_3',
          goalId: 'goal_vacation',
          date: DateTime(2026, 4, 15),
          amount: 6500.0,
        ),
      ];

      // Non-essential categories: Dining, Entertainment, Shopping
      // Essential category: Rent
      final categories = <String, Category>{
        'cat_rent': Category(
          id: 'cat_rent',
          name: 'Rent',
          kind: 'expense',
          group: 'needs',
          iconKey: 'home',
          colorValue: 0xFF000000,
          essential: true, // ESSENTIAL: must NEVER be trimmed
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
        'cat_ent': Category(
          id: 'cat_ent',
          name: 'Entertainment',
          kind: 'expense',
          group: 'wants',
          iconKey: 'film',
          colorValue: 0xFF000000,
          essential: false,
        ),
        'cat_shop': Category(
          id: 'cat_shop',
          name: 'Shopping',
          kind: 'expense',
          group: 'wants',
          iconKey: 'bag',
          colorValue: 0xFF000000,
          essential: false,
        ),
      };

      // Past transactions for categories over Apr, May, Jun
      final txs = <Transaction>[
        // Rent: 25000/mo (essential)
        for (int m = 4; m <= 6; m++)
          Transaction(
            id: 'tx_rent_$m',
            title: 'Rent',
            amount: -25000.0,
            category: 'Rent',
            categoryId: 'cat_rent',
            date: DateTime(2026, m, 5),
            mode: 'expense',
            icon: 'home',
            kind: 'expense',
          ),
        // Dining: 10000/mo -> 20% max trim = 2000
        for (int m = 4; m <= 6; m++)
          Transaction(
            id: 'tx_din_$m',
            title: 'Dining',
            amount: -10000.0,
            category: 'Dining',
            categoryId: 'cat_dining',
            date: DateTime(2026, m, 10),
            mode: 'expense',
            icon: 'utensils',
            kind: 'expense',
          ),
        // Entertainment: 5000/mo -> 20% max trim = 1000
        for (int m = 4; m <= 6; m++)
          Transaction(
            id: 'tx_ent_$m',
            title: 'Movies',
            amount: -5000.0,
            category: 'Entertainment',
            categoryId: 'cat_ent',
            date: DateTime(2026, m, 12),
            mode: 'expense',
            icon: 'film',
            kind: 'expense',
          ),
        // Shopping: 4000/mo -> 20% max trim = 800
        for (int m = 4; m <= 6; m++)
          Transaction(
            id: 'tx_shop_$m',
            title: 'Clothes',
            amount: -4000.0,
            category: 'Shopping',
            categoryId: 'cat_shop',
            date: DateTime(2026, m, 18),
            mode: 'expense',
            icon: 'bag',
            kind: 'expense',
          ),
      ];

      final budgetLines = <String, BudgetLine>{
        'cat_dining': BudgetLine(
          id: 'bl_din',
          categoryId: 'cat_dining',
          amount: 10000.0,
          startMonth: '2026-01',
        ),
        'cat_ent': BudgetLine(
          id: 'bl_ent',
          categoryId: 'cat_ent',
          amount: 5000.0,
          startMonth: '2026-01',
        ),
        'cat_shop': BudgetLine(
          id: 'bl_shop',
          categoryId: 'cat_shop',
          amount: 4000.0,
          startMonth: '2026-01',
        ),
      };

      final plan = GoalPlannerEngine.planGoal(
        goal: goal,
        goalEntries: entries,
        transactions: txs,
        categories: categories,
        budgetLines: budgetLines,
        currentDate: now,
      );

      // Total saved so far: 6500 * 3 = 19500
      expect(plan.saved, equals(19500.0));
      expect(plan.monthsLeft, equals(6));

      // Required monthly: (60000 - 19500) / 6 = 6750.0
      expect(plan.requiredMonthly, equals(6750.0));

      // Rate: 6500.0
      expect(plan.currentRate, equals(6500.0));

      // Shortfall: 6750 - 6500 = 250.0
      expect(plan.shortfall, equals(250.0));

      // Now test with 0 saved to exactly verify 60,000 / 6 = 10,000/mo and rate 6,500 -> shortfall 3,500:
      final planFresh = GoalPlannerEngine.planGoal(
        goal: goal,
        goalEntries: [],
        transactions: txs,
        categories: categories,
        budgetLines: budgetLines,
        currentDate: now,
      );

      expect(planFresh.requiredMonthly, equals(10000.0));
      expect(planFresh.currentRate, equals(0.0));
      expect(planFresh.shortfall, equals(10000.0));

      // Now test with entries having 0 current saved and 6500 rate:
      final mockEntriesWithRate = [
        GoalEntry(
          id: 'e1',
          goalId: 'goal_vacation',
          date: DateTime(2026, 6, 1),
          amount: 6500.0,
        ),
        GoalEntry(
          id: 'e2',
          goalId: 'goal_vacation',
          date: DateTime(2026, 5, 1),
          amount: 6500.0,
        ),
        GoalEntry(
          id: 'e3',
          goalId: 'goal_vacation',
          date: DateTime(2026, 4, 1),
          amount: 6500.0,
        ),
        // Withdrawal of 19500 so saved is 0:
        GoalEntry(
          id: 'e4',
          goalId: 'goal_vacation',
          date: DateTime(2026, 6, 20),
          amount: -19500.0,
        ),
      ];

      final planExactSpec = GoalPlannerEngine.planGoal(
        goal: goal,
        goalEntries: mockEntriesWithRate,
        transactions: txs,
        categories: categories,
        budgetLines: budgetLines,
        currentDate: now,
      );

      // Target 60,000 in 6 months -> required 10,000/mo
      expect(planExactSpec.requiredMonthly, equals(10000.0));
      // Rate 6,500/mo
      expect(planExactSpec.currentRate, equals(6500.0));
      // Shortfall 3,500/mo
      expect(planExactSpec.shortfall, equals(3500.0));

      // Trims:
      // 1. Rent is never trimmed (essential: true)
      expect(planExactSpec.trimSuggestions.any((t) => t.categoryId == 'cat_rent'), isFalse);

      // 2. Greedy trimming on non-essentials:
      // Dining: 3m avg = 10000 => trimmed by 20% = 2000 (remaining shortfall = 1500)
      // Ent: 3m avg = 5000 => trimmed by 20% = 1000 (remaining shortfall = 500)
      // Shop: 3m avg = 4000 => trimmed by 500 (new budget = 3500)
      expect(planExactSpec.trimSuggestions.length, equals(3));
      expect(planExactSpec.trimSuggestions[0].categoryId, equals('cat_dining'));
      expect(planExactSpec.trimSuggestions[0].suggestedTrim, equals(2000.0));
      expect(planExactSpec.trimSuggestions[0].newBudget, equals(8000.0));

      expect(planExactSpec.trimSuggestions[1].categoryId, equals('cat_ent'));
      expect(planExactSpec.trimSuggestions[1].suggestedTrim, equals(1000.0));
      expect(planExactSpec.trimSuggestions[1].newBudget, equals(4000.0));

      expect(planExactSpec.trimSuggestions[2].categoryId, equals('cat_shop'));
      expect(planExactSpec.trimSuggestions[2].suggestedTrim, equals(500.0));
      expect(planExactSpec.trimSuggestions[2].newBudget, equals(3500.0));

      expect(planExactSpec.isInsufficient, isFalse);
    });

    test('Reports insufficient when 20% trims cannot cover shortfall', () {
      final now = DateTime(2026, 7, 1);
      final deadline = now.add(const Duration(days: 183)); // 6 months

      final goal = SavingsGoal(
        id: 'goal_house',
        name: 'House Downpayment',
        targetAmount: 300000.0, // Large target
        deadline: deadline,
        colorValue: 0xFF38BDF8,
      );

      final categories = <String, Category>{
        'cat_shop': Category(
          id: 'cat_shop',
          name: 'Shopping',
          kind: 'expense',
          group: 'wants',
          iconKey: 'bag',
          colorValue: 0xFF000000,
          essential: false,
        ),
      };

      final txs = <Transaction>[
        for (int m = 4; m <= 6; m++)
          Transaction(
            id: 'tx_s_$m',
            title: 'Shopping',
            amount: -5000.0,
            category: 'Shopping',
            categoryId: 'cat_shop',
            date: DateTime(2026, m, 10),
            mode: 'expense',
            icon: 'bag',
            kind: 'expense',
          ),
      ];

      final plan = GoalPlannerEngine.planGoal(
        goal: goal,
        goalEntries: [],
        transactions: txs,
        categories: categories,
        budgetLines: {},
        currentDate: now,
      );

      // Shortfall = 50,000/mo, but max trim on shopping is only 20% of 5000 = 1000.
      expect(plan.isInsufficient, isTrue);
      expect(plan.trimSuggestions.first.suggestedTrim, equals(1000.0));
    });

    test('Sinking fund monthly reserve formula', () {
      final now = DateTime(2026, 1, 1);
      final dueDate = DateTime(2026, 5, 1); // 4 months

      final reserve = GoalPlannerEngine.sinkingFundMonthlyReserve(
        target: 24000.0,
        dueDate: dueDate,
        currentDate: now,
      );

      expect(reserve, equals(6000.0));
    });
  });
}
