import 'dart:math';
import 'package:intl/intl.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class DueItem {
  final RecurringRule rule;
  final DateTime dueDate;
  final double estimatedAmount;
  final bool isVariable;

  const DueItem({
    required this.rule,
    required this.dueDate,
    required this.estimatedAmount,
    this.isVariable = false,
  });

  String get sourceRef => 'rec:${rule.id}:${DateFormat('yyyy-MM-dd').format(dueDate)}';
}

class DetectedSubscription {
  final String normalizedMerchant;
  final String rawMerchant;
  final double latestAmount;
  final double averageAmount;
  final int cycleDays; // 7, 14, 30, 91, 365
  final String frequency; // weekly, monthly, quarterly, yearly
  final bool isVariable;
  final bool hasPriceChange;
  final double? previousAmount;
  final bool isPossiblyCancelled;
  final int occurrenceCount;
  final List<Transaction> matchingTransactions;

  const DetectedSubscription({
    required this.normalizedMerchant,
    required this.rawMerchant,
    required this.latestAmount,
    required this.averageAmount,
    required this.cycleDays,
    required this.frequency,
    required this.isVariable,
    required this.hasPriceChange,
    this.previousAmount,
    required this.isPossiblyCancelled,
    required this.occurrenceCount,
    required this.matchingTransactions,
  });
}

class RecurringEngine {
  /// Computes all occurrence due dates for [rule] in the window `[from, to]`.
  static List<DateTime> occurrences(RecurringRule rule, DateTime from, DateTime to) {
    if (rule.status != 'active') return [];

    final list = <DateTime>[];
    final start = rule.startDate;
    final end = rule.endDate;

    final freq = rule.frequency.toLowerCase();
    final interval = rule.interval > 0 ? rule.interval : 1;

    DateTime cur = start;

    // Advance cur until it's on or after from, or evaluate from start
    while (true) {
      if (end != null && cur.isAfter(end)) break;

      if (!cur.isBefore(from) && !cur.isAfter(to)) {
        list.add(cur);
      }

      if (cur.isAfter(to)) break;

      // Advance to next cycle
      cur = _nextOccurrence(rule, cur, freq, interval);
      // Safety check against infinite loops
      if (cur.isBefore(start) || list.length > 500) break;
    }

    return list;
  }

  static DateTime _nextOccurrence(
    RecurringRule rule,
    DateTime current,
    String freq,
    int interval,
  ) {
    switch (freq) {
      case 'weekly':
        return current.add(Duration(days: 7 * interval));

      case 'monthly':
        final targetMonth = current.month + interval;
        final targetYear = current.year + ((targetMonth - 1) ~/ 12);
        final normalizedMonth = ((targetMonth - 1) % 12) + 1;

        final targetDay = rule.dayOfMonth ?? rule.anchorDate?.day ?? rule.startDate.day;
        final daysInTargetMonth = DateTime(targetYear, normalizedMonth + 1, 0).day;
        final clampedDay = min(targetDay, daysInTargetMonth);

        return DateTime(targetYear, normalizedMonth, clampedDay);

      case 'quarterly':
        final targetMonth = current.month + (3 * interval);
        final targetYear = current.year + ((targetMonth - 1) ~/ 12);
        final normalizedMonth = ((targetMonth - 1) % 12) + 1;

        final targetDay = rule.dayOfMonth ?? rule.anchorDate?.day ?? rule.startDate.day;
        final daysInTargetMonth = DateTime(targetYear, normalizedMonth + 1, 0).day;
        final clampedDay = min(targetDay, daysInTargetMonth);

        return DateTime(targetYear, normalizedMonth, clampedDay);

      case 'yearly':
        final targetYear = current.year + interval;
        final targetMonth = rule.startDate.month;
        final targetDay = rule.startDate.day;

        // Check leap year Feb 29 clamp
        final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        final clampedDay = min(targetDay, daysInTargetMonth);

        return DateTime(targetYear, targetMonth, clampedDay);

      default:
        // Default to monthly
        return DateTime(current.year, current.month + interval, current.day);
    }
  }

  /// Calculates the estimated amount for a recurring rule:
  /// if [amountIsVariable] is true, computes average of the last 3 posted transactions with this rule's id.
  static double estimateAmount(RecurringRule rule, Iterable<Transaction> transactions) {
    if (!rule.amountIsVariable) return rule.amount;

    final ruleTxs = transactions
        .where((tx) =>
            tx.recurringRuleId == rule.id ||
            (tx.sourceRef != null && tx.sourceRef!.startsWith('rec:${rule.id}:')))
        .toList();

    if (ruleTxs.isEmpty) return rule.amount;

    ruleTxs.sort((a, b) => b.date.compareTo(a.date));
    final recent = ruleTxs.take(3).toList();
    final sum = recent.fold<double>(0.0, (acc, tx) => acc + tx.amount.abs());
    return Money.r2(sum / recent.length);
  }

  /// Normalises merchant name for subscription detection:
  /// lowercase, strips digits, punctuation, UPI/gateway tokens, and web domains.
  static String normalizeMerchant(String? input) {
    if (input == null || input.trim().isEmpty) return '';

    String s = input.toLowerCase();

    // Strip web domains
    s = s.replaceAll(RegExp(r'\.(com|in|org|net|co|io|app)'), '');

    // Strip common payment prefixes / tokens
    s = s.replaceAll(RegExp(r'\b(upi|paytm|razorpay|billdesk|googlepay|gpay|phonepe)\b'), '');

    // Strip digits
    s = s.replaceAll(RegExp(r'[0-9]'), '');

    // Strip non-alphanumeric
    s = s.replaceAll(RegExp(r'[^a-z\s]'), ' ');

    // Normalize whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// P6-4: Detects subscriptions from transaction history per §5.4:
  /// Group by normalised merchant; require ≥3 occurrences with intervals within ±3 days of 7, 14, 30, 91, 365
  /// and amount variance ≤ 5% (≤ 15% flags variable).
  /// Flag price-change when the latest amount differs from the previous by > 5%;
  /// Flag 'possibly cancelled' when ≥2 expected cycles are missing.
  static List<DetectedSubscription> detectSubscriptions({
    required Iterable<Transaction> transactions,
    required DateTime currentDate,
    Set<String> dismissedSuggestions = const {},
  }) {
    // Only analyze expenses and refunds
    final expenses = transactions
        .where((tx) =>
            (tx.effectiveKind == 'expense' || tx.effectiveKind == 'subscription') &&
            tx.amount.abs() > 0)
        .toList();

    final grouped = <String, List<Transaction>>{};

    for (final tx in expenses) {
      final merchantRaw = tx.merchant ?? tx.title;
      final normalized = normalizeMerchant(merchantRaw);
      if (normalized.length < 3) continue;
      if (dismissedSuggestions.contains(normalized)) continue;

      grouped.putIfAbsent(normalized, () => []).add(tx);
    }

    final detected = <DetectedSubscription>[];

    for (final entry in grouped.entries) {
      final normMerchant = entry.key;
      final txList = entry.value;

      if (txList.length < 3) continue;

      // Sort chronological
      txList.sort((a, b) => a.date.compareTo(b.date));

      // Calculate intervals in days
      final intervals = <int>[];
      for (int i = 1; i < txList.length; i++) {
        final diff = txList[i].date.difference(txList[i - 1].date).inDays;
        intervals.add(diff);
      }

      if (intervals.isEmpty) continue;

      // Match target cycle
      const cycles = [7, 14, 30, 91, 365];
      int? matchedCycle;
      String freq = 'monthly';

      for (final cycle in cycles) {
        int matchingCount = 0;
        for (final diff in intervals) {
          if ((diff - cycle).abs() <= 3) {
            matchingCount++;
          }
        }
        // At least 60% of intervals match cycle ±3 days
        if (matchingCount >= (intervals.length * 0.6).ceil()) {
          matchedCycle = cycle;
          if (cycle == 7) freq = 'weekly';
          else if (cycle == 14) freq = 'weekly';
          else if (cycle == 30) freq = 'monthly';
          else if (cycle == 91) freq = 'quarterly';
          else if (cycle == 365) freq = 'yearly';
          break;
        }
      }

      if (matchedCycle == null) continue;

      // Calculate amounts and variance
      final amounts = txList.map((tx) => tx.amount.abs()).toList();
      final avgAmt = amounts.reduce((a, b) => a + b) / amounts.length;
      final latestAmt = amounts.last;
      final prevAmt = amounts.length >= 2 ? amounts[amounts.length - 2] : null;

      // Amount variance
      double maxDeviation = 0.0;
      for (final a in amounts) {
        final dev = (a - avgAmt).abs() / avgAmt;
        if (dev > maxDeviation) maxDeviation = dev;
      }

      // Max variance must be <= 15%
      if (maxDeviation > 0.15) continue;
      final isVariable = maxDeviation > 0.05;

      // Price change flag: latest differs from previous by > 5%
      bool hasPriceChange = false;
      if (prevAmt != null) {
        final changePct = ((latestAmt - prevAmt).abs() / prevAmt);
        if (changePct > 0.05) {
          hasPriceChange = true;
        }
      }

      // Possibly cancelled flag: >= 2 expected cycles missing
      final lastDate = txList.last.date;
      final daysSinceLast = currentDate.difference(lastDate).inDays;
      final isPossiblyCancelled = daysSinceLast >= (matchedCycle * 2.2);

      detected.add(DetectedSubscription(
        normalizedMerchant: normMerchant,
        rawMerchant: txList.last.merchant ?? txList.last.title,
        latestAmount: Money.r2(latestAmt),
        averageAmount: Money.r2(avgAmt),
        cycleDays: matchedCycle,
        frequency: freq,
        isVariable: isVariable,
        hasPriceChange: hasPriceChange,
        previousAmount: prevAmt != null ? Money.r2(prevAmt) : null,
        isPossiblyCancelled: isPossiblyCancelled,
        occurrenceCount: txList.length,
        matchingTransactions: txList,
      ));
    }

    return detected;
  }
}
