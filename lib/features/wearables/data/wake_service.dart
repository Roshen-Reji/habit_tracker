import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/xp_ledger.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/tasks/data/task_day_log_repository.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/features/tasks/models/task_day_log.dart';
import 'package:habit_tracker/features/tasks/models/wake_log.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/wearables/engine/wake_rules.dart';

class WakeLogResult {
  final bool success;
  final bool onTime;
  final String message;
  final WakeEvaluation? evaluation;
  final Goal? goal;

  WakeLogResult({
    required this.success,
    required this.onTime,
    required this.message,
    this.evaluation,
    this.goal,
  });
}

class WakeService {
  static final WakeService instance = WakeService._();
  WakeService._();
  factory WakeService() => instance;

  static const String goalBoxName = 'mission_box_v4';

  Box<Goal> get _goalBox => Hive.box<Goal>(goalBoxName);

  /// Returns the current wake-up task if one exists.
  Goal? getWakeupGoal() {
    if (!Hive.isBoxOpen(goalBoxName)) return null;
    return _goalBox.values
        .where((g) => g.kind == 'wakeup' && !g.isArchived)
        .firstOrNull;
  }

  /// Creates or updates the single wake-up goal.
  Future<Goal> createOrUpdateWakeupTask({
    required int targetMinutes,
    int graceMinutes = 0,
    String? direction,
    String? title,
  }) async {
    final dir = direction ?? WearableSettings.wakeDirection;
    final metricOp =
        (dir == 'by' || dir == '<=' || dir == 'before') ? '<=' : '>=';

    final existing = getWakeupGoal();
    if (existing != null) {
      existing.targetMinutes = targetMinutes;
      existing.graceMinutes = graceMinutes;
      existing.metricOp = metricOp;
      await existing.save();
      return existing;
    }

    final targetH = targetMinutes ~/ 60;
    final targetM = targetMinutes % 60;
    final targetStr =
        '${targetH.toString().padLeft(2, '0')}:${targetM.toString().padLeft(2, '0')}';

    final goal = Goal(
      id: 'goal_wakeup_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Wake up at $targetStr',
      type: GoalType.daily,
      category: GoalCategory.health,
      targetValue: 1.0,
      unit: 'times',
      kind: 'wakeup',
      targetMinutes: targetMinutes,
      graceMinutes: graceMinutes,
      metricOp: metricOp,
      createdDate: DateTime.now(),
    );

    await _goalBox.put(goal.id, goal);
    return goal;
  }

  /// Logs a wake-up event, evaluates against target, updates streak, awards reversible XP,
  /// and writes to the Day Journal auto-log.
  Future<WakeLogResult> logWake(
    DateTime wakeAt, {
    String source = 'manual',
    String? sleepSessionId,
  }) async {
    final dayKey = DateFormat('yyyy-MM-dd').format(wakeAt);
    final goal = getWakeupGoal();

    final targetMin = goal?.targetMinutes ??
        WearableSettings.wakeTargetMinutesDefault ??
        300; // default 5:00 AM (300 mins)
    final graceMin = goal?.graceMinutes ?? WearableSettings.wakeGraceMinutes;
    final direction =
        (goal?.metricOp == '<=') ? 'by' : WearableSettings.wakeDirection;

    final eval = WakeRules.evaluate(
      wakeAt: wakeAt,
      targetMinutes: targetMin,
      graceMinutes: graceMin,
      direction: direction,
    );

    final existingWake = WakeLogRepository.instance.getLog(dayKey);
    final wasOnTime = existingWake?.onTime;

    // 1. Save WakeLog
    final wakeLog = WakeLog(
      dayKey: dayKey,
      wakeAt: wakeAt,
      source: source,
      sleepSessionId: sleepSessionId,
      targetMinutesAtLog: targetMin,
      onTime: eval.onTime,
    );
    await WakeLogRepository.instance.saveLog(wakeLog);

    // 2. Save TaskDayLog
    if (goal != null) {
      final taskLog = TaskDayLog(
        id: TaskDayLog.generateId(goal.id, dayKey),
        goalId: goal.id,
        dayKey: dayKey,
        status: eval.onTime ? 'done' : 'missed',
        value: 1.0,
        valueText: DateFormat('h:mm a').format(wakeAt),
        source: source,
        note: eval.statusText,
      );
      await TaskDayLogRepository.instance.setLog(taskLog);

      // Update goal completion and streak using log's own date
      final logDate = DateTime(wakeAt.year, wakeAt.month, wakeAt.day);
      final resetAfterMisses = WearableSettings.wakeStreakResetAfterMisses;

      if (eval.onTime) {
        goal.isCompleted = true;
        goal.currentValue = 1.0;
        goal.progress = 1.0;
        if (wasOnTime == null || !wasOnTime) {
          goal.streakCount = WakeRules.updateStreak(
            currentStreak: goal.streakCount,
            onTime: true,
            resetAfterMisses: resetAfterMisses,
          );
        }
        goal.lastCompletedDate = logDate;
      } else {
        goal.isCompleted = false;
        goal.currentValue = 0.0;
        goal.progress = 0.0;
        if (wasOnTime == true) {
          // Edit from on-time to missed: decrement streak
          if (goal.streakCount > 0) {
            goal.streakCount -= 1;
          }
        }
      }
      await goal.save();
    }

    // 3. XP Allocation via XpLedger (Reversible!)
    if (eval.onTime) {
      await XpLedger.set(dayKey, 'wake_on_time', 5);
    } else {
      await XpLedger.set(dayKey, 'wake_on_time', 0);
    }

    // 4. Day Journal Auto-Log hook (P3-6)
    if (WearableSettings.journalAutologEnabled) {
      final autoEvent = AutoLogEvent(
        key: 'wake',
        kind: 'wake',
        text: '${eval.statusText} · via $source',
        timestamp: wakeAt,
        source: source,
        params: {
          'wakeAt': wakeAt.toIso8601String(),
          'onTime': eval.onTime,
          'targetMinutes': targetMin,
        },
      );
      await JournalDayRepository.instance.appendAutoLog(dayKey, autoEvent);
    }

    final wakeTimeStr = DateFormat('h:mm a').format(wakeAt);
    final targetTimeStr =
        '${(targetMin ~/ 60).toString().padLeft(2, '0')}:${(targetMin % 60).toString().padLeft(2, '0')}';

    final message = eval.onTime
        ? 'Logged $wakeTimeStr, on time (target $targetTimeStr). Added to today\'s journal.'
        : 'Logged $wakeTimeStr, off your $targetTimeStr target. Marked missed.';

    return WakeLogResult(
      success: true,
      onTime: eval.onTime,
      message: message,
      evaluation: eval,
      goal: goal,
    );
  }

  /// Undoes a previous wake log for [dayKey].
  Future<void> undo(String dayKey) async {
    await WakeLogRepository.instance.deleteLog(dayKey);

    final goal = getWakeupGoal();
    if (goal != null) {
      final log = TaskDayLogRepository.instance.getLog(goal.id, dayKey);
      if (log != null) {
        log.status = 'pending';
        log.value = 0;
        await TaskDayLogRepository.instance.setLog(log);
      }
      goal.isCompleted = false;
      goal.currentValue = 0;
      goal.progress = 0;
      await goal.save();
    }

    // Reverse XP
    await XpLedger.set(dayKey, 'wake_on_time', 0);

    // Remove from Journal
    await JournalDayRepository.instance.removeAutoLog(dayKey, 'wake');
  }

  /// Rollover hook: marks unlogged past days as missed.
  Future<void> rolloverMissedDays(DateTime now) async {
    final goal = getWakeupGoal();
    if (goal == null) return;

    final policy = WearableSettings.wakeUnloggedPolicy;
    if (policy == 'neutral') return;

    int consecutiveMisses = 0;
    final resetAfterMisses = WearableSettings.wakeStreakResetAfterMisses;
    final penaltyXp = WearableSettings.wakeMissPenaltyXp;

    for (int i = 1; i <= 60; i++) {
      final pastDate = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(pastDate);

      // If created after this day, skip
      if (goal.createdDate != null && pastDate.isBefore(goal.createdDate!)) {
        break;
      }

      final existingWake = WakeLogRepository.instance.getLog(dayKey);
      final existingTaskLog =
          TaskDayLogRepository.instance.getLog(goal.id, dayKey);

      final isMissed = (existingWake != null && !existingWake.onTime) ||
          (existingTaskLog != null && existingTaskLog.status == 'missed');

      if (existingWake == null && existingTaskLog == null) {
        final missedLog = TaskDayLog(
          id: TaskDayLog.generateId(goal.id, dayKey),
          goalId: goal.id,
          dayKey: dayKey,
          status: 'missed',
          source: 'rollover',
          note: 'Unlogged day',
        );
        await TaskDayLogRepository.instance.setLog(missedLog);

        if (penaltyXp > 0) {
          await XpLedger.set(dayKey, 'wake_miss_penalty', -penaltyXp);
        }
        consecutiveMisses++;
      } else if (isMissed) {
        consecutiveMisses++;
      } else {
        // Encountered an on-time or non-missed day, stop counting consecutive misses
        break;
      }
    }

    if (consecutiveMisses >= resetAfterMisses && goal.streakCount > 0) {
      goal.streakCount = 0;
      await goal.save();
    }
  }
}
