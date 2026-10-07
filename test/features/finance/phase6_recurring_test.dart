import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/models/recurring_rule.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';

void main() {
  group('Phase 6 Recurring Engine Unit Tests', () {
    test('Month-end clamps: day 31 clamps to Feb 28 and Apr 30', () {
      final rule = RecurringRule(
        id: 'rec_rent',
        name: 'Apartment Rent',
        kind: 'bill',
        amount: 30000.0,
        frequency: 'monthly',
        dayOfMonth: 31,
        startDate: DateTime(2025, 1, 31),
        createdAt: DateTime(2025, 1, 1),
      );

      final occ = RecurringEngine.occurrences(
        rule,
        DateTime(2025, 1, 1),
        DateTime(2025, 5, 1),
      );

      // Jan 31, Feb 28, Mar 31, Apr 30
      expect(occ.length, equals(4));
      expect(occ[0], equals(DateTime(2025, 1, 31)));
      expect(occ[1], equals(DateTime(2025, 2, 28))); // Clamped to 28
      expect(occ[2], equals(DateTime(2025, 3, 31)));
      expect(occ[3], equals(DateTime(2025, 4, 30))); // Clamped to 30
    });

    test('Leap year: Feb 29 clamps to Feb 28 in non-leap year', () {
      final rule = RecurringRule(
        id: 'rec_anniversary',
        name: 'Leap Club Membership',
        kind: 'subscription',
        amount: 5000.0,
        frequency: 'yearly',
        startDate: DateTime(2024, 2, 29), // 2024 is a leap year
        createdAt: DateTime(2024, 1, 1),
      );

      final occ = RecurringEngine.occurrences(
        rule,
        DateTime(2024, 1, 1),
        DateTime(2026, 12, 31),
      );

      // 2024-02-29, 2025-02-28 (non-leap), 2026-02-28 (non-leap)
      expect(occ.length, equals(3));
      expect(occ[0], equals(DateTime(2024, 2, 29)));
      expect(occ[1], equals(DateTime(2025, 2, 28)));
      expect(occ[2], equals(DateTime(2026, 2, 28)));
    });

    test('Three-month gap catchup: all missed occurrences generated', () {
      final rule = RecurringRule(
        id: 'rec_broadband',
        name: 'Broadband',
        kind: 'bill',
        amount: 999.0,
        frequency: 'monthly',
        dayOfMonth: 10,
        startDate: DateTime(2026, 1, 10),
        createdAt: DateTime(2026, 1, 1),
      );

      // Evaluated on April 15, 2026 (app was not opened since January)
      final occ = RecurringEngine.occurrences(
        rule,
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 15),
      );

      // Jan 10, Feb 10, Mar 10, Apr 10
      expect(occ.length, equals(4));
      expect(occ.map((d) => d.month).toList(), equals([1, 2, 3, 4]));
    });

    test('December rollover across year boundary', () {
      final rule = RecurringRule(
        id: 'rec_sub',
        name: 'Streaming',
        kind: 'subscription',
        amount: 499.0,
        frequency: 'monthly',
        dayOfMonth: 15,
        startDate: DateTime(2026, 11, 15),
        createdAt: DateTime(2026, 11, 1),
      );

      final occ = RecurringEngine.occurrences(
        rule,
        DateTime(2026, 11, 1),
        DateTime(2027, 2, 1),
      );

      // Nov 15 2026, Dec 15 2026, Jan 15 2027
      expect(occ.length, equals(3));
      expect(occ[0], equals(DateTime(2026, 11, 15)));
      expect(occ[1], equals(DateTime(2026, 12, 15)));
      expect(occ[2], equals(DateTime(2027, 1, 15)));
    });

    test('Paused and ended rules return no occurrences', () {
      final pausedRule = RecurringRule(
        id: 'rec_gym',
        name: 'Gym',
        kind: 'subscription',
        amount: 2000.0,
        frequency: 'monthly',
        startDate: DateTime(2026, 1, 1),
        status: 'paused',
        createdAt: DateTime(2026, 1, 1),
      );

      final occ = RecurringEngine.occurrences(
        pausedRule,
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 1),
      );
      expect(occ, isEmpty);
    });

    test('Variable amount estimates from average of last 3 posted transactions', () {
      final rule = RecurringRule(
        id: 'rec_elec',
        name: 'Electricity',
        kind: 'bill',
        amount: 1500.0,
        amountIsVariable: true,
        frequency: 'monthly',
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final txs = [
        // Jan: 1800
        Transaction(
          id: 'tx_1',
          title: 'Electricity',
          amount: -1800.0,
          category: 'Utilities',
          date: DateTime(2026, 1, 5),
          mode: 'expense',
          icon: 'zap',
          kind: 'expense',
          recurringRuleId: 'rec_elec',
        ),
        // Feb: 2200
        Transaction(
          id: 'tx_2',
          title: 'Electricity',
          amount: -2200.0,
          category: 'Utilities',
          date: DateTime(2026, 2, 5),
          mode: 'expense',
          icon: 'zap',
          kind: 'expense',
          recurringRuleId: 'rec_elec',
        ),
        // Mar: 2600
        Transaction(
          id: 'tx_3',
          title: 'Electricity',
          amount: -2600.0,
          category: 'Utilities',
          date: DateTime(2026, 3, 5),
          mode: 'expense',
          icon: 'zap',
          kind: 'expense',
          recurringRuleId: 'rec_elec',
        ),
      ];

      // Average of 1800, 2200, 2600 = 2200.0
      final est = RecurringEngine.estimateAmount(rule, txs);
      expect(est, equals(2200.0));
    });

    test('Subscription detection: 4 monthly 649 charges -> detected', () {
      final txs = [
        Transaction(
          id: 'tx_n1',
          title: 'Netflix Subscription',
          merchant: 'Netflix.com',
          amount: -649.0,
          category: 'Entertainment',
          date: DateTime(2026, 1, 15),
          mode: 'expense',
          icon: 'tv',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_n2',
          title: 'Netflix Subscription',
          merchant: 'Netflix.com',
          amount: -649.0,
          category: 'Entertainment',
          date: DateTime(2026, 2, 14), // 30 days
          mode: 'expense',
          icon: 'tv',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_n3',
          title: 'Netflix Subscription',
          merchant: 'Netflix.com',
          amount: -649.0,
          category: 'Entertainment',
          date: DateTime(2026, 3, 16), // 30 days
          mode: 'expense',
          icon: 'tv',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_n4',
          title: 'Netflix Subscription',
          merchant: 'Netflix.com',
          amount: -649.0,
          category: 'Entertainment',
          date: DateTime(2026, 4, 15), // 30 days
          mode: 'expense',
          icon: 'tv',
          kind: 'expense',
        ),
      ];

      final detected = RecurringEngine.detectSubscriptions(
        transactions: txs,
        currentDate: DateTime(2026, 4, 20),
      );

      expect(detected.length, equals(1));
      expect(detected.first.normalizedMerchant, equals('netflix'));
      expect(detected.first.latestAmount, equals(649.0));
      expect(detected.first.frequency, equals('monthly'));
      expect(detected.first.hasPriceChange, isFalse);
    });

    test('Subscription detection: 649, 649, 799 -> price-change flag', () {
      final txs = [
        Transaction(
          id: 'tx_s1',
          title: 'Spotify',
          merchant: 'Spotify India',
          amount: -649.0,
          category: 'Entertainment',
          date: DateTime(2026, 1, 10),
          mode: 'expense',
          icon: 'music',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_s2',
          title: 'Spotify',
          merchant: 'Spotify India',
          amount: -649.0,
          category: 'Entertainment',
          date: DateTime(2026, 2, 9),
          mode: 'expense',
          icon: 'music',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_s3',
          title: 'Spotify',
          merchant: 'Spotify India',
          amount: -799.0, // price increase
          category: 'Entertainment',
          date: DateTime(2026, 3, 11),
          mode: 'expense',
          icon: 'music',
          kind: 'expense',
        ),
      ];

      final detected = RecurringEngine.detectSubscriptions(
        transactions: txs,
        currentDate: DateTime(2026, 3, 20),
      );

      expect(detected.length, equals(1));
      expect(detected.first.hasPriceChange, isTrue);
      expect(detected.first.previousAmount, equals(649.0));
      expect(detected.first.latestAmount, equals(799.0));
    });

    test('Subscription detection: irregular amounts are NOT detected', () {
      final txs = [
        Transaction(
          id: 'tx_i1',
          title: 'Amazon Shopping',
          merchant: 'Amazon',
          amount: -500.0,
          category: 'Shopping',
          date: DateTime(2026, 1, 5),
          mode: 'expense',
          icon: 'shopping-bag',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_i2',
          title: 'Amazon Shopping',
          merchant: 'Amazon',
          amount: -2500.0,
          category: 'Shopping',
          date: DateTime(2026, 2, 4),
          mode: 'expense',
          icon: 'shopping-bag',
          kind: 'expense',
        ),
        Transaction(
          id: 'tx_i3',
          title: 'Amazon Shopping',
          merchant: 'Amazon',
          amount: -350.0,
          category: 'Shopping',
          date: DateTime(2026, 3, 5),
          mode: 'expense',
          icon: 'shopping-bag',
          kind: 'expense',
        ),
      ];

      final detected = RecurringEngine.detectSubscriptions(
        transactions: txs,
        currentDate: DateTime(2026, 3, 20),
      );

      expect(detected, isEmpty);
    });
  });
}
