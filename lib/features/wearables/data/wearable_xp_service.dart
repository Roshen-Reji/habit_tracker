import 'package:intl/intl.dart';
import 'package:habit_tracker/data/services/xp_ledger.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/wearables/engine/xp_rules.dart';

class WearableXpService {
  static final WearableXpService instance = WearableXpService._();
  WearableXpService._();
  factory WearableXpService() => instance;

  /// Reconciles wearable XP for a specific dayKey using the reversible XpLedger.
  Future<void> reconcile(String dayKey) async {
    // 1. Safety gates: must be enabled, mock rows excluded
    if (!WearableSettings.isEnabled || WearableSettings.useMockProvider) {
      return;
    }

    // 2. Migration gate: never reconcile days prior to xp_ledger_start
    final startKey = WearableSettings.xpLedgerStart;
    if (startKey != null && dayKey.compareTo(startKey) < 0) {
      return;
    }

    final view = WearableRepository.instance.dayView(dayKey);

    final steps = view.totalSteps;
    final stepGoal = view.activity?.stepGoal ?? WearableSettings.stepGoalDefault;
    final activeMinutes = view.activeMinutes;
    final activeMinutesGoal = WearableSettings.activeMinutesGoalDefault;
    final workoutIds = view.exercises.map((e) => e.externalId).toList();
    final sleepMinutes = view.mainSleep?.durationMin ?? 0;
    final sleepGoalMinutes = WearableSettings.sleepGoalMinutesDefault;

    final awards = WearableXpRules.computeAwards(
      steps: steps,
      stepGoal: stepGoal,
      activeMinutes: activeMinutes,
      activeMinutesGoal: activeMinutesGoal,
      workoutIds: workoutIds,
      sleepMinutes: sleepMinutes,
      sleepGoalMinutes: sleepGoalMinutes,
    );

    // Get current ledger entries for this day to reverse missing ones
    final currentEntries = XpLedger.entriesForDay(dayKey);
    final wearableKeys = [
      WearableXpRules.ruleSteps,
      WearableXpRules.ruleStretchSteps,
      WearableXpRules.ruleActiveTime,
      WearableXpRules.ruleSleepGoal,
      ...currentEntries.where((e) => e.ruleId.startsWith('workout:')).map((e) => e.ruleId),
    ];

    // Apply awards or reverse down to 0 if no longer eligible
    for (final rule in wearableKeys) {
      final amount = awards[rule] ?? 0;
      await XpLedger.set(dayKey, rule, amount);
    }
  }

  /// Reconciles the last [days] days plus today.
  Future<void> reconcileRecent({int days = 3}) async {
    final now = DateTime.now();
    for (int i = 0; i <= days; i++) {
      final d = now.subtract(Duration(days: i));
      final k = DateFormat('yyyy-MM-dd').format(d);
      await reconcile(k);
    }
  }
}
