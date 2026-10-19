import 'dart:math' as math;
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';

/// Pure Dart science engine for clinical BMR/TDEE calculations,
/// gym trainer macro partitioning, EWMA weight trend math, and
/// supportive doctor coaching insights. Zero Flutter material dependencies.
class NutritionScienceEngine {
  const NutritionScienceEngine._();

  /// Mifflin-St Jeor BMR + Safe Activity Multiplier + Goal Deficit/Surplus.
  /// Strictly enforces clinical safety floors (>=1300 kcal F / >=1500 kcal M).
  static DailyTargets computeDailyTargets(
    NutritionProfile profile, {
    double activeBurnKcal = 0.0,
  }) {
    // 1. Mifflin-St Jeor BMR calculation
    // Men: (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) + 5
    // Women: (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) - 161
    final weightKg = profile.currentWeightKg > 0 ? profile.currentWeightKg : 70.0;
    final heightCm = profile.heightCm > 0 ? profile.heightCm : 175.0;
    final age = profile.age > 0 ? profile.age : 25;

    final double bmrBase = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age);
    final double bmr;
    switch (profile.sex) {
      case BiologicalSex.male:
        bmr = bmrBase + 5.0;
        break;
      case BiologicalSex.female:
        bmr = bmrBase - 161.0;
        break;
      case BiologicalSex.other:
        bmr = bmrBase - 78.0; // Midpoint
        break;
    }

    // 2. Total Daily Energy Expenditure (TDEE)
    final double rawTdee = (bmr * profile.activityLevel.multiplier) + activeBurnKcal;

    // 3. Goal Calorie Adjustment
    double deltaKcal = 0.0;
    switch (profile.goal) {
      case DietGoal.gradualLoss:
        // 0.25 kg/wk ~ 275 kcal deficit; 0.5 kg/wk ~ 500 kcal deficit
        deltaKcal = profile.paceKgPerWeek <= 0.3 ? -275.0 : -450.0;
        break;
      case DietGoal.gradualGain:
        deltaKcal = profile.paceKgPerWeek <= 0.3 ? 250.0 : 380.0;
        break;
      case DietGoal.maintain:
      case DietGoal.improveHabits:
        deltaKcal = 0.0;
        break;
    }

    double calculatedTarget = rawTdee + deltaKcal;

    // 4. Clinical Safety Floor Enforcement
    // Medical ethics: Never prescribe starvation diets that damage thyroid & metabolic rate.
    final double clinicalFloor =
        profile.sex == BiologicalSex.female ? 1300.0 : 1500.0;
    bool floorApplied = false;
    String explanation;

    if (calculatedTarget < clinicalFloor) {
      calculatedTarget = clinicalFloor;
      floorApplied = true;
      explanation =
          'Calorie target clamped to clinical safety floor (${clinicalFloor.toInt()} kcal) to safeguard basal metabolic rate and prevent micronutrient deficiencies.';
    } else {
      explanation =
          'Mifflin-St Jeor TDEE (${rawTdee.round()} kcal) adjusted by ${deltaKcal >= 0 ? "+" : ""}${deltaKcal.round()} kcal for sustainable ${profile.goal.label.toLowerCase()}.';
    }

    final double finalKcal = calculatedTarget;

    // 5. Evidence-Based Macro Split (Gym Trainer + Sports Nutrition)
    // Protein: 1.6 - 2.0g per kg of body weight for active/loss/gain goals
    final double proteinG;
    if (profile.customProteinTargetG != null && profile.customProteinTargetG! > 0) {
      proteinG = profile.customProteinTargetG!;
    } else {
      final double proteinPerKg;
      switch (profile.activityLevel) {
        case PhysicalActivityLevel.sedentary:
          proteinPerKg = 1.2;
          break;
        case PhysicalActivityLevel.light:
          proteinPerKg = 1.4;
          break;
        case PhysicalActivityLevel.moderate:
          proteinPerKg = 1.7;
          break;
        case PhysicalActivityLevel.active:
        case PhysicalActivityLevel.athlete:
          proteinPerKg = 2.0;
          break;
      }
      proteinG = (weightKg * proteinPerKg).clamp(65.0, 220.0);
    }

    // Fibre: 14g per 1000 kcal, clamped between 28g and 35g
    final double fibreG;
    if (profile.customFibreTargetG != null && profile.customFibreTargetG! > 0) {
      fibreG = profile.customFibreTargetG!;
    } else {
      fibreG = ((finalKcal / 1000.0) * 14.0).clamp(28.0, 38.0);
    }

    // Healthy Fats: 25% to 30% of target energy (9 kcal/g)
    final double fatCalories = finalKcal * 0.28;
    final double fatG = (fatCalories / 9.0).clamp(40.0, 100.0);

    // Remaining calories for Complex Carbohydrates (4 kcal/g)
    final double proteinCalories = proteinG * 4.0;
    final double remainingCarbCalories =
        math.max(200.0, finalKcal - proteinCalories - fatCalories);
    final double carbsG = (remainingCarbCalories / 4.0).clamp(60.0, 450.0);

    // Hydration Target: 35ml per kg + 500ml for training
    final double waterMl =
        ((weightKg * 35.0) + (activeBurnKcal > 0 ? 500.0 : 250.0)).clamp(2000.0, 4000.0);

    return DailyTargets(
      targetKcal: finalKcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fibreG: fibreG,
      ironMg: profile.sex == BiologicalSex.female ? 18.0 : 12.0,
      calciumMg: 1000.0,
      waterMl: waterMl,
      clinicalFloorApplied: floorApplied,
      explanation: explanation,
    );
  }

  /// 7-day Exponentially Weighted Moving Average ($EWMA_t = 0.25 W_t + 0.75 EWMA_{t-1}$).
  /// De-emphasizes daily water/glycogen swings to reveal true body tissue trajectory.
  static EWMAWeightTrend computeWeightTrend(
    List<WeightProgressEntry> rawEntries, {
    double defaultWeightKg = 0.0,
  }) {
    if (rawEntries.isEmpty) {
      return EWMAWeightTrend(
        latestRawKg: defaultWeightKg,
        currentEwmaKg: defaultWeightKg,
        weeklyRateOfChangeKg: 0.0,
        trendDirection: 'stable',
        smoothedSeries: const {},
      );
    }

    // Sort chronologically by dateIso
    final sorted = List<WeightProgressEntry>.from(rawEntries)
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    const double alpha = 0.25;
    final Map<String, double> smoothedMap = {};
    double currentEwma = sorted.first.weightKg;

    for (int i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      if (i == 0) {
        currentEwma = entry.weightKg;
      } else {
        currentEwma = (alpha * entry.weightKg) + ((1.0 - alpha) * currentEwma);
      }
      smoothedMap[entry.dateIso] = double.parse(currentEwma.toStringAsFixed(2));
    }

    final double latestRaw = sorted.last.weightKg;
    final double latestEwma = currentEwma;

    // Rate of change over available days (up to 7 entries)
    double weeklyChange = 0.0;
    if (sorted.length >= 2) {
      final int lookbackIdx = math.max(0, sorted.length - 7);
      final double pastEwma = smoothedMap[sorted[lookbackIdx].dateIso] ?? currentEwma;
      final int daysDiff = math.max(
        1,
        DateTime.parse(sorted.last.dateIso)
            .difference(DateTime.parse(sorted[lookbackIdx].dateIso))
            .inDays,
      );
      weeklyChange = ((latestEwma - pastEwma) / daysDiff) * 7.0;
    }

    final String direction;
    if (weeklyChange < -0.15) {
      direction = 'losing';
    } else if (weeklyChange > 0.15) {
      direction = 'gaining';
    } else {
      direction = 'stable';
    }

    return EWMAWeightTrend(
      latestRawKg: double.parse(latestRaw.toStringAsFixed(2)),
      currentEwmaKg: double.parse(latestEwma.toStringAsFixed(2)),
      weeklyRateOfChangeKg: double.parse(weeklyChange.toStringAsFixed(2)),
      trendDirection: direction,
      smoothedSeries: smoothedMap,
    );
  }

  /// Evaluates today's macro intake and returns non-judgmental Doctor/Trainer coaching.
  static List<DoctorTrainerInsight> analyzeDayBalance({
    required List<DietLogEntry> logs,
    required DailyTargets targets,
    required NutritionProfile profile,
    double loggedWaterMl = 0.0,
  }) {
    final List<DoctorTrainerInsight> insights = [];

    final double consumedKcal = logs.fold(0.0, (sum, e) => sum + e.kcal);
    final double consumedProtein = logs.fold(0.0, (sum, e) => sum + e.proteinG);
    final double consumedFibre = logs.fold(0.0, (sum, e) => sum + e.fibreG);

    final double remainingKcal = targets.targetKcal - consumedKcal;
    final double remainingProtein = targets.proteinG - consumedProtein;
    final double remainingFibre = targets.fibreG - consumedFibre;

    // 1. Protein Recovery Check (Gym Trainer Science)
    if (remainingProtein > 20.0) {
      insights.add(
        DoctorTrainerInsight(
          id: 'protein_boost',
          title: 'Muscle Recovery & Satiety',
          message:
              'You are ${remainingProtein.round()}g away from your protein target. Adding 2 boiled eggs, 100g paneer, 1 cup curd, or 1 katori sprouted moong to your next meal will optimize metabolic burn.',
          category: 'protein',
          suggestedFoodOrSwap: 'Boiled Eggs / Paneer / Moong Sprouts',
          actionPillText: '+ Add Protein Snack',
        ),
      );
    } else if (consumedProtein >= targets.proteinG) {
      insights.add(
        const DoctorTrainerInsight(
          id: 'protein_achieved',
          title: 'Protein Target Crushed!',
          message:
              'Great job hitting your amino acid baseline today! This supports lean tissue retention and post-workout muscle repair.',
          category: 'protein',
          actionPillText: '✓ Great Recovery',
        ),
      );
    }

    // 2. Fibre & Gut Microbiome Check (Medical Doctor Science)
    if (remainingFibre > 12.0) {
      insights.add(
        DoctorTrainerInsight(
          id: 'fibre_boost',
          title: 'Gut Health & Blood Sugar Balance',
          message:
              'Fibre is ${remainingFibre.round()}g below target. Pairing dinner with a vegetable thoran, cucumber-carrot salad, or swapping white rice for matta rice/oats promotes smooth digestion.',
          category: 'fibre',
          suggestedFoodOrSwap: 'Cucumber Salad / Vegetable Thoran',
          actionPillText: 'Suggest Veg Swap',
        ),
      );
    }

    // 3. Hydration Check
    final double waterDeficit = targets.waterMl - loggedWaterMl;
    if (waterDeficit > 800.0) {
      insights.add(
        DoctorTrainerInsight(
          id: 'hydration_reminder',
          title: 'Hydration Check',
          message:
              'You have ${waterDeficit.round()} ml remaining to reach optimal hydration. Consistent water intake prevents false hunger signals.',
          category: 'hydration',
          actionPillText: '+250ml Water',
        ),
      );
    }

    // 4. Over-Target Reassurance (Zero-Shame UX Law)
    if (remainingKcal < -200.0) {
      insights.add(
        DoctorTrainerInsight(
          id: 'non_shaming_surplus',
          title: 'Sustainable Nutrition Note',
          message:
              'You enjoyed ${(consumedKcal - targets.targetKcal).round()} kcal above target today. That is completely normal! True progress is built on multi-week consistency, not single-day restriction. Do not skip meals tomorrow; simply resume your normal balanced portions.',
          category: 'balance',
          actionPillText: 'Dismiss & Stay Consistent',
        ),
      );
    }

    return insights;
  }
}
