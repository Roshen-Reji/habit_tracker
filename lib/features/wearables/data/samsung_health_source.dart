import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/features/wearables/data/wearable_source.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';

class SamsungHealthSource implements WearableSource {
  static const MethodChannel _channel = MethodChannel('habit/samsung_health');

  @override
  String get name => 'Samsung Health (Galaxy Watch)';

  @override
  Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMethod<Map>('isAvailable');
      return res?['isAvailable'] == true;
    } catch (e) {
      debugPrint('SamsungHealthSource.isAvailable error: $e');
      return false;
    }
  }

  @override
  Future<Map<String, bool>> checkPermissions() async {
    try {
      final res = await _channel.invokeMethod<Map>('checkPermissions');
      if (res == null) return {};
      return res.map((key, value) => MapEntry(key.toString(), value == true));
    } catch (e) {
      debugPrint('SamsungHealthSource.checkPermissions error: $e');
      return {};
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermissions');
      return res == true;
    } catch (e) {
      debugPrint('SamsungHealthSource.requestPermissions error: $e');
      return false;
    }
  }

  @override
  Future<bool> openExternalApp() async {
    try {
      final res = await _channel.invokeMethod<bool>('openSamsungHealth');
      return res == true;
    } catch (e) {
      debugPrint('SamsungHealthSource.openExternalApp error: $e');
      return false;
    }
  }

  @override
  Future<List<DailyActivity>> fetchDailyActivity(int days) async {
    try {
      final res = await _channel.invokeListMethod<Map>('readDailyActivity', {'days': days});
      if (res == null) return [];
      return res.map((m) {
        return DailyActivity(
          dayKey: m['dayKey'].toString(),
          steps: (m['steps'] as num?)?.toInt() ?? 0,
          distanceM: (m['distanceMeters'] as num?)?.toDouble(),
          totalKcal: (m['totalBurnedCalories'] as num?)?.toDouble(),
          activeKcal: (m['activeCalories'] as num?)?.toDouble() ??
              ((m['totalBurnedCalories'] as num?)?.toDouble() != null
                  ? ((m['totalBurnedCalories'] as num)!.toDouble() * 0.35)
                  : null),
          activeMinutes: (m['activeMinutes'] as num?)?.toInt(),
          sourceNote: m['source']?.toString() ?? 'samsung_health',
        );
      }).toList();
    } catch (e) {
      debugPrint('SamsungHealthSource.fetchDailyActivity error: $e');
      return [];
    }
  }

  @override
  Future<List<SleepSession>> fetchSleepSessions(int days) async {
    try {
      final res = await _channel.invokeListMethod<Map>('readSleep', {'days': days});
      if (res == null) return [];
      return res.map((m) {
        final startMs = (m['startTime'] as num).toInt();
        final endMs = (m['endTime'] as num).toInt();
        return SleepSession(
          externalId: m['id']?.toString() ?? 'shealth_sleep_$startMs',
          dayKey: m['dayKey'].toString(),
          start: DateTime.fromMillisecondsSinceEpoch(startMs),
          end: DateTime.fromMillisecondsSinceEpoch(endMs),
          durationMin: (m['totalMinutes'] as num?)?.toInt() ?? ((endMs - startMs) ~/ 60000),
          awakeMin: (m['wakeMinutes'] as num?)?.toInt(),
          lightMin: (m['lightMinutes'] as num?)?.toInt(),
          deepMin: (m['deepMinutes'] as num?)?.toInt(),
          remMin: (m['remMinutes'] as num?)?.toInt(),
          score: (m['sleepScore'] as num?)?.toInt(),
          efficiency: (m['efficiency'] as num?)?.toDouble(),
          sourceDevice: m['source']?.toString() ?? 'samsung_health',
        );
      }).toList();
    } catch (e) {
      debugPrint('SamsungHealthSource.fetchSleepSessions error: $e');
      return [];
    }
  }

  @override
  Future<List<ExerciseSession>> fetchExercises(int days) async {
    try {
      final res = await _channel.invokeListMethod<Map>('readExercises', {'days': days});
      if (res == null) return [];
      return res.map((m) {
        final startMs = (m['startTime'] as num).toInt();
        final endMs = (m['endTime'] as num).toInt();
        final durMin = ((endMs - startMs) ~/ 60000).clamp(1, 1440);
        return ExerciseSession(
          externalId: m['id']?.toString() ?? 'shealth_workout_$startMs',
          dayKey: m['dayKey'].toString(),
          type: m['exerciseType']?.toString() ?? 'Workout',
          title: m['title']?.toString() ?? m['exerciseType']?.toString() ?? 'Workout',
          start: DateTime.fromMillisecondsSinceEpoch(startMs),
          end: DateTime.fromMillisecondsSinceEpoch(endMs),
          durationMin: durMin,
          totalKcal: (m['calories'] as num?)?.toDouble(),
          activeKcal: (m['calories'] as num?)?.toDouble(),
          avgHr: (m['avgHeartRate'] as num?)?.toInt(),
          maxHr: (m['maxHeartRate'] as num?)?.toInt(),
          distanceM: (m['distanceMeters'] as num?)?.toDouble(),
          sourceDevice: m['source']?.toString() ?? 'samsung_health',
        );
      }).toList();
    } catch (e) {
      debugPrint('SamsungHealthSource.fetchExercises error: $e');
      return [];
    }
  }

  @override
  Future<List<BodyCompSample>> fetchBodyComposition(int days) async {
    try {
      final res = await _channel.invokeListMethod<Map>('readBodyComposition', {'days': days});
      if (res == null) return [];
      return res.map((m) {
        final ts = (m['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        return BodyCompSample(
          externalId: m['id']?.toString() ?? 'shealth_bcomp_$ts',
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          weightKg: (m['weightKg'] as num?)?.toDouble(),
          bodyFatPct: (m['bodyFatPercent'] as num?)?.toDouble(),
          skeletalMuscleMassKg: (m['skeletalMuscleMassKg'] as num?)?.toDouble(),
          bodyFatMassKg: (m['fatMassKg'] as num?)?.toDouble(),
          bodyWaterPct: (m['totalBodyWaterKg'] as num?)?.toDouble(),
          bmi: (m['bmi'] as num?)?.toDouble(),
          bmrKcal: (m['bmrKcal'] as num?)?.toDouble(),
          sourceDevice: m['source']?.toString() ?? 'samsung_health',
        );
      }).toList();
    } catch (e) {
      debugPrint('SamsungHealthSource.fetchBodyComposition error: $e');
      return [];
    }
  }

  @override
  Future<List<EnergyScoreDay>> fetchEnergyScores(int days) async {
    try {
      final res = await _channel.invokeListMethod<Map>('readEnergyScore', {'days': days});
      if (res == null) return [];
      return res.map((m) {
        return EnergyScoreDay(
          dayKey: m['dayKey'].toString(),
          score: (m['score'] as num?)?.toInt() ?? 75,
          extraJson: jsonEncode(m),
        );
      }).toList();
    } catch (e) {
      debugPrint('SamsungHealthSource.fetchEnergyScores error: $e');
      return [];
    }
  }

  @override
  Future<List<AgesSample>> fetchAgesSamples(int days) async {
    try {
      final res = await _channel.invokeListMethod<Map>('readAgesIndex', {'days': days});
      if (res == null) return [];
      return res.map((m) {
        final ts = (m['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        return AgesSample(
          id: m['id']?.toString() ?? 'shealth_ages_$ts',
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          score: (m['score'] as num?)?.toDouble() ?? 45.0,
          sourceDevice: m['source']?.toString() ?? 'samsung_health',
          extraJson: jsonEncode(m),
        );
      }).toList();
    } catch (e) {
      debugPrint('SamsungHealthSource.fetchAgesSamples error: $e');
      return [];
    }
  }
}
