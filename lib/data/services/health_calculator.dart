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
  final int? sleepScore;
  final double? agesScore;
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
    this.sleepScore,
    this.agesScore,
    this.steps,
  });

  /// Computes a composite health score from 0 to 100 based on nutrition, adherence,
  /// missions, and Galaxy Watch 7 sleep + Samsung Health AGEs index when available.
  double get compositeScore {
    // If no wearable sleep/AGEs data, use classic 35 / 35 / 30 model
    if (sleepScore == null && agesScore == null) {
      double score = 0.0;
      if (calorieTarget > 0) {
        final ratio = netCalories / calorieTarget;
        if (ratio >= 0.8 && ratio <= 1.05) {
          score += 35.0;
        } else if (ratio > 0.5 && ratio < 1.3) {
          score += 25.0;
        } else if (ratio > 0) {
          score += 15.0;
        }
      } else {
        score += 35.0;
      }

      if (medicineTotalToday > 0) {
        final medRatio =
            (medicineTakenToday / medicineTotalToday).clamp(0.0, 1.0);
        score += medRatio * 35.0;
      } else {
        score += 35.0;
      }

      if (healthMissionsTotalToday > 0) {
        final missionRatio =
            (healthMissionsCompletedToday / healthMissionsTotalToday)
                .clamp(0.0, 1.0);
        score += missionRatio * 30.0;
      } else {
        score += 30.0;
      }

      return score.clamp(0.0, 100.0);
    }

    // Wearable-enhanced composite score (100 pts)
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

    // 2. Medicine adherence (25 pts)
    if (medicineTotalToday > 0) {
      final medRatio =
          (medicineTakenToday / medicineTotalToday).clamp(0.0, 1.0);
      score += medRatio * 25.0;
    } else {
      score += 25.0;
    }

    // 3. Health & Wake missions (20 pts)
    if (healthMissionsTotalToday > 0) {
      final missionRatio =
          (healthMissionsCompletedToday / healthMissionsTotalToday)
              .clamp(0.0, 1.0);
      score += missionRatio * 20.0;
    } else {
      score += 20.0;
    }

    // 4. Galaxy Watch Sleep Score (15 pts)
    if (sleepScore != null) {
      final sleepRatio = (sleepScore! / 100.0).clamp(0.0, 1.0);
      score += sleepRatio * 15.0;
    } else {
      score += 12.0;
    }

    // 5. Samsung Health AGEs Index / Longevity (15 pts)
    if (agesScore != null) {
      if (agesScore! <= 45.0) {
        score += 15.0;
      } else if (agesScore! <= 52.0) {
        score += 12.0;
      } else if (agesScore! <= 60.0) {
        score += 8.0;
      } else {
        score += 5.0;
      }
    } else {
      score += 12.0;
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

    // 5. Wearables (Sleep, AGEs, Steps)
    int? sleepScore;
    double? agesScore;
    int? steps;

    if (Hive.isBoxOpen(WearableRepository.sleepBoxName)) {
      final sleep = WearableRepository.instance.getMainSleep(todayKey);
      sleepScore = sleep?.score;
    }
    if (Hive.isBoxOpen(WearableRepository.agesBoxName)) {
      final ages = WearableRepository.instance.getLatestAges();
      agesScore = ages?.score;
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
      sleepScore: sleepScore,
      agesScore: agesScore,
      steps: steps,
    );
  }
}
