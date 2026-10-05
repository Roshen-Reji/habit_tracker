import 'package:habit_tracker/features/wearables/models/models.dart';

abstract class WearableSource {
  String get name;
  String get sourceId;

  Future<bool> isAvailable();

  Future<Map<String, bool>> checkPermissions();

  Future<bool> requestPermissions();

  Future<bool> openExternalApp();

  Future<List<DailyActivity>> fetchDailyActivity(int days);

  Future<List<SleepSession>> fetchSleepSessions(int days);

  Future<List<ExerciseSession>> fetchExercises(int days);

  Future<List<BodyCompSample>> fetchBodyComposition(int days);

  Future<List<EnergyScoreDay>> fetchEnergyScores(int days);

  Future<List<AgesSample>> fetchAgesSamples(int days);
}
