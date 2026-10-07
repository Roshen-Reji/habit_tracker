import 'package:habit_tracker/core/utils/format_utils.dart';
import 'dart:math';
import 'package:habit_tracker/features/finance/engine/money.dart';

enum ForecastConfidence {
  high,
  medium,
  low,
}

class SafeToSpendResult {
  final double safeToSpend;
  final double shortfall;
  final double perDay;
  final int daysLeft;
  final double liquid;
  final double obligations;
  final double goalsEarmark;
  final double plannedEssential;
  final double cardDues;
  final double raw;

  const SafeToSpendResult({
    required this.safeToSpend,
    required this.shortfall,
    required this.perDay,
    required this.daysLeft,
    required this.liquid,
    required this.obligations,
    required this.goalsEarmark,
    required this.plannedEssential,
    required this.cardDues,
    double? raw,
  }) : raw = raw ?? (safeToSpend - shortfall);

  bool get hasShortfall => shortfall > 0;
}

class ForecastResult {
  final double projectedMonthEnd;
  final ForecastConfidence confidence;
  final String summary;
  final double liquid;
  final double expectedIncomeRemaining;
  final double obligations;
  final double cardDues;
  final double remainingVariable;

  const ForecastResult({
    required this.projectedMonthEnd,
    required this.confidence,
    required this.summary,
    required this.liquid,
    required this.expectedIncomeRemaining,
    required this.obligations,
    required this.cardDues,
    required this.remainingVariable,
  });
}

class CashFlowResult {
  final double income;
  final double spending;
  final double net;
  final double savingsRate;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> merchantBreakdown;
  final double expectedIncomeNext30;
  final double billsDueNext30;
  final double expectedVariableNext30;
  final double remainingNext30;

  const CashFlowResult({
    required this.income,
    required this.spending,
    required this.net,
    required this.savingsRate,
    required this.categoryBreakdown,
    required this.merchantBreakdown,
    required this.expectedIncomeNext30,
    required this.billsDueNext30,
    required this.expectedVariableNext30,
    required this.remainingNext30,
  });
}

class ForecastEngine {
  /// P8-3 Safe to spend calculation
  /// S = liquid - O - G - P - C
  /// - liquid: Σ balance of spendable bank/cash/wallet accounts
  /// - O: obligations in (today, horizon] (unposted non-income recurring rules, excluding credit card payment transfers)
  /// - G: Σ planned monthly goal/fund contributions not yet contributed this month
  /// - P: Σ over essential budget lines of max(0, effective - spent - unpostedRecurringInThatCategory)
  /// - C: card statement balances falling due by the horizon
  static SafeToSpendResult calculateSafeToSpend({
    required double liquid,
    required double obligations,
    required double goalsEarmark,
    required double plannedEssential,
    required double cardDues,
    required DateTime today,
    DateTime? horizon,
  }) {
    final effectiveHorizon =
        horizon ?? DateTime(today.year, today.month + 1, 0);
    final daysLeft = max(1, effectiveHorizon.difference(today).inDays + 1);

    final rawS =
        liquid - obligations - goalsEarmark - plannedEssential - cardDues;
    final safeToSpend = Money.r2(max(0.0, rawS));
    final shortfall = Money.r2(max(0.0, -rawS));
    final perDay = Money.r2(safeToSpend / daysLeft);

    return SafeToSpendResult(
      safeToSpend: safeToSpend,
      shortfall: shortfall,
      perDay: perDay,
      daysLeft: daysLeft,
      liquid: Money.r2(liquid),
      obligations: Money.r2(obligations),
      goalsEarmark: Money.r2(goalsEarmark),
      plannedEssential: Money.r2(plannedEssential),
      cardDues: Money.r2(cardDues),
      raw: Money.r2(rawS),
    );
  }

  /// P8-2 Month-end forecast of liquid balance
  /// projectedMonthEnd = liquid + expectedIncomeRemaining - O - C - Σ remainingVariable
  /// Confidence: High (>=3m history & CV < 0.25), Medium (>=2m), Low (<2m).
  static ForecastResult calculateMonthEndForecast({
    required double liquid,
    required double expectedIncomeRemaining,
    required double obligations,
    required double cardDues,
    required double remainingVariable,
    required List<double> pastMonthlyVariableSpend,
  }) {
    final projected = Money.r2(
      liquid +
          expectedIncomeRemaining -
          obligations -
          cardDues -
          remainingVariable,
    );

    // Compute confidence based on history length and CV
    ForecastConfidence confidence = ForecastConfidence.low;
    if (pastMonthlyVariableSpend.length >= 3) {
      final mean = _mean(pastMonthlyVariableSpend);
      if (mean > 0) {
        final stdDev = _stdDev(pastMonthlyVariableSpend, mean);
        final cv = stdDev / mean;
        if (cv < 0.25) {
          confidence = ForecastConfidence.high;
        } else {
          confidence = ForecastConfidence.medium;
        }
      } else {
        confidence = ForecastConfidence.medium;
      }
    } else if (pastMonthlyVariableSpend.length >= 2) {
      confidence = ForecastConfidence.medium;
    }

    String summary;
    if (projected >= 0) {
      summary =
          'On track to finish the month with ${FormatUtils.formatMoney(projected, decimals: 0)} liquid buffer';
    } else {
      summary =
          'Projected deficit of ${FormatUtils.formatMoney((-projected), decimals: 0)} by month end';
    }

    return ForecastResult(
      projectedMonthEnd: projected,
      confidence: confidence,
      summary: summary,
      liquid: Money.r2(liquid),
      expectedIncomeRemaining: Money.r2(expectedIncomeRemaining),
      obligations: Money.r2(obligations),
      cardDues: Money.r2(cardDues),
      remainingVariable: Money.r2(remainingVariable),
    );
  }

  /// Variable spend projection per category:
  /// projected_c = w * (spent_c / daysElapsed * daysInMonth) + (1 - w) * avg3_c
  /// w = daysElapsed / daysInMonth
  /// remaining_c = max(0, projected_c - spent_c)
  static double projectCategoryVariableSpend({
    required double currentSpent,
    required int daysElapsed,
    required int daysInMonth,
    required double avg3MonthSpend,
    bool hasHistory = true,
  }) {
    if (daysInMonth <= 0 || daysElapsed <= 0) return currentSpent;
    final pace = (currentSpent / daysElapsed) * daysInMonth;
    if (!hasHistory) {
      return Money.r2(pace);
    }
    final w = (daysElapsed / daysInMonth).clamp(0.0, 1.0);
    final projected = w * pace + (1.0 - w) * avg3MonthSpend;
    return Money.r2(projected);
  }

  /// Calculate remaining variable spend across categories:
  /// Σ max(0, projected_c - spent_c)
  static double calculateTotalRemainingVariable({
    required Map<String, double> currentCategorySpend,
    required Map<String, double> category3MonthAvg,
    required int daysElapsed,
    required int daysInMonth,
    Set<String>? recurringCoveredCategories,
  }) {
    double totalRemaining = 0.0;
    final covered = recurringCoveredCategories ?? {};

    for (final entry in currentCategorySpend.entries) {
      if (covered.contains(entry.key)) continue;
      final spent = entry.value;
      final avg3 = category3MonthAvg[entry.key] ?? 0.0;
      final hasHistory = category3MonthAvg.containsKey(entry.key) && avg3 > 0;
      final projected = projectCategoryVariableSpend(
        currentSpent: spent,
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
        avg3MonthSpend: avg3,
        hasHistory: hasHistory,
      );
      totalRemaining += max(0.0, projected - spent);
    }

    return Money.r2(totalRemaining);
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _stdDev(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }
}
