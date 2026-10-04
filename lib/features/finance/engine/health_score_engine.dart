import 'dart:math';
import 'package:habit_tracker/features/finance/engine/constants.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';

class HealthScoreComponent {
  final String id;
  final String name;
  final double score; // 0 to 100
  final double baseWeight;
  final bool hasData;
  final String description;

  const HealthScoreComponent({
    required this.id,
    required this.name,
    required this.score,
    required this.baseWeight,
    required this.hasData,
    required this.description,
  });
}

class HealthScoreResult {
  final double overallScore; // 0 to 100
  final List<HealthScoreComponent> components;
  final HealthScoreComponent? weakestComponent;
  final String nextMilestone;

  const HealthScoreResult({
    required this.overallScore,
    required this.components,
    required this.weakestComponent,
    required this.nextMilestone,
  });
}

class HealthScoreEngine {
  /// Calculate Financial Health Score (0 - 100) per MVP 3 spec §5.4.
  static HealthScoreResult calculate({
    // 1. Budgeting (25 pts)
    double? lastMonthBudgetLimit,
    double? lastMonthBudgetOverspend,

    // 2. Savings (25 pts)
    double? savingsRate3m, // e.g. 0.18 = 18%

    // 3. Debt (20 pts)
    double? monthlyDebtObligations,
    double? monthlyIncome,
    double? totalCardBalance,
    double? totalCardLimit,
    bool hasNoDebt = false,

    // 4. Emergency Fund (20 pts)
    required double liquidBalance,
    required double avgMonthlyEssential3m,
    int targetMonths = FinanceConstants.emergencyTargetMonths,

    // 5. Consistency (10 pts)
    List<double>? last6MonthsSpending,
  }) {
    final components = <HealthScoreComponent>[];

    // 1. Budgeting (25 pts)
    if (lastMonthBudgetLimit != null && lastMonthBudgetLimit > 0) {
      final overspend = lastMonthBudgetOverspend ?? 0.0;
      final ratio = (1.0 - (overspend / lastMonthBudgetLimit)).clamp(0.0, 1.0);
      final score = ratio * 100.0;
      components.add(HealthScoreComponent(
        id: 'budgeting',
        name: 'Budget Discipline',
        score: Money.r2(score),
        baseWeight: FinanceConstants.healthWeightBudgeting,
        hasData: true,
        description: overspend == 0
            ? 'Stayed within all budget limits last month'
            : '₹${overspend.toStringAsFixed(0)} overspend on ₹${lastMonthBudgetLimit.toStringAsFixed(0)} limit',
      ));
    } else {
      components.add(const HealthScoreComponent(
        id: 'budgeting',
        name: 'Budget Discipline',
        score: 0.0,
        baseWeight: FinanceConstants.healthWeightBudgeting,
        hasData: false,
        description: 'Set category budgets to track discipline',
      ));
    }

    // 2. Savings (25 pts)
    // 100 * clamp(savingsRate3m / 0.20, 0, 1)
    if (savingsRate3m != null) {
      final score = (savingsRate3m / 0.20).clamp(0.0, 1.0) * 100.0;
      final pct = (savingsRate3m * 100).toStringAsFixed(1);
      components.add(HealthScoreComponent(
        id: 'savings',
        name: 'Savings Rate',
        score: Money.r2(score),
        baseWeight: FinanceConstants.healthWeightSavings,
        hasData: true,
        description: '$pct% 3-month savings rate (target 20%)',
      ));
    } else {
      components.add(const HealthScoreComponent(
        id: 'savings',
        name: 'Savings Rate',
        score: 0.0,
        baseWeight: FinanceConstants.healthWeightSavings,
        hasData: false,
        description: 'Need income & spending history',
      ));
    }

    // 3. Debt (20 pts)
    // DTI <= 0.20 -> 100, falling linearly to 0 at >= 0.50
    // card util <= 0.30 -> 100, falling to 0 at >= 0.90
    // no debt -> 100
    if (hasNoDebt) {
      components.add(const HealthScoreComponent(
        id: 'debt',
        name: 'Debt & Credit',
        score: 100.0,
        baseWeight: FinanceConstants.healthWeightDebt,
        hasData: true,
        description: 'Debt-free! Perfect score',
      ));
    } else {
      final debtParts = <double>[];
      final descriptions = <String>[];

      // DTI
      if (monthlyDebtObligations != null && monthlyIncome != null && monthlyIncome > 0) {
        final dti = (monthlyDebtObligations / monthlyIncome).clamp(0.0, 1.0);
        double dtiScore;
        if (dti <= 0.20) {
          dtiScore = 100.0;
        } else if (dti >= 0.50) {
          dtiScore = 0.0;
        } else {
          dtiScore = ((0.50 - dti) / (0.50 - 0.20)) * 100.0;
        }
        debtParts.add(dtiScore);
        descriptions.add('DTI: ${(dti * 100).toStringAsFixed(1)}%');
      }

      // Card Utilisation
      if (totalCardBalance != null && totalCardLimit != null && totalCardLimit > 0) {
        final util = (totalCardBalance / totalCardLimit).clamp(0.0, 1.0);
        double utilScore;
        if (util <= 0.30) {
          utilScore = 100.0;
        } else if (util >= 0.90) {
          utilScore = 0.0;
        } else {
          utilScore = ((0.90 - util) / (0.90 - 0.30)) * 100.0;
        }
        debtParts.add(utilScore);
        descriptions.add('Card util: ${(util * 100).toStringAsFixed(1)}%');
      }

      if (debtParts.isNotEmpty) {
        final avgDebtScore = debtParts.reduce((a, b) => a + b) / debtParts.length;
        components.add(HealthScoreComponent(
          id: 'debt',
          name: 'Debt & Credit',
          score: Money.r2(avgDebtScore),
          baseWeight: FinanceConstants.healthWeightDebt,
          hasData: true,
          description: descriptions.join(' • '),
        ));
      } else {
        components.add(const HealthScoreComponent(
          id: 'debt',
          name: 'Debt & Credit',
          score: 100.0,
          baseWeight: FinanceConstants.healthWeightDebt,
          hasData: true,
          description: 'No active loans or credit balances',
        ));
      }
    }

    // 4. Emergency Fund (20 pts)
    // 100 * clamp(liquid / avgMonthlyEssential3m / targetMonths, 0, 1)
    if (avgMonthlyEssential3m > 0) {
      final monthsSaved = liquidBalance / avgMonthlyEssential3m;
      final score = (monthsSaved / targetMonths).clamp(0.0, 1.0) * 100.0;
      components.add(HealthScoreComponent(
        id: 'emergency',
        name: 'Emergency Buffer',
        score: Money.r2(score),
        baseWeight: FinanceConstants.healthWeightEmergency,
        hasData: true,
        description: '${monthsSaved.toStringAsFixed(1)} of $targetMonths months saved',
      ));
    } else {
      final score = liquidBalance > 0 ? 100.0 : 0.0;
      components.add(HealthScoreComponent(
        id: 'emergency',
        name: 'Emergency Buffer',
        score: score,
        baseWeight: FinanceConstants.healthWeightEmergency,
        hasData: liquidBalance > 0,
        description: liquidBalance > 0 ? 'Liquid savings available' : 'No liquid buffer',
      ));
    }

    // 5. Consistency (10 pts)
    // Needs >= 3 months. 100 * clamp(1 - CV6m / 0.5, 0, 1)
    if (last6MonthsSpending != null && last6MonthsSpending.length >= 3) {
      final mean = last6MonthsSpending.reduce((a, b) => a + b) / last6MonthsSpending.length;
      if (mean > 0) {
        final variance = last6MonthsSpending
                .map((v) => pow(v - mean, 2))
                .reduce((a, b) => a + b) /
            last6MonthsSpending.length;
        final stdDev = sqrt(variance);
        final cv = stdDev / mean;
        final score = (1.0 - (cv / 0.5)).clamp(0.0, 1.0) * 100.0;
        components.add(HealthScoreComponent(
          id: 'consistency',
          name: 'Spending Consistency',
          score: Money.r2(score),
          baseWeight: FinanceConstants.healthWeightConsistency,
          hasData: true,
          description: cv < 0.20 ? 'Highly predictable monthly spend' : 'Moderate spend variability',
        ));
      } else {
        components.add(const HealthScoreComponent(
          id: 'consistency',
          name: 'Spending Consistency',
          score: 100.0,
          baseWeight: FinanceConstants.healthWeightConsistency,
          hasData: true,
          description: 'Steady spending pattern',
        ));
      }
    } else {
      components.add(const HealthScoreComponent(
        id: 'consistency',
        name: 'Spending Consistency',
        score: 0.0,
        baseWeight: FinanceConstants.healthWeightConsistency,
        hasData: false,
        description: 'Requires at least 3 months of spend history',
      ));
    }

    // Renormalise weights for components with data
    double totalActiveWeight = 0.0;
    double weightedScoreSum = 0.0;
    HealthScoreComponent? weakest;

    for (final comp in components) {
      if (comp.hasData) {
        totalActiveWeight += comp.baseWeight;
        weightedScoreSum += comp.score * comp.baseWeight;
        if (weakest == null || comp.score < weakest.score) {
          weakest = comp;
        }
      }
    }

    final overall = totalActiveWeight > 0
        ? Money.r2(weightedScoreSum / totalActiveWeight)
        : 0.0;

    // Next milestone copy
    String nextMilestone;
    if (avgMonthlyEssential3m > 0) {
      final currentMonths = liquidBalance / avgMonthlyEssential3m;
      final nextMonthsTarget = (currentMonths.floor() + 1).clamp(1, targetMonths);
      final targetAmount = nextMonthsTarget * avgMonthlyEssential3m;
      if (currentMonths < targetMonths) {
        nextMilestone = 'Save ₹${targetAmount.toStringAsFixed(0)} to reach $nextMonthsTarget months of emergency buffer';
      } else {
        nextMilestone = 'Emergency fund fully funded ($targetMonths+ months). Next: boost investment SIPs';
      }
    } else {
      nextMilestone = 'Build a 1-month essential emergency buffer';
    }

    return HealthScoreResult(
      overallScore: overall,
      components: components,
      weakestComponent: weakest,
      nextMilestone: nextMilestone,
    );
  }
}
