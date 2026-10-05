import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/tasks/models/wake_log.dart';

class WakeLogRepository {
  static const String boxName = 'wake_logs';

  static final WakeLogRepository instance = WakeLogRepository._();
  WakeLogRepository._();
  factory WakeLogRepository() => instance;

  static void registerAdapter() {
    if (!Hive.isAdapterRegistered(67)) {
      Hive.registerAdapter(WakeLogAdapter());
    }
  }

  static Future<Box<WakeLog>> openBox() async {
    registerAdapter();
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<WakeLog>(boxName);
    }
    return await Hive.openBox<WakeLog>(boxName);
  }

  Box<WakeLog> get box => Hive.box<WakeLog>(boxName);

  Future<void> saveLog(WakeLog log) async {
    final b = await openBox();
    await b.put(log.dayKey, log);
  }

  WakeLog? getLog(String dayKey) {
    if (!Hive.isBoxOpen(boxName)) return null;
    return box.get(dayKey);
  }

  Future<void> deleteLog(String dayKey) async {
    if (!Hive.isBoxOpen(boxName)) return;
    await box.delete(dayKey);
  }

  List<WakeLog> getAllLogs() {
    if (!Hive.isBoxOpen(boxName)) return [];
    final list = box.values.toList();
    list.sort((a, b) => b.dayKey.compareTo(a.dayKey));
    return list;
  }
}
