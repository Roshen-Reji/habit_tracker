import 'dart:convert';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/split_entry.dart';
import 'package:habit_tracker/features/finance/models/split_group.dart';
import 'package:habit_tracker/models/finance_model.dart';

class MemberBalance {
  final String member;
  final double totalPaid;
  final double totalShare;
  final double
      net; // totalPaid - totalShare. > 0 means owed money, < 0 means owes money.

  const MemberBalance({
    required this.member,
    required this.totalPaid,
    required this.totalShare,
    required this.net,
  });
}

class SettlementTransfer {
  final String from;
  final String to;
  final double amount;

  const SettlementTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'amount': amount,
      };
}

class GroupReport {
  final String groupId;
  final String groupName;
  final double totalSpent;
  final Map<String, double> perPersonSpent; // what they consumed
  final Map<String, double> perPersonPaid; // what they paid at checkout
  final List<MemberBalance> balances;
  final List<SettlementTransfer> settlements;

  const GroupReport({
    required this.groupId,
    required this.groupName,
    required this.totalSpent,
    required this.perPersonSpent,
    required this.perPersonPaid,
    required this.balances,
    required this.settlements,
  });
}

class SplitSettleEngine {
  /// Calculates member balances across all unsettled entries in a group.
  static List<MemberBalance> calculateBalances({
    required List<String> members,
    required List<SplitEntry> entries,
    bool includeSettled = false,
  }) {
    final paidMap = <String, double>{for (var m in members) m: 0.0};
    final shareMap = <String, double>{for (var m in members) m: 0.0};

    final activeEntries =
        includeSettled ? entries : entries.where((e) => !e.settled);

    for (final e in activeEntries) {
      final payer = e.paidBy;
      paidMap[payer] = Money.r2((paidMap[payer] ?? 0.0) + e.amount);

      for (final entry in e.shares.entries) {
        final member = entry.key;
        shareMap[member] = Money.r2((shareMap[member] ?? 0.0) + entry.value);
      }
    }

    return members.map((m) {
      final paid = paidMap[m] ?? 0.0;
      final share = shareMap[m] ?? 0.0;
      final net = Money.r2(paid - share);
      return MemberBalance(
        member: m,
        totalPaid: paid,
        totalShare: share,
        net: net,
      );
    }).toList();
  }

  /// Minimal-transactions settlement algorithm.
  /// Finds the minimal sequence of payments to settle all debts.
  /// Uses a greedy matching of largest debtor to largest creditor.
  /// Rounds to paise (2 decimal places) and assigns any rounding remainder deterministically.
  static List<SettlementTransfer> calculateSettlements(
      List<MemberBalance> balances) {
    // Separate into debtors (net < 0) and creditors (net > 0)
    final debtors = <_MutableBalance>[];
    final creditors = <_MutableBalance>[];

    for (final b in balances) {
      final net = Money.r2(b.net);
      if (net < -0.005) {
        debtors.add(_MutableBalance(b.member, -net)); // positive debt amount
      } else if (net > 0.005) {
        creditors.add(_MutableBalance(b.member, net)); // positive credit amount
      }
    }

    final settlements = <SettlementTransfer>[];

    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      // Sort to pick largest debtor and largest creditor
      debtors.sort((a, b) => b.amount.compareTo(a.amount));
      creditors.sort((a, b) => b.amount.compareTo(a.amount));

      final debtor = debtors.first;
      final creditor = creditors.first;

      final transferAmount = Money.r2(
          debtor.amount < creditor.amount ? debtor.amount : creditor.amount);

      if (transferAmount > 0.005) {
        settlements.add(SettlementTransfer(
          from: debtor.member,
          to: creditor.member,
          amount: transferAmount,
        ));
      }

      debtor.amount = Money.r2(debtor.amount - transferAmount);
      creditor.amount = Money.r2(creditor.amount - transferAmount);

      if (debtor.amount <= 0.005) {
        debtors.removeAt(0);
      }
      if (creditor.amount <= 0.005) {
        creditors.removeAt(0);
      }
    }

    return settlements;
  }

  /// Generates a comprehensive Trip / Group spend and settlement report.
  static GroupReport generateGroupReport(
      SplitGroup group, List<SplitEntry> entries) {
    double totalSpent = 0.0;
    final perPersonSpent = <String, double>{
      for (var m in group.members) m: 0.0
    };
    final perPersonPaid = <String, double>{for (var m in group.members) m: 0.0};

    for (final e in entries) {
      totalSpent = Money.r2(totalSpent + e.amount);
      perPersonPaid[e.paidBy] =
          Money.r2((perPersonPaid[e.paidBy] ?? 0.0) + e.amount);

      for (final share in e.shares.entries) {
        perPersonSpent[share.key] =
            Money.r2((perPersonSpent[share.key] ?? 0.0) + share.value);
      }
    }

    final balances = calculateBalances(
        members: group.members, entries: entries, includeSettled: false);
    final settlements = calculateSettlements(balances);

    return GroupReport(
      groupId: group.id,
      groupName: group.name,
      totalSpent: totalSpent,
      perPersonSpent: perPersonSpent,
      perPersonPaid: perPersonPaid,
      balances: balances,
      settlements: settlements,
    );
  }

  /// Deterministically divides an amount equally among participants,
  /// with remainder paise distributed one cent/paisa at a time to the first participants.
  static Map<String, double> splitEqually({
    required double totalAmount,
    required List<String> participants,
  }) {
    if (participants.isEmpty) return {};
    final totalPaise = (totalAmount * 100).round();
    final count = participants.length;
    final basePaise = totalPaise ~/ count;
    var remainder = totalPaise % count;

    final result = <String, double>{};
    for (var i = 0; i < count; i++) {
      var paise = basePaise;
      if (remainder > 0) {
        paise += 1;
        remainder--;
      }
      result[participants[i]] = paise / 100.0;
    }
    return result;
  }

  /// Extracts owed split lines from individual transactions (P2-3).
  /// Format: [{categoryId, amount, note, isOwed: true, counterparty: "Friend"}]
  static List<SplitEntry> extractOwedEntriesFromTransactions(
      List<Transaction> transactions) {
    final list = <SplitEntry>[];

    for (final tx in transactions) {
      if (tx.splits == null || tx.splits!.isEmpty) continue;

      try {
        final decoded = jsonDecode(tx.splits!);
        if (decoded is! List) continue;

        for (final item in decoded) {
          if (item is Map &&
              (item['isOwed'] == true || item['isOwed'] == 'true')) {
            final counterparty =
                (item['counterparty'] ?? 'Friend').toString().trim();
            final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
            if (amt <= 0) continue;

            final note = item['note']?.toString();
            final title = (note != null && note.isNotEmpty)
                ? note
                : (tx.title.isNotEmpty ? tx.title : 'Owed share');

            list.add(SplitEntry(
              id: 'owed_${tx.id ?? tx.key}_${counterparty.hashCode}',
              groupId: 'personal_owed',
              date: tx.date,
              title: title,
              amount: amt,
              paidBy: 'You',
              shares: {
                counterparty: amt,
              },
              txId: tx.id ?? tx.key.toString(),
              settled: false,
            ));
          }
        }
      } catch (_) {
        // Ignore unparseable splits
      }
    }

    return list;
  }

  /// Total unsettled receivables for user (You) per Invariant I2.
  static double calculateTotalReceivables({
    required List<SplitEntry> entries,
    required List<Transaction> transactions,
    String user = 'You',
  }) {
    double total = 0.0;

    // 1. From split entries where user paid
    for (final e in entries.where(
        (e) => !e.settled && e.paidBy.toLowerCase() == user.toLowerCase())) {
      for (final share in e.shares.entries) {
        if (share.key.toLowerCase() != user.toLowerCase()) {
          total = Money.r2(total + share.value);
        }
      }
    }

    // 2. From individual transaction owed split lines
    final txOwed = extractOwedEntriesFromTransactions(transactions);
    for (final e in txOwed) {
      total = Money.r2(total + e.amount);
    }

    return total;
  }

  /// Total unsettled payables where user owes others per Invariant I2.
  static double calculateTotalPayables({
    required List<SplitEntry> entries,
    String user = 'You',
  }) {
    double total = 0.0;

    for (final e in entries.where(
        (e) => !e.settled && e.paidBy.toLowerCase() != user.toLowerCase())) {
      final userShare = e.shares[user] ?? e.shares['You'] ?? 0.0;
      total = Money.r2(total + userShare);
    }

    return total;
  }
}

class _MutableBalance {
  final String member;
  double amount;
  _MutableBalance(this.member, this.amount);
}
