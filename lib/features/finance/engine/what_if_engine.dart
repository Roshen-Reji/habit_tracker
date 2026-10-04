import 'package:habit_tracker/features/finance/engine/money.dart';

enum AffordabilityStatus {
  comfortable,
  tight,
  notNow,
}

class WhatIfResult {
  final double amount;
  final AffordabilityStatus status;
  final double forecastMonthEnd;
  final double projectedAfter;
  final double emergencyBuffer;
  final double deficit;
  final int? monthsToSave;
  final String title;
  final String explanation;
  final String recommendation;

  const WhatIfResult({
    required this.amount,
    required this.status,
    required this.forecastMonthEnd,
    required this.projectedAfter,
    required this.emergencyBuffer,
    required this.deficit,
    this.monthsToSave,
    required this.title,
    required this.explanation,
    required this.recommendation,
  });

  bool get isAffordable => status != AffordabilityStatus.notNow;
}

class WhatIfEngine {
  /// Evaluate whether the user can afford an expense of [amount].
  /// [forecastMonthEnd]: projected liquid cash balance at month-end.
  /// [emergencyBuffer]: 1 month of essential expenses.
  /// [avgMonthlySurplus3m]: mean monthly net surplus (income - spending) over the last 3 months.
  static WhatIfResult canAfford({
    required double amount,
    required double forecastMonthEnd,
    required double emergencyBuffer,
    required double avgMonthlySurplus3m,
  }) {
    final projectedAfter = Money.r2(forecastMonthEnd - amount);
    final deficit = Money.r2(emergencyBuffer > 0
        ? (amount - forecastMonthEnd + emergencyBuffer)
        : (amount - forecastMonthEnd));

    AffordabilityStatus status;
    String title;
    String explanation;
    String recommendation;
    int? monthsToSave;

    if (projectedAfter >= emergencyBuffer) {
      status = AffordabilityStatus.comfortable;
      title = 'You can comfortably afford this';
      explanation =
          'After this expense of ₹${amount.toStringAsFixed(0)}, you will still have ₹${projectedAfter.toStringAsFixed(0)} at month end, keeping your 1-month emergency buffer intact.';
      recommendation = 'Safe to proceed with this purchase without impacting commitments.';
    } else if (projectedAfter >= 0) {
      status = AffordabilityStatus.tight;
      title = 'Tight fit — reduces your safety buffer';
      explanation =
          'You will finish the month positive with ₹${projectedAfter.toStringAsFixed(0)}, but your 1-month emergency buffer (₹${emergencyBuffer.toStringAsFixed(0)}) will be partially compromised.';
      recommendation =
          'You can afford it if essential, but consider delaying non-essential purchases or trimming discretionary spending.';
    } else {
      status = AffordabilityStatus.notNow;
      title = 'Not recommended right now';
      final cashDeficit = Money.r2(-projectedAfter);
      explanation =
          'Spending ₹${amount.toStringAsFixed(0)} causes a projected deficit of ₹${cashDeficit.toStringAsFixed(0)} by month end, potentially risking upcoming bills or obligations.';

      if (avgMonthlySurplus3m > 0) {
        monthsToSave = (amount / avgMonthlySurplus3m).ceil();
        if (monthsToSave < 1) monthsToSave = 1;
        recommendation =
            'Save for $monthsToSave month${monthsToSave > 1 ? 's' : ''} at your current average surplus of ₹${avgMonthlySurplus3m.toStringAsFixed(0)}/month before buying.';
      } else {
        recommendation =
            'Reduce recurring bills or wait until liquid cash reserves increase before taking on this expense.';
      }
    }

    return WhatIfResult(
      amount: amount,
      status: status,
      forecastMonthEnd: forecastMonthEnd,
      projectedAfter: projectedAfter,
      emergencyBuffer: emergencyBuffer,
      deficit: deficit > 0 ? deficit : 0.0,
      monthsToSave: monthsToSave,
      title: title,
      explanation: explanation,
      recommendation: recommendation,
    );
  }
}
