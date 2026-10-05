import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/features/wearables/data/metric_task_service.dart';
import 'package:habit_tracker/features/wearables/data/mock_wearable_source.dart';
import 'package:habit_tracker/features/wearables/data/samsung_health_source.dart';
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

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier(SyncStatus.idle);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  WearableSource? _activeSource;

  WearableSource getActiveSource() {
    if (_activeSource != null) return _activeSource!;

    final useMock = kDebugMode && WearableSettings.useMockProvider;
    if (useMock) {
      _activeSource = MockWearableSource();
    } else {
      _activeSource = SamsungHealthSource();
    }
    return _activeSource!;
  }

  void resetSource() {
    _activeSource = null;
  }

  /// Triggers a sync for the past [days] (default 7 for incremental, 30 for backfill).
  Future<bool> sync({int days = 7}) async {
    if (statusNotifier.value == SyncStatus.syncing) return false;

    if (!WearableSettings.isEnabled) {
      statusNotifier.value = SyncStatus.idle;
      return false;
    }

    statusNotifier.value = SyncStatus.syncing;
    errorNotifier.value = null;

    try {
      final source = getActiveSource();
      final repo = WearableRepository.instance;

      // 1. Fetch telemetry across all 6 streams
      final dailyList = await source.fetchDailyActivity(days);
      final sleepList = await source.fetchSleepSessions(days);
      final exerciseList = await source.fetchExercises(days);
      final bodyList = await source.fetchBodyComposition(days);
      final energyList = await source.fetchEnergyScores(days);
      final agesList = await source.fetchAgesSamples(days);

      // 2. Persist in Hive
      for (final d in dailyList) {
        await repo.upsertDaily(d);
      }
      for (final s in sleepList) {
        await repo.upsertSleep(s);
      }
      for (final e in exerciseList) {
        await repo.upsertExercise(e);
      }
      for (final b in bodyList) {
        await repo.upsertBodyComp(b);
      }
      for (final en in energyList) {
        await repo.upsertEnergyScore(en);
      }
      for (final a in agesList) {
        await repo.upsertAges(a);
      }

      // 3. Reconcile Exercise Calories with DietDayLog (skip mock data from polluting real records)
      if (source.sourceId != 'mock') {
        await _reconcileExerciseCalories(exerciseList, dailyList);

        // 4. Auto-log to Day Journal if enabled
        if (WearableSettings.journalAutologEnabled) {
          await _autoLogToJournal(sleepList, energyList, agesList, exerciseList);
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
            targetCalories: Hive.box('settings').get('daily_calorie_target', defaultValue: 2000.0).toDouble(),
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

  /// Day Journal auto-log hooks
  Future<void> _autoLogToJournal(
    List<SleepSession> sleepList,
    List<EnergyScoreDay> energyList,
    List<AgesSample> agesList,
    List<ExerciseSession> exerciseList,
  ) async {
    final journalRepo = JournalDayRepository.instance;
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // Morning telemetry summary (Sleep + Energy + AGEs)
    final todaySleep = sleepList.where((s) => s.dayKey == todayKey && !s.isNap).firstOrNull;
    final todayEnergy = energyList.where((e) => e.dayKey == todayKey).firstOrNull;
    final todayAges = agesList.firstOrNull;

    if (todaySleep != null) {
      final hours = todaySleep.durationMin ~/ 60;
      final mins = todaySleep.durationMin % 60;
      final scoreStr = todaySleep.score != null ? ' (Score: ${todaySleep.score})' : '';
      final energyStr = todayEnergy != null ? ' · Energy: ${todayEnergy.score}/100' : '';
      final agesStr = todayAges != null ? ' · AGEs: ${todayAges.score.toStringAsFixed(1)}' : '';

      final sleepEvent = AutoLogEvent(
        key: 'sleep_$todayKey',
        kind: 'sleep',
        text: 'Slept ${hours}h ${mins}m$scoreStr$energyStr$agesStr',
        timestamp: todaySleep.end,
        source: 'samsung_health',
      );
      await journalRepo.appendAutoLog(todayKey, sleepEvent);
    }

    // Workout auto-logs
    for (final ex in exerciseList) {
      if (ex.dayKey == todayKey) {
        final workoutEvent = AutoLogEvent(
          key: 'workout_${ex.externalId}',
          kind: 'workout',
          text: '${ex.title ?? ex.type} · ${ex.durationMin}m · ${(ex.activeKcal ?? 0).round()} kcal',
          timestamp: ex.start,
          source: 'samsung_health',
        );
        await journalRepo.appendAutoLog(todayKey, workoutEvent);
      }
    }
  }

  /// Auto-log wake up from wearable sleep end if user has a wake goal and unlogged today
  Future<void> _autoLogWakeFromSleep(List<SleepSession> sleepList) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existingWake = WakeLogRepository.instance.getLog(today);
    if (existingWake != null) return; // User already logged or already auto-logged

    final todaySleep = sleepList.where((s) => s.dayKey == today && !s.isNap).firstOrNull;
    if (todaySleep == null) return;

    // If sleep ended this morning, auto-log wake
    if (todaySleep.end.day == DateTime.now().day) {
      await WakeService.instance.logWake(
        todaySleep.end,
        source: 'samsung_health',
        sleepSessionId: todaySleep.externalId,
      );
    }
  }
}
