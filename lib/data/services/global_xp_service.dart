import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class GlobalXPService {
  static void addXP(int amount) {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    int currentXp = settings.get('global_xp', defaultValue: 0);
    settings.put('global_xp', currentXp + amount);

    _recordDailyXP(amount);
  }

  static void subtractXP(int amount) {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    int currentXp = settings.get('global_xp', defaultValue: 0);
    int newXp = (currentXp - amount).clamp(0, 999999);
    settings.put('global_xp', newXp);

    _recordDailyXP(-amount);
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
}
