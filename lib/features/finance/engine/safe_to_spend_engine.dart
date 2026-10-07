import 'package:intl/intl.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/goal_planner_engine.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class SafeToSpendExplanationItem {
  final String id;
  final String label;
  final double amount;
  final String? subtitle;
  final bool isDeduplicated;

  const SafeToSpendExplanationItem({
    required this.id,
    required this.label,
    required this.amount,
    this.subtitle,
    this.isDeduplicated = false,
  });
}

class SafeToSpendExplanation {
  final double liquid;
  final List<SafeToSpendExplanationItem> liquidItems;

  final double obligations;
  final List<SafeToSpendExplanationItem> obligationItems;

  final double goalsEarmark;
  final List<SafeToSpendExplanationItem> goalItems;

  final double plannedEssential;
  final List<SafeToSpendExplanationItem> essentialItems;

  final double cardDues;
  final List<SafeToSpendExplanationItem> cardDueItems;

  final List<SafeToSpendExplanationItem> excludedItems;

  final SafeToSpendResult result;
  final List<String> deduplicationNotes;

  const SafeToSpendExplanation({
    required this.liquid,
    required this.liquidItems,
    required this.obligations,
    required this.obligationItems,
    required this.goalsEarmark,
    required this.goalItems,
    required this.plannedEssential,
    required this.essentialItems,
    required this.cardDues,
    required this.cardDueItems,
    this.excludedItems = const [],
    required this.result,
    required this.deduplicationNotes,
  });
}

class SafeToSpendEngine {
  /// Pure function explaining each component of Safe to Spend with rule IDs and de-duplications.
  static SafeToSpendExplanation explain({
    required Iterable<Account> accounts,
    required Map<String, double> accountBalances,
    required Iterable<RecurringRule> recurringRules,
    required Iterable<SavingsGoal> goals,
    required Iterable<GoalEntry> goalEntries,
    required Iterable<BudgetLine> budgetLines,
    required Map<String, double> categorySpentThisMonth,
    required double Function(BudgetLine, String) getEffectiveBudget,
    required Set<String> postedSourceRefs,
    required DateTime today,
    DateTime? horizon,
  }) {
    final effectiveHorizon =
        horizon ?? DateTime(today.year, today.month + 1, 0);
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0, 23, 59, 59);

    // 1. Liquid breakdown
    final liquidItems = <SafeToSpendExplanationItem>[];
    final excludedItems = <SafeToSpendExplanationItem>[];
    double liquidTotal = 0.0;
    for (final acc in accounts) {
      final bal = accountBalances[acc.id] ?? 0.0;
      if (acc.spendable && !acc.archived && !acc.isLiability) {
        liquidTotal += bal;
        liquidItems.add(SafeToSpendExplanationItem(
          id: acc.id,
          label: acc.name,
          amount: bal,
        ));
      } else {
        final reasons = <String>[];
        if (acc.isLiability) reasons.add('Liability');
        if (!acc.spendable) reasons.add('Non-spendable');
        if (acc.archived) reasons.add('Archived');
        excludedItems.add(SafeToSpendExplanationItem(
          id: acc.id,
          label: acc.name,
          amount: bal,
          subtitle: reasons.join(' · '),
        ));
      }
    }
    liquidTotal = Money.r2(liquidTotal);

    // 2. Obligations breakdown
    final cardAccountIds = accounts
        .where((a) => a.kind == 'credit' && !a.archived)
        .map((a) => a.id)
        .toSet();

    final obligationItems = <SafeToSpendExplanationItem>[];
    double obligationsTotal = 0.0;
    final activeRules =
        recurringRules.where((r) => r.status == 'active').toList();
    final sipFundAccountIds = <String, RecurringRule>{};

    for (final rule in activeRules) {
      if (rule.kind == 'income') continue;
      if (rule.kind == 'transfer' &&
          rule.toAccountId != null &&
          cardAccountIds.contains(rule.toAccountId)) {
        continue;
      }

      if (rule.kind == 'sip' && rule.toAccountId != null) {
        sipFundAccountIds[rule.toAccountId!] = rule;
      }

      final occs = RecurringEngine.occurrences(
        rule,
        today.add(const Duration(days: 1)),
        effectiveHorizon,
      );

      for (final occ in occs) {
        final dateKey = DateFormat('yyyy-MM-dd').format(occ);
        final sourceRef = 'rec:${rule.id}:$dateKey';
        if (!postedSourceRefs.contains(sourceRef)) {
          obligationsTotal += rule.amount;
          obligationItems.add(SafeToSpendExplanationItem(
            id: rule.id,
            label: '${rule.name} (${rule.kind.toUpperCase()})',
            amount: rule.amount,
            subtitle: 'Due: $dateKey',
          ));
        }
      }
    }
    obligationsTotal = Money.r2(obligationsTotal);

    // 3. Goals breakdown with SIP de-duplication
    final goalItems = <SafeToSpendExplanationItem>[];
    final deduplicationNotes = <String>[];
    double goalsEarmarkTotal = 0.0;

    for (final goal in goals.where((g) => !g.archived)) {
      final isFundedBySip = goal.accountId != null &&
          sipFundAccountIds.containsKey(goal.accountId);

      final planned = goal.plannedMonthly ??
          GoalPlannerEngine.calculateRequiredMonthly(
            target: goal.targetAmount,
            saved: goalEntries
                .where((e) => e.goalId == goal.id)
                .fold(0.0, (sum, e) => sum + e.amount),
            deadline: goal.deadline,
            asOf: today,
          );

      final thisMonthContributions = goalEntries
          .where((e) =>
              e.goalId == goal.id &&
              !e.date.isBefore(monthStart) &&
              !e.date.isAfter(monthEnd))
          .fold(0.0, (sum, e) => sum + e.amount);

      final needed =
          (planned - thisMonthContributions).clamp(0.0, double.infinity);

      if (isFundedBySip) {
        final rule = sipFundAccountIds[goal.accountId!]!;
        deduplicationNotes.add(
            'Goal "${goal.name}" is funded by monthly SIP "${rule.name}". Counted in Obligations only to prevent double counting.');
        goalItems.add(SafeToSpendExplanationItem(
          id: goal.id,
          label: goal.name,
          amount: needed,
          subtitle: 'Deduplicated: funded by SIP "${rule.name}"',
          isDeduplicated: true,
        ));
      } else {
        goalsEarmarkTotal += needed;
        goalItems.add(SafeToSpendExplanationItem(
          id: goal.id,
          label: goal.name,
          amount: needed,
          subtitle: 'Planned monthly contribution',
        ));
      }
    }
    goalsEarmarkTotal = Money.r2(goalsEarmarkTotal);

    // 4. Essential budget lines
    final essentialItems = <SafeToSpendExplanationItem>[];
    double plannedEssentialTotal = 0.0;
    final monthKey = '${today.year}-${today.month.toString().padLeft(2, '0')}';

    for (final line in budgetLines.where((b) => b.essential)) {
      if (line.categoryId == null) continue;
      final effective = getEffectiveBudget(line, monthKey);
      final spent = categorySpentThisMonth[line.categoryId!] ?? 0.0;

      double unpostedCatRecurring = 0.0;
      for (final rule in activeRules) {
        if (rule.categoryId == line.categoryId && rule.kind != 'income') {
          final occs = RecurringEngine.occurrences(
            rule,
            today.add(const Duration(days: 1)),
            effectiveHorizon,
          );
          for (final occ in occs) {
            final dateKey = DateFormat('yyyy-MM-dd').format(occ);
            final sourceRef = 'rec:${rule.id}:$dateKey';
            if (!postedSourceRefs.contains(sourceRef)) {
              unpostedCatRecurring += rule.amount;
            }
          }
        }
      }

      final remaining = (effective - spent - unpostedCatRecurring)
          .clamp(0.0, double.infinity);
      if (remaining > 0) {
        plannedEssentialTotal += remaining;
        essentialItems.add(SafeToSpendExplanationItem(
          id: line.id,
          label: 'Category ${line.categoryId}',
          amount: remaining,
          subtitle:
              'Budget: ${Money.r2(effective)} | Spent: ${Money.r2(spent)} | Recurring: ${Money.r2(unpostedCatRecurring)}',
        ));
      }
    }
    plannedEssentialTotal = Money.r2(plannedEssentialTotal);

    // 5. Card dues
    final cardDueItems = <SafeToSpendExplanationItem>[];
    double cardDuesTotal = 0.0;
    for (final cardId in cardAccountIds) {
      final bal = accountBalances[cardId] ?? 0.0;
      if (bal < 0) {
        final due = bal.abs();
        cardDuesTotal += due;
        final cardAcc = accounts.firstWhere((a) => a.id == cardId);
        cardDueItems.add(SafeToSpendExplanationItem(
          id: cardId,
          label: cardAcc.name,
          amount: due,
          subtitle: 'Current balance due',
        ));
      }
    }
    cardDuesTotal = Money.r2(cardDuesTotal);

    final result = ForecastEngine.calculateSafeToSpend(
      liquid: liquidTotal,
      obligations: obligationsTotal,
      goalsEarmark: goalsEarmarkTotal,
      plannedEssential: plannedEssentialTotal,
      cardDues: cardDuesTotal,
      today: today,
      horizon: effectiveHorizon,
    );

    return SafeToSpendExplanation(
      liquid: liquidTotal,
      liquidItems: liquidItems,
      obligations: obligationsTotal,
      obligationItems: obligationItems,
      goalsEarmark: goalsEarmarkTotal,
      goalItems: goalItems,
      plannedEssential: plannedEssentialTotal,
      essentialItems: essentialItems,
      cardDues: cardDuesTotal,
      cardDueItems: cardDueItems,
      excludedItems: excludedItems,
      result: result,
      deduplicationNotes: deduplicationNotes,
    );
  }
}
