class WearableXpRules {
  static const int stepsAward = 10;
  static const int stretchStepsAward = 5;
  static const int activeTimeAward = 5;
  static const int workoutAwardPerSession = 8;
  static const int sleepGoalAward = 8;

  /// Combined daily wearable XP cap.
  static const int dailyCap = 40;

  static const String ruleSteps = 'steps_goal';
  static const String ruleStretchSteps = 'steps_stretch';
  static const String ruleActiveTime = 'active_time_goal';
  static const String ruleSleepGoal = 'sleep_goal';

  /// Evaluates awards for a day's metrics and returns a map of ruleKey -> raw XP award,
  /// plus a scaled/clamped map that respects the 40 XP daily cap.
  static Map<String, int> computeAwards({
    required int steps,
    required int stepGoal,
    required int activeMinutes,
    required int activeMinutesGoal,
    required List<String> workoutIds,
    required int sleepMinutes,
    required int sleepGoalMinutes,
  }) {
    final raw = <String, int>{};

    // 1. Steps
    if (stepGoal > 0 && steps >= stepGoal) {
      raw[ruleSteps] = stepsAward;
      if (steps >= (stepGoal * 1.5).round()) {
        raw[ruleStretchSteps] = stretchStepsAward;
      }
    }

    // 2. Active minutes
    if (activeMinutesGoal > 0 && activeMinutes >= activeMinutesGoal) {
      raw[ruleActiveTime] = activeTimeAward;
    }

    // 3. Workouts
    for (final id in workoutIds) {
      raw['workout:'] = workoutAwardPerSession;
    }

    // 4. Sleep duration
    if (sleepGoalMinutes > 0 && sleepMinutes >= sleepGoalMinutes) {
      raw[ruleSleepGoal] = sleepGoalAward;
    }

    // Apply 40 XP daily cap
    final total = raw.values.fold<int>(0, (sum, val) => sum + val);
    if (total <= dailyCap) {
      return raw;
    }

    // Proportionally clamp to 40 XP or sequentially cap
    int remainingBudget = dailyCap;
    final clamped = <String, int>{};

    for (final entry in raw.entries) {
      if (remainingBudget <= 0) {
        clamped[entry.key] = 0;
      } else if (entry.value <= remainingBudget) {
        clamped[entry.key] = entry.value;
        remainingBudget -= entry.value;
      } else {
        clamped[entry.key] = remainingBudget;
        remainingBudget = 0;
      }
    }

    return clamped;
  }
}
