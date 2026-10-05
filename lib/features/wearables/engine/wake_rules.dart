class WakeEvaluation {
  final bool onTime;
  final int wakeMinutes;
  final int targetMinutes;
  final int diffMinutes;
  final String statusText;

  WakeEvaluation({
    required this.onTime,
    required this.wakeMinutes,
    required this.targetMinutes,
    required this.diffMinutes,
    required this.statusText,
  });
}

class WakeRules {
  /// Evaluates whether a wake time was on time against targetMinutes and graceMinutes.
  /// [direction]: 'after' (e.g. wake at or after target) or 'before' (wake at or before target).
  static WakeEvaluation evaluate({
    required DateTime wakeAt,
    required int targetMinutes,
    int graceMinutes = 0,
    String direction = 'after',
  }) {
    final wakeMinutes = wakeAt.hour * 60 + wakeAt.minute;
    bool onTime;
    int diff;

    if (direction == 'after') {
      diff = wakeMinutes - targetMinutes;
      onTime = wakeMinutes >= (targetMinutes - graceMinutes);
    } else {
      diff = targetMinutes - wakeMinutes;
      onTime = wakeMinutes <= (targetMinutes + graceMinutes);
    }

    final targetH = targetMinutes ~/ 60;
    final targetM = targetMinutes % 60;
    final targetStr = '${targetH.toString().padLeft(2, '0')}:${targetM.toString().padLeft(2, '0')}';

    final wakeH = wakeAt.hour;
    final wakeM = wakeAt.minute;
    final wakeStr = '${wakeH.toString().padLeft(2, '0')}:${wakeM.toString().padLeft(2, '0')}';

    String statusText;
    if (onTime) {
      statusText = 'Woke up at $wakeStr (target $targetStr) · On time ✓';
    } else {
      final absDiff = diff.abs();
      statusText = 'Woke up at $wakeStr ($absDiff min off target $targetStr) · Missed ✕';
    }

    return WakeEvaluation(
      onTime: onTime,
      wakeMinutes: wakeMinutes,
      targetMinutes: targetMinutes,
      diffMinutes: diff,
      statusText: statusText,
    );
  }

  /// Calculates updated streak given the current streak and whether today was on time.
  /// Rule: "keep unless for a long time". Single miss does not reset to 0; consecutive misses (>3) reset.
  static int updateStreak({
    required int currentStreak,
    required bool onTime,
    int consecutiveMisses = 0,
  }) {
    if (onTime) {
      return currentStreak + 1;
    } else {
      if (consecutiveMisses >= 3) {
        return 0; // reset only after a long time
      }
      return currentStreak; // preserve streak for occasional miss
    }
  }
}
