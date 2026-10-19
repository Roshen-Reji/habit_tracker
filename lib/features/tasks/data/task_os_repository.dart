import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/data/task_day_log_repository.dart';
import 'package:habit_tracker/features/tasks/models/task_day_log.dart';
import 'package:habit_tracker/features/tasks/engine/rrule_recurrence_engine.dart';

/// Offline-first reactive repository for Tasks OS backed by Hive boxes.
/// Extends [ChangeNotifier] and maintains [revision] for immediate reactivity.
class TaskOsRepository extends ChangeNotifier {
  static final TaskOsRepository instance = TaskOsRepository._();
  TaskOsRepository._();

  static const String taskOsBoxName = 'task_os_box';
  static const String syncOpLogBoxName = 'sync_op_log_box';

  Box? _box;
  Box? _syncBox;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final ValueNotifier<List<TaskItem>> tasksNotifier = ValueNotifier([]);
  final ValueNotifier<List<CourseItem>> coursesNotifier = ValueNotifier([]);
  final ValueNotifier<List<TimetableSlotItem>> timetableNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<ClassSessionLog>> sessionLogsNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<ExamItem>> examsNotifier = ValueNotifier([]);
  final ValueNotifier<List<ForgivingHabitItem>> habitsNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<FocusSessionLog>> focusLogsNotifier =
      ValueNotifier([]);
  final ValueNotifier<SchedulingRules> rulesNotifier =
      ValueNotifier(const SchedulingRules());

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void _notifyMutation() {
    revision.value++;
    notifyListeners();
  }

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
    _notifyMutation();
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

    // Load Focus Session Logs
    final rawFocus = _box!.get('focus_logs', defaultValue: <dynamic>[]);
    final List<FocusSessionLog> focusLogs = [];
    if (rawFocus is List) {
      for (var item in rawFocus) {
        if (item is Map) focusLogs.add(FocusSessionLog.fromMap(item));
      }
    }
    focusLogsNotifier.value = focusLogs;

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
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  // ================= TASKS CRUD =================

  List<TaskItem> get activeTasks =>
      tasksNotifier.value.where((t) => !t.isDeleted).toList();

  /// Strictly one-time tasks (isHabit == false)
  List<TaskItem> get oneTimeTasks =>
      activeTasks.where((t) => !t.isHabit).toList();

  /// Recurring tasks / habits stored in tasks list (isHabit == true)
  List<TaskItem> get recurringTasks =>
      activeTasks.where((t) => t.isHabit).toList();

  /// One-time tasks scheduled for a specific date ('YYYY-MM-DD')
  List<TaskItem> getTasksForDate(String dateIso) {
    return oneTimeTasks.where((t) => t.scheduledDate == dateIso).toList();
  }

  /// Incomplete one-time tasks whose scheduled date / due date has passed
  List<TaskItem> getOverdueTasks(DateTime now) {
    return oneTimeTasks.where((t) => t.isOverdue(now)).toList();
  }

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
    _notifyMutation();
  }

  Future<void> completeTask(String taskId, DateTime now) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = current[index];
    if (task.status == TaskStatus.done) return;

    current[index] = task.copyWith(
      status: TaskStatus.done,
      completedAt: now,
      updatedAt: now,
    );
    _logSyncOp('task', taskId, 'complete', current[index].toMap());

    // XP Award: +15 XP for P1/P2, +10 XP for P3/P4
    try {
      final xp = (task.priority <= TaskPriority.high) ? 15 : 10;
      GlobalXPService.addXP(xp);
    } catch (_) {}

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
    _notifyMutation();
  }

  Future<void> uncompleteTask(String taskId) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = current[index];
    final now = DateTime.now();
    current[index] = task.copyWith(
      status: TaskStatus.todo,
      completedAt: null,
      updatedAt: now,
    );
    _logSyncOp('task', taskId, 'uncomplete', current[index].toMap());

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
    _notifyMutation();
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
    _notifyMutation();
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
    _notifyMutation();
  }

  Future<void> toggleTaskDone(String taskId, DateTime now) async {
    final current = List<TaskItem>.from(tasksNotifier.value);
    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = current[index];
    final isDone = task.status == TaskStatus.done;
    final newStatus = isDone ? TaskStatus.todo : TaskStatus.done;
    final completedAt = isDone ? null : now;

    current[index] = task.copyWith(
      status: newStatus,
      completedAt: completedAt,
      updatedAt: now,
    );
    _logSyncOp('task', taskId, 'status_change', current[index].toMap());

    // If it's a recurring habit, record day log and spawn next instance
    if (task.isHabit) {
      final dateIso =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      try {
        TaskDayLogRepository.instance.setLog(TaskDayLog(
          id: TaskDayLog.generateId(task.id, dateIso),
          goalId: task.id,
          dayKey: dateIso,
          status: !isDone ? 'done' : 'pending',
          loggedAt: now,
        ));
      } catch (_) {}

      if (!isDone) {
        final nextInstance = RruleRecurrenceEngine.spawnNextRecurringInstance(
          task: current[index],
          completedAt: now,
        );
        if (nextInstance != null) {
          current.add(nextInstance);
        }
      }
    }

    // XP Award on marking done
    if (!isDone) {
      try {
        final xp = (task.priority <= TaskPriority.high) ? 15 : 10;
        GlobalXPService.addXP(xp);
      } catch (_) {}
    }

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
    _notifyMutation();
  }

  Future<void> bulkUpdateStatus(
      List<String> taskIds, String newStatus, DateTime now) async {
    if (taskIds.isEmpty) return;
    final current = List<TaskItem>.from(tasksNotifier.value);
    final idsSet = taskIds.toSet();

    for (int i = 0; i < current.length; i++) {
      if (idsSet.contains(current[i].id)) {
        final wasDone = current[i].status == TaskStatus.done;
        final willBeDone = newStatus == TaskStatus.done;
        current[i] = current[i].copyWith(
          status: newStatus,
          completedAt: willBeDone ? now : null,
          updatedAt: now,
        );
        if (!wasDone && willBeDone) {
          try {
            final xp = (current[i].priority <= TaskPriority.high) ? 15 : 10;
            GlobalXPService.addXP(xp);
          } catch (_) {}
        }
        _logSyncOp('task', current[i].id, 'bulk_status', current[i].toMap());
      }
    }

    tasksNotifier.value = current;
    await _box?.put('tasks', current.map((t) => t.toMap()).toList());
    _notifyMutation();
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
  List<CourseItem> get courses => activeCourses;

  CourseItem? getCourseById(String courseId) {
    try {
      return activeCourses
          .firstWhere((c) => c.id == courseId || c.code == courseId);
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
    _notifyMutation();
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
    _notifyMutation();
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
    _notifyMutation();
  }

  List<ClassSessionLog> get sessionLogs => sessionLogsNotifier.value;

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
    _notifyMutation();
  }

  Future<void> markAttendance({
    required String slotId,
    required String courseId,
    required String dateIso,
    required String attendance, // 'present', 'absent', 'unmarked'
    String status = 'scheduled', // 'scheduled', 'cancelled', 'extra'
    String? notes,
  }) async {
    final log = ClassSessionLog(
      id: 'session_${slotId}_$dateIso',
      slotId: slotId,
      courseId: courseId,
      dateIso: dateIso,
      status: status,
      attendance: attendance,
      notes: notes,
    );
    await logClassSession(log);
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
    _notifyMutation();
  }

  Future<void> updateExamTopicConfidence(
      String examId, String topicId, int newConfidence) async {
    final current = List<ExamItem>.from(examsNotifier.value);
    final examIndex = current.indexWhere((e) => e.id == examId);
    if (examIndex == -1) return;

    final exam = current[examIndex];
    final updatedTopics = exam.topics.map((t) {
      if (t.id == topicId) {
        final now = DateTime.now();
        // Dynamic spaced repetition intervals based on confidence
        final nextDays = (newConfidence <= 1)
            ? 1
            : (newConfidence == 2 ? 3 : 7);
        return ExamTopicItem(
          id: t.id,
          title: t.title,
          confidence: newConfidence,
          lastStudiedAt: now,
          nextReviewAt: now.add(Duration(days: nextDays)),
        );
      }
      return t;
    }).toList();

    current[examIndex] = ExamItem(
      id: exam.id,
      courseId: exam.courseId,
      title: exam.title,
      examDate: exam.examDate,
      venue: exam.venue,
      weightage: exam.weightage,
      topics: updatedTopics,
      deletedAt: exam.deletedAt,
    );

    _logSyncOp('exam', examId, 'update_topic_confidence', {
      'topicId': topicId,
      'confidence': newConfidence,
    });

    examsNotifier.value = current;
    await _box?.put('exams', current.map((e) => e.toMap()).toList());
    _notifyMutation();
  }

  // ================= HABITS CRUD =================

  List<ForgivingHabitItem> get activeHabits =>
      habitsNotifier.value.where((h) => h.deletedAt == null).toList();
  List<ForgivingHabitItem> get habits => activeHabits;

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
    _notifyMutation();
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
    bool awardedXp = false;

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
        awardedXp = true;
      }
    }

    final updated = habit.copyWith(
      completedDatesIso: completed,
      frozenDatesIso: frozen,
      freezesLeft: freezes,
      currentStreak: habit.copyWith(completedDatesIso: completed, frozenDatesIso: frozen).computeCurrentStreak(),
      bestStreak: habit.copyWith(completedDatesIso: completed, frozenDatesIso: frozen).computeBestStreak(),
    );
    current[index] = updated;

    // Log completion in TaskDayLogRepository
    try {
      final isDone = completed.contains(dateIso);
      TaskDayLogRepository.instance.setLog(TaskDayLog(
        id: TaskDayLog.generateId(habitId, dateIso),
        goalId: habitId,
        dayKey: dateIso,
        status: isFreeze ? 'neutral' : (isDone ? 'done' : 'pending'),
        loggedAt: DateTime.now(),
      ));
    } catch (_) {}

    if (awardedXp) {
      try {
        GlobalXPService.addXP(10);
      } catch (_) {}
    }

    _logSyncOp('habit', habitId, 'toggle_day', updated.toMap());
    habitsNotifier.value = current;
    await _box?.put('habits', current.map((h) => h.toMap()).toList());
    _notifyMutation();
  }

  Future<void> toggleHabitToday(String habitId) async {
    final now = DateTime.now();
    final dateIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await toggleHabitDay(habitId, dateIso, false);
  }

  Future<void> useHabitFreeze(String habitId, String dateIso) async {
    await toggleHabitDay(habitId, dateIso, true);
  }

  Future<void> deleteHabit(String habitId, {bool permanent = false}) async {
    final current = List<ForgivingHabitItem>.from(habitsNotifier.value);
    final index = current.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    if (permanent) {
      current.removeAt(index);
      _logSyncOp('habit', habitId, 'permanent_delete', null);
    } else {
      current[index] = current[index].copyWith(
        deletedAt: DateTime.now(),
      );
      _logSyncOp('habit', habitId, 'delete', current[index].toMap());
    }

    habitsNotifier.value = current;
    await _box?.put('habits', current.map((h) => h.toMap()).toList());
    _notifyMutation();
  }

  // ================= SCHEDULING RULES & PLANS =================

  Future<void> saveSchedulingRules(SchedulingRules rules) async {
    rulesNotifier.value = rules;
    await _box?.put('scheduling_rules', rules.toMap());
    _logSyncOp('rules', 'global', 'update', rules.toMap());
    _notifyMutation();
  }

  Future<void> saveRules(SchedulingRules rules) => saveSchedulingRules(rules);

  Future<void> acceptPlanProposal(PlanProposalItem plan) async {
    _logSyncOp('plan', plan.id, 'accept', plan.toMap());
    _notifyMutation();
  }

  // ================= FOCUS SESSIONS CRUD =================

  List<FocusSessionLog> get focusLogs => focusLogsNotifier.value;

  Future<void> logFocusSession(FocusSessionLog log) async {
    final current = List<FocusSessionLog>.from(focusLogsNotifier.value);
    current.add(log);
    focusLogsNotifier.value = current;
    await _box?.put('focus_logs', current.map((l) => l.toMap()).toList());

    // Award +20 XP on completed focus session
    try {
      GlobalXPService.addXP(20);
    } catch (_) {}

    // Update parent task actualMin if attached
    if (log.taskId != null) {
      final taskList = List<TaskItem>.from(tasksNotifier.value);
      final tIndex = taskList.indexWhere((t) => t.id == log.taskId);
      if (tIndex != -1) {
        final existingTask = taskList[tIndex];
        taskList[tIndex] = existingTask.copyWith(
          actualMin: existingTask.actualMin + log.actualMin,
          updatedAt: DateTime.now(),
        );
        tasksNotifier.value = taskList;
        await _box?.put('tasks', taskList.map((t) => t.toMap()).toList());
      }
    }

    _logSyncOp('focus_log', log.id, 'create', log.toMap());
    _notifyMutation();
  }

  // ================= PLACEHOLDER PURGE & CLEAN SLATE =================

  /// Discontinued: Auto-seeding placeholder tasks is permanently disabled.
  Future<void> seedIfEmpty() async {
    return;
  }

  /// Purges all pre-seeded dummy placeholder data (tasks, habits, courses, exams)
  /// that were automatically injected into the database.
  Future<void> purgePreseededPlaceholders() async {
    const seedTaskIds = {'task_dbms_lab', 'task_ieee_pr', 'task_read_clean_code'};
    const seedCourseIds = {'course_dbms', 'course_os'};
    const seedHabitIds = {'habit_leetcode', 'habit_sys_design'};
    const seedExamIds = {'exam_dbms_mid', 'exam_sample_1'};

    bool changed = false;

    // Purge tasks
    final currentTasks = List<TaskItem>.from(tasksNotifier.value);
    final filteredTasks =
        currentTasks.where((t) => !seedTaskIds.contains(t.id)).toList();
    if (filteredTasks.length != currentTasks.length) {
      tasksNotifier.value = filteredTasks;
      await _box?.put('tasks', filteredTasks.map((t) => t.toMap()).toList());
      changed = true;
    }

    // Purge courses
    final currentCourses = List<CourseItem>.from(coursesNotifier.value);
    final filteredCourses =
        currentCourses.where((c) => !seedCourseIds.contains(c.id)).toList();
    if (filteredCourses.length != currentCourses.length) {
      coursesNotifier.value = filteredCourses;
      await _box?.put(
          'courses', filteredCourses.map((c) => c.toMap()).toList());
      changed = true;
    }

    // Purge habits
    final currentHabits = List<ForgivingHabitItem>.from(habitsNotifier.value);
    final filteredHabits =
        currentHabits.where((h) => !seedHabitIds.contains(h.id)).toList();
    if (filteredHabits.length != currentHabits.length) {
      habitsNotifier.value = filteredHabits;
      await _box?.put('habits', filteredHabits.map((h) => h.toMap()).toList());
      changed = true;
    }

    // Purge exams
    final currentExams = List<ExamItem>.from(examsNotifier.value);
    final filteredExams =
        currentExams.where((e) => !seedExamIds.contains(e.id)).toList();
    if (filteredExams.length != currentExams.length) {
      examsNotifier.value = filteredExams;
      await _box?.put('exams', filteredExams.map((e) => e.toMap()).toList());
      changed = true;
    }

    if (changed) {
      _notifyMutation();
    }
  }

  /// Completely clears all tasks and user data for a pristine clean slate.
  Future<void> clearAllData() async {
    tasksNotifier.value = [];
    coursesNotifier.value = [];
    timetableNotifier.value = [];
    sessionLogsNotifier.value = [];
    examsNotifier.value = [];
    habitsNotifier.value = [];
    focusLogsNotifier.value = [];

    await _box?.clear();
    await _syncBox?.clear();
    _notifyMutation();
  }
}
