class WakeEvaluation {
  final bool onTime;
  final int wakeMinutes;
  final int targetMinutes;
  final int diffMinutes;
  final String statusText;
  final String ruleText;

  WakeEvaluation({
    required this.onTime,
    required this.wakeMinutes,
    required this.targetMinutes,
    required this.diffMinutes,
    required this.statusText,
    required this.ruleText,
  });
}

class WakeRules {
  static String plainRuleText(int targetMinutes, {String direction = 'from'}) {
    final targetH = targetMinutes ~/ 60;
    final targetM = targetMinutes % 60;
    final h12 = targetH == 0 ? 12 : (targetH > 12 ? targetH - 12 : targetH);
    final ampm = targetH >= 12 ? 'PM' : 'AM';
    final targetStr = '${h12.toString().padLeft(2, '0')}:${targetM.toString().padLeft(2, '0')} $ampm';

    if (direction == 'by' || direction == 'before' || direction == '<=') {
      return 'Ticked if waking by $targetStr';
    }
    return 'Ticked if waking from $targetStr';
  }

  /// Evaluates whether a wake time was on time against targetMinutes and graceMinutes.
  /// [direction]: 'from'/'after'/'>=' (wake at or after target) or 'by'/'before'/'<=' (wake at or before target).
  static WakeEvaluation evaluate({
    required DateTime wakeAt,
    required int targetMinutes,
    int graceMinutes = 0,
    String direction = 'from',
  }) {
    final wakeMinutes = wakeAt.hour * 60 + wakeAt.minute;
    final isBy = direction == 'by' || direction == 'before' || direction == '<=';
    bool onTime;
    int diff;

    if (isBy) {
      diff = targetMinutes - wakeMinutes;
      onTime = wakeMinutes <= (targetMinutes + graceMinutes);
    } else {
      diff = wakeMinutes - targetMinutes;
      onTime = wakeMinutes >= (targetMinutes - graceMinutes);
    }

    final ruleText = plainRuleText(targetMinutes, direction: direction);

    final targetH = targetMinutes ~/ 60;
    final targetM = targetMinutes % 60;
    final targetStr = '${targetH.toString().padLeft(2, '0')}:${targetM.toString().padLeft(2, '0')}';

    final wakeH = wakeAt.hour;
    final wakeM = wakeAt.minute;
    final wakeStr = '${wakeH.toString().padLeft(2, '0')}:${wakeM.toString().padLeft(2, '0')}';

    String statusText;
    if (onTime) {
      statusText = 'Woke up at $wakeStr ($ruleText) · On time ✓';
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
      ruleText: ruleText,
    );
  }

  /// Calculates updated streak given the current streak and whether today was on time.
  /// Rule: "keep unless for a long time". Single miss does not reset to 0; consecutive misses (> resetAfterMisses) reset.
  static int updateStreak({
    required int currentStreak,
    required bool onTime,
    int consecutiveMisses = 0,
    int resetAfterMisses = 3,
  }) {
    if (onTime) {
      return currentStreak + 1;
    } else {
      if (consecutiveMisses >= resetAfterMisses) {
        return 0; // reset only after N consecutive misses
      }
      return currentStreak; // preserve streak for occasional miss
    }
  }
}
