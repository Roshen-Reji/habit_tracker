import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:habit_tracker/features/wearables/data/wearable_source.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';

class MockWearableSource implements WearableSource {
  @override
  String get name => 'Galaxy Watch 7 (Simulator)';

  @override
  String get sourceId => 'mock';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, bool>> checkPermissions() async {
    return {
      'activity': true,
      'sleep': true,
      'exercise': true,
      'body_composition': true,
      'energy_score': true,
      'ages_index': true,
    };
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> openExternalApp() async => true;

  @override
  Future<List<DailyActivity>> fetchDailyActivity(int days) async {
    final list = <DailyActivity>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      final steps = 7800 + ((date.day * 373) % 4500);
      final totalKcal = 1950.0 + ((date.day * 43) % 550);
      final activeKcal = 420.0 + ((date.day * 29) % 320);
      final activeMin = 45 + ((date.day * 7) % 45);
      final distM = steps * 0.76;

      list.add(
        DailyActivity(
          dayKey: dayKey,
          steps: steps,
          distanceM: distM,
          totalKcal: totalKcal,
          activeKcal: activeKcal,
          activeMinutes: activeMin,
          floors: 8 + (date.day % 12),
          restingHr: 58 + (date.day % 8),
          avgHr: 72 + (date.day % 14),
          spo2Avg: 97.5 + (date.day % 3) * 0.5,
          stepGoal: 10000,
          activeKcalGoal: 500,
          sourceNote: 'Galaxy Watch 7 (Mock)',
        ),
      );
    }
    return list;
  }

  @override
  Future<List<SleepSession>> fetchSleepSessions(int days) async {
    final list = <SleepSession>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);

      // Sleep from 23:15 previous night to ~06:30 morning
      final sleepStart = DateTime(date.year, date.month, date.day - 1, 23, 15);
      final sleepEnd = DateTime(date.year, date.month, date.day, 6, 25 + (date.day % 20));
      final durationMin = sleepEnd.difference(sleepStart).inMinutes;

      final deep = 85 + (date.day * 5) % 40;
      final rem = 90 + (date.day * 3) % 35;
      final awake = 20 + (date.day * 2) % 20;
      final light = durationMin - (deep + rem + awake);
      final score = (78 + (date.day * 3) % 19).clamp(65, 96);

      list.add(
        SleepSession(
          externalId: 'mock_sleep_$dayKey',
          dayKey: dayKey,
          start: sleepStart,
          end: sleepEnd,
          durationMin: durationMin,
          awakeMin: awake,
          lightMin: light,
          deepMin: deep,
          remMin: rem,
          score: score,
          efficiency: 0.92,
          isNap: false,
          sourceDevice: 'Galaxy Watch 7',
        ),
      );
    }
    return list;
  }

  @override
  Future<List<ExerciseSession>> fetchExercises(int days) async {
    final list = <ExerciseSession>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      // 5 out of 7 days have a workout
      if (i % 3 == 2) continue;

      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      final isRunning = i % 2 == 0;

      final start = DateTime(date.year, date.month, date.day, 17, 30);
      final end = start.add(Duration(minutes: isRunning ? 38 : 50));
      final durMin = end.difference(start).inMinutes;
      final kcal = isRunning ? 320.0 + (date.day % 80) : 260.0 + (date.day % 60);

      list.add(
        ExerciseSession(
          externalId: 'mock_workout_$dayKey',
          dayKey: dayKey,
          type: isRunning ? 'Running' : 'Strength Training',
          title: isRunning ? 'Evening Outdoor Run' : 'Upper Body Strength',
          start: start,
          end: end,
          durationMin: durMin,
          totalKcal: kcal,
          activeKcal: kcal,
          avgHr: isRunning ? 144 : 126,
          maxHr: isRunning ? 172 : 152,
          distanceM: isRunning ? 4850.0 : null,
          sourceDevice: 'Galaxy Watch 7',
        ),
      );
    }
    return list;
  }

  @override
  Future<List<BodyCompSample>> fetchBodyComposition(int days) async {
    final list = <BodyCompSample>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i += 3) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);

      list.add(
        BodyCompSample(
          externalId: 'mock_bcomp_$dayKey',
          timestamp: DateTime(date.year, date.month, date.day, 7, 30),
          weightKg: 72.4 + (date.day % 5) * 0.1,
          bodyFatPct: 16.8 + (date.day % 3) * 0.2,
          skeletalMuscleMassKg: 35.1,
          bodyFatMassKg: 12.1,
          bodyWaterPct: 58.4,
          bmi: 22.8,
          bmrKcal: 1690.0,
          sourceDevice: 'Galaxy Watch 7 BioActive BIA',
        ),
      );
    }
    return list;
  }

  @override
  Future<List<EnergyScoreDay>> fetchEnergyScores(int days) async {
    final list = <EnergyScoreDay>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      final score = (83 - (date.day % 16)).clamp(68, 95);

      final extra = {
        'dayKey': dayKey,
        'score': score,
        'evaluation': score >= 80 ? 'Optimal' : (score >= 70 ? 'Good' : 'Needs Rest'),
        'sleepScoreAvg': 82.0 + (date.day % 8),
        'activityScore': 79.0 + (date.day % 12),
        'sleepHrScore': 85.0,
        'sleepHrvScore': 81.0,
      };

      list.add(
        EnergyScoreDay(
          dayKey: dayKey,
          score: score,
          extraJson: jsonEncode(extra),
        ),
      );
    }
    return list;
  }

  @override
  Future<List<AgesSample>> fetchAgesSamples(int days) async {
    final list = <AgesSample>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);

      // AGEs scores typically range around 40-55 on Samsung Health
      final score = 42.0 + (date.day % 11) * 0.8;
      final level = score < 45.0 ? 'low' : (score < 52.0 ? 'optimal' : 'medium');
      final trend = score < 46.0 ? 'improving' : 'stable';

      final extra = {
        'dayKey': dayKey,
        'score': score,
        'level': level,
        'trend': trend,
        'description': 'Measured by Galaxy Watch 7 BioActive Sensor during deep sleep.',
        'recommendation': 'Maintain antioxidant intake and consistent sleep to support cellular longevity.',
      };

      list.add(
        AgesSample(
          id: 'mock_ages_$dayKey',
          timestamp: DateTime(date.year, date.month, date.day, 6, 30),
          score: score,
          sourceDevice: 'Galaxy Watch 7 BioActive',
          extraJson: jsonEncode(extra),
        ),
      );
    }
    return list;
  }
}
