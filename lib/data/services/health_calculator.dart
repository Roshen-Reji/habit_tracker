import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class HealthSummaryData {
  final double? latestWeightKg;
  final double? startWeightKg;
  final double? goalWeightKg;
  final String weightUnit;
  final double consumedCalories;
  final double burnedCalories;
  final double netCalories;
  final double calorieTarget;
  final int medicineTakenToday;
  final int medicineTotalToday;
  final int healthMissionsCompletedToday;
  final int healthMissionsTotalToday;
  final int? sleepDurationMin;
  final int? steps;

  const HealthSummaryData({
    this.latestWeightKg,
    this.startWeightKg,
    this.goalWeightKg,
    this.weightUnit = 'kg',
    required this.consumedCalories,
    required this.burnedCalories,
    required this.netCalories,
    required this.calorieTarget,
    required this.medicineTakenToday,
    required this.medicineTotalToday,
    required this.healthMissionsCompletedToday,
    required this.healthMissionsTotalToday,
    this.sleepDurationMin,
    this.steps,
  });

  /// Computes a composite health score from 0 to 100 based on nutrition, adherence,
  /// missions, sleep duration, and activity.
  double get compositeScore {
    double score = 0.0;

    // 1. Calorie adherence (25 pts)
    if (calorieTarget > 0) {
      final ratio = netCalories / calorieTarget;
      if (ratio >= 0.8 && ratio <= 1.05) {
        score += 25.0;
      } else if (ratio > 0.5 && ratio < 1.3) {
        score += 18.0;
      } else if (ratio > 0) {
        score += 10.0;
      }
    } else {
      score += 25.0;
    }

    // 2. Medicine adherence (20 pts)
    if (medicineTotalToday > 0) {
      final medRatio =
          (medicineTakenToday / medicineTotalToday).clamp(0.0, 1.0);
      score += medRatio * 20.0;
    } else {
      score += 20.0;
    }

    // 3. Health & Wake missions (15 pts)
    if (healthMissionsTotalToday > 0) {
      final missionRatio =
          (healthMissionsCompletedToday / healthMissionsTotalToday)
              .clamp(0.0, 1.0);
      score += missionRatio * 15.0;
    } else {
      score += 15.0;
    }

    // 4. Sleep duration (20 pts) - Target 7-9 hours (420-540 mins)
    if (sleepDurationMin != null && sleepDurationMin! > 0) {
      if (sleepDurationMin! >= 420 && sleepDurationMin! <= 540) {
        score += 20.0;
      } else if (sleepDurationMin! >= 360) {
        score += 15.0;
      } else if (sleepDurationMin! >= 300) {
        score += 10.0;
      } else {
        score += 5.0;
      }
    } else {
      score += 10.0;
    }

    // 5. Activity (20 pts) - Target 8000+ steps
    if (steps != null && steps! > 0) {
      if (steps! >= 8000) {
        score += 20.0;
      } else if (steps! >= 5000) {
        score += 15.0;
      } else if (steps! >= 3000) {
        score += 10.0;
      } else {
        score += 5.0;
      }
    } else {
      score += 10.0;
    }

    return score.clamp(0.0, 100.0);
  }
}

class HealthCalculator {
  /// Pure composite function over data or active Hive boxes
  static HealthSummaryData computeSummary({
    DateTime? now,
    List<WeightEntry>? weights,
    DietDayLog? dietLog,
    double? calorieTarget,
    MedicineDailyStats? medStats,
    List<Goal>? goals,
    Map<dynamic, dynamic>? settingsMap,
  }) {
    final current = now ?? DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(current);

    // 1. Weights
    final weightList = weights ??
        (Hive.isBoxOpen('weight_entries')
            ? Hive.box<WeightEntry>('weight_entries').values.toList()
            : <WeightEntry>[]);
    weightList.sort((a, b) => a.date.compareTo(b.date));
    final latestWeight = weightList.isNotEmpty ? weightList.last.kg : null;

    final settings = settingsMap ??
        (Hive.isBoxOpen('settings') ? Hive.box('settings').toMap() : {});

    final startWeight = (settings['weight_start'] as num?)?.toDouble();
    final goalWeight = (settings['weight_goal'] as num?)?.toDouble();
    final unit = settings['weight_unit']?.toString() ?? 'kg';

    // 2. Diet & Calories
    final log = dietLog ??
        (Hive.isBoxOpen('diet_logs')
            ? Hive.box<DietDayLog>('diet_logs').get(todayKey)
            : null);
    final target = calorieTarget ??
        (settings['daily_calorie_target'] as num?)?.toDouble() ??
        2000.0;

    final consumed = log?.totalCalories ?? 0.0;
    final burned = log?.totalBurned ?? 0.0;
    final net = consumed - burned;

    // 3. Medicine
    final medicineStats =
        medStats ?? MedicineService.getDailyStats(now: current);

    // 4. Health missions
    final goalList = goals ??
        (Hive.isBoxOpen('mission_box_v4')
            ? Hive.box<Goal>('mission_box_v4').values.toList()
            : <Goal>[]);

    final healthGoals = goalList
        .where((g) =>
            g.category == GoalCategory.health && g.type == GoalType.daily)
        .toList();

    final completedHealth = healthGoals.where((g) => g.isCompleted).length;

    // 5. Wearables (Sleep, Steps)
    int? sleepDurationMin;
    int? steps;

    if (Hive.isBoxOpen(WearableRepository.sleepBoxName)) {
      final sleep = WearableRepository.instance.getMainSleep(todayKey);
      sleepDurationMin = sleep?.durationMin;
    }
    if (Hive.isBoxOpen(WearableRepository.dailyBoxName)) {
      final daily = WearableRepository.instance.getDaily(todayKey);
      steps = daily?.steps;
    }

    return HealthSummaryData(
      latestWeightKg: latestWeight,
      startWeightKg: startWeight,
      goalWeightKg: goalWeight,
      weightUnit: unit,
      consumedCalories: consumed,
      burnedCalories: burned,
      netCalories: net,
      calorieTarget: target,
      medicineTakenToday: medicineStats.takenDosesToday,
      medicineTotalToday: medicineStats.totalDosesToday,
      healthMissionsCompletedToday: completedHealth,
      healthMissionsTotalToday: healthGoals.length,
      sleepDurationMin: sleepDurationMin,
      steps: steps,
    );
  }
}
