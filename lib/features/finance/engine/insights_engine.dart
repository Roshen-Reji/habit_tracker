import 'package:habit_tracker/core/utils/format_utils.dart';
import 'dart:math';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

enum InsightSeverity {
  info,
  warning,
  danger,
  success,
}

class FinanceInsight {
  final String stableKey;
  final InsightSeverity severity;
  final String kind;
  final String title;
  final String body;
  final String? deepLink;
  final Map<String, dynamic> params;

  const FinanceInsight({
    required this.stableKey,
    required this.severity,
    required this.kind,
    required this.title,
    required this.body,
    this.deepLink,
    this.params = const {},
  });
}

class InsightsEngine {
  /// Generate deterministic insights based on financial data.
  static List<FinanceInsight> generateInsights({
    required DateTime today,
    required double liquidBalance,
    required List<Transaction> currentMonthTransactions,
    required List<Transaction> past3MonthsTransactions,
    required List<Category> categories,
    required List<BudgetLine> budgetLines,
    required Map<String, double> budgetLineSpent,
    required List<SavingsGoal> activeGoals,
    required Map<String, double> goalSavedAmounts,
    required Map<String, double> goal3mMonthlyRates,
    required List<RecurringRule> recurringRules,
    required double currentNetWorth,
    required double lastMonthNetWorth,
    required double currentSavingsRate,
    required double pastSavingsRate3m,
    required double avgMonthlyEssential3m,
    Set<String>? dismissedKeys,
  }) {
    final dismissed = dismissedKeys ?? <String>{};
    final insights = <FinanceInsight>[];

    final monthKey = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final daysElapsed = today.day;
    final monthFraction = daysElapsed / daysInMonth;

    final catMap = {for (final c in categories) c.id: c};

    // 1. Bill Collisions with low liquid balance (Danger)
    for (final rule in recurringRules) {
      if (rule.status != 'active' || rule.kind == 'income') continue;
      final dueDay = rule.dayOfMonth ?? 1;
      final daysUntilDue = dueDay - today.day;
      if (daysUntilDue >= 0 && daysUntilDue <= 5) {
        if (rule.amount > liquidBalance) {
          final key = 'bill_collision_${rule.id}_$monthKey';
          if (!dismissed.contains(key)) {
            insights.add(FinanceInsight(
              stableKey: key,
              severity: InsightSeverity.danger,
              kind: 'bill_collision',
              title: 'Upcoming Bill Exceeds Liquid Balance',
              body:
                  '${rule.name} (${FormatUtils.formatMoney(rule.amount, decimals: 0)}) is due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}, but your liquid balance is ${FormatUtils.formatMoney(liquidBalance, decimals: 0)}.',
              deepLink: 'bills',
              params: {'ruleId': rule.id, 'amount': rule.amount},
            ));
          }
        }
      }
    }

    // 2. Suspected Duplicate Charges (Warning)
    // Same merchant and amount within 24 hours
    for (var i = 0; i < currentMonthTransactions.length; i++) {
      final tx1 = currentMonthTransactions[i];
      if (tx1.effectiveKind != 'expense' ||
          tx1.merchant == null ||
          tx1.merchant!.isEmpty) {
        continue;
      }
      for (var j = i + 1; j < currentMonthTransactions.length; j++) {
        final tx2 = currentMonthTransactions[j];
        if (tx2.effectiveKind != 'expense') continue;
        if (tx1.merchant?.toLowerCase() == tx2.merchant?.toLowerCase() &&
            (tx1.amount.abs() - tx2.amount.abs()).abs() < 0.01) {
          final diffHours = tx1.date.difference(tx2.date).inHours.abs();
          if (diffHours <= 24) {
            final key = 'dup_charge_${tx1.id}_${tx2.id}';
            if (!dismissed.contains(key)) {
              insights.add(FinanceInsight(
                stableKey: key,
                severity: InsightSeverity.warning,
                kind: 'duplicate_charge',
                title: 'Possible Duplicate Charge',
                body:
                    'Two charges of ${FormatUtils.formatMoney(tx1.amount.abs(), decimals: 0)} at ${tx1.merchant} within $diffHours hours on ${tx1.date.day}/${tx1.date.month}.',
                deepLink: 'transactions',
                params: {
                  'txId1': tx1.id,
                  'txId2': tx2.id,
                  'merchant': tx1.merchant
                },
              ));
            }
          }
        }
      }
    }

    // 3. Unusually Large Transactions (> 3x category median, floor ₹1,000)
    final txsByCategory = <String, List<double>>{};
    for (final tx in past3MonthsTransactions) {
      if (tx.effectiveKind == 'expense' && tx.categoryId != null) {
        txsByCategory
            .putIfAbsent(tx.categoryId!, () => [])
            .add(tx.amount.abs());
      }
    }

    final catMedians = <String, double>{};
    for (final entry in txsByCategory.entries) {
      if (entry.value.length >= 3) {
        final sorted = List<double>.from(entry.value)..sort();
        catMedians[entry.key] = sorted[sorted.length ~/ 2];
      }
    }

    for (final tx in currentMonthTransactions) {
      if (tx.effectiveKind != 'expense' || tx.categoryId == null) continue;
      final median = catMedians[tx.categoryId!];
      final amt = tx.amount.abs();
      if (median != null && amt >= 1000.0 && amt > 3.0 * median) {
        final key = 'unusual_large_tx_${tx.id}';
        final catName = catMap[tx.categoryId]?.name ?? 'Category';
        if (!dismissed.contains(key)) {
          insights.add(FinanceInsight(
            stableKey: key,
            severity: InsightSeverity.warning,
            kind: 'unusual_large_tx',
            title: 'Unusually Large $catName Expense',
            body:
                '${FormatUtils.formatMoney(amt, decimals: 0)} at ${tx.merchant ?? tx.title} is over 3× your typical spend for $catName (median ${FormatUtils.formatMoney(median, decimals: 0)}).',
            deepLink: 'transactions',
            params: {'txId': tx.id, 'amount': amt, 'median': median},
          ));
        }
      }
    }

    // 4. Budget Pace Warnings (> 25% ahead of elapsed month pace)
    for (final line in budgetLines) {
      final spent = budgetLineSpent[line.id] ?? 0.0;
      if (line.amount > 0 && monthFraction > 0.15 && monthFraction < 0.95) {
        final spentFraction = spent / line.amount;
        if (spentFraction > monthFraction + 0.25 && spentFraction < 1.0) {
          final catName = catMap[line.categoryId]?.name ?? 'Budget';
          final key = 'budget_pace_${line.id}_$monthKey';
          if (!dismissed.contains(key)) {
            insights.add(FinanceInsight(
              stableKey: key,
              severity: InsightSeverity.warning,
              kind: 'budget_pace',
              title: '$catName Pace Warning',
              body:
                  'You have spent ${(spentFraction * 100).toStringAsFixed(0)}% of your $catName budget at day $daysElapsed of $daysInMonth. Consider slowing down.',
              deepLink: 'budget',
              params: {'lineId': line.id, 'spent': spent, 'limit': line.amount},
            ));
          }
        }
      }
    }

    // 5. Category Spikes (> +20% and > ₹500 vs 3-month average)
    final currentCatTotals = <String, double>{};
    for (final tx in currentMonthTransactions) {
      if (tx.effectiveKind == 'expense' && tx.categoryId != null) {
        currentCatTotals[tx.categoryId!] =
            (currentCatTotals[tx.categoryId!] ?? 0.0) + tx.amount.abs();
      }
    }

    final past3mCatTotals = <String, double>{};
    for (final tx in past3MonthsTransactions) {
      if (tx.effectiveKind == 'expense' && tx.categoryId != null) {
        past3mCatTotals[tx.categoryId!] =
            (past3mCatTotals[tx.categoryId!] ?? 0.0) + tx.amount.abs();
      }
    }

    for (final entry in currentCatTotals.entries) {
      final catId = entry.key;
      final currentSpent = entry.value;
      final pastTotal = past3mCatTotals[catId] ?? 0.0;
      final avg3m = pastTotal / 3.0;

      if (avg3m > 0 &&
          currentSpent > avg3m * 1.20 &&
          (currentSpent - avg3m) > 500.0) {
        final catName = catMap[catId]?.name ?? 'Category';
        final pctUp =
            (((currentSpent - avg3m) / avg3m) * 100).toStringAsFixed(0);
        final key = 'cat_spike_${catId}_$monthKey';
        if (!dismissed.contains(key)) {
          insights.add(FinanceInsight(
            stableKey: key,
            severity: InsightSeverity.info,
            kind: 'category_spike',
            title: '$catName Spending Up +$pctUp%',
            body:
                'You\'ve spent ${FormatUtils.formatMoney(currentSpent, decimals: 0)} so far, exceeding your 3-month average of ${FormatUtils.formatMoney(avg3m, decimals: 0)}.',
            deepLink: 'budget',
            params: {
              'categoryId': catId,
              'currentSpent': currentSpent,
              'avg3m': avg3m
            },
          ));
        }
      }
    }

    // 6. Goals Behind Schedule
    for (final goal in activeGoals) {
      if (goal.targetAmount <= 0) continue;
      final saved = goalSavedAmounts[goal.id] ?? 0.0;
      final rate = goal3mMonthlyRates[goal.id] ?? 0.0;
      final deadline = goal.deadline;
      if (deadline != null) {
        final daysLeft = deadline.difference(today).inDays;
        final monthsLeft = max<int>(1, (daysLeft / 30.4375).ceil());
        final projectedSaved = saved + (rate * monthsLeft);
        if (projectedSaved < goal.targetAmount &&
            (goal.targetAmount - projectedSaved) > 1000) {
          final key = 'goal_behind_${goal.id}_$monthKey';
          if (!dismissed.contains(key)) {
            final shortfall = goal.targetAmount - projectedSaved;
            insights.add(FinanceInsight(
              stableKey: key,
              severity: InsightSeverity.info,
              kind: 'goal_behind',
              title: '${goal.name} May Fall Short',
              body:
                  'At your current pace of ${FormatUtils.formatMoney(rate, decimals: 0)}/mo, you will be ${FormatUtils.formatMoney(shortfall, decimals: 0)} short of your ${FormatUtils.formatMoney(goal.targetAmount, decimals: 0)} goal by ${deadline.day}/${deadline.month}/${deadline.year}.',
              deepLink: 'goals',
              params: {'goalId': goal.id, 'shortfall': shortfall},
            ));
          }
        }
      }
    }

    // 7. Active Subscriptions Cost Summary
    final subs = recurringRules
        .where((r) => r.status == 'active' && r.kind == 'subscription')
        .toList();
    if (subs.isNotEmpty) {
      double monthlyTotal = 0.0;
      for (final s in subs) {
        if (s.frequency == 'yearly') {
          monthlyTotal += s.amount / 12.0;
        } else if (s.frequency == 'quarterly') {
          monthlyTotal += s.amount / 3.0;
        } else if (s.frequency == 'weekly') {
          monthlyTotal += s.amount * 4.33;
        } else {
          monthlyTotal += s.amount;
        }
      }
      final key = 'sub_total_$monthKey';
      if (!dismissed.contains(key) && monthlyTotal > 0) {
        insights.add(FinanceInsight(
          stableKey: key,
          severity: InsightSeverity.info,
          kind: 'subscription_total',
          title: '${subs.length} Active Subscriptions',
          body:
              'Totaling ${FormatUtils.formatMoney(monthlyTotal, decimals: 0)}/month (${FormatUtils.formatMoney((monthlyTotal * 12), decimals: 0)}/year) across ${subs.length} streaming and software services.',
          deepLink: 'bills',
          params: {'count': subs.length, 'monthlyTotal': monthlyTotal},
        ));
      }
    }

    // 8. Net Worth Trend
    if (lastMonthNetWorth > 0) {
      final change = currentNetWorth - lastMonthNetWorth;
      final pct = (change / lastMonthNetWorth) * 100.0;
      final key = 'networth_trend_$monthKey';
      if (!dismissed.contains(key) && pct.abs() >= 1.0) {
        final isPositive = change >= 0;
        insights.add(FinanceInsight(
          stableKey: key,
          severity: isPositive ? InsightSeverity.success : InsightSeverity.info,
          kind: 'net_worth_trend',
          title: isPositive
              ? 'Net Worth Grew +${pct.toStringAsFixed(1)}%'
              : 'Net Worth Dipped ${pct.toStringAsFixed(1)}%',
          body:
              '${isPositive ? 'Increased' : 'Decreased'} by ${FormatUtils.formatMoney(change.abs(), decimals: 0)} vs last month.',
          deepLink: 'networth',
          params: {'change': change, 'pct': pct},
        ));
      }
    }

    // 9. Savings Rate Trend
    if (pastSavingsRate3m > 0 && currentSavingsRate > 0) {
      final diff = (currentSavingsRate - pastSavingsRate3m) * 100.0;
      final key = 'savings_rate_trend_$monthKey';
      if (!dismissed.contains(key) && diff >= 5.0) {
        insights.add(FinanceInsight(
          stableKey: key,
          severity: InsightSeverity.success,
          kind: 'savings_rate_trend',
          title: 'Savings Rate Boosted!',
          body:
              'Your savings rate is ${(currentSavingsRate * 100).toStringAsFixed(0)}% this month (+${diff.toStringAsFixed(1)}% higher than your 3-month baseline).',
          deepLink: 'overview',
          params: {'currentRate': currentSavingsRate, 'diff': diff},
        ));
      }
    }

    // 10. Emergency Fund Status
    if (avgMonthlyEssential3m > 0) {
      final monthsSaved = liquidBalance / avgMonthlyEssential3m;
      final key = 'emergency_fund_status_$monthKey';
      if (!dismissed.contains(key)) {
        if (monthsSaved < 1.0) {
          insights.add(FinanceInsight(
            stableKey: key,
            severity: InsightSeverity.warning,
            kind: 'emergency_fund_status',
            title: 'Low Emergency Fund Buffer',
            body:
                'You have ${(monthsSaved * 30).toStringAsFixed(0)} days of essential spending saved. Aim for at least 3 to 6 months of liquid reserves.',
            deepLink: 'accounts',
            params: {'monthsSaved': monthsSaved},
          ));
        } else if (monthsSaved >= 6.0) {
          insights.add(FinanceInsight(
            stableKey: key,
            severity: InsightSeverity.success,
            kind: 'emergency_fund_status',
            title: 'Robust Emergency Reserves',
            body:
                'You have ${monthsSaved.toStringAsFixed(1)} months of emergency buffer saved. Your essential safety net is well protected.',
            deepLink: 'accounts',
            params: {'monthsSaved': monthsSaved},
          ));
        }
      }
    }

    return insights;
  }
}
