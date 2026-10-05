class WearableXpRules {
  static const int stepsAward = 10;
  static const int stretchStepsAward = 5;
  static const int activeTimeAward = 5;
  static const int workoutAwardPerSession = 8;
  static const int maxWorkoutsPerDay = 3;
  static const int sleepGoalAward = 8;
  static const int sleepQualityAward = 4;
  static const int energyScoreAward = 3;

  /// Combined daily wearable XP cap.
  static const int dailyCap = 40;

  static const String ruleSteps = 'wear_steps';
  static const String ruleStretchSteps = 'wear_steps_stretch';
  static const String ruleActiveTime = 'wear_active_time';
  static const String ruleWorkout = 'wear_workout';
  static const String ruleSleepGoal = 'wear_sleep_goal';
  static const String ruleSleepQuality = 'wear_sleep_quality';
  static const String ruleEnergy = 'wear_energy';

  /// Evaluates awards for a day's metrics and returns a map of ruleKey -> raw XP award,
  /// plus a scaled/clamped map that respects the 40 XP daily cap.
  static Map<String, int> computeAwards({
    required int steps,
    required int stepGoal,
    required int activeMinutes,
    required int activeMinutesGoal,
    required int workoutCount,
    required int sleepMinutes,
    required int sleepGoalMinutes,
    int? sleepScore,
    int? energyScore,
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
    if (workoutCount > 0) {
      final eligibleWorkouts = workoutCount.clamp(0, maxWorkoutsPerDay);
      raw[ruleWorkout] = eligibleWorkouts * workoutAwardPerSession;
    }

    // 4. Sleep duration
    if (sleepGoalMinutes > 0 && sleepMinutes >= sleepGoalMinutes) {
      raw[ruleSleepGoal] = sleepGoalAward;
    }

    // 5. Sleep quality
    if (sleepScore != null && sleepScore >= 80) {
      raw[ruleSleepQuality] = sleepQualityAward;
    }

    // 6. Energy score
    if (energyScore != null && energyScore >= 80) {
      raw[ruleEnergy] = energyScoreAward;
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
