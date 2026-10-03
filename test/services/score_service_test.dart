import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/services/score_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box xpBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('score_service_test_');
    Hive.init(tempDir.path);
    xpBox = await Hive.openBox('xp_history_test');
  });

  tearDownAll(() async {
    await xpBox.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await xpBox.clear();
  });

  group('ScoreService Unit Tests (P2-3)', () {
    test('getDailyXP returns correct XP or 0 for missing dates', () {
      final today = DateTime(2026, 10, 3);
      final key = DateFormat('yyyy-MM-dd').format(today);
      xpBox.put(key, 50);

      expect(ScoreService.getDailyXP(today, xpBox: xpBox), 50);
      expect(
        ScoreService.getDailyXP(DateTime(2026, 10, 2), xpBox: xpBox),
        0,
      );
    });

    test('getRangeXP computes correct sum across date range', () {
      final d1 = DateTime(2026, 10, 1);
      final d2 = DateTime(2026, 10, 2);
      final d3 = DateTime(2026, 10, 3);

      xpBox.put(DateFormat('yyyy-MM-dd').format(d1), 20);
      xpBox.put(DateFormat('yyyy-MM-dd').format(d2), 30);
      xpBox.put(DateFormat('yyyy-MM-dd').format(d3), 50);

      final total = ScoreService.getRangeXP(d1, d3, xpBox: xpBox);
      expect(total, 100);
    });

    test('getScoreSummary returns accurate week, month, and year totals', () {
      final now = DateTime(2026, 10, 10);
      final fmt = DateFormat('yyyy-MM-dd');

      // 3 days ago (in week, month, year)
      xpBox.put(fmt.format(now.subtract(const Duration(days: 3))), 40);
      // 15 days ago (in month, year, NOT in week)
      xpBox.put(fmt.format(now.subtract(const Duration(days: 15))), 60);
      // 50 days ago (in year, NOT in month or week)
      xpBox.put(fmt.format(now.subtract(const Duration(days: 50))), 100);

      final summary = ScoreService.getScoreSummary(now: now, xpBox: xpBox);

      expect(summary['week'], 40);
      expect(summary['month'], 100); // 40 + 60
      expect(summary['year'], 200); // 40 + 60 + 100
    });

    test('getScoreDeltas calculates day, week, and month deltas accurately',
        () {
      final now = DateTime(2026, 10, 15);
      final fmt = DateFormat('yyyy-MM-dd');

      // Today vs Yesterday
      xpBox.put(fmt.format(now), 70);
      xpBox.put(fmt.format(now.subtract(const Duration(days: 1))), 30);

      // This week (past 7 days): today(70) + yesterday(30) = 100
      // Last week (days 7 to 13 ago): put 40
      xpBox.put(fmt.format(now.subtract(const Duration(days: 8))), 40);

      final deltas = ScoreService.getScoreDeltas(now: now, xpBox: xpBox);

      expect(deltas['today'], 70);
      expect(deltas['yesterday'], 30);
      expect(deltas['dayDelta'], 40); // 70 - 30

      expect(deltas['thisWeek'], 100);
      expect(deltas['lastWeek'], 40);
      expect(deltas['weekDelta'], 60); // 100 - 40
    });
  });
}
