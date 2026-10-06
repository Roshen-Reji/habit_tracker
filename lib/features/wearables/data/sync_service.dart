import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/features/wearables/data/metric_task_service.dart';
import 'package:habit_tracker/features/wearables/data/health_connect_source.dart';
import 'package:habit_tracker/features/wearables/data/wake_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/wearables/data/wearable_source.dart';
import 'package:habit_tracker/features/wearables/data/wearable_xp_service.dart';
import 'package:habit_tracker/features/wearables/engine/calorie_reconciler.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();
  factory SyncService() => instance;

  final ValueNotifier<SyncStatus> statusNotifier =
      ValueNotifier(SyncStatus.idle);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  WearableSource? _activeSource;

  WearableSource getActiveSource() {
    _activeSource ??= HealthConnectSource();
    return _activeSource!;
  }

  void resetSource() {
    _activeSource = null;
  }

  /// Triggers a sync for the past [days] (default 3 for incremental, wear_backfill_days for backfill).
  Future<bool> sync({int? days}) async {
    if (statusNotifier.value == SyncStatus.syncing) return false;

    if (!WearableSettings.isEnabled) {
      statusNotifier.value = SyncStatus.idle;
      return false;
    }

    final isFirstRun = WearableSettings.lastSyncMs == 0;
    final int syncDays = days ??
        (isFirstRun
            ? Hive.box('settings').get('wear_backfill_days', defaultValue: 30)
            : 3);

    statusNotifier.value = SyncStatus.syncing;
    errorNotifier.value = null;

    try {
      WearableSource source = getActiveSource();
      if (source is HealthConnectSource) {
        final perms = await source.checkPermissions();
        if (perms['all'] != true) {
          final granted = await source.requestPermissions();
          if (!granted) {
            statusNotifier.value = SyncStatus.error;
            errorNotifier.value = 'Health Connect permissions not granted';
            return false;
          }
        }
      }
      final repo = WearableRepository.instance;

      List<DailyActivity> dailyList = [];
      List<SleepSession> sleepList = [];
      List<ExerciseSession> exerciseList = [];
      List<BodyCompSample> bodyList = [];

      int readCount = 0;

      // 1. Fetch telemetry across streams with per-type try-catch
      try {
        dailyList = await source.fetchDailyActivity(syncDays);
        if (dailyList.isNotEmpty) {
          await repo.dailyBox.putAll({for (final d in dailyList) d.dayKey: d});
          readCount += dailyList.length;
        }
      } catch (e) {
        debugPrint('Sync daily error: $e');
      }

      try {
        sleepList = await source.fetchSleepSessions(syncDays);
        if (sleepList.isNotEmpty) {
          await repo.sleepBox
              .putAll({for (final s in sleepList) s.externalId: s});
          readCount += sleepList.length;
        }
      } catch (e) {
        debugPrint('Sync sleep error: $e');
      }

      try {
        exerciseList = await source.fetchExercises(syncDays);
        if (exerciseList.isNotEmpty) {
          await repo.exerciseBox
              .putAll({for (final e in exerciseList) e.externalId: e});
          readCount += exerciseList.length;
        }
      } catch (e) {
        debugPrint('Sync exercise error: $e');
      }

      try {
        bodyList = await source.fetchBodyComposition(syncDays);
        if (bodyList.isNotEmpty) {
          await repo.bodyBox.putAll({
            for (final b in bodyList)
              '${b.dayKey}_${b.timestamp.millisecondsSinceEpoch}': b
          });
          readCount += bodyList.length;
        }
      } catch (e) {
        debugPrint('Sync body comp error: $e');
      }

      // 3. Reconcile Exercise Calories with DietDayLog
      if (source.sourceId != 'mock') {
        await _reconcileExerciseCalories(exerciseList, dailyList);
        await _reconcileWeight(bodyList);

        // 4. Auto-log to Day Journal if enabled
        if (WearableSettings.journalAutologEnabled) {
          await _autoLogToJournal(sleepList, exerciseList);
        }

        // 5. Auto-log wake up from wearable sleep end if wake goal is pending
        await _autoLogWakeFromSleep(sleepList);

        // 6. Reconcile Wearable XP with XpLedger
        await WearableXpService.instance.reconcileRecent(days: 3);

        // 7. Reconcile Metric Tasks
        final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await MetricTaskService.instance.reconcileDay(todayKey);
      }

      final now = DateTime.now();
      WearableSettings.lastSyncMs = now.millisecondsSinceEpoch;
      lastSyncNotifier.value = now;
      statusNotifier.value = SyncStatus.success;
      return true;
    } catch (e, st) {
      debugPrint('SyncService.sync error: $e\n$st');
      errorNotifier.value = e.toString();
      statusNotifier.value = SyncStatus.error;
      return false;
    }
  }

  /// Reconciles wearable exercise workouts into DietDayLog
  /// User confirmed directive: "credit for excersie sessions but total burned calories should be taken"
  Future<void> _reconcileExerciseCalories(
    List<ExerciseSession> exercises,
    List<DailyActivity> dailyList,
  ) async {
    if (!Hive.isBoxOpen('diet_logs')) return;
    final dietBox = Hive.box<DietDayLog>('diet_logs');

    // Group workouts by dayKey
    final byDay = <String, List<ExerciseSession>>{};
    for (final ex in exercises) {
      byDay.putIfAbsent(ex.dayKey, () => []).add(ex);
    }

    for (final entry in byDay.entries) {
      final dayKey = entry.key;
      final sessions = entry.value;

      final dayLog = dietBox.get(dayKey) ??
          DietDayLog(
            dateKey: dayKey,
            targetCalories: Hive.box('settings')
                .get('daily_calorie_target', defaultValue: 2000.0)
                .toDouble(),
          );

      final result = CalorieReconciler.reconcileWorkouts(
        currentEntries: dayLog.burnEntries,
        sessions: sessions,
        creditMode: WearableSettings.burnCreditMode,
      );

      if (result.modified) {
        dayLog.burnEntries = result.entries;
        await dietBox.put(dayKey, dayLog);
      }
    }
  }

  /// Reconciles wearable body composition weight into WeightEntry
  Future<void> _reconcileWeight(List<BodyCompSample> bodyList) async {
    if (!Hive.isBoxOpen('weight_entries')) return;
    final weightBox = Hive.box<WeightEntry>('weight_entries');

    final existingEntries = weightBox.values.toList();
    bool modified = false;

    // Group body samples by dayKey and keep the latest per day
    final byDay = <String, BodyCompSample>{};
    for (final b in bodyList) {
      if (b.weightKg == null) continue;
      final existing = byDay[b.dayKey];
      if (existing == null || b.timestamp.isAfter(existing.timestamp)) {
        byDay[b.dayKey] = b;
      }
    }

    for (final MapEntry(key: dayKey, value: sample) in byDay.entries) {
      // Check if manual entry exists for this day (manual wins)
      final existing =
          existingEntries.where((e) => e.date == dayKey).firstOrNull;
      if (existing == null) {
        // Add new wearable entry
        await weightBox.add(
          WeightEntry(
            date: dayKey,
            kg: sample.weightKg!,
            source: 'health_connect',
            externalId: sample.externalId ??
                'wear_${sample.timestamp.millisecondsSinceEpoch}',
          ),
        );
        modified = true;
      } else if (existing.source == 'health_connect') {
        // Update existing wearable entry if different
        if (existing.kg != sample.weightKg!) {
          final idx = existingEntries.indexOf(existing);
          final updated = WeightEntry(
            date: dayKey,
            kg: sample.weightKg!,
            source: 'health_connect',
            externalId: existing.externalId,
          );
          await weightBox.putAt(idx, updated);
          modified = true;
        }
      }
    }
  }

  /// Day Journal auto-log hooks
  Future<void> _autoLogToJournal(
    List<SleepSession> sleepList,
    List<ExerciseSession> exerciseList,
  ) async {
    final journalRepo = JournalDayRepository.instance;
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // Morning telemetry summary (Sleep)
    final todaySleep =
        sleepList.where((s) => s.dayKey == todayKey && !s.isNap).firstOrNull;

    if (todaySleep != null) {
      final hours = todaySleep.durationMin ~/ 60;
      final mins = todaySleep.durationMin % 60;
      final scoreStr =
          todaySleep.score != null ? ' (Score: ${todaySleep.score})' : '';

      final sleepEvent = AutoLogEvent(
        key: 'sleep_$todayKey',
        kind: 'sleep',
        text: 'Slept ${hours}h ${mins}m$scoreStr',
        timestamp: todaySleep.end,
        source: 'health_connect',
      );
      await journalRepo.appendAutoLog(todayKey, sleepEvent);
    }

    // Workout auto-logs
    for (final ex in exerciseList) {
      if (ex.dayKey == todayKey) {
        final workoutEvent = AutoLogEvent(
          key: 'workout_${ex.externalId}',
          kind: 'workout',
          text:
              '${ex.title ?? ex.type} · ${ex.durationMin}m · ${(ex.activeKcal ?? 0).round()} kcal',
          timestamp: ex.start,
          source: 'health_connect',
        );
        await journalRepo.appendAutoLog(todayKey, workoutEvent);
      }
    }
  }

  /// Auto-log wake up from wearable sleep end if user has a wake goal and unlogged today
  Future<void> _autoLogWakeFromSleep(List<SleepSession> sleepList) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existingWake = WakeLogRepository.instance.getLog(today);
    if (existingWake != null)
      return; // User already logged or already auto-logged

    final todaySleep =
        sleepList.where((s) => s.dayKey == today && !s.isNap).firstOrNull;
    if (todaySleep == null) return;

    // If sleep ended this morning, auto-log wake
    if (todaySleep.end.day == DateTime.now().day) {
      await WakeService.instance.logWake(
        todaySleep.end,
        source: 'health_connect',
        sleepSessionId: todaySleep.externalId,
      );
    }
  }
}
