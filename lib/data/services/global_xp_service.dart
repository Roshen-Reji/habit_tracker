import 'package:habit_tracker/core/progression/progression_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class GlobalXPService {
  static void addXP(int amount) {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    int currentXp = settings.get('global_xp', defaultValue: 0);
    settings.put('global_xp', currentXp + amount);

    _recordDailyXP(amount);
    ProgressionService.refresh();
  }

  static void subtractXP(int amount) {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    int currentXp = settings.get('global_xp', defaultValue: 0);
    int newXp = (currentXp - amount).clamp(0, 999999);
    settings.put('global_xp', newXp);

    _recordDailyXP(-amount);
    ProgressionService.refresh();
  }

  static void _recordDailyXP(int amount) {
    if (!Hive.isBoxOpen('xp_history')) return;
    final box = Hive.box('xp_history');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    int currentDaily = box.get(today, defaultValue: 0);
    int newDaily = (currentDaily + amount).clamp(0, 999999);
    box.put(today, newDaily);
  }

  static List<int> getPast7DaysXP() {
    if (!Hive.isBoxOpen('xp_history')) return List.filled(7, 0);
    final box = Hive.box('xp_history');
    List<int> history = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime d = now.subtract(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(d);
      history.add(box.get(dateStr, defaultValue: 0));
    }
    return history;
  }

  /// Adds or subtracts XP for a specific historical or current date, updating both global_xp and xp_history[date].
  static void addXPForDate(DateTime date, int delta) {
    if (!Hive.isBoxOpen('settings') || !Hive.isBoxOpen('xp_history')) return;
    if (delta == 0) return;

    final settings = Hive.box('settings');
    int currentGlobalXp = settings.get('global_xp', defaultValue: 0);
    int newGlobalXp = (currentGlobalXp + delta).clamp(0, 9999999);
    settings.put('global_xp', newGlobalXp);

    final box = Hive.box('xp_history');
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    int currentDaily = box.get(dateStr, defaultValue: 0);
    int newDaily = (currentDaily + delta).clamp(0, 9999999);
    box.put(dateStr, newDaily);

    ProgressionService.refresh();
  }
}
