import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/features/finance/ui/recurring/recurring_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // 1. Finance Alarm Snooze action (plugin only, no Hive isolate access)
  if (response.actionId == 'snooze_10') {
    final plugin = FlutterLocalNotificationsPlugin();
    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
    try {
      await plugin.zonedSchedule(
        id: (response.id ?? 1000) + 1,
        title: 'Snoozed: Finance Reminder',
        body: 'Payment reminder due now',
        scheduledDate: tz.TZDateTime.from(snoozeTime, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_alarm',
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
        payload: response.payload,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } catch (e) {
      debugPrint('Background snooze error: $e');
    }
    return;
  }

  // 2. Medicine Actions
  if (response.payload != null && response.payload!.startsWith('med:')) {
    final parts = response.payload!.split(':');
    if (parts.length >= 2) {
      final medId = parts[1];
      try {
        if (!Hive.isBoxOpen('medicine_logs')) {
          await Hive.initFlutter();
          if (!Hive.isAdapterRegistered(31)) {
            Hive.registerAdapter(MedicineLogAdapter());
          }
          await Hive.openBox<MedicineLog>('medicine_logs');
        }
        final box = Hive.box<MedicineLog>('medicine_logs');
        if (response.actionId == 'taken') {
          final log = MedicineLog(
            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
            medicineId: medId,
            scheduledAt: DateTime.now(),
            status: 'taken',
            loggedAt: DateTime.now(),
          );
          await box.put(log.id, log);
        } else if (response.actionId == 'snooze') {
          // Snooze 10 minutes
          final notif = NotificationService();
          await notif.scheduleMedicineReminder(
            id: (medId.hashCode + 9999) & 0x7FFFFFFF,
            medicineId: medId,
            title: 'Snoozed Medicine Dose',
            body: 'Reminder to take your dose.',
            scheduledDate: DateTime.now().add(const Duration(minutes: 10)),
          );
        }
      } catch (e) {
        debugPrint('Background notification error: $e');
      }
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('Timezone lookup warning: $e, falling back to Asia/Kolkata');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {}
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'snooze_10') {
          notificationTapBackground(response);
          return;
        }
        _handleNotificationNavigation(response);
        notificationTapBackground(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Setup notification channels on Android
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'finance_reminders',
          'Finance Reminders',
          description: 'Reminders for bills, SIPs, and dues',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'finance_alarm',
          'Finance Alarms',
          description: 'Alarm notifications for finance due dates',
          importance: Importance.max,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      );
    }

    // Check if app was launched via tapping a notification
    final launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final response = launchDetails.notificationResponse;
      if (response != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationNavigation(response);
        });
      }
    }

    _isInitialized = true;
  }

  static void _handleNotificationNavigation(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    if (payload.startsWith('rec:')) {
      globalNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const RecurringPage()),
      );
    } else if (payload.startsWith('acc:')) {
      globalNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AccountsPage()),
      );
    }
  }

  Future<void> scheduleTaskReminder(Goal task) async {
    if (task.reminderTime == null) return;

    DateTime scheduledTime = task.reminderTime!;
    DateTime now = DateTime.now();

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: task.key.hashCode,
      title: "Task Reminder: ${task.title}",
      body: "It's time to work on your task!",
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_tracker_channel',
          'Habit Reminders',
          channelDescription: 'Notifications for your daily tasks',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF18FFFF),
          ledColor: Color(0xFF18FFFF),
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isExact = true,
  }) async {
    final scheduleMode = isExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_channel',
          'Medicine Reminders',
          channelDescription: 'Notifications for scheduled medicine doses',
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFF10B981),
          actions: const [
            AndroidNotificationAction(
              'taken',
              'Taken',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'snooze',
              'Snooze',
              showsUserInterface: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'med:$medicineId',
      androidScheduleMode: scheduleMode,
    );
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) return;
    try {
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_reminders',
            'Finance Reminders',
            channelDescription:
                'Notifications for SIP debits and finance alerts',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
    String channelId = 'finance_reminders',
    String channelName = 'Finance Reminders',
  }) async {
    if (!_isInitialized) return;
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Finance alerts, budget warnings and reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
