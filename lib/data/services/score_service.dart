import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

/// Pure calculation service for XP score summaries and delta comparisons.
class ScoreService {
  static int getDailyXP(DateTime date, {Box? xpBox}) {
    if (xpBox == null && !Hive.isBoxOpen('xp_history')) return 0;
    final box = xpBox ?? Hive.box('xp_history');
    final key = DateFormat('yyyy-MM-dd').format(date);
    return (box.get(key, defaultValue: 0) as num).toInt();
  }

  static int getRangeXP(DateTime start, DateTime end, {Box? xpBox}) {
    if (xpBox == null && !Hive.isBoxOpen('xp_history')) return 0;
    final box = xpBox ?? Hive.box('xp_history');
    int total = 0;
    DateTime cur = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(endDate)) {
      final key = DateFormat('yyyy-MM-dd').format(cur);
      total += (box.get(key, defaultValue: 0) as num).toInt();
      cur = cur.add(const Duration(days: 1));
    }
    return total;
  }

  /// Calculates XP totals for Week (past 7 days), Month (past 30 days), and Year (past 365 days).
  static Map<String, int> getScoreSummary({DateTime? now, Box? xpBox}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final week = getRangeXP(today.subtract(const Duration(days: 6)), today,
        xpBox: xpBox);
    final month = getRangeXP(today.subtract(const Duration(days: 29)), today,
        xpBox: xpBox);
    final year = getRangeXP(today.subtract(const Duration(days: 364)), today,
        xpBox: xpBox);
    return {
      'week': week,
      'month': month,
      'year': year,
    };
  }

  /// Calculates deltas: today vs yesterday, this week vs last week, this month vs last month.
  static Map<String, int> getScoreDeltas({DateTime? now, Box? xpBox}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayXP = getDailyXP(today, xpBox: xpBox);
    final yesterdayXP = getDailyXP(yesterday, xpBox: xpBox);
    final dayDelta = todayXP - yesterdayXP;

    final thisWeekXP = getRangeXP(
        today.subtract(const Duration(days: 6)), today,
        xpBox: xpBox);
    final lastWeekXP = getRangeXP(today.subtract(const Duration(days: 13)),
        today.subtract(const Duration(days: 7)),
        xpBox: xpBox);
    final weekDelta = thisWeekXP - lastWeekXP;

    final thisMonthXP = getRangeXP(
        today.subtract(const Duration(days: 29)), today,
        xpBox: xpBox);
    final lastMonthXP = getRangeXP(today.subtract(const Duration(days: 59)),
        today.subtract(const Duration(days: 30)),
        xpBox: xpBox);
    final monthDelta = thisMonthXP - lastMonthXP;

    return {
      'dayDelta': dayDelta,
      'weekDelta': weekDelta,
      'monthDelta': monthDelta,
      'today': todayXP,
      'yesterday': yesterdayXP,
      'thisWeek': thisWeekXP,
      'lastWeek': lastWeekXP,
      'thisMonth': thisMonthXP,
      'lastMonth': lastMonthXP,
    };
  }
}
