import 'package:intl/intl.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Calculation engine for budgets: effective budget with rollover,
/// 50/30/20 & zero-based models, and variable spend projections.
class BudgetEngine {
  /// Computes the effective budget for [line] in [month] ('yyyy-MM').
  ///
  /// Formula:
  /// - `effective(line, m) = base(line, m) + carry(line, m)`
  /// - `base(line, m)` = override for `m` else `line.amount`
  /// - `carry(line, m)` = 0 if rollover off or `m <= line.startMonth`
  ///                      else `max(0, effective(line, m-1) - spent(line, m-1))`
  ///                      (or without `max` if [rolloverCarryNegative] is true).
  static double effectiveBudget({
    required BudgetLine line,
    required String monthKey,
    required Iterable<Transaction> transactions,
    Map<String, double>? overrides, // key: '${line.id}_${monthKey}'
    bool rolloverCarryNegative = false,
  }) {
    final baseAmount = overrides?['${line.id}_$monthKey'] ?? line.amount;

    if (!line.rollover) {
      return Money.r2(baseAmount);
    }

    final currentMonthDt = _parseMonthKey(monthKey);
    final startMonthDt = _parseMonthKey(line.startMonth);

    // If month is before or equal to start month, there is no carryover
    if (!currentMonthDt.isAfter(startMonthDt)) {
      return Money.r2(baseAmount);
    }

    final carry = _calculateCarry(
      line: line,
      currentMonthDt: currentMonthDt,
      startMonthDt: startMonthDt,
      transactions: transactions,
      overrides: overrides,
      rolloverCarryNegative: rolloverCarryNegative,
    );

    return Money.r2(baseAmount + carry);
  }

  static double _calculateCarry({
    required BudgetLine line,
    required DateTime currentMonthDt,
    required DateTime startMonthDt,
    required Iterable<Transaction> transactions,
    Map<String, double>? overrides,
    required bool rolloverCarryNegative,
  }) {
    // Previous month
    final prevMonthDt = DateTime(currentMonthDt.year, currentMonthDt.month - 1);
    final prevMonthKey = DateFormat('yyyy-MM').format(prevMonthDt);

    final prevEffective = effectiveBudget(
      line: line,
      monthKey: prevMonthKey,
      transactions: transactions,
      overrides: overrides,
      rolloverCarryNegative: rolloverCarryNegative,
    );

    // Calculate spend in previous month for this category
    final prevStart = DateTime(prevMonthDt.year, prevMonthDt.month, 1);
    final prevEnd =
        DateTime(prevMonthDt.year, prevMonthDt.month + 1, 0, 23, 59, 59);

    final prevSpent = line.categoryId != null
        ? LedgerEngine.spending(
            transactions,
            from: prevStart,
            to: prevEnd,
            categoryId: line.categoryId,
          )
        : 0.0;

    final leftover = prevEffective - prevSpent;

    if (rolloverCarryNegative) {
      return leftover;
    } else {
      return leftover > 0 ? leftover : 0.0;
    }
  }

  /// Calculates variable spend projection for category [categoryId] in [currentDate].
  ///
  /// Formula:
  /// `projected = w * (spent / daysElapsed * daysInMonth) + (1 - w) * avg3`
  /// where `w = daysElapsed / daysInMonth`
  /// and `avg3` is the average spending over the previous 3 calendar months.
  static double projectedCategorySpend({
    required String categoryId,
    required DateTime currentDate,
    required Iterable<Transaction> transactions,
  }) {
    final year = currentDate.year;
    final month = currentDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final daysElapsed = currentDate.day.clamp(1, daysInMonth);

    // Current month spend up to today
    final currentMonthStart = DateTime(year, month, 1);
    final currentSpent = LedgerEngine.spending(
      transactions,
      from: currentMonthStart,
      to: currentDate,
      categoryId: categoryId,
    );

    // 3-month historical average
    double historicalSum = 0.0;
    int historicalCount = 0;

    for (int i = 1; i <= 3; i++) {
      final prevStart = DateTime(year, month - i, 1);
      final prevEnd = DateTime(year, month - i + 1, 0, 23, 59, 59);
      final prevSpent = LedgerEngine.spending(
        transactions,
        from: prevStart,
        to: prevEnd,
        categoryId: categoryId,
      );

      historicalSum += prevSpent;
      historicalCount++;
    }

    final avg3 = historicalCount > 0 ? (historicalSum / historicalCount) : 0.0;

    final w = daysElapsed / daysInMonth;
    final paceProjection = (currentSpent / daysElapsed) * daysInMonth;

    final double projected;
    if (avg3 <= 0) {
      // If no history exists, use pace projection alone
      projected = paceProjection;
    } else {
      projected = (w * paceProjection) + ((1 - w) * avg3);
    }

    return Money.r2(projected);
  }

  /// Recommends a weekly cut to stay within budget if projecting to overspend:
  /// `cutAboutWeekly = max(0, projected - budget) / (daysLeft / 7)`
  static double recommendedWeeklyCut({
    required double projectedSpend,
    required double budgetLimit,
    required DateTime currentDate,
  }) {
    final year = currentDate.year;
    final month = currentDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final daysLeft = (daysInMonth - currentDate.day).clamp(1, daysInMonth);

    final overspend = projectedSpend - budgetLimit;
    if (overspend <= 0) return 0.0;

    final weeksLeft = daysLeft / 7.0;
    return Money.r2(overspend / weeksLeft);
  }

  /// Evaluates budget status copy and alert state.
  static BudgetStatus evaluateStatus({
    required double effectiveBudget,
    required double spent,
    required double projectedSpend,
    required DateTime currentDate,
  }) {
    final year = currentDate.year;
    final month = currentDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final daysElapsed = currentDate.day.clamp(1, daysInMonth);

    final isOverBudget = spent > effectiveBudget;
    final isProjectedOver = projectedSpend > effectiveBudget;

    // Pace: is spending faster than daily proportional rate?
    final dailyPace = spent / daysElapsed;
    final expectedDaily = effectiveBudget / daysInMonth;
    final isSpendingFast = !isOverBudget && dailyPace > (expectedDaily * 1.15);

    final pctSpent =
        effectiveBudget > 0 ? (spent / effectiveBudget) * 100 : 100.0;

    String copy;
    if (isOverBudget) {
      final over = spent - effectiveBudget;
      copy = 'Over budget by ${FormatUtils.formatMoney(over)}';
    } else if (isProjectedOver) {
      final over = projectedSpend - effectiveBudget;
      copy = 'Paced to exceed by ${FormatUtils.formatMoney(over)}';
    } else if (isSpendingFast) {
      copy = 'Spending faster than usual';
    } else {
      copy = 'On track (${pctSpent.toStringAsFixed(0)}% used)';
    }

    return BudgetStatus(
      percentUsed: pctSpent,
      isOverBudget: isOverBudget,
      isProjectedOver: isProjectedOver,
      isSpendingFast: isSpendingFast,
      statusCopy: copy,
    );
  }

  /// 50/30/20 Rule computation:
  /// Expected income -> Needs (50%), Wants (30%), Savings (20%).
  static Map<String, BudgetGroupProgress> compute50_30_20({
    required double expectedIncome,
    required Iterable<Transaction> monthTransactions,
    required Map<String, Category> categories,
    double needsPct = 0.50,
    double wantsPct = 0.30,
    double savingsPct = 0.20,
    double goalSavingsActual = 0.0,
  }) {
    final needsTarget = Money.r2(expectedIncome * needsPct);
    final wantsTarget = Money.r2(expectedIncome * wantsPct);
    final savingsTarget = Money.r2(expectedIncome * savingsPct);

    double needsSpent = 0.0;
    double wantsSpent = 0.0;
    double savingsSpent = goalSavingsActual;

    for (final tx in monthTransactions) {
      final kind = tx.effectiveKind;

      if (kind == 'investment') {
        savingsSpent += tx.amount.abs();
        continue;
      }

      if (kind != 'expense' && kind != 'refund') continue;

      final catId = tx.categoryId;
      final category = catId != null ? categories[catId] : null;
      final group = category?.group.toLowerCase() ?? 'wants';

      final signedAmt = kind == 'refund' ? -tx.amount.abs() : tx.amount.abs();

      if (group == 'needs') {
        needsSpent += signedAmt;
      } else if (group == 'savings') {
        savingsSpent += signedAmt;
      } else {
        wantsSpent += signedAmt;
      }
    }

    return {
      'needs': BudgetGroupProgress(
        target: needsTarget,
        actual: Money.r2(needsSpent),
        targetPercentage: needsPct * 100,
      ),
      'wants': BudgetGroupProgress(
        target: wantsTarget,
        actual: Money.r2(wantsSpent),
        targetPercentage: wantsPct * 100,
      ),
      'savings': BudgetGroupProgress(
        target: savingsTarget,
        actual: Money.r2(savingsSpent),
        targetPercentage: savingsPct * 100,
      ),
    };
  }

  /// Zero-based budgeting:
  /// `leftToAssign = expectedIncome - sum(budgetAssignments)`
  static double zeroBasedLeftToAssign({
    required double expectedIncome,
    required Iterable<BudgetLine> lines,
    Iterable<double> extraBuckets = const [],
  }) {
    double assigned = 0.0;
    for (final l in lines) {
      assigned += l.amount;
    }
    for (final b in extraBuckets) {
      assigned += b;
    }
    return Money.r2(expectedIncome - assigned);
  }

  static DateTime _parseMonthKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class BudgetStatus {
  final double percentUsed;
  final bool isOverBudget;
  final bool isProjectedOver;
  final bool isSpendingFast;
  final String statusCopy;

  const BudgetStatus({
    required this.percentUsed,
    required this.isOverBudget,
    required this.isProjectedOver,
    required this.isSpendingFast,
    required this.statusCopy,
  });
}

class BudgetGroupProgress {
  final double target;
  final double actual;
  final double targetPercentage;

  const BudgetGroupProgress({
    required this.target,
    required this.actual,
    required this.targetPercentage,
  });

  double get percentUsed => target > 0 ? (actual / target) * 100 : 0.0;
  double get remaining => target - actual;
}
