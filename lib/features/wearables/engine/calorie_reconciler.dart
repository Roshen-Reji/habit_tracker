import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/features/wearables/models/exercise_session.dart';

class CalorieReconcileResult {
  final List<CalorieBurnEntry> entries;
  final bool modified;
  final int addedCount;
  final int supersededCount;

  CalorieReconcileResult({
    required this.entries,
    required this.modified,
    required this.addedCount,
    required this.supersededCount,
  });
}

class CalorieReconciler {
  /// Pure function to reconcile watch workout sessions into diet burn entries.
  /// - Modes: 'workouts_only' (default), 'none'
  /// - Deduplicates against manual entries within +/- 30 mins OR matching activity name with duration within 25%.
  /// - Sets `supersededBy = session.externalId` on matched manual entries without deleting them.
  /// - Restores `supersededBy = null` if the corresponding watch session is removed.
  static CalorieReconcileResult reconcileWorkouts({
    required List<CalorieBurnEntry> currentEntries,
    required List<ExerciseSession> sessions,
    String creditMode = 'workouts_only',
  }) {
    if (creditMode == 'none') {
      return CalorieReconcileResult(
        entries: currentEntries,
        modified: false,
        addedCount: 0,
        supersededCount: 0,
      );
    }

    final entries = List<CalorieBurnEntry>.from(currentEntries);
    bool modified = false;
    int addedCount = 0;
    int supersededCount = 0;

    final sessionExternalIds = sessions.map((s) => s.externalId).toSet();

    // 1. Restore any superseded entries whose source session no longer exists
    for (final entry in entries) {
      if (entry.supersededBy != null && !sessionExternalIds.contains(entry.supersededBy)) {
        entry.supersededBy = null;
        modified = true;
      }
    }

    // 2. Process each watch exercise session
    for (final session in sessions) {
      final watchEntryId = 'health_${session.externalId}';
      final kcal = session.totalKcal ?? session.activeKcal ?? 0.0;
      final sessionName = (session.title ?? session.type).trim().toLowerCase();

      final existingIdx = entries.indexWhere(
        (e) => e.id == watchEntryId || e.externalId == session.externalId,
      );

      if (existingIdx != -1) {
        // Already exists: update values if revised
        final existing = entries[existingIdx];
        if (existing.caloriesBurned != kcal || existing.durationMinutes != session.durationMin) {
          existing.caloriesBurned = kcal;
          existing.durationMinutes = session.durationMin;
          existing.activity = session.title ?? session.type;
          modified = true;
        }
      } else {
        // De-dup against manual entries
        for (final manual in entries) {
          final isWearable = manual.source == 'health_connect' || manual.source == 'samsung_health' || manual.source == 'wearable';
          if (!isWearable && manual.supersededBy == null) {
            final timeDiffMin = manual.timestamp.difference(session.start).inMinutes.abs();
            final manualName = manual.activity.trim().toLowerCase();
            final durDiffRatio = session.durationMin > 0
                ? (manual.durationMinutes - session.durationMin).abs() / session.durationMin
                : 1.0;

            final timeMatches = timeDiffMin <= 30;
            final activityAndDurationMatches = manualName == sessionName && durDiffRatio <= 0.25;

            if (timeMatches || activityAndDurationMatches) {
              manual.supersededBy = session.externalId;
              modified = true;
              supersededCount++;
            }
          }
        }

        // Add the wearable burn entry
        entries.add(
          CalorieBurnEntry(
            id: watchEntryId,
            activity: session.title ?? session.type,
            caloriesBurned: kcal,
            durationMinutes: session.durationMin,
            timestamp: session.start,
            source: 'health_connect',
            externalId: session.externalId,
          ),
        );
        modified = true;
        addedCount++;
      }
    }

    return CalorieReconcileResult(
      entries: entries,
      modified: modified,
      addedCount: addedCount,
      supersededCount: supersededCount,
    );
  }

  /// Calculates suggested calorie target using the Mifflin-St Jeor equation.
  static double? calculateMifflinStJeorTarget({
    required String? sex, // 'male' or 'female'
    required DateTime? dob,
    required double? heightCm,
    required double? weightKg,
    double activityMultiplier = 1.375, // Lightly active default
    int deficitKcal = 500,
  }) {
    if (sex == null || dob == null || heightCm == null || weightKg == null) {
      return null;
    }

    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    if (age <= 0 || heightCm <= 0 || weightKg <= 0) return null;

    double bmr;
    if (sex.toLowerCase().startsWith('m')) {
      // Men: 10 * weight + 6.25 * height - 5 * age + 5
      bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age + 5.0;
    } else {
      // Women: 10 * weight + 6.25 * height - 5 * age - 161
      bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age - 161.0;
    }

    final tdee = bmr * activityMultiplier;
    final target = tdee - deficitKcal;
    return target.clamp(1200.0, 4500.0);
  }
}
