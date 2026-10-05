import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/tasks/models/task_day_log.dart';

class TaskDayLogRepository {
  static const String boxName = 'task_day_logs';

  static final TaskDayLogRepository instance = TaskDayLogRepository._();
  TaskDayLogRepository._();
  factory TaskDayLogRepository() => instance;

  static void registerAdapter() {
    if (!Hive.isAdapterRegistered(66)) {
      Hive.registerAdapter(TaskDayLogAdapter());
    }
  }

  static Future<Box<TaskDayLog>> openBox() async {
    registerAdapter();
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<TaskDayLog>(boxName);
    }
    return await Hive.openBox<TaskDayLog>(boxName);
  }

  Box<TaskDayLog> get box => Hive.box<TaskDayLog>(boxName);

  Future<void> setLog(TaskDayLog log) async {
    final b = await openBox();
    await b.put(log.id, log);
  }

  TaskDayLog? getLog(String goalId, String dayKey) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final id = TaskDayLog.generateId(goalId, dayKey);
    return box.get(id);
  }

  List<TaskDayLog> getLogsForGoal(String goalId) {
    if (!Hive.isBoxOpen(boxName)) return [];
    return box.values.where((l) => l.goalId == goalId).toList();
  }

  List<TaskDayLog> getLogsForDay(String dayKey) {
    if (!Hive.isBoxOpen(boxName)) return [];
    return box.values.where((l) => l.dayKey == dayKey).toList();
  }
}
