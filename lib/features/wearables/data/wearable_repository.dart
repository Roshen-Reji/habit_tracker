import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';

class WearableRepository {
  static const String dailyBoxName = 'wear_daily';
  static const String sleepBoxName = 'wear_sleep';
  static const String exerciseBoxName = 'wear_exercise';
  static const String bodyBoxName = 'wear_body';
  static const String energyBoxName = 'wear_energy';
  static const String agesBoxName = 'wear_ages';

  static final WearableRepository instance = WearableRepository._();
  WearableRepository._();
  factory WearableRepository() => instance;

  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(60))
      Hive.registerAdapter(DailyActivityAdapter());
    if (!Hive.isAdapterRegistered(61))
      Hive.registerAdapter(SleepSessionAdapter());
    if (!Hive.isAdapterRegistered(62))
      Hive.registerAdapter(ExerciseSessionAdapter());
    if (!Hive.isAdapterRegistered(63))
      Hive.registerAdapter(BodyCompSampleAdapter());
    if (!Hive.isAdapterRegistered(64))
      Hive.registerAdapter(EnergyScoreDayAdapter());
    if (!Hive.isAdapterRegistered(65))
      Hive.registerAdapter(AgesSampleAdapter());
  }

  static Future<void> openBoxes() async {
    registerAdapters();
    if (!Hive.isBoxOpen(dailyBoxName))
      await Hive.openBox<DailyActivity>(dailyBoxName);
    if (!Hive.isBoxOpen(sleepBoxName))
      await Hive.openBox<SleepSession>(sleepBoxName);
    if (!Hive.isBoxOpen(exerciseBoxName))
      await Hive.openBox<ExerciseSession>(exerciseBoxName);
    if (!Hive.isBoxOpen(bodyBoxName))
      await Hive.openBox<BodyCompSample>(bodyBoxName);
    if (!Hive.isBoxOpen(energyBoxName))
      await Hive.openBox<EnergyScoreDay>(energyBoxName);
    if (!Hive.isBoxOpen(agesBoxName))
      await Hive.openBox<AgesSample>(agesBoxName);
  }

  Box<DailyActivity> get dailyBox => Hive.box<DailyActivity>(dailyBoxName);
  Box<SleepSession> get sleepBox => Hive.box<SleepSession>(sleepBoxName);
  Box<ExerciseSession> get exerciseBox =>
      Hive.box<ExerciseSession>(exerciseBoxName);
  Box<BodyCompSample> get bodyBox => Hive.box<BodyCompSample>(bodyBoxName);
  Box<EnergyScoreDay> get energyBox => Hive.box<EnergyScoreDay>(energyBoxName);
  Box<AgesSample> get agesBox => Hive.box<AgesSample>(agesBoxName);

  // Daily Activity
  Future<void> upsertDaily(DailyActivity activity) async {
    await dailyBox.put(activity.dayKey, activity);
  }

  DailyActivity? getDaily(String dayKey) {
    if (!Hive.isBoxOpen(dailyBoxName)) return null;
    return dailyBox.get(dayKey);
  }

  // Sleep
  Future<void> upsertSleep(SleepSession session) async {
    await sleepBox.put(session.externalId, session);
  }

  List<SleepSession> getSleepForDay(String dayKey,
      {bool includeDeleted = false}) {
    if (!Hive.isBoxOpen(sleepBoxName)) return [];
    return sleepBox.values
        .where((s) => s.dayKey == dayKey && (includeDeleted || !s.deleted))
        .toList();
  }

  SleepSession? getMainSleep(String dayKey) {
    final list = getSleepForDay(dayKey).where((s) => !s.isNap).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.durationMin.compareTo(a.durationMin));
    return list.first;
  }

  // Exercise
  Future<void> upsertExercise(ExerciseSession session) async {
    await exerciseBox.put(session.externalId, session);
  }

  List<ExerciseSession> getExercisesForDay(String dayKey,
      {bool includeDeleted = false}) {
    if (!Hive.isBoxOpen(exerciseBoxName)) return [];
    return exerciseBox.values
        .where((e) => e.dayKey == dayKey && (includeDeleted || !e.deleted))
        .toList();
  }

  // Body Composition
  Future<void> upsertBodyComp(BodyCompSample sample) async {
    await bodyBox.put(sample.externalId, sample);
  }

  BodyCompSample? getLatestBodyComp() {
    if (!Hive.isBoxOpen(bodyBoxName)) return null;
    final list = bodyBox.values.where((b) => !b.deleted).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.first;
  }

  // Energy Score
  Future<void> upsertEnergyScore(EnergyScoreDay energy) async {
    await energyBox.put(energy.dayKey, energy);
  }

  EnergyScoreDay? getEnergyScore(String dayKey) {
    if (!Hive.isBoxOpen(energyBoxName)) return null;
    return energyBox.get(dayKey);
  }

  // AGEs Index
  Future<void> upsertAges(AgesSample sample) async {
    await agesBox.put(sample.id, sample);
  }

  AgesSample? getLatestAges() {
    if (!Hive.isBoxOpen(agesBoxName)) return null;
    final list = agesBox.values.toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.first;
  }

  /// P5-1: Combined day view for any dayKey
  WearableDayView dayView(String dayKey) {
    return WearableDayView(
      dayKey: dayKey,
      activity: getDaily(dayKey),
      mainSleep: getMainSleep(dayKey),
      allSleep: getSleepForDay(dayKey),
      exercises: getExercisesForDay(dayKey),
      energy: getEnergyScore(dayKey),
      bodyComp: getLatestBodyComp(),
      ages: getLatestAges(),
    );
  }
}

/// Consolidated day view containing all wearable metrics for a single date.
class WearableDayView {
  final String dayKey;
  final DailyActivity? activity;
  final SleepSession? mainSleep;
  final List<SleepSession> allSleep;
  final List<ExerciseSession> exercises;
  final EnergyScoreDay? energy;
  final BodyCompSample? bodyComp;
  final AgesSample? ages;

  WearableDayView({
    required this.dayKey,
    this.activity,
    this.mainSleep,
    this.allSleep = const [],
    this.exercises = const [],
    this.energy,
    this.bodyComp,
    this.ages,
  });

  int get totalSteps => activity?.steps ?? 0;
  double get totalActiveKcal => activity?.activeKcal ?? 0.0;
  int get activeMinutes => activity?.activeMinutes ?? 0;
  int? get sleepScore => mainSleep?.score;
  int? get sleepDurationMin => mainSleep?.durationMin;
  int? get energyScore => energy?.score;
  double? get agesScore => ages?.score;
  double? get latestWeight => bodyComp?.weightKg;
  int? get restingHeartRate => activity?.restingHr;
}
