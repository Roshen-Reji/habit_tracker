import 'dart:math';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class TrimSuggestion {
  final String categoryId;
  final String categoryName;
  final double threeMonthAvg;
  final double maxTrim;
  final double suggestedTrim;
  final double currentBudget;
  final double newBudget;

  const TrimSuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.threeMonthAvg,
    required this.maxTrim,
    required this.suggestedTrim,
    required this.currentBudget,
    required this.newBudget,
  });
}

class GoalPlan {
  final double target;
  final double saved;
  final int monthsLeft;
  final double requiredMonthly;
  final double currentRate;
  final double shortfall;
  final bool isInsufficient;
  final List<TrimSuggestion> trimSuggestions;

  const GoalPlan({
    required this.target,
    required this.saved,
    required this.monthsLeft,
    required this.requiredMonthly,
    required this.currentRate,
    required this.shortfall,
    required this.isInsufficient,
    required this.trimSuggestions,
  });
}

/// Calculation engine for savings goals, target planning, sinking funds, and trim suggestions.
class GoalPlannerEngine {
  /// Computes months left until deadline.
  /// `monthsLeft = max(1, ceil(daysUntilDeadline / 30.4375))`
  static int monthsUntil(DateTime deadline, DateTime now) {
    final diffDays = deadline.difference(now).inDays;
    if (diffDays <= 0) return 1;
    return max(1, (diffDays / 30.4375).ceil());
  }

  /// Calculates the total saved amount for a goal.
  static double totalSaved(Iterable<GoalEntry> entries) {
    double sum = 0.0;
    for (final e in entries) {
      sum += e.amount;
    }
    return Money.r2(sum);
  }

  /// Evaluates the goal plan: required monthly, rate over last 3 months, shortfall,
  /// and greedy trim suggestions over non-essential categories (up to 20% each).
  static GoalPlan planGoal({
    required SavingsGoal goal,
    required Iterable<GoalEntry> goalEntries,
    required Iterable<Transaction> transactions,
    required Map<String, Category> categories,
    required Map<String, BudgetLine> budgetLines,
    required DateTime currentDate,
  }) {
    final entries = goalEntries.where((e) => e.goalId == goal.id).toList();
    final saved = totalSaved(entries);
    final target = goal.targetAmount;

    // Months left
    final deadline = goal.deadline ?? goal.dueDate;
    final int monthsLeft;
    if (deadline != null) {
      monthsLeft = monthsUntil(deadline, currentDate);
    } else {
      monthsLeft = 12; // default 1 year horizon if no deadline specified
    }

    final remainingToSave = max(0.0, target - saved);
    final requiredMonthly = Money.r2(remainingToSave / monthsLeft);

    // Current monthly contribution rate: average over the previous 3 calendar months
    final year = currentDate.year;
    final month = currentDate.month;
    double past3mContributions = 0.0;

    for (int i = 1; i <= 3; i++) {
      final prevStart = DateTime(year, month - i, 1);
      final prevEnd = DateTime(year, month - i + 1, 0, 23, 59, 59);

      for (final e in entries) {
        if (!e.date.isBefore(prevStart) && !e.date.isAfter(prevEnd) && e.amount > 0) {
          past3mContributions += e.amount;
        }
      }
    }

    final currentRate = Money.r2(past3mContributions / 3.0);
    final shortfall = Money.r2(max(0.0, requiredMonthly - currentRate));

    if (shortfall <= 0) {
      return GoalPlan(
        target: target,
        saved: saved,
        monthsLeft: monthsLeft,
        requiredMonthly: requiredMonthly,
        currentRate: currentRate,
        shortfall: 0.0,
        isInsufficient: false,
        trimSuggestions: const [],
      );
    }

    // -------------------------------------------------------------------------
    // TRIM SUGGESTIONS
    // Greedy over non-essential categories by 3-month average descending,
    // up to 20% per category, until the shortfall is covered.
    // Never touches essential categories, never exceeds 20%,
    // and reports "insufficient" when short.
    // -------------------------------------------------------------------------

    final nonEssentialCategories = categories.values
        .where((c) => !c.archived && c.kind == 'expense' && !c.essential)
        .toList();

    final categoryAvgs = <String, double>{};
    for (final cat in nonEssentialCategories) {
      double cat3mSum = 0.0;
      for (int i = 1; i <= 3; i++) {
        final prevStart = DateTime(year, month - i, 1);
        final prevEnd = DateTime(year, month - i + 1, 0, 23, 59, 59);
        final spent = LedgerEngine.spending(
          transactions,
          from: prevStart,
          to: prevEnd,
          categoryId: cat.id,
        );
        cat3mSum += spent;
      }
      final avg = cat3mSum / 3.0;
      if (avg > 0) {
        categoryAvgs[cat.id] = Money.r2(avg);
      }
    }

    // Sort descending by 3-month average
    nonEssentialCategories.sort((a, b) {
      final avgA = categoryAvgs[a.id] ?? 0.0;
      final avgB = categoryAvgs[b.id] ?? 0.0;
      return avgB.compareTo(avgA);
    });

    double remainingShortfall = shortfall;
    final suggestions = <TrimSuggestion>[];

    for (final cat in nonEssentialCategories) {
      final avg = categoryAvgs[cat.id] ?? 0.0;
      if (avg <= 0) continue;

      final maxTrim = Money.r2(avg * 0.20);
      if (maxTrim <= 0) continue;

      final trimAmount = Money.r2(min(remainingShortfall, maxTrim));
      if (trimAmount <= 0) continue;

      final existingLine = budgetLines[cat.id];
      final currentBudget = existingLine?.amount ?? avg;
      final newBudget = Money.r2(max(0.0, currentBudget - trimAmount));

      suggestions.add(TrimSuggestion(
        categoryId: cat.id,
        categoryName: cat.name,
        threeMonthAvg: avg,
        maxTrim: maxTrim,
        suggestedTrim: trimAmount,
        currentBudget: currentBudget,
        newBudget: newBudget,
      ));

      remainingShortfall = Money.r2(remainingShortfall - trimAmount);
      if (remainingShortfall <= 0.01) {
        break;
      }
    }

    final isInsufficient = remainingShortfall > 0.01;

    return GoalPlan(
      target: target,
      saved: saved,
      monthsLeft: monthsLeft,
      requiredMonthly: requiredMonthly,
      currentRate: currentRate,
      shortfall: shortfall,
      isInsufficient: isInsufficient,
      trimSuggestions: suggestions,
    );
  }

  /// Calculates sinking fund monthly reserve:
  /// `target / monthsLeft`
  static double sinkingFundMonthlyReserve({
    required double target,
    required DateTime dueDate,
    required DateTime currentDate,
  }) {
    final months = monthsUntil(dueDate, currentDate);
    return Money.r2(target / months);
  }
}
