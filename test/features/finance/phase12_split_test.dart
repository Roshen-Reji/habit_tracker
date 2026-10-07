import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/engine/split_settle_engine.dart';
import 'package:habit_tracker/features/finance/models/split_entry.dart';
import 'package:habit_tracker/features/finance/models/split_group.dart';

void main() {
  group('Phase 12: SplitSettleEngine - Equal Splitting with Deterministic Paise Allocation', () {
    test('Splits ₹1,000 among 3 people with deterministic remainder paise', () {
      final shares = SplitSettleEngine.splitEqually(
        totalAmount: 1000.0,
        participants: ['Alice', 'Bob', 'Charlie'],
      );

      expect(shares.length, 3);
      // 1000 * 100 = 100000 paise. 100000 / 3 = 33333 paise each, with 1 remainder paise.
      // Alice gets 333.34, Bob gets 333.33, Charlie gets 333.33
      expect(shares['Alice'], 333.34);
      expect(shares['Bob'], 333.33);
      expect(shares['Charlie'], 333.33);

      final sum = shares.values.fold<double>(0.0, (acc, s) => acc + s);
      expect((sum * 100).round() / 100, 1000.0);
    });

    test('Splits ₹100 among 3 people gives 33.34, 33.33, 33.33', () {
      final shares = SplitSettleEngine.splitEqually(
        totalAmount: 100.0,
        participants: ['P1', 'P2', 'P3'],
      );

      expect(shares['P1'], 33.34);
      expect(shares['P2'], 33.33);
      expect(shares['P3'], 33.33);
      final sum = shares.values.fold<double>(0.0, (acc, s) => acc + s);
      expect((sum * 100).round() / 100, 100.0);
    });
  });

  group('Phase 12: Minimal-Transactions Settlement Algorithm', () {
    test('3-person simple example: A paid for all', () {
      // Alice paid ₹1,200 for lunch (shares: Alice 400, Bob 400, Charlie 400)
      // Net: Alice +800, Bob -400, Charlie -400
      const balances = [
        MemberBalance(member: 'Alice', totalPaid: 1200.0, totalShare: 400.0, net: 800.0),
        MemberBalance(member: 'Bob', totalPaid: 0.0, totalShare: 400.0, net: -400.0),
        MemberBalance(member: 'Charlie', totalPaid: 0.0, totalShare: 400.0, net: -400.0),
      ];

      final settlements = SplitSettleEngine.calculateSettlements(balances);

      expect(settlements.length, 2);
      expect(settlements.any((s) => s.from == 'Bob' && s.to == 'Alice' && s.amount == 400.0), isTrue);
      expect(settlements.any((s) => s.from == 'Charlie' && s.to == 'Alice' && s.amount == 400.0), isTrue);
    });

    test('4-person complex scenario minimizes number of transactions', () {
      // Total spent = 200 (each share = 50)
      // A paid 100 (net +50)
      // B paid 50 (net 0)
      // C paid 30 (net -20)
      // D paid 20 (net -30)
      const balances = [
        MemberBalance(member: 'A', totalPaid: 100.0, totalShare: 50.0, net: 50.0),
        MemberBalance(member: 'B', totalPaid: 50.0, totalShare: 50.0, net: 0.0),
        MemberBalance(member: 'C', totalPaid: 30.0, totalShare: 50.0, net: -20.0),
        MemberBalance(member: 'D', totalPaid: 20.0, totalShare: 50.0, net: -30.0),
      ];

      final settlements = SplitSettleEngine.calculateSettlements(balances);

      // Should settle in exactly 2 transactions: D pays A 30, C pays A 20. B is involved in 0!
      expect(settlements.length, 2);
      expect(settlements.any((s) => s.from == 'D' && s.to == 'A' && s.amount == 30.0), isTrue);
      expect(settlements.any((s) => s.from == 'C' && s.to == 'A' && s.amount == 20.0), isTrue);
    });
  });

  group('Phase 12: Trip Mode Report & Receivables Calculation', () {
    test('Generates group report with total spent, consumption, and settlements', () {
      final group = SplitGroup(
        id: 'grp_goa',
        name: 'Goa Trip',
        kind: 'trip',
        members: ['You', 'Rohan', 'Sneha'],
        createdAt: DateTime(2026, 3, 1),
      );

      final entries = [
        SplitEntry(
          id: 'e1',
          groupId: 'grp_goa',
          date: DateTime(2026, 3, 2),
          title: 'Resort Booking',
          amount: 15000.0,
          paidBy: 'You',
          shares: {'You': 5000.0, 'Rohan': 5000.0, 'Sneha': 5000.0},
        ),
        SplitEntry(
          id: 'e2',
          groupId: 'grp_goa',
          date: DateTime(2026, 3, 3),
          title: 'Dinner at Beach',
          amount: 3000.0,
          paidBy: 'Rohan',
          shares: {'You': 1000.0, 'Rohan': 1000.0, 'Sneha': 1000.0},
        ),
      ];

      final report = SplitSettleEngine.generateGroupReport(group, entries);

      expect(report.totalSpent, 18000.0);
      expect(report.perPersonPaid['You'], 15000.0);
      expect(report.perPersonPaid['Rohan'], 3000.0);
      expect(report.perPersonPaid['Sneha'], 0.0);

      expect(report.perPersonSpent['You'], 6000.0);
      expect(report.perPersonSpent['Rohan'], 6000.0);
      expect(report.perPersonSpent['Sneha'], 6000.0);

      // You: paid 15k, consumed 6k -> net +9,000
      // Rohan: paid 3k, consumed 6k -> net -3,000
      // Sneha: paid 0k, consumed 6k -> net -6,000
      expect(report.settlements.length, 2);
      expect(report.settlements.any((s) => s.from == 'Sneha' && s.to == 'You' && s.amount == 6000.0), isTrue);
      expect(report.settlements.any((s) => s.from == 'Rohan' && s.to == 'You' && s.amount == 3000.0), isTrue);
    });

    test('Extracts owed split lines from transaction JSON splits (P2-3 & I2)', () {
      final tx = Transaction(
        id: 'tx_dinner',
        title: 'Team Dinner',
        amount: -1200.0,
        kind: 'expense',
        date: DateTime(2026, 3, 10),
        splits: '[{"categoryId":"cat_food","amount":700.0,"note":"My meal"},{"categoryId":"cat_food","amount":300.0,"note":"Snacks"},{"amount":200.0,"isOwed":true,"counterparty":"Vikas"}]',
      );

      final owedEntries = SplitSettleEngine.extractOwedEntriesFromTransactions([tx]);
      expect(owedEntries.length, 1);
      expect(owedEntries.first.amount, 200.0);
      expect(owedEntries.first.shares['Vikas'], 200.0);

      final totalReceivables = SplitSettleEngine.calculateTotalReceivables(
        entries: [],
        transactions: [tx],
      );
      expect(totalReceivables, 200.0);
    });
  });
}
