import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/xp_ledger.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';

class MetricTaskService {
  static final MetricTaskService instance = MetricTaskService._();
  MetricTaskService._();
  factory MetricTaskService() => instance;

  static const String goalBoxName = 'mission_box_v4';

  /// Reconciles all kind == 'metric' goals against wearable day metrics.
  /// Reaching the target completes the goal directly, awarding XP through `metric:{goalId}` in XpLedger.
  /// If data is revised down, the goal is uncompleted and XP is reversed to 0 in XpLedger.
  Future<void> reconcileDay(String dayKey) async {
    if (!Hive.isBoxOpen(goalBoxName)) return;
    final box = Hive.box<Goal>(goalBoxName);
    final metricGoals =
        box.values.where((g) => g.kind == 'metric' && !g.isArchived).toList();
    if (metricGoals.isEmpty) return;

    final view = WearableRepository.instance.dayView(dayKey);

    for (final goal in metricGoals) {
      double metricValue = 0.0;
      switch (goal.metricKey) {
        case 'steps':
          metricValue = view.totalSteps.toDouble();
          break;
        case 'active_minutes':
          metricValue = view.activeMinutes.toDouble();
          break;
        case 'sleep_minutes':
          metricValue = (view.mainSleep?.durationMin ?? 0).toDouble();
          break;
        case 'workout_minutes':
          metricValue = view.exercises
              .fold<int>(0, (sum, e) => sum + e.durationMin)
              .toDouble();
          break;
        case 'energy_score':
          metricValue = (view.energy?.score ?? 0).toDouble();
          break;
        default:
          continue;
      }

      goal.currentValue = metricValue;
      final target = goal.targetValue;
      final op = goal.metricOp ?? '>=';
      final bool completed = (op == '<=')
          ? (metricValue > 0 && metricValue <= target)
          : (metricValue >= target);

      final wasCompleted = goal.isCompleted;
      goal.isCompleted = completed;
      goal.progress = target > 0
          ? (metricValue / target).clamp(0.0, 1.0)
          : (completed ? 1.0 : 0.0);

      if (completed) {
        if (!wasCompleted) {
          goal.streakCount += 1;
          goal.lastCompletedDate = DateTime.now();
        }
        await XpLedger.set(dayKey, 'metric:${goal.id}', goal.xpValue);
      } else {
        if (wasCompleted) {
          if (goal.streakCount > 0) goal.streakCount -= 1;
        }
        await XpLedger.set(dayKey, 'metric:${goal.id}', 0);
      }
      await goal.save();
    }
  }
}
