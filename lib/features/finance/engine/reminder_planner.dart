import 'package:intl/intl.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/recurring_rule.dart';

enum ReminderStyle {
  notification,
  alarm,
}

class PlannedReminder {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final ReminderStyle style;
  final String payload;

  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.style,
    required this.payload,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedReminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          when == other.when &&
          title == other.title &&
          body == other.body &&
          style == other.style &&
          payload == other.payload;

  @override
  int get hashCode =>
      id.hashCode ^
      when.hashCode ^
      title.hashCode ^
      body.hashCode ^
      style.hashCode ^
      payload.hashCode;

  @override
  String toString() =>
      'PlannedReminder(id: $id, when: $when, title: "$title", style: $style)';
}

class ReminderPlanner {
  static const int maxPendingReminders = 60;
  static const int horizonDays = 45;

  /// Pure Dart planning of finance reminders for the next 45 days.
  /// Caps result at [maxPendingReminders].
  static List<PlannedReminder> plan({
    required List<RecurringRule> rules,
    required List<Account> accounts,
    bool enabled = true,
    int timeMinutes = 540, // 09:00 default (9 * 60)
    int daysBefore = 1,
    String styleBill = 'both',
    String styleSub = 'notification',
    String styleSip = 'notification',
    String styleEmi = 'both',
    String styleCard = 'notification',
    DateTime? now,
  }) {
    if (!enabled) return const [];

    final clock = now ?? DateTime.now();
    final horizon = clock.add(const Duration(days: horizonDays));
    final accountMap = {for (final a in accounts) a.id: a};

    final hour = (timeMinutes ~/ 60).clamp(0, 23);
    final minute = (timeMinutes % 60).clamp(0, 59);

    final List<PlannedReminder> planned = [];

    String styleSettingForKind(String kind) {
      switch (kind.toLowerCase()) {
        case 'bill':
          return styleBill;
        case 'subscription':
          return styleSub;
        case 'sip':
          return styleSip;
        case 'emi':
          return styleEmi;
        default:
          return 'notification';
      }
    }

    // 1. Process active recurring rules
    for (final rule in rules) {
      if (rule.status != 'active') continue;
      final setting = styleSettingForKind(rule.kind);
      if (setting == 'off') continue;

      final occurrences = RecurringEngine.occurrences(rule, clock, horizon);
      final payingAcc = accountMap[rule.accountId];
      final targetAcc =
          rule.toAccountId != null ? accountMap[rule.toAccountId] : null;
      final payingName = payingAcc?.name ?? 'Main';

      for (final dueDate in occurrences) {
        final dateStr = DateFormat('yyyy-MM-dd').format(dueDate);
        final formattedAmt = FormatUtils.formatMoney(rule.amount);
        final formattedDate = DateFormat('d MMM').format(dueDate);

        String entityName;
        if (rule.kind.toLowerCase() == 'sip' && targetAcc != null) {
          entityName = targetAcc.name;
        } else if (rule.kind.toLowerCase() == 'emi' && targetAcc != null) {
          entityName = targetAcc.name;
        } else {
          entityName = rule.name;
        }

        final kindUpper = rule.kind.toUpperCase();
        final body =
            '$kindUpper $formattedAmt · $entityName · due $formattedDate, from $payingName';

        // Timing 1: Days before
        if (daysBefore > 0) {
          final reminderDate = dueDate.subtract(Duration(days: daysBefore));
          final whenBefore = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            hour,
            minute,
          );
          if (whenBefore.isAfter(clock)) {
            final id = reminderStableId(rule.id, dateStr, 'before');
            final style = (setting == 'alarm')
                ? ReminderStyle.alarm
                : ReminderStyle.notification;
            planned.add(PlannedReminder(
              id: id,
              when: whenBefore,
              title: 'Upcoming $kindUpper: $entityName',
              body: body,
              style: style,
              payload: 'rec:${rule.id}',
            ));
          }
        }

        // Timing 2: On the day
        final whenDay = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          hour,
          minute,
        );
        if (whenDay.isAfter(clock)) {
          final id = reminderStableId(rule.id, dateStr, 'day');
          final style = (setting == 'alarm' || setting == 'both')
              ? ReminderStyle.alarm
              : ReminderStyle.notification;
          planned.add(PlannedReminder(
            id: id,
            when: whenDay,
            title: '$kindUpper Due Today: $entityName',
            body: body,
            style: style,
            payload: 'rec:${rule.id}',
          ));
        }
      }
    }

    // 2. Process Credit Cards
    if (styleCard != 'off') {
      final cardAccounts = accounts.where((a) =>
          !a.archived &&
          (a.kind == 'credit_card' || a.kind == 'credit') &&
          a.dueDay != null &&
          a.dueDay! >= 1 &&
          a.dueDay! <= 31);

      for (final card in cardAccounts) {
        final dueDay = card.dueDay!;
        var currentMonthDate = DateTime(clock.year, clock.month, 1);
        while (currentMonthDate.isBefore(horizon)) {
          final daysInMonth = DateTime(
            currentMonthDate.year,
            currentMonthDate.month + 1,
            0,
          ).day;
          final clampedDay = dueDay.clamp(1, daysInMonth);
          final dueDate = DateTime(
            currentMonthDate.year,
            currentMonthDate.month,
            clampedDay,
          );

          if (dueDate.isAfter(clock.subtract(const Duration(days: 1))) &&
              dueDate.isBefore(horizon)) {
            final dateStr = DateFormat('yyyy-MM-dd').format(dueDate);
            final formattedDate = DateFormat('d MMM').format(dueDate);
            final body = 'Credit Card Due · ${card.name} · due $formattedDate';

            if (daysBefore > 0) {
              final reminderDate = dueDate.subtract(Duration(days: daysBefore));
              final whenBefore = DateTime(
                reminderDate.year,
                reminderDate.month,
                reminderDate.day,
                hour,
                minute,
              );
              if (whenBefore.isAfter(clock)) {
                final id = reminderStableId(card.id, dateStr, 'before');
                final style = (styleCard == 'alarm')
                    ? ReminderStyle.alarm
                    : ReminderStyle.notification;
                planned.add(PlannedReminder(
                  id: id,
                  when: whenBefore,
                  title: 'Upcoming Card Due: ${card.name}',
                  body: body,
                  style: style,
                  payload: 'acc:${card.id}',
                ));
              }
            }

            final whenDay = DateTime(
              dueDate.year,
              dueDate.month,
              dueDate.day,
              hour,
              minute,
            );
            if (whenDay.isAfter(clock)) {
              final id = reminderStableId(card.id, dateStr, 'day');
              final style = (styleCard == 'alarm' || styleCard == 'both')
                  ? ReminderStyle.alarm
                  : ReminderStyle.notification;
              planned.add(PlannedReminder(
                id: id,
                when: whenDay,
                title: 'Card Payment Due Today: ${card.name}',
                body: body,
                style: style,
                payload: 'acc:${card.id}',
              ));
            }
          }
          currentMonthDate = DateTime(
            currentMonthDate.year,
            currentMonthDate.month + 1,
            1,
          );
        }
      }
    }

    // Sort by when ascending
    planned.sort((a, b) => a.when.compareTo(b.when));

    // Cap at maxPendingReminders (60)
    if (planned.length > maxPendingReminders) {
      return planned.sublist(0, maxPendingReminders);
    }
    return planned;
  }

  /// 31-bit stable hash of ruleId + yyyy-MM-dd + 'before'|'day'
  static int reminderStableId(String ruleId, String yyyyMmDd, String timing) {
    return ('$ruleId:$yyyyMmDd:$timing'.hashCode) & 0x7FFFFFFF;
  }
}
