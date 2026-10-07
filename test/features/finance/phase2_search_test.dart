import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/engine/search_parser.dart';

void main() {
  group('Phase 2 SearchParser Unit Tests', () {
    test('parses numeric operators: >, <, >=, <=, =', () {
      final q1 = SearchParser.parse('>2000');
      expect(q1.minAmount, greaterThanOrEqualTo(2000.0));
      expect(q1.maxAmount, isNull);

      final q2 = SearchParser.parse('<500');
      expect(q2.maxAmount, lessThanOrEqualTo(500.0));
      expect(q2.minAmount, isNull);

      final q3 = SearchParser.parse('>=1000 <=5000');
      expect(q3.minAmount, equals(1000.0));
      expect(q3.maxAmount, equals(5000.0));

      final q4 = SearchParser.parse('=750');
      expect(q4.exactAmount, equals(750.0));
    });

    test('parses field operators: merchant, cat, tag, acct, month, year, kind', () {
      final q = SearchParser.parse('merchant:swiggy cat:food tag:dinner acct:hdfc month:sep year:2026 kind:expense');
      expect(q.merchant, equals('swiggy'));
      expect(q.category, equals('food'));
      expect(q.tag, equals('dinner'));
      expect(q.account, equals('hdfc'));
      expect(q.month, equals(9));
      expect(q.year, equals(2026));
      expect(q.kind, equals('expense'));
    });

    test('parses free text and numeric ±10% token', () {
      final q = SearchParser.parse('dinner 500');
      expect(q.freeTextTokens, containsAll(['dinner', '500']));
    });

    test('matches transactions with operators and free text', () {
      final tx1 = Transaction(
        id: 'tx_1',
        title: 'Swiggy Dinner',
        amount: -520.0,
        category: 'Food',
        date: DateTime(2026, 9, 15),
        mode: 'expense',
        icon: 'tag',
        kind: 'expense',
        merchant: 'Swiggy',
        tags: ['dinner', 'weekend'],
        accountId: 'acc_hdfc',
      );

      final tx2 = Transaction(
        id: 'tx_2',
        title: 'Amazon Gadgets',
        amount: -3500.0,
        category: 'Shopping',
        date: DateTime(2026, 10, 1),
        mode: 'expense',
        icon: 'tag',
        kind: 'expense',
        merchant: 'Amazon',
        tags: ['tech'],
        accountId: 'acc_icici',
      );

      final List<Transaction> txList = [tx1, tx2];

      // Test 1: >2000
      final res1 = SearchParser.filter(
        transactions: txList,
        query: SearchParser.parse('>2000'),
      );
      expect(res1.length, equals(1));
      expect(res1.first.id, equals('tx_2'));

      // Test 2: month:sep
      final res2 = SearchParser.filter(
        transactions: txList,
        query: SearchParser.parse('month:sep'),
      );
      expect(res2.length, equals(1));
      expect(res2.first.id, equals('tx_1'));

      // Test 3: numeric free text 500 (matches 450 to 550) -> tx1 is 520
      final res3 = SearchParser.filter(
        transactions: txList,
        query: SearchParser.parse('500'),
      );
      expect(res3.length, equals(1));
      expect(res3.first.id, equals('tx_1'));

      // Test 4: combined query: swiggy cat:food
      final res4 = SearchParser.filter(
        transactions: txList,
        query: SearchParser.parse('swiggy cat:food'),
      );
      expect(res4.length, equals(1));
      expect(res4.first.id, equals('tx_1'));
    });

    test('20,000 transactions search performance executes under 100 ms', () {
      final bigList = <Transaction>[];
      final categories = <String, Category>{
        'cat_food': Category(id: 'cat_food', name: 'Food', kind: 'expense', group: 'needs', iconKey: 'tag', colorValue: 0xFF22C55E),
        'cat_shop': Category(id: 'cat_shop', name: 'Shopping', kind: 'expense', group: 'wants', iconKey: 'tag', colorValue: 0xFF3B82F6),
      };
      final accounts = <String, Account>{
        'acc_hdfc': Account(id: 'acc_hdfc', name: 'HDFC Bank', kind: 'bank', openingBalance: 1000.0, openingDate: DateTime(2026, 1, 1), colorValue: 0xFF22C55E),
      };

      for (var i = 0; i < 20000; i++) {
        bigList.add(Transaction(
          id: 'tx_$i',
          title: (i % 2 == 0) ? 'Swiggy Meal' : 'Amazon Order',
          amount: (i % 2 == 0) ? -450.0 : -2500.0,
          category: (i % 2 == 0) ? 'Food' : 'Shopping',
          categoryId: (i % 2 == 0) ? 'cat_food' : 'cat_shop',
          date: DateTime(2026, (i % 12) + 1, (i % 28) + 1),
          mode: 'expense',
          icon: 'tag',
          kind: 'expense',
          merchant: (i % 2 == 0) ? 'Swiggy' : 'Amazon',
          accountId: 'acc_hdfc',
        ));
      }

      final query = SearchParser.parse('swiggy >400 cat:food month:sep');
      // Warm up JIT
      SearchParser.filter(
        transactions: bigList.sublist(0, 100),
        query: query,
        categories: categories,
        accounts: accounts,
      );

      final stopwatch = Stopwatch()..start();

      final results = SearchParser.filter(
        transactions: bigList,
        query: query,
        categories: categories,
        accounts: accounts,
      );

      stopwatch.stop();

      expect(results.isNotEmpty, isTrue);
      // Under 100 ms requirement from P2-5 spec!
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
