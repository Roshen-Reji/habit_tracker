import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/health_score_engine.dart';
import 'package:habit_tracker/features/finance/engine/insights_engine.dart';
import 'package:habit_tracker/features/finance/engine/what_if_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

void main() {
  group('Phase 8 - Forecast & Safe to Spend Engine', () {
    test('P8-3: Safe to spend formula S = liquid - O - G - P - C', () {
      final today = DateTime(2026, 10, 10);
      final horizon = DateTime(2026, 10, 31);
      // daysLeft = 31 - 10 + 1 = 22 days

      final res = ForecastEngine.calculateSafeToSpend(
        liquid: 50000.0,
        obligations: 10000.0,
        goalsEarmark: 5000.0,
        plannedEssential: 15000.0,
        cardDues: 5000.0,
        today: today,
        horizon: horizon,
      );

      // 50,000 - 10,000 - 5,000 - 15,000 - 5,000 = 15,000
      expect(res.safeToSpend, 15000.0);
      expect(res.shortfall, 0.0);
      expect(res.hasShortfall, false);
      expect(res.daysLeft, 22);
      expect(res.perDay, closeTo(15000.0 / 22, 0.01));
    });

    test('P8-3: Safe to spend reports shortfall when negative', () {
      final today = DateTime(2026, 10, 15);
      final horizon = DateTime(2026, 10, 31);

      final res = ForecastEngine.calculateSafeToSpend(
        liquid: 20000.0,
        obligations: 15000.0,
        goalsEarmark: 5000.0,
        plannedEssential: 8000.0,
        cardDues: 2000.0,
        today: today,
        horizon: horizon,
      );

      // 20,000 - 15,000 - 5,000 - 8,000 - 2,000 = -10,000
      expect(res.safeToSpend, 0.0);
      expect(res.shortfall, 10000.0);
      expect(res.hasShortfall, true);
      expect(res.perDay, 0.0);
    });

    test('P8-2: Category variable spend projection formula w * pace + (1-w) * avg3', () {
      // Day 15 of 30: w = 0.5
      // Current spent = 3,000 -> pace = 6,000
      // 3-month avg = 4,000
      // projected = 0.5 * 6,000 + 0.5 * 4,000 = 5,000
      final proj = ForecastEngine.projectCategoryVariableSpend(
        currentSpent: 3000.0,
        daysElapsed: 15,
        daysInMonth: 30,
        avg3MonthSpend: 4000.0,
        hasHistory: true,
      );

      expect(proj, 5000.0);
    });

    test('P8-2: Month-end forecast and confidence levels', () {
      // 3 months of very consistent spend -> high confidence (CV < 0.25)
      final resHigh = ForecastEngine.calculateMonthEndForecast(
        liquid: 40000.0,
        expectedIncomeRemaining: 30000.0,
        obligations: 10000.0,
        cardDues: 5000.0,
        remainingVariable: 15000.0,
        pastMonthlyVariableSpend: [20000.0, 20500.0, 19500.0],
      );

      // 40,000 + 30,000 - 10,000 - 5,000 - 15,000 = 40,000
      expect(resHigh.projectedMonthEnd, 40000.0);
      expect(resHigh.confidence, ForecastConfidence.high);

      // Low confidence with < 2 months of history
      final resLow = ForecastEngine.calculateMonthEndForecast(
        liquid: 40000.0,
        expectedIncomeRemaining: 30000.0,
        obligations: 10000.0,
        cardDues: 5000.0,
        remainingVariable: 15000.0,
        pastMonthlyVariableSpend: [20000.0],
      );
      expect(resLow.confidence, ForecastConfidence.low);
    });
  });

  group('Phase 8 - Financial Health Score Engine', () {
    test('P8-4: Perfect health score for debt-free user with max savings and full emergency buffer', () {
      final res = HealthScoreEngine.calculate(
        lastMonthBudgetLimit: 50000.0,
        lastMonthBudgetOverspend: 0.0, // 100% budget discipline
        savingsRate3m: 0.25, // >= 20% -> 100%
        hasNoDebt: true, // 100%
        liquidBalance: 300000.0,
        avgMonthlyEssential3m: 50000.0, // 6 months saved -> 100%
        targetMonths: 6,
        last6MonthsSpending: [45000.0, 46000.0, 44000.0, 45000.0, 45500.0, 44500.0], // Low CV -> 100%
      );

      expect(res.overallScore, closeTo(100.0, 1.0));
      expect(res.components.length, 5);
    });

    test('P8-4: Identifies weakest component correctly', () {
      final res = HealthScoreEngine.calculate(
        lastMonthBudgetLimit: 50000.0,
        lastMonthBudgetOverspend: 20000.0, // 60% score
        savingsRate3m: 0.10, // 10% / 20% = 50% score
        monthlyDebtObligations: 25000.0,
        monthlyIncome: 50000.0, // DTI = 0.50 -> 0% score!
        totalCardBalance: 0.0,
        totalCardLimit: 100000.0,
        liquidBalance: 150000.0,
        avgMonthlyEssential3m: 30000.0,
        targetMonths: 6,
      );

      expect(res.weakestComponent, isNotNull);
      expect(res.weakestComponent!.id, 'debt');
      expect(res.weakestComponent!.score, 0.0);
    });
  });

  group('Phase 8 - What-If Simulator Engine', () {
    test('P8-6: Comfortable when projectedAfter >= emergencyBuffer', () {
      final res = WhatIfEngine.canAfford(
        amount: 20000.0,
        forecastMonthEnd: 70000.0,
        emergencyBuffer: 30000.0, // 70k - 20k = 50k >= 30k
        avgMonthlySurplus3m: 15000.0,
      );

      expect(res.status, AffordabilityStatus.comfortable);
      expect(res.isAffordable, true);
      expect(res.projectedAfter, 50000.0);
      expect(res.monthsToSave, isNull);
    });

    test('P8-6: Tight when projectedAfter >= 0 but < emergencyBuffer', () {
      final res = WhatIfEngine.canAfford(
        amount: 50000.0,
        forecastMonthEnd: 70000.0,
        emergencyBuffer: 30000.0, // 70k - 50k = 20k < 30k but >= 0
        avgMonthlySurplus3m: 15000.0,
      );

      expect(res.status, AffordabilityStatus.tight);
      expect(res.isAffordable, true);
      expect(res.projectedAfter, 20000.0);
    });

    test('P8-6: Not now when projectedAfter < 0, provides monthsToSave', () {
      final res = WhatIfEngine.canAfford(
        amount: 100000.0,
        forecastMonthEnd: 40000.0,
        emergencyBuffer: 30000.0, // 40k - 100k = -60k
        avgMonthlySurplus3m: 20000.0,
      );

      expect(res.status, AffordabilityStatus.notNow);
      expect(res.isAffordable, false);
      expect(res.projectedAfter, -60000.0);
      // ceil(100k / 20k) = 5 months
      expect(res.monthsToSave, 5);
    });
  });

  group('Phase 8 - Insights Engine', () {
    test('P8-5: Generates duplicate charge warning for same merchant & amount in 24h', () {
      final tx1 = Transaction(
        title: 'Uber Ride',
        amount: -350.0,
        category: 'Transport',
        date: DateTime(2026, 10, 4, 10, 0),
        id: 'tx_1',
        merchant: 'Uber',
        categoryId: 'cat_transport',
      );
      final tx2 = Transaction(
        title: 'Uber Ride',
        amount: -350.0,
        category: 'Transport',
        date: DateTime(2026, 10, 4, 12, 0),
        id: 'tx_2',
        merchant: 'Uber',
        categoryId: 'cat_transport',
      );

      final insights = InsightsEngine.generateInsights(
        today: DateTime(2026, 10, 4),
        liquidBalance: 20000.0,
        currentMonthTransactions: [tx1, tx2],
        past3MonthsTransactions: [],
        categories: [Category(id: 'cat_transport', name: 'Transport')],
        budgetLines: [],
        budgetLineSpent: {},
        activeGoals: [],
        goalSavedAmounts: {},
        goal3mMonthlyRates: {},
        recurringRules: [],
        currentNetWorth: 50000.0,
        lastMonthNetWorth: 50000.0,
        currentSavingsRate: 0.2,
        pastSavingsRate3m: 0.2,
        avgMonthlyEssential3m: 10000.0,
      );

      final dup = insights.where((i) => i.kind == 'duplicate_charge');
      expect(dup.length, 1);
      expect(dup.first.severity, InsightSeverity.warning);
      expect(dup.first.body, contains('Two charges of ₹350 at Uber within 2 hours'));
    });

    test('P8-5: Generates bill collision danger when bill exceeds liquid balance', () {
      final rule = RecurringRule(
        id: 'rec_rent',
        name: 'House Rent',
        amount: 25000.0,
        dayOfMonth: 6, // due in 2 days from Oct 4
        status: 'active',
      );

      final insights = InsightsEngine.generateInsights(
        today: DateTime(2026, 10, 4),
        liquidBalance: 15000.0, // Less than ₹25,000!
        currentMonthTransactions: [],
        past3MonthsTransactions: [],
        categories: [],
        budgetLines: [],
        budgetLineSpent: {},
        activeGoals: [],
        goalSavedAmounts: {},
        goal3mMonthlyRates: {},
        recurringRules: [rule],
        currentNetWorth: 50000.0,
        lastMonthNetWorth: 50000.0,
        currentSavingsRate: 0.2,
        pastSavingsRate3m: 0.2,
        avgMonthlyEssential3m: 10000.0,
      );

      final collision = insights.where((i) => i.kind == 'bill_collision');
      expect(collision.length, 1);
      expect(collision.first.severity, InsightSeverity.danger);
      expect(collision.first.body, contains('due in 2 days, but your liquid balance is ₹15000'));
    });
  });
}
