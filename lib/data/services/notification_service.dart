import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/health_models.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
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
        notificationTapBackground(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _isInitialized = true;
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
            'finance_channel',
            'Finance Notifications',
            channelDescription:
                'Notifications for SIP debits and finance alerts',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFF18FFFF),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
