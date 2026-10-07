import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/goal_planner_engine.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Pure Dart snapshot of computed finance state, aggregated in a single pass.
class FinanceSnapshot {
  final DateTime asOf;
  final Map<String, double> accountBalances;
  final double liquid;
  final double netWorth;
  final double monthIncome;
  final double monthSpending;
  final SafeToSpendResult? safeToSpend;
  final double obligations;
  final Set<String> postedSourceRefs;
  final RecurringRule? nextSip;
  final RecurringRule? nextEmi;
  final List<RecurringRule> upcomingSipsAndEmis;

  const FinanceSnapshot({
    required this.asOf,
    required this.accountBalances,
    required this.liquid,
    required this.netWorth,
    required this.monthIncome,
    required this.monthSpending,
    required this.safeToSpend,
    required this.obligations,
    required this.postedSourceRefs,
    this.nextSip,
    this.nextEmi,
    this.upcomingSipsAndEmis = const [],
  });

  /// Single pass computation over transactions, valuations, accounts, rules, and goals.
  static FinanceSnapshot compute({
    required Iterable<Account> accounts,
    required Iterable<Transaction> transactions,
    required Iterable<Valuation> valuations,
    required Iterable<RecurringRule> recurringRules,
    required Iterable<SavingsGoal> goals,
    required Iterable<GoalEntry> goalEntries,
    required Iterable<BudgetLine> budgetLines,
    required double Function(BudgetLine, String) getEffectiveBudget,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final cutoff = now;
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final accountMap = <String, Account>{};
    for (final a in accounts) {
      accountMap[a.id] = a;
    }

    // Step 1: Initialize per-account balances and check valuations for valued assets
    final balances = <String, double>{};
    final valuationCutoffDates = <String, DateTime>{};

    for (final acc in accounts) {
      double currentBalance = acc.openingBalance;
      if (acc.isValuedAsset) {
        final relVals = valuations
            .where((v) => v.accountId == acc.id && !v.date.isAfter(cutoff))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        if (relVals.isNotEmpty) {
          currentBalance = relVals.first.value;
          final vDate = relVals.first.date;
          valuationCutoffDates[acc.id] =
              DateTime(vDate.year, vDate.month, vDate.day, 23, 59, 59, 999);
        }
      }
      balances[acc.id] = currentBalance;
    }

    // Step 2: Single pass over transactions
    final postedRefs = <String>{};
    double mIncome = 0.0;
    double mSpending = 0.0;
    double unsettledReceivables = 0.0;
    final currentMonthCategorySpend = <String, double>{};

    for (final tx in transactions) {
      if (tx.sourceRef != null && tx.sourceRef!.isNotEmpty) {
        postedRefs.add(tx.sourceRef!);
      }

      // Check unsettled split receivables
      if (tx.splits != null && tx.splits!.isNotEmpty) {
        try {
          final List parsed = jsonDecode(tx.splits!);
          for (final item in parsed) {
            if (item is Map && item['isOwed'] == true) {
              unsettledReceivables += Money.asDouble(item['amount']);
            }
          }
        } catch (e) {
          debugPrint('FinanceSnapshot splits parse error: $e');
        }
      }

      // Process month income/spending for current month
      final isCurrentMonth =
          tx.date.year == now.year && tx.date.month == now.month;
      if (isCurrentMonth) {
        final kind = tx.effectiveKind;
        if (kind == 'income') {
          mIncome += tx.amount.abs();
        } else if (kind == 'refund') {
          final cat = tx.categoryId ?? tx.category;
          mSpending -= tx.amount.abs();
          currentMonthCategorySpend[cat] =
              (currentMonthCategorySpend[cat] ?? 0.0) - tx.amount.abs();
        } else if (kind == 'debt_payment') {
          final interest = tx.interestAmount ?? 0.0;
          if (interest > 0) {
            mSpending += interest;
            const cat = 'cat_interest_fees';
            currentMonthCategorySpend[cat] =
                (currentMonthCategorySpend[cat] ?? 0.0) + interest;
          }
        } else if (kind == 'expense') {
          if (tx.splits != null && tx.splits!.isNotEmpty) {
            try {
              final List parsed = jsonDecode(tx.splits!);
              for (final item in parsed) {
                if (item is Map) {
                  if (item['isOwed'] == true) continue;
                  final itemCat = item['categoryId']?.toString() ?? 'Other';
                  final itemAmount = Money.asDouble(item['amount']);
                  mSpending += itemAmount;
                  currentMonthCategorySpend[itemCat] =
                      (currentMonthCategorySpend[itemCat] ?? 0.0) + itemAmount;
                }
              }
            } catch (_) {
              final cat = tx.categoryId ?? tx.category;
              mSpending += tx.amount.abs();
              currentMonthCategorySpend[cat] =
                  (currentMonthCategorySpend[cat] ?? 0.0) + tx.amount.abs();
            }
          } else {
            final cat = tx.categoryId ?? tx.category;
            mSpending += tx.amount.abs();
            currentMonthCategorySpend[cat] =
                (currentMonthCategorySpend[cat] ?? 0.0) + tx.amount.abs();
          }
        }
      }

      // Skip balance effects if after cutoff
      if (tx.date.isAfter(cutoff)) continue;

      final absAmount = tx.amount.abs();
      final kind = tx.effectiveKind;

      // Primary account effect
      if (tx.accountId != null && accountMap.containsKey(tx.accountId)) {
        final acc = accountMap[tx.accountId]!;
        final vCutoff = valuationCutoffDates[acc.id];
        final skipForAccount = tx.date.isBefore(acc.openingDate) ||
            (vCutoff != null && !tx.date.isAfter(vCutoff));

        if (!skipForAccount) {
          double delta = 0.0;
          switch (kind) {
            case 'expense':
            case 'transfer':
            case 'investment':
            case 'debt_payment':
              delta = -absAmount;
              break;
            case 'income':
            case 'refund':
            case 'reimbursement':
              delta = absAmount;
              break;
            case 'adjustment':
              delta = (tx.amount >= 0 ? absAmount : -absAmount);
              break;
            default:
              delta = (tx.mode.toLowerCase() == 'expense' || tx.amount < 0)
                  ? -absAmount
                  : absAmount;
          }
          balances[acc.id] = (balances[acc.id] ?? 0.0) + delta;
        }
      }

      // Destination account effect
      if (tx.toAccountId != null && accountMap.containsKey(tx.toAccountId)) {
        final toAcc = accountMap[tx.toAccountId]!;
        final vCutoff = valuationCutoffDates[toAcc.id];
        final skipForToAccount = tx.date.isBefore(toAcc.openingDate) ||
            (vCutoff != null && !tx.date.isAfter(vCutoff));

        if (!skipForToAccount) {
          switch (kind) {
            case 'transfer':
            case 'investment':
              balances[toAcc.id] = (balances[toAcc.id] ?? 0.0) + absAmount;
              break;
            case 'emi':
            case 'debt_payment':
              final rate = toAcc.annualRate ?? 0.0;
              final currentBal = balances[toAcc.id] ?? 0.0;
              final interest =
                  tx.interestAmount ?? (rate / 1200.0 * currentBal.abs());
              final principal = (absAmount - interest).clamp(0.0, absAmount);
              balances[toAcc.id] = (balances[toAcc.id] ?? 0.0) + principal;
              break;
            default:
              break;
          }
        }
      }
    }

    // Round balances
    for (final id in balances.keys) {
      balances[id] = Money.r2(balances[id]!);
    }

    // Step 3: Compute liquid and net worth from balances
    double computedLiquid = 0.0;
    double computedNetWorth = 0.0;

    for (final acc in accounts) {
      final bal = balances[acc.id] ?? 0.0;
      if (acc.spendable && !acc.archived && !acc.isLiability) {
        computedLiquid += bal;
      }
      if (acc.includeInNetWorth && !acc.archived) {
        computedNetWorth += bal;
      }
    }

    computedNetWorth = Money.r2(computedNetWorth + unsettledReceivables);
    computedLiquid = Money.r2(computedLiquid);

    // Step 4: Next SIP and EMI
    final activeRules =
        recurringRules.where((r) => r.status == 'active').toList();
    final upcomingRules = <MapEntry<DateTime, RecurringRule>>[];

    for (final r in activeRules) {
      if (r.kind == 'sip' || r.kind == 'emi') {
        final occs = RecurringEngine.occurrences(
          r,
          now,
          now.add(const Duration(days: 60)),
        );
        for (final occ in occs) {
          upcomingRules.add(MapEntry(occ, r));
        }
      }
    }
    upcomingRules.sort((a, b) => a.key.compareTo(b.key));

    RecurringRule? nextSipRule;
    RecurringRule? nextEmiRule;
    for (final entry in upcomingRules) {
      if (nextSipRule == null && entry.value.kind == 'sip') {
        nextSipRule = entry.value;
      }
      if (nextEmiRule == null && entry.value.kind == 'emi') {
        nextEmiRule = entry.value;
      }
      if (nextSipRule != null && nextEmiRule != null) break;
    }

    final upcomingSipsAndEmisList =
        upcomingRules.map((e) => e.value).toSet().toList();

    // Step 5: Safe to Spend calculation using O(1) set lookups
    final effectiveHorizon = DateTime(now.year, now.month + 1, 0);
    final cardAccountIds = accounts
        .where((a) => a.kind == 'credit' && !a.archived)
        .map((a) => a.id)
        .toSet();

    double obligations = 0.0;
    final sipRuleGoalIds = <String>{};

    for (final rule in activeRules) {
      if (rule.kind == 'income') continue;
      if (rule.kind == 'transfer' &&
          rule.toAccountId != null &&
          cardAccountIds.contains(rule.toAccountId)) {
        continue;
      }

      // Check if this rule is linked to a goal
      if (rule.kind == 'sip' && rule.toAccountId != null) {
        for (final g in goals) {
          if (g.accountId == rule.toAccountId) {
            sipRuleGoalIds.add(g.id);
          }
        }
      }

      final occurrences = RecurringEngine.occurrences(
        rule,
        now.add(const Duration(days: 1)),
        effectiveHorizon,
      );

      for (final occ in occurrences) {
        final dateKey = DateFormat('yyyy-MM-dd').format(occ);
        final sourceRef = 'rec:${rule.id}:$dateKey';
        if (!postedRefs.contains(sourceRef)) {
          obligations += rule.amount;
        }
      }
    }

    // G: goals/fund contributions not yet contributed this month (de-duplicated for SIP funded goals)
    double goalsEarmark = 0.0;
    final activeGoals = goals.where((g) => !g.archived);

    for (final goal in activeGoals) {
      // If goal is funded by a SIP counted in obligations, avoid double counting
      if (sipRuleGoalIds.contains(goal.id)) {
        continue;
      }

      final planned = goal.plannedMonthly ??
          GoalPlannerEngine.calculateRequiredMonthly(
            target: goal.targetAmount,
            saved: goalEntries
                .where((e) => e.goalId == goal.id)
                .fold(0.0, (sum, e) => sum + e.amount),
            deadline: goal.deadline,
            asOf: now,
          );

      final thisMonthContributions = goalEntries
          .where((e) =>
              e.goalId == goal.id &&
              !e.date.isBefore(monthStart) &&
              !e.date.isAfter(monthEnd))
          .fold(0.0, (sum, e) => sum + e.amount);

      final remainingGoalNeed =
          (planned - thisMonthContributions).clamp(0.0, double.infinity);
      goalsEarmark += remainingGoalNeed;
    }

    // P: planned essential budget lines
    double plannedEssential = 0.0;
    final essentialLines = budgetLines.where((b) => b.essential);
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    for (final line in essentialLines) {
      if (line.categoryId == null) continue;
      final effective = getEffectiveBudget(line, monthKey);
      final spent = currentMonthCategorySpend[line.categoryId!] ?? 0.0;

      double unpostedCatRecurring = 0.0;
      for (final rule in activeRules) {
        if (rule.categoryId == line.categoryId && rule.kind != 'income') {
          final occs = RecurringEngine.occurrences(
            rule,
            now.add(const Duration(days: 1)),
            effectiveHorizon,
          );
          for (final occ in occs) {
            final dateKey = DateFormat('yyyy-MM-dd').format(occ);
            final sourceRef = 'rec:${rule.id}:$dateKey';
            if (!postedRefs.contains(sourceRef)) {
              unpostedCatRecurring += rule.amount;
            }
          }
        }
      }

      final remaining = (effective - spent - unpostedCatRecurring)
          .clamp(0.0, double.infinity);
      plannedEssential += remaining;
    }

    // C: card statement balances falling due by horizon
    double cardDues = 0.0;
    for (final cardId in cardAccountIds) {
      final bal = balances[cardId] ?? 0.0;
      if (bal < 0) {
        cardDues += bal.abs();
      }
    }

    final safeToSpendResult = ForecastEngine.calculateSafeToSpend(
      liquid: computedLiquid,
      obligations: obligations,
      goalsEarmark: goalsEarmark,
      plannedEssential: plannedEssential,
      cardDues: cardDues,
      today: now,
      horizon: effectiveHorizon,
    );

    return FinanceSnapshot(
      asOf: now,
      accountBalances: balances,
      liquid: computedLiquid,
      netWorth: computedNetWorth,
      monthIncome: Money.r2(mIncome),
      monthSpending: Money.r2(mSpending),
      safeToSpend: safeToSpendResult,
      obligations: Money.r2(obligations),
      postedSourceRefs: postedRefs,
      nextSip: nextSipRule,
      nextEmi: nextEmiRule,
      upcomingSipsAndEmis: upcomingSipsAndEmisList,
    );
  }
}
