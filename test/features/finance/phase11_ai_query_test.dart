import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/engine/query.dart';
import 'package:habit_tracker/features/finance/engine/what_if_engine.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/data/services/ai_context.dart';
import 'package:habit_tracker/data/services/ai_service.dart';

void main() {
  group('Phase 11: FinanceQuery Parsing & Serialization', () {
    test('Serializes and deserializes FinanceQuery JSON', () {
      const query = FinanceQuery(
        metric: QueryMetric.sum,
        subject: QuerySubject.spending,
        filters: QueryFilters(
          merchant: 'Swiggy',
          category: 'Food',
          period: QueryPeriod.lastMonth,
          amountMin: 200.0,
        ),
        groupBy: QueryGroupBy.merchant,
        compareTo: QueryPeriod.thisMonth,
        topN: 3,
      );

      final json = query.toJson();
      expect(json['metric'], 'sum');
      expect(json['subject'], 'spending');
      expect(json['filters']['merchant'], 'Swiggy');
      expect(json['filters']['period'], 'lastMonth');
      expect(json['groupBy'], 'merchant');

      final parsed = FinanceQuery.fromJson(json);
      expect(parsed.metric, QueryMetric.sum);
      expect(parsed.subject, QuerySubject.spending);
      expect(parsed.filters.merchant, 'Swiggy');
      expect(parsed.filters.category, 'Food');
      expect(parsed.filters.period, QueryPeriod.lastMonth);
      expect(parsed.filters.amountMin, 200.0);
      expect(parsed.groupBy, QueryGroupBy.merchant);
      expect(parsed.compareTo, QueryPeriod.thisMonth);
      expect(parsed.topN, 3);
    });

    test('Parses query from sample LLM JSON response', () {
      final sampleLlmJson = {
        'metric': 'top',
        'subject': 'spending',
        'groupBy': 'merchant',
        'topN': 5,
        'filters': {
          'period': 'thisMonth',
        }
      };

      final query = FinanceQuery.fromJson(sampleLlmJson);
      expect(query.metric, QueryMetric.top);
      expect(query.groupBy, QueryGroupBy.merchant);
      expect(query.topN, 5);
      expect(query.filters.period, QueryPeriod.thisMonth);
    });
  });

  group('Phase 11: Deterministic Query Executor', () {
    final now = DateTime(2026, 3, 15, 12, 0); // March 2026

    final accounts = [
      Account(
        id: 'acc_hdfc',
        name: 'HDFC Bank',
        kind: 'bank',
        openingBalance: 25000.0,
        openingDate: DateTime(2026, 1, 1),
        includeInNetWorth: true,
        spendable: true,
      ),
      Account(
        id: 'acc_icici',
        name: 'ICICI Savings',
        kind: 'bank',
        openingBalance: 15000.0,
        openingDate: DateTime(2026, 1, 1),
        includeInNetWorth: true,
        spendable: true,
      ),
      Account(
        id: 'acc_card',
        name: 'Amazon ICICI Card',
        kind: 'credit_card',
        openingBalance: 0.0,
        openingDate: DateTime(2026, 1, 1),
        includeInNetWorth: true,
        spendable: false,
      ),
    ];

    final categories = [
      Category(id: 'cat_food', name: 'Food & Dining', kind: 'expense'),
      Category(id: 'cat_shop', name: 'Shopping', kind: 'expense'),
      Category(id: 'cat_salary', name: 'Salary', kind: 'income'),
    ];

    final transactions = [
      // February 2026 (last month)
      Transaction(
        id: 'tx_feb_1',
        title: 'Swiggy Dinner',
        merchant: 'Swiggy',
        amount: -450.0,
        kind: 'expense',
        categoryId: 'cat_food',
        accountId: 'acc_hdfc',
        date: DateTime(2026, 2, 10),
      ),
      Transaction(
        id: 'tx_feb_2',
        title: 'Swiggy Lunch',
        merchant: 'Swiggy',
        amount: -350.0,
        kind: 'expense',
        categoryId: 'cat_food',
        accountId: 'acc_hdfc',
        date: DateTime(2026, 2, 18),
      ),
      Transaction(
        id: 'tx_feb_3',
        title: 'Zomato Pizza',
        merchant: 'Zomato',
        amount: -800.0,
        kind: 'expense',
        categoryId: 'cat_food',
        accountId: 'acc_hdfc',
        date: DateTime(2026, 2, 22),
      ),
      Transaction(
        id: 'tx_feb_refund',
        title: 'Swiggy Cancellation Refund',
        merchant: 'Swiggy',
        amount: 100.0,
        kind: 'refund',
        categoryId: 'cat_food',
        accountId: 'acc_hdfc',
        date: DateTime(2026, 2, 25),
      ),

      // March 2026 (this month)
      Transaction(
        id: 'tx_mar_1',
        title: 'Salary Deposit',
        amount: 60000.0,
        kind: 'income',
        categoryId: 'cat_salary',
        accountId: 'acc_hdfc',
        date: DateTime(2026, 3, 1),
      ),
      Transaction(
        id: 'tx_mar_2',
        title: 'Amazon Monitor',
        merchant: 'Amazon',
        amount: -12000.0,
        kind: 'expense',
        categoryId: 'cat_shop',
        accountId: 'acc_card',
        date: DateTime(2026, 3, 5),
      ),
      Transaction(
        id: 'tx_mar_3',
        title: 'Transfer to Savings',
        amount: 10000.0,
        kind: 'transfer',
        accountId: 'acc_hdfc',
        toAccountId: 'acc_icici',
        date: DateTime(2026, 3, 7),
      ),
      Transaction(
        id: 'tx_mar_4',
        title: 'Swiggy Snack',
        merchant: 'Swiggy',
        amount: -250.0,
        kind: 'expense',
        categoryId: 'cat_food',
        accountId: 'acc_hdfc',
        date: DateTime(2026, 3, 12),
      ),
    ];

    test('"spent on Swiggy last month" excludes other merchants and subtracts refund (I3)', () {
      const query = FinanceQuery(
        metric: QueryMetric.sum,
        subject: QuerySubject.spending,
        filters: QueryFilters(
          merchant: 'Swiggy',
          period: QueryPeriod.lastMonth,
        ),
      );

      final result = FinanceQueryExecutor.execute(
        query: query,
        transactions: transactions,
        accounts: accounts,
        today: now,
        categories: categories,
      );

      // Feb Swiggy: 450 + 350 - 100 refund = 700.0
      expect(result.value, 700.0);
      expect(result.count, 3);
      expect(result.formattedAnswer, contains('₹700.00 at Swiggy'));
    });

    test('"expenses above ₹2,000 this year" excludes transfers and small expenses', () {
      const query = FinanceQuery(
        metric: QueryMetric.sum,
        subject: QuerySubject.spending,
        filters: QueryFilters(
          amountMin: 2000.0,
          period: QueryPeriod.thisYear,
        ),
      );

      final result = FinanceQueryExecutor.execute(
        query: query,
        transactions: transactions,
        accounts: accounts,
        today: now,
        categories: categories,
      );

      // Only Amazon Monitor (₹12,000). Transfer of ₹10,000 is excluded per I3!
      expect(result.value, 12000.0);
      expect(result.count, 1);
    });

    test('"top merchants" groups and ranks spending descending', () {
      const query = FinanceQuery(
        metric: QueryMetric.top,
        subject: QuerySubject.spending,
        groupBy: QueryGroupBy.merchant,
        topN: 3,
        filters: QueryFilters(
          period: QueryPeriod.thisYear,
        ),
      );

      final result = FinanceQueryExecutor.execute(
        query: query,
        transactions: transactions,
        accounts: accounts,
        today: now,
        categories: categories,
      );

      expect(result.groups.keys.first, 'Amazon');
      expect(result.groups['Amazon'], 12000.0);
    });

    test('Net worth query calculates assets minus liabilities (I2)', () {
      const query = FinanceQuery(subject: QuerySubject.networth);

      final result = FinanceQueryExecutor.execute(
        query: query,
        transactions: transactions,
        accounts: accounts,
        today: now,
      );

      // Opening: HDFC 25k, ICICI 15k, Card 0
      // Feb: HDFC: -450 -350 -800 +100 = -1500
      // Mar: HDFC: +60000 -10000(transfer) -250 = +49750
      // Mar: ICICI: +10000(transfer)
      // Mar: Card: -12000 liability
      // Total assets: 25k - 1.5k + 49.75k + 15k + 10k = 98,250
      // Liabilities: 12,000
      // Net worth: 98,250 - 12,000 = 86,250
      expect(result.value, 86250.0);
      expect(result.formattedAnswer, contains('₹86250.00'));
    });
  });

  group('Phase 11: Privacy & Action Confirmation Invariants', () {
    test('AiAction requires confirmation by default before execution', () {
      final action = AiAction(
        type: 'finance_transaction',
        payload: {'title': 'Dinner', 'amount': 350.0},
      );
      expect(action.isConfirmed, isFalse);
    });

    test('AiContext system prompt includes all extended finance action types', () {
      final prompt = AiContext.buildSystemPrompt();
      expect(prompt, contains('finance_transaction'));
      expect(prompt, contains('finance_transfer'));
      expect(prompt, contains('finance_budget'));
      expect(prompt, contains('finance_goal'));
      expect(prompt, contains('finance_recurring'));
      expect(prompt, contains('finance_whatif'));
      expect(prompt, contains('finance_query'));
    });

    test('What-If engine provides saving plan when deficit exists', () {
      final res = WhatIfEngine.canAfford(
        amount: 50000.0,
        forecastMonthEnd: 20000.0,
        emergencyBuffer: 15000.0,
        avgMonthlySurplus3m: 5000.0,
      );

      expect(res.status, AffordabilityStatus.notNow);
      expect(res.monthsToSave, isNotNull);
      expect(res.monthsToSave! > 0, isTrue);
    });
  });
}
