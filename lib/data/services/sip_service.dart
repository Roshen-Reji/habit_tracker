import 'dart:math' as math;
import 'package:hive/hive.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/data/services/notification_service.dart';

class SipService {
  /// One-time idempotent migration:
  /// Gives every existing SIP a stable `id` and `createdAt = now` (if missing),
  /// ensuring existing SIPs are never back-charged.
  static void migrateSips({Box? settingsBox, DateTime? now}) {
    final box = settingsBox ?? Hive.box('finance_settings');
    final clock = now ?? DateTime.now();

    final planner = Map<String, dynamic>.from(box.get(
      'planner',
      defaultValue: {'fixedExpenses': [], 'sips': []},
    ));
    final rawSips = List.from(planner['sips'] ?? []);
    bool modified = false;

    for (int i = 0; i < rawSips.length; i++) {
      final sip = Map<String, dynamic>.from(rawSips[i] as Map);
      if (sip['id'] == null || sip['id'].toString().isEmpty) {
        sip['id'] = 'sip_${clock.millisecondsSinceEpoch}_$i';
        modified = true;
      }
      if (sip['createdAt'] == null) {
        sip['createdAt'] = clock.toIso8601String();
        modified = true;
      }
      rawSips[i] = sip;
    }

    if (modified) {
      planner['sips'] = rawSips;
      box.put('planner', planner);
    }
  }

  /// Executes due SIP debits:
  /// For each calendar month from the later of `createdAt`'s month and the month
  /// after `sip_ledger[id]`, through the current month:
  /// Computes `dueDate = DateTime(y, m, min(due, daysInMonth))`.
  /// Posts an expense `Transaction` when `dueDate >= createdAt` and `dueDate <= now`.
  /// Uses deterministic key `sip_{id}_{yyyy-MM}` with `box.put` to ensure idempotency.
  /// Updates `finance_settings['sip_ledger'] = {id: 'yyyy-MM'}`.
  /// Returns the number of debits posted.
  static Future<int> runDue({
    DateTime? now,
    Box? financeSettingsBox,
    Box<Transaction>? txBox,
  }) async {
    final settingsBox = financeSettingsBox ?? Hive.box('finance_settings');
    final transactionsBox =
        txBox ?? Hive.box<Transaction>('finance_transactions');
    final clock = now ?? DateTime.now();

    migrateSips(settingsBox: settingsBox, now: clock);

    final planner = Map<String, dynamic>.from(settingsBox.get(
      'planner',
      defaultValue: {'fixedExpenses': [], 'sips': []},
    ));
    final sips = List.from(planner['sips'] ?? []);
    final ledger = Map<String, dynamic>.from(
        settingsBox.get('sip_ledger', defaultValue: {}));

    int postedCount = 0;

    for (final rawSip in sips) {
      final sip = Map<String, dynamic>.from(rawSip as Map);
      final id = sip['id']?.toString();
      if (id == null || id.isEmpty) continue;

      final name = sip['name']?.toString() ?? 'SIP';
      final amount = (sip['amount'] is num)
          ? (sip['amount'] as num).toDouble()
          : double.tryParse(sip['amount']?.toString() ?? '0') ?? 0.0;
      final due = (sip['due'] is int)
          ? sip['due'] as int
          : int.tryParse(sip['due']?.toString() ?? '5') ?? 5;

      final createdAtStr = sip['createdAt']?.toString();
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? clock
          : clock;

      // Determine starting year/month
      final lastPostedMonthStr = ledger[id]?.toString();
      int startYear;
      int startMonth;

      if (lastPostedMonthStr != null && lastPostedMonthStr.contains('-')) {
        final parts = lastPostedMonthStr.split('-');
        final lastYear = int.parse(parts[0]);
        final lastMonth = int.parse(parts[1]);
        if (lastMonth == 12) {
          startYear = lastYear + 1;
          startMonth = 1;
        } else {
          startYear = lastYear;
          startMonth = lastMonth + 1;
        }
      } else {
        startYear = createdAt.year;
        startMonth = createdAt.month;
      }

      var currentIter = DateTime(startYear, startMonth, 1);
      final targetEnd = DateTime(clock.year, clock.month, 1);

      while (!currentIter.isAfter(targetEnd)) {
        final y = currentIter.year;
        final m = currentIter.month;
        final daysInMonth = DateTime(y, m + 1, 0).day;
        final actualDueDay = math.min(due, daysInMonth);
        final dueDate = DateTime(y, m, actualDueDay);

        final monthKey = '$y-${m.toString().padLeft(2, '0')}';

        // Check if dueDate is on or after createdAt (date only)
        // AND dueDate is on or before now (date only)
        final isAfterOrSameCreatedAt = _isDateSameOrAfter(dueDate, createdAt);
        final isBeforeOrSameNow = _isDateSameOrBefore(dueDate, clock);

        if (isAfterOrSameCreatedAt && isBeforeOrSameNow) {
          final txKey = 'sip_${id}_$monthKey';

          if (!transactionsBox.containsKey(txKey)) {
            final tx = Transaction(
              title: 'SIP · $name',
              amount: -amount.abs(),
              category: 'Investment',
              date: dueDate,
              mode: 'expense',
              icon: 'expense',
            );

            await transactionsBox.put(txKey, tx);
            postedCount++;

            try {
              NotificationService().showInstantNotification(
                id: txKey.hashCode,
                title: 'SIP Debited: $name',
                body:
                    '₹${amount.toStringAsFixed(0)} debited for $monthKey on ${dueDate.day}/${dueDate.month}.',
              );
            } catch (_) {}
          }

          ledger[id] = monthKey;
          await settingsBox.put('sip_ledger', ledger);
        }

        // Advance to next month
        currentIter = (m == 12) ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
      }
    }

    return postedCount;
  }

  /// Calculates the next debit date for a given SIP
  static DateTime getNextDebitDate(Map sip, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final due = (sip['due'] is int)
        ? sip['due'] as int
        : int.tryParse(sip['due']?.toString() ?? '5') ?? 5;

    final createdAtStr = sip['createdAt']?.toString();
    final createdAt =
        createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? clock : clock;

    // Check this month
    final daysThisMonth = DateTime(clock.year, clock.month + 1, 0).day;
    final thisMonthDue =
        DateTime(clock.year, clock.month, math.min(due, daysThisMonth));

    if (_isDateSameOrAfter(thisMonthDue, clock) &&
        _isDateSameOrAfter(thisMonthDue, createdAt)) {
      return thisMonthDue;
    }

    // Next month
    final nextYear = clock.month == 12 ? clock.year + 1 : clock.year;
    final nextMonth = clock.month == 12 ? 1 : clock.month + 1;
    final daysNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    return DateTime(nextYear, nextMonth, math.min(due, daysNextMonth));
  }

  /// Checks if an SIP has already posted its debit for the given month
  static bool isPostedForMonth(
      String sipId, String yearMonth, Box settingsBox) {
    final ledger = Map<String, dynamic>.from(
        settingsBox.get('sip_ledger', defaultValue: {}));
    final lastPosted = ledger[sipId]?.toString();
    if (lastPosted == null) return false;
    return lastPosted.compareTo(yearMonth) >= 0;
  }

  static bool _isDateSameOrAfter(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return !aDate.isBefore(bDate);
  }

  static bool _isDateSameOrBefore(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return !aDate.isAfter(bDate);
  }
}
