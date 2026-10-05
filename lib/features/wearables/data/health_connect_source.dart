import 'dart:io';
import 'package:health/health.dart';
import 'package:habit_tracker/features/wearables/data/wearable_source.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';
import 'package:intl/intl.dart';

class HealthConnectSource implements WearableSource {
  final Health _health = Health();

  @override
  String get name => 'Health Connect';

  @override
  String get sourceId => 'health_connect';

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    // We check if health connect is installed and available
    // health package handles Android 14+ natively and <14 via APK
    return true; // We'll manage availability via permissions/status
  }

  @override
  Future<Map<String, bool>> checkPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.WORKOUT,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.WEIGHT,
      HealthDataType.BODY_FAT_PERCENTAGE,
    ];
    final hasPermissions = await _health.hasPermissions(types) ?? false;
    return {
      'all': hasPermissions,
    };
  }

  @override
  Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.WORKOUT,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.WEIGHT,
      HealthDataType.BODY_FAT_PERCENTAGE,
    ];
    try {
      return await _health.requestAuthorization(types);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> openExternalApp() async {
    // There is no openExternalApp for Health Connect from the plugin directly that we need,
    // but we can try to launch the Health Connect settings using Android intent if needed.
    return false;
  }

  @override
  Future<List<DailyActivity>> fetchDailyActivity(int days) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final List<DailyActivity> list = [];

    // health package aggregate calls per day
    for (int i = 0; i <= days; i++) {
      final day = now.subtract(Duration(days: i));
      final midnight = DateTime(day.year, day.month, day.day);
      final nextMidnight = midnight.add(const Duration(days: 1));
      
      final steps = await _health.getTotalStepsInInterval(midnight, nextMidnight);
      
      final healthData = await _health.getHealthDataFromTypes(
        startTime: midnight, 
        endTime: nextMidnight, 
        types: [
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.ACTIVE_ENERGY_BURNED,
        ],
      );

      double distance = 0.0;
      double activeEnergy = 0.0;
      for (final d in healthData) {
        if (d.type == HealthDataType.DISTANCE_DELTA) {
          distance += (d.value as NumericHealthValue).numericValue.toDouble();
        } else if (d.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          activeEnergy += (d.value as NumericHealthValue).numericValue.toDouble();
        }
      }

      list.add(DailyActivity(
        dayKey: DateFormat('yyyy-MM-dd').format(midnight),
        steps: steps ?? 0,
        distanceM: distance > 0 ? distance : null,
        activeKcal: activeEnergy > 0 ? activeEnergy : null,
      ));
    }

    return list;
  }

  @override
  Future<List<SleepSession>> fetchSleepSessions(int days) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    
    final healthData = await _health.getHealthDataFromTypes(
      startTime: start, 
      endTime: now, 
      types: [HealthDataType.SLEEP_SESSION],
    );

    final List<SleepSession> list = [];
    for (final d in healthData) {
      final duration = d.dateTo.difference(d.dateFrom).inMinutes;
      final dayKey = DateFormat('yyyy-MM-dd').format(d.dateTo); // Day is local date of session end
      
      list.add(SleepSession(
        externalId: d.uuid,
        dayKey: dayKey,
        start: d.dateFrom,
        end: d.dateTo,
        durationMin: duration,
        isNap: duration < 180, // rough heuristic or rely on stages if provided
        score: null, // Health Connect does not provide a score directly
        sourceDevice: d.sourceId,
      ));
    }
    return list;
  }

  @override
  Future<List<ExerciseSession>> fetchExercises(int days) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    
    final healthData = await _health.getHealthDataFromTypes(
      startTime: start, 
      endTime: now, 
      types: [HealthDataType.WORKOUT],
    );

    final List<ExerciseSession> list = [];
    for (final d in healthData) {
      final duration = d.dateTo.difference(d.dateFrom).inMinutes;
      final dayKey = DateFormat('yyyy-MM-dd').format(d.dateFrom);
      
      double? activeKcal;
      double? distance;
      // Health Connect exercise session might contain these if we query the session details,
      // but in flutter_health, the value might be a WorkoutHealthValue
      if (d.value is WorkoutHealthValue) {
        final wv = d.value as WorkoutHealthValue;
        activeKcal = wv.totalEnergyBurned != null ? wv.totalEnergyBurned!.toDouble() : null;
        distance = wv.totalDistance != null ? wv.totalDistance!.toDouble() : null;
      }

      list.add(ExerciseSession(
        externalId: d.uuid,
        dayKey: dayKey,
        type: d.typeString,
        title: d.typeString,
        start: d.dateFrom,
        end: d.dateTo,
        durationMin: duration,
        activeKcal: activeKcal,
        distanceM: distance,
        sourceDevice: d.sourceId,
      ));
    }
    return list;
  }

  @override
  Future<List<BodyCompSample>> fetchBodyComposition(int days) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    
    final healthData = await _health.getHealthDataFromTypes(
      startTime: start, 
      endTime: now, 
      types: [HealthDataType.WEIGHT, HealthDataType.BODY_FAT_PERCENTAGE],
    );

    final byDay = <String, BodyCompSample>{};
    for (final d in healthData) {
      final dayKey = DateFormat('yyyy-MM-dd').format(d.dateFrom);
      final existing = byDay[dayKey] ?? BodyCompSample(
        externalId: d.uuid,
        timestamp: d.dateFrom,
        sourceDevice: d.sourceId,
      );

      if (d.type == HealthDataType.WEIGHT) {
        existing.weightKg = (d.value as NumericHealthValue).numericValue.toDouble();
      } else if (d.type == HealthDataType.BODY_FAT_PERCENTAGE) {
        existing.bodyFatPct = (d.value as NumericHealthValue).numericValue.toDouble();
      }
      
      byDay[dayKey] = existing;
    }
    
    return byDay.values.toList();
  }
}
