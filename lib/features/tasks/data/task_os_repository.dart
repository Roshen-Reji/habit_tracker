import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

/// Offline-first repository for Tasks OS backed by Hive boxes
class TaskOsRepository {
  static final TaskOsRepository instance = TaskOsRepository._();
  TaskOsRepository._();

  static const String taskOsBoxName = 'task_os_box';
  static const String syncOpLogBoxName = 'sync_op_log_box';

  Box? _box;
  Box? _syncBox;

  final ValueNotifier<List<TaskItem>> tasksNotifier = ValueNotifier([]);
  final ValueNotifier<List<CourseItem>> coursesNotifier = ValueNotifier([]);
  final ValueNotifier<List<TimetableSlotItem>> timetableNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<ClassSessionLog>> sessionLogsNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<ExamItem>> examsNotifier = ValueNotifier([]);
  final ValueNotifier<List<ForgivingHabitItem>> habitsNotifier =
      ValueNotifier([]);
  final ValueNotifier<SchedulingRules> rulesNotifier =
      ValueNotifier(const SchedulingRules());

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init({Box? overrideBox, Box? overrideSyncBox}) async {
    if (_isInitialized && overrideBox == null) return;

    if (overrideBox != null) {
      _box = overrideBox;
    } else if (Hive.isBoxOpen(taskOsBoxName)) {
      _box = Hive.box(taskOsBoxName);
    } else {
      _box = await Hive.openBox(taskOsBoxName);
    }

    if (overrideSyncBox != null) {
      _syncBox = overrideSyncBox;
    } else if (Hive.isBoxOpen(syncOpLogBoxName)) {
      _syncBox = Hive.box(syncOpLogBoxName);
    } else {
      _syncBox = await Hive.openBox(syncOpLogBoxName);
    }

    _loadFromBox();
    _isInitialized = true;
  }

  void _loadFromBox() {
    if (_box == null) return;

    // Load Tasks
    final rawTasks = _box!.get('tasks', defaultValue: <dynamic>[]);
    final List<TaskItem> tasks = [];
    if (rawTasks is List) {
      for (var item in rawTasks) {
        if (item is Map) tasks.add(TaskItem.fromMap(item));
      }
    }
    tasksNotifier.value = tasks;

    // Load Courses
    final rawCourses = _box!.get('courses', defaultValue: <dynamic>[]);
    final List<CourseItem> courses = [];
    if (rawCourses is List) {
      for (var item in rawCourses) {
        if (item is Map) courses.add(CourseItem.fromMap(item));
      }
    }
    coursesNotifier.value = courses;

    // Load Timetable Slots
    final rawSlots = _box!.get('timetable_slots', defaultValue: <dynamic>[]);
    final List<TimetableSlotItem> slots = [];
    if (rawSlots is List) {
      for (var item in rawSlots) {
        if (item is Map) slots.add(TimetableSlotItem.fromMap(item));
      }
    }
    timetableNotifier.value = slots;

    // Load Class Session Logs
    final rawLogs = _box!.get('session_logs', defaultValue: <dynamic>[]);
    final List<ClassSessionLog> logs = [];
    if (rawLogs is List) {
      for (var item in rawLogs) {
        if (item is Map) logs.add(ClassSessionLog.fromMap(item));
      }
    }
    sessionLogsNotifier.value = logs;

    // Load Exams
    final rawExams = _box!.get('exams', defaultValue: <dynamic>[]);
    final List<ExamItem> exams = [];
    if (rawExams is List) {
      for (var item in rawExams) {
        if (item is Map) exams.add(ExamItem.fromMap(item));
      }
    }
    examsNotifier.value = exams;

    // Load Habits
    final rawHabits = _box!.get('habits', defaultValue: <dynamic>[]);
    final List<ForgivingHabitItem> habits = [];
    if (rawHabits is List) {
      for (var item in rawHabits) {
        if (item is Map) habits.add(ForgivingHabitItem.fromMap(item));
      }
    }
    habitsNotifier.value = habits;

    // Load Rules
    final rawRules = _box!.get('scheduling_rules');
    if (rawRules is Map) {
      rulesNotifier.value = SchedulingRules.fromMap(rawRules);
    }
  }

  void _logSyncOp(String entityType, String entityId, String action,
      Map<String, dynamic>? payload) {
    if (_syncBox == null) return;
    final logId = '${DateTime.now().millisecondsSinceEpoch}_${entityId}_$action';
    _syncBox!.put(logId, {
      'entityType': entityType,
      'entityId': entityId,
      'action': action, // create, update, delete
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  // ================= TASKS CRUD =================

  List<TaskItem> get activeTasks =>
      tasksNotifier.value.where((t) => !t.isDeleted).toList();

  Future<void> saveTask(TaskItem task) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == task.id);
    final isNew = index == -1;

    final updatedTask = task.copyWith(updatedAt: DateTime.now());
    if (isNew) {
      current.add(updatedTask);
      _logSyncOp('task', task.id, 'create', updatedTask.toMap());
    } else {
      current[index] = updatedTask;
      _logSyncOp('task', task.id, 'update', updatedTask.toMap());
    }

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
  }

  Future<void> deleteTask(String taskId, {bool permanent = false}) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    if (permanent) {
      current.removeAt(index);
      _logSyncOp('task', taskId, 'permanent_delete', null);
    } else {
      current[index] = current[index].copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _logSyncOp('task', taskId, 'delete', current[index].toMap());
    }

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
  }

  Future<void> restoreTask(String taskId) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    current[index] = current[index].copyWith(
      deletedAt: null,
      updatedAt: DateTime.now(),
    );
    _logSyncOp('task', taskId, 'restore', current[index].toMap());

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
  }

  Future<void> toggleTaskDone(String taskId, DateTime now) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = current[index];
    final newStatus =
        task.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
    final completedAt = newStatus == TaskStatus.done ? now : null;

    current[index] = task.copyWith(
      status: newStatus,
      completedAt: completedAt,
      updatedAt: now,
    );
    _logSyncOp('task', taskId, 'status_change', current[index].toMap());

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
  }

  /// Fast local search (< 150ms) across title, notes, tags, and course code
  List<TaskItem> searchTasks(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return activeTasks;

    return activeTasks.where((task) {
      if (task.title.toLowerCase().contains(q)) return true;
      if (task.notes != null && task.notes!.toLowerCase().contains(q)) {
        return true;
      }
      if (task.courseId != null && task.courseId!.toLowerCase().contains(q)) {
        return true;
      }
      for (var tag in task.tags) {
        if (tag.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  // ================= COURSES CRUD =================

  List<CourseItem> get activeCourses =>
      coursesNotifier.value.where((c) => c.deletedAt == null).toList();

  CourseItem? getCourseById(String courseId) {
    try {
      return activeCourses.firstWhere((c) => c.id == courseId || c.code == courseId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCourse(CourseItem course) async {
    final current = List<CourseItem>.from(coursesNotifier.value);
    final index = current.indexWhere((c) => c.id == course.id);
    final updated = course.copyWith(updatedAt: DateTime.now());

    if (index == -1) {
      current.add(updated);
      _logSyncOp('course', course.id, 'create', updated.toMap());
    } else {
      current[index] = updated;
      _logSyncOp('course', course.id, 'update', updated.toMap());
    }

    coursesNotifier.value = current;
    await _box?.put('courses', current.map((c) => c.toMap()).toList());
  }

  Future<void> deleteCourse(String courseId) async {
    final current = List<CourseItem>.from(coursesNotifier.value);
    final index = current.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    current[index] = CourseItem(
      id: current[index].id,
      semesterId: current[index].semesterId,
      name: current[index].name,
      code: current[index].code,
      colorHex: current[index].colorHex,
      credits: current[index].credits,
      instructor: current[index].instructor,
      room: current[index].room,
      requiredAttendancePct: current[index].requiredAttendancePct,
      gradeScale: current[index].gradeScale,
      gradeComponents: current[index].gradeComponents,
      createdAt: current[index].createdAt,
      updatedAt: DateTime.now(),
      deletedAt: DateTime.now(),
    );
    _logSyncOp('course', courseId, 'delete', current[index].toMap());

    coursesNotifier.value = current;
    await _box?.put('courses', current.map((c) => c.toMap()).toList());
  }

  // ================= TIMETABLE & ATTENDANCE =================

  List<TimetableSlotItem> get timetableSlots => timetableNotifier.value;

  Future<void> saveTimetableSlot(TimetableSlotItem slot) async {
    final current = List<TimetableSlotItem>.from(timetableNotifier.value);
    final index = current.indexWhere((s) => s.id == slot.id);
    if (index == -1) {
      current.add(slot);
      _logSyncOp('timetable_slot', slot.id, 'create', slot.toMap());
    } else {
      current[index] = slot;
      _logSyncOp('timetable_slot', slot.id, 'update', slot.toMap());
    }

    timetableNotifier.value = current;
    await _box?.put('timetable_slots', current.map((s) => s.toMap()).toList());
  }

  Future<void> logClassSession(ClassSessionLog log) async {
    final current = List<ClassSessionLog>.from(sessionLogsNotifier.value);
    final index = current.indexWhere(
        (s) => s.slotId == log.slotId && s.dateIso == log.dateIso);
    if (index == -1) {
      current.add(log);
    } else {
      current[index] = log;
    }

    _logSyncOp('session_log', log.id, 'save', log.toMap());
    sessionLogsNotifier.value = current;
    await _box?.put('session_logs', current.map((s) => s.toMap()).toList());
  }

  // ================= EXAMS CRUD =================

  List<ExamItem> get activeExams =>
      examsNotifier.value.where((e) => e.deletedAt == null).toList();

  Future<void> saveExam(ExamItem exam) async {
    final current = List<ExamItem>.from(examsNotifier.value);
    final index = current.indexWhere((e) => e.id == exam.id);
    if (index == -1) {
      current.add(exam);
      _logSyncOp('exam', exam.id, 'create', exam.toMap());
    } else {
      current[index] = exam;
      _logSyncOp('exam', exam.id, 'update', exam.toMap());
    }

    examsNotifier.value = current;
    await _box?.put('exams', current.map((e) => e.toMap()).toList());
  }

  // ================= HABITS CRUD =================

  List<ForgivingHabitItem> get activeHabits =>
      habitsNotifier.value.where((h) => h.deletedAt == null).toList();

  Future<void> saveHabit(ForgivingHabitItem habit) async {
    final current = List<ForgivingHabitItem>.from(habitsNotifier.value);
    final index = current.indexWhere((h) => h.id == habit.id);
    if (index == -1) {
      current.add(habit);
      _logSyncOp('habit', habit.id, 'create', habit.toMap());
    } else {
      current[index] = habit;
      _logSyncOp('habit', habit.id, 'update', habit.toMap());
    }

    habitsNotifier.value = current;
    await _box?.put('habits', current.map((h) => h.toMap()).toList());
  }

  Future<void> toggleHabitDay(
      String habitId, String dateIso, bool isFreeze) async {
    final current = List<ForgivingHabitItem>.from(habitsNotifier.value);
    final index = current.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    final habit = current[index];
    final completed = List<String>.from(habit.completedDatesIso);
    final frozen = List<String>.from(habit.frozenDatesIso);
    int freezes = habit.freezesLeft;

    if (isFreeze) {
      if (frozen.contains(dateIso)) {
        frozen.remove(dateIso);
        freezes++;
      } else if (freezes > 0) {
        completed.remove(dateIso);
        frozen.add(dateIso);
        freezes--;
      }
    } else {
      if (completed.contains(dateIso)) {
        completed.remove(dateIso);
      } else {
        frozen.remove(dateIso);
        completed.add(dateIso);
      }
    }

    final updated = habit.copyWith(
      completedDatesIso: completed,
      frozenDatesIso: frozen,
      freezesLeft: freezes,
    );
    current[index] = updated;

    _logSyncOp('habit', habitId, 'toggle_day', updated.toMap());
    habitsNotifier.value = current;
    await _box?.put('habits', current.map((h) => h.toMap()).toList());
  }

  // ================= SCHEDULING RULES =================

  Future<void> saveSchedulingRules(SchedulingRules rules) async {
    rulesNotifier.value = rules;
    await _box?.put('scheduling_rules', rules.toMap());
    _logSyncOp('rules', 'global', 'update', rules.toMap());
  }
}
