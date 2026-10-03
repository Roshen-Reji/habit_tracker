import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:habit_tracker/data/models/goal.dart';

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
      id: task.key.hashCode, // Use hive key hashcode as unique ID
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
          color: Color(0xFF18FFFF), // tealAccent
          ledColor: Color(0xFF18FFFF),
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
