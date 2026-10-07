import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/features/finance/engine/reminder_planner.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/recurring_rule.dart';

class ReminderScheduler {
  static const String channelReminders = 'finance_reminders';
  static const String channelAlarms = 'finance_alarm';

  static int _lastSyncTimestampMs = 0;

  /// Syncs reminders if at least 1 hour has elapsed since last sync.
  static Future<void> syncIfThrottleElapsed({DateTime? clock}) async {
    final nowMs = (clock ?? DateTime.now()).millisecondsSinceEpoch;
    // 1 hour = 3600 * 1000 ms
    if (nowMs - _lastSyncTimestampMs < 3600 * 1000) {
      return;
    }
    await sync(clock: clock);
  }

  /// Full synchronization between [ReminderPlanner] and the platform notification scheduler.
  static Future<void> sync({DateTime? clock, bool force = false}) async {
    try {
      if (!Hive.isBoxOpen('finance_settings') ||
          !Hive.isBoxOpen('fin_recurring') ||
          !Hive.isBoxOpen('fin_accounts')) {
        return;
      }

      final settingsBox = Hive.box('finance_settings');
      final recurringBox = Hive.box<RecurringRule>('fin_recurring');
      final accountsBox = Hive.box<Account>('fin_accounts');

      final enabled =
          settingsBox.get('rem_enabled', defaultValue: true) as bool;
      final timeMinutes =
          settingsBox.get('rem_time_minutes', defaultValue: 540) as int;
      final daysBefore =
          settingsBox.get('rem_days_before', defaultValue: 1) as int;
      final styleBill =
          settingsBox.get('rem_style_bill', defaultValue: 'both') as String;
      final styleSub = settingsBox.get('rem_style_sub',
          defaultValue: 'notification') as String;
      final styleSip = settingsBox.get('rem_style_sip',
          defaultValue: 'notification') as String;
      final styleEmi =
          settingsBox.get('rem_style_emi', defaultValue: 'both') as String;
      final styleCard = settingsBox.get('rem_style_card',
          defaultValue: 'notification') as String;

      final now = clock ?? DateTime.now();
      final rules = recurringBox.values.toList();
      final accounts = accountsBox.values.toList();

      final planned = ReminderPlanner.plan(
        rules: rules,
        accounts: accounts,
        enabled: enabled,
        timeMinutes: timeMinutes,
        daysBefore: daysBefore,
        styleBill: styleBill,
        styleSub: styleSub,
        styleSip: styleSip,
        styleEmi: styleEmi,
        styleCard: styleCard,
        now: now,
      );

      final plannedIds = planned.map((p) => p.id).toSet();

      // Read previously scheduled IDs
      final rawStoredIds = settingsBox.get('reminder_ids');
      final Set<int> oldIds = <int>{};
      if (rawStoredIds is List) {
        for (final item in rawStoredIds) {
          if (item is int) oldIds.add(item);
        }
      }

      final notifService = NotificationService();
      final plugin = notifService.flutterLocalNotificationsPlugin;

      // 1. Cancel removed reminders
      final idsToCancel = oldIds.difference(plannedIds);
      for (final id in idsToCancel) {
        try {
          await plugin.cancel(id: id);
        } catch (e) {
          debugPrint('Failed to cancel reminder $id: $e');
        }
      }

      // 2. Schedule planned reminders
      if (enabled) {
        for (final item in planned) {
          try {
            await _scheduleSingle(plugin, item);
          } catch (e) {
            debugPrint('Failed to schedule reminder ${item.id}: $e');
          }
        }
      }

      // 3. Persist new IDs
      await settingsBox.put('reminder_ids', planned.map((p) => p.id).toList());
      _lastSyncTimestampMs = now.millisecondsSinceEpoch;
      await settingsBox.put('rem_last_synced_at', _lastSyncTimestampMs);
    } catch (e) {
      debugPrint('ReminderScheduler.sync error: $e');
    }
  }

  static Future<void> _scheduleSingle(
    FlutterLocalNotificationsPlugin plugin,
    PlannedReminder item,
  ) async {
    final tzDate = tz.TZDateTime.from(item.when, tz.local);

    if (item.style == ReminderStyle.notification) {
      AndroidScheduleMode mode = AndroidScheduleMode.exactAllowWhileIdle;
      try {
        await plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: tzDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelReminders,
              'Finance Reminders',
              channelDescription: 'Reminders for bills, SIPs, and dues',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: item.payload,
          androidScheduleMode: mode,
        );
      } catch (_) {
        // Fallback to inexact if exact scheduling is restricted
        await plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: tzDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelReminders,
              'Finance Reminders',
              channelDescription: 'Reminders for bills, SIPs, and dues',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: item.payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } else {
      // Alarm style
      final alarmDetails = AndroidNotificationDetails(
        channelAlarms,
        'Finance Alarms',
        channelDescription: 'Alarm notifications for finance due dates',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
        actions: const [
          AndroidNotificationAction('snooze_10', 'Snooze 10 min'),
          AndroidNotificationAction('open', 'Open'),
        ],
      );

      try {
        await plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: tzDate,
          notificationDetails: NotificationDetails(
            android: alarmDetails,
            iOS: const DarwinNotificationDetails(),
          ),
          payload: item.payload,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
        );
      } catch (_) {
        // Fallback to exactAllowWhileIdle or inexact
        try {
          await plugin.zonedSchedule(
            id: item.id,
            title: item.title,
            body: item.body,
            scheduledDate: tzDate,
            notificationDetails: NotificationDetails(
              android: alarmDetails,
              iOS: const DarwinNotificationDetails(),
            ),
            payload: item.payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (_) {
          await plugin.zonedSchedule(
            id: item.id,
            title: item.title,
            body: item.body,
            scheduledDate: tzDate,
            notificationDetails: NotificationDetails(
              android: alarmDetails,
              iOS: const DarwinNotificationDetails(),
            ),
            payload: item.payload,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    }
  }

  /// Schedules a test reminder 1 minute from now for user verification.
  static Future<void> sendTestReminder({bool asAlarm = false}) async {
    final plugin = NotificationService().flutterLocalNotificationsPlugin;
    final testDate = DateTime.now().add(const Duration(minutes: 1));
    final tzDate = tz.TZDateTime.from(testDate, tz.local);
    const testId = 999999;

    if (!asAlarm) {
      await plugin.zonedSchedule(
        id: testId,
        title: 'Test Notification: Finance Reminder',
        body: 'SIP ₹1,000 · Test Fund · due today, from Main',
        scheduledDate: tzDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelReminders,
            'Finance Reminders',
            channelDescription: 'Reminders for bills, SIPs, and dues',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'rec:test',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } else {
      await plugin.zonedSchedule(
        id: testId,
        title: 'Test Alarm: Finance Reminder',
        body: 'EMI ₹5,000 · Home Loan · due now, from Main',
        scheduledDate: tzDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelAlarms,
            'Finance Alarms',
            channelDescription: 'Alarm notifications for finance due dates',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            additionalFlags: Int32List.fromList([4]),
            actions: const [
              AndroidNotificationAction('snooze_10', 'Snooze 10 min'),
              AndroidNotificationAction('open', 'Open'),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'rec:test',
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    }
  }
}
