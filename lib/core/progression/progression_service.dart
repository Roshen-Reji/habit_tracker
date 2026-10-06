import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:habit_tracker/core/progression/progression_engine.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/user_rank.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProgressionService {
  static final ValueNotifier<UserRank> _rankNotifier = ValueNotifier<UserRank>(
    UserRank(
      title: 'RECRUIT',
      position: 'UNASSIGNED',
      level: 1,
      progressToNext: 0.0,
      totalXp: 0,
    ),
  );

  static ValueListenable<UserRank> get rankListenable => _rankNotifier;
  static UserRank get currentRank => _rankNotifier.value;

  static bool _initialized = false;

  /// Initializes the progression service, runs the one-time migration if needed,
  /// and listens to changes on the settings and mission boxes.
  static void init() {
    if (_initialized) {
      refresh();
      return;
    }
    _initialized = true;

    _migrateIfNeeded();
    refresh();

    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').listenable(keys: ['global_xp']).addListener(refresh);
    }
    if (Hive.isBoxOpen('mission_box_v4')) {
      Hive.box<Goal>('mission_box_v4').listenable().addListener(refresh);
    }
  }

  /// One-time idempotent migration (P5-3).
  /// Ensures existing users whose level was based on goals do not lose XP.
  static void _migrateIfNeeded() {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    final alreadyMigrated = settings.get('progression_v2', defaultValue: false);
    if (alreadyMigrated == true) return;

    double legacy = 0;
    if (Hive.isBoxOpen('mission_box_v4')) {
      final goals = Hive.box<Goal>('mission_box_v4').values;
      for (final goal in goals) {
        final double weight = goal.type == GoalType.monthly
            ? 50.0
            : (goal.type == GoalType.weekly ? 20.0 : 5.0);
        if (goal.isCompleted) {
          legacy += weight;
        }
        legacy += (goal.streakCount * (weight * 0.1));
      }
    }

    final int legacyXp = legacy.toInt();
    final int currentGlobal = settings.get('global_xp', defaultValue: 0) as int;

    // Persist backup JSON
    final backup = {
      'prev_global_xp': currentGlobal,
      'legacy_xp': legacyXp,
      'migrated_at': DateTime.now().toIso8601String(),
    };
    settings.put('progression_v2_backup', jsonEncode(backup));

    final mergedXp = math.max(currentGlobal, legacyXp);
    settings.put('global_xp', mergedXp);
    settings.put('progression_v2', true);
  }

  /// Recomputes current progression and rank from Hive data.
  static void refresh() {
    int totalXp = 0;
    if (Hive.isBoxOpen('settings')) {
      totalXp = Hive.box('settings').get('global_xp', defaultValue: 0) as int;
    }

    final progression = ProgressionEngine.calculate(totalXp);
    final position = _calculatePositionFromGoals();

    _rankNotifier.value = UserRank(
      title: progression.rankTitle,
      position: position,
      level: progression.level,
      progressToNext: progression.progress,
      totalXp: progression.totalXp,
    );
  }

  static String _calculatePositionFromGoals() {
    if (!Hive.isBoxOpen('mission_box_v4')) return 'UNASSIGNED';

    final goals = Hive.box<Goal>('mission_box_v4').values;
    final Map<GoalCategory, int> categoryPoints = {};

    for (final goal in goals) {
      final double weight = goal.type == GoalType.monthly
          ? 50.0
          : (goal.type == GoalType.weekly ? 20.0 : 5.0);
      if (goal.isCompleted) {
        categoryPoints[goal.category] =
            (categoryPoints[goal.category] ?? 0) + weight.toInt();
      }
      categoryPoints[goal.category] = (categoryPoints[goal.category] ?? 0) +
          (goal.streakCount * (weight * 0.1)).toInt();
    }

    if (categoryPoints.isEmpty) return 'UNASSIGNED';

    final bestCategory =
        categoryPoints.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    switch (bestCategory) {
      case GoalCategory.learning:
        return 'LEAD RESEARCHER';
      case GoalCategory.fitness:
        return 'TACTICAL ATHLETE';
      case GoalCategory.productivity:
        return 'OPERATIONS CHIEF';
      case GoalCategory.health:
        return 'BIO-SECURITY OFFICER';
      case GoalCategory.hobby:
        return 'CREATIVE DIRECTOR';
    }
  }
}
