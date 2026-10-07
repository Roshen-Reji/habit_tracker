/// Pure Dart Progression Engine.
///
/// Implements the unified leveling and rank curve:
/// - Base XP to advance from Level 1 to 2: 100 XP.
/// - Each subsequent level requires +25 XP more: XP(L -> L+1) = 100 + 25 * (L - 1).
/// - Rank titles:
///     Levels 1..4:   RECRUIT
///     Levels 5..9:   OPERATIVE
///     Levels 10..19: SPECIALIST
///     Levels 20..34: VETERAN
///     Levels 35..49: LEADER
///     Levels 50+:    LEGEND
library;

class ProgressionResult {
  final int totalXp;
  final int level;
  final String rankTitle;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final double progress; // 0.0 .. 1.0 clamped
  final int xpToNext;

  const ProgressionResult({
    required this.totalXp,
    required this.level,
    required this.rankTitle,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.progress,
    required this.xpToNext,
  });

  @override
  String toString() =>
      'ProgressionResult(level: $level, title: $rankTitle, xp: $xpIntoLevel/$xpForNextLevel, total: $totalXp)';
}

class ProgressionEngine {
  static const int baseLevelXp = 100;
  static const int stepLevelXp = 25;

  /// Returns the XP required to advance from [level] to [level] + 1.
  /// Formula: 100 + 25 * (level - 1)
  static int xpRequiredForLevel(int level) {
    if (level < 1) return baseLevelXp;
    return baseLevelXp + stepLevelXp * (level - 1);
  }

  /// Returns the cumulative XP needed from Level 1 to reach the start of [level].
  static int cumulativeXpForLevel(int level) {
    if (level <= 1) return 0;
    final n = level - 1;
    // Sum_{k=1..n} (100 + 25*(k-1)) = 100*n + 25 * n*(n-1)/2
    return baseLevelXp * n + (stepLevelXp * n * (n - 1)) ~/ 2;
  }

  /// Resolves the military/tactical rank title corresponding to [level].
  static String rankTitleForLevel(int level) {
    if (level >= 50) return 'LEGEND';
    if (level >= 35) return 'LEADER';
    if (level >= 20) return 'VETERAN';
    if (level >= 10) return 'SPECIALIST';
    if (level >= 5) return 'OPERATIVE';
    return 'RECRUIT';
  }

  /// Calculates the complete progression state from a [totalXp] integer.
  static ProgressionResult calculate(int totalXp) {
    final clampedXp = totalXp < 0 ? 0 : totalXp;

    int level = 1;
    int remainingXp = clampedXp;

    while (true) {
      final req = xpRequiredForLevel(level);
      if (remainingXp < req) {
        final progress = req > 0 ? (remainingXp / req).clamp(0.0, 1.0) : 0.0;
        final xpToNext = req - remainingXp;
        return ProgressionResult(
          totalXp: clampedXp,
          level: level,
          rankTitle: rankTitleForLevel(level),
          xpIntoLevel: remainingXp,
          xpForNextLevel: req,
          progress: progress,
          xpToNext: xpToNext,
        );
      }
      remainingXp -= req;
      level++;
    }
  }
}
