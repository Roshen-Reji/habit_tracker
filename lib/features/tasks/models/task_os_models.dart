/// Priority levels: 1 = Urgent, 2 = High, 3 = Medium, 4 = Low
class TaskPriority {
  static const int urgent = 1;
  static const int high = 2;
  static const int medium = 3;
  static const int low = 4;

  static String label(int priority) {
    switch (priority) {
      case urgent:
        return 'Urgent';
      case high:
        return 'High';
      case medium:
        return 'Medium';
      case low:
      default:
        return 'Low';
    }
  }
}

/// Task statuses in the Tasks OS
class TaskStatus {
  static const String inbox = 'inbox';
  static const String todo = 'todo';
  static const String doing = 'doing';
  static const String done = 'done';
  static const String archived = 'archived';
}

/// A subtask / checklist item inside a parent task
class SubtaskItem {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? dueAt;
  final int order;

  const SubtaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueAt,
    this.order = 0,
  });

  SubtaskItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? dueAt,
    int? order,
  }) {
    return SubtaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueAt: dueAt ?? this.dueAt,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'dueAt': dueAt?.toIso8601String(),
        'order': order,
      };

  factory SubtaskItem.fromMap(Map map) => SubtaskItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        isCompleted: map['isCompleted'] == true,
        dueAt: map['dueAt'] != null
            ? DateTime.tryParse(map['dueAt'].toString())
            : null,
        order: (map['order'] as num?)?.toInt() ?? 0,
      );
}

/// The core Task model for Tasks OS
class TaskItem {
  final String id;
  final String title;
  final String? notes;
  final String status; // inbox, todo, doing, done, archived
  final int priority; // 1 (Urgent) .. 4 (Low)
  final DateTime? dueAt;
  final bool hasDueTime;
  final DateTime? startAt; // "Hide until"
  final String? courseId;
  final String? projectId;
  final String? parentTaskId;
  final List<SubtaskItem> subtasks;
  final List<String> tags;
  final int? estimateMin; // e.g. 30 min
  final int actualMin;
  final String? recurrenceRule; // e.g. "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,WE"
  final String recurrenceMode; // 'fixed' or 'afterCompletion'
  final List<int> reminderOffsetsMin; // e.g. [1440, 60] (minutes before dueAt)
  final double? weightage; // e.g. 20.0 for 20% of semester grade
  final double? maxMarks;
  final double? scoreObtained;
  final List<String> blockedByTaskIds;
  final String? templateName;
  final DateTime? completedAt;
  final DateTime? deletedAt; // Tombstone for sync
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deviceId;

  const TaskItem({
    required this.id,
    required this.title,
    this.notes,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.low,
    this.dueAt,
    this.hasDueTime = false,
    this.startAt,
    this.courseId,
    this.projectId,
    this.parentTaskId,
    this.subtasks = const [],
    this.tags = const [],
    this.estimateMin = 30,
    this.actualMin = 0,
    this.recurrenceRule,
    this.recurrenceMode = 'fixed',
    this.reminderOffsetsMin = const [],
    this.weightage,
    this.maxMarks,
    this.scoreObtained,
    this.blockedByTaskIds = const [],
    this.templateName,
    this.completedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
  });

  bool get isDone => status == TaskStatus.done;
  bool get isDeleted => deletedAt != null;
  bool get isRecurring => recurrenceRule != null && recurrenceRule!.isNotEmpty;

  bool isOverdue(DateTime now) {
    if (dueAt == null || isDone || isDeleted) return false;
    return dueAt!.isBefore(now);
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    String? status,
    int? priority,
    DateTime? dueAt,
    bool? hasDueTime,
    DateTime? startAt,
    String? courseId,
    String? projectId,
    String? parentTaskId,
    List<SubtaskItem>? subtasks,
    List<String>? tags,
    int? estimateMin,
    int? actualMin,
    String? recurrenceRule,
    String? recurrenceMode,
    List<int>? reminderOffsetsMin,
    double? weightage,
    double? maxMarks,
    double? scoreObtained,
    List<String>? blockedByTaskIds,
    String? templateName,
    DateTime? completedAt,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      hasDueTime: hasDueTime ?? this.hasDueTime,
      startAt: startAt ?? this.startAt,
      courseId: courseId ?? this.courseId,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      subtasks: subtasks ?? this.subtasks,
      tags: tags ?? this.tags,
      estimateMin: estimateMin ?? this.estimateMin,
      actualMin: actualMin ?? this.actualMin,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceMode: recurrenceMode ?? this.recurrenceMode,
      reminderOffsetsMin: reminderOffsetsMin ?? this.reminderOffsetsMin,
      weightage: weightage ?? this.weightage,
      maxMarks: maxMarks ?? this.maxMarks,
      scoreObtained: scoreObtained ?? this.scoreObtained,
      blockedByTaskIds: blockedByTaskIds ?? this.blockedByTaskIds,
      templateName: templateName ?? this.templateName,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'status': status,
        'priority': priority,
        'dueAt': dueAt?.toIso8601String(),
        'hasDueTime': hasDueTime,
        'startAt': startAt?.toIso8601String(),
        'courseId': courseId,
        'projectId': projectId,
        'parentTaskId': parentTaskId,
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'tags': tags,
        'estimateMin': estimateMin,
        'actualMin': actualMin,
        'recurrenceRule': recurrenceRule,
        'recurrenceMode': recurrenceMode,
        'reminderOffsetsMin': reminderOffsetsMin,
        'weightage': weightage,
        'maxMarks': maxMarks,
        'scoreObtained': scoreObtained,
        'blockedByTaskIds': blockedByTaskIds,
        'templateName': templateName,
        'completedAt': completedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deviceId': deviceId,
      };

  factory TaskItem.fromMap(Map map) {
    final subtaskList = <SubtaskItem>[];
    if (map['subtasks'] is List) {
      for (var s in map['subtasks']) {
        if (s is Map) subtaskList.add(SubtaskItem.fromMap(s));
      }
    }

    final tagsList = <String>[];
    if (map['tags'] is List) {
      for (var t in map['tags']) {
        if (t != null) tagsList.add(t.toString());
      }
    }

    final remindersList = <int>[];
    if (map['reminderOffsetsMin'] is List) {
      for (var r in map['reminderOffsetsMin']) {
        if (r is num) remindersList.add(r.toInt());
      }
    }

    final blockedList = <String>[];
    if (map['blockedByTaskIds'] is List) {
      for (var b in map['blockedByTaskIds']) {
        if (b != null) blockedList.add(b.toString());
      }
    }

    return TaskItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      notes: map['notes']?.toString(),
      status: map['status']?.toString() ?? TaskStatus.todo,
      priority: (map['priority'] as num?)?.toInt() ?? TaskPriority.low,
      dueAt: map['dueAt'] != null
          ? DateTime.tryParse(map['dueAt'].toString())
          : null,
      hasDueTime: map['hasDueTime'] == true,
      startAt: map['startAt'] != null
          ? DateTime.tryParse(map['startAt'].toString())
          : null,
      courseId: map['courseId']?.toString(),
      projectId: map['projectId']?.toString(),
      parentTaskId: map['parentTaskId']?.toString(),
      subtasks: subtaskList,
      tags: tagsList,
      estimateMin: (map['estimateMin'] as num?)?.toInt() ?? 30,
      actualMin: (map['actualMin'] as num?)?.toInt() ?? 0,
      recurrenceRule: map['recurrenceRule']?.toString(),
      recurrenceMode: map['recurrenceMode']?.toString() ?? 'fixed',
      reminderOffsetsMin: remindersList,
      weightage: (map['weightage'] as num?)?.toDouble(),
      maxMarks: (map['maxMarks'] as num?)?.toDouble(),
      scoreObtained: (map['scoreObtained'] as num?)?.toDouble(),
      blockedByTaskIds: blockedList,
      templateName: map['templateName']?.toString(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deviceId: map['deviceId']?.toString(),
    );
  }
}

/// Course grade component (midterm, lab, quiz, etc.)
class GradeComponentItem {
  final String id;
  final String name;
  final double weightagePct; // e.g. 25.0%
  final double maxMarks; // e.g. 100.0
  final double? scoreObtained;

  const GradeComponentItem({
    required this.id,
    required this.name,
    required this.weightagePct,
    this.maxMarks = 100.0,
    this.scoreObtained,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'weightagePct': weightagePct,
        'maxMarks': maxMarks,
        'scoreObtained': scoreObtained,
      };

  factory GradeComponentItem.fromMap(Map map) => GradeComponentItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        weightagePct: (map['weightagePct'] as num?)?.toDouble() ?? 0.0,
        maxMarks: (map['maxMarks'] as num?)?.toDouble() ?? 100.0,
        scoreObtained: (map['scoreObtained'] as num?)?.toDouble(),
      );
}

/// Academic Course model
class CourseItem {
  final String id;
  final String? semesterId;
  final String name;
  final String code; // e.g. "CS301", "DBMS"
  final String colorHex;
  final double credits;
  final String? instructor;
  final String? room;
  final double requiredAttendancePct; // default 0.75 (75%)
  final String gradeScale; // 'cgpa10', 'gpa4', 'percentage'
  final List<GradeComponentItem> gradeComponents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const CourseItem({
    required this.id,
    this.semesterId,
    required this.name,
    required this.code,
    required this.colorHex,
    this.credits = 3.0,
    this.instructor,
    this.room,
    this.requiredAttendancePct = 0.75,
    this.gradeScale = 'cgpa10',
    this.gradeComponents = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  CourseItem copyWith({
    String? id,
    String? semesterId,
    String? name,
    String? code,
    String? colorHex,
    double? credits,
    String? instructor,
    String? room,
    double? requiredAttendancePct,
    String? gradeScale,
    List<GradeComponentItem>? gradeComponents,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return CourseItem(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      name: name ?? this.name,
      code: code ?? this.code,
      colorHex: colorHex ?? this.colorHex,
      credits: credits ?? this.credits,
      instructor: instructor ?? this.instructor,
      room: room ?? this.room,
      requiredAttendancePct:
          requiredAttendancePct ?? this.requiredAttendancePct,
      gradeScale: gradeScale ?? this.gradeScale,
      gradeComponents: gradeComponents ?? this.gradeComponents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'semesterId': semesterId,
        'name': name,
        'code': code,
        'colorHex': colorHex,
        'credits': credits,
        'instructor': instructor,
        'room': room,
        'requiredAttendancePct': requiredAttendancePct,
        'gradeScale': gradeScale,
        'gradeComponents': gradeComponents.map((g) => g.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory CourseItem.fromMap(Map map) {
    final comps = <GradeComponentItem>[];
    if (map['gradeComponents'] is List) {
      for (var c in map['gradeComponents']) {
        if (c is Map) comps.add(GradeComponentItem.fromMap(c));
      }
    }

    return CourseItem(
      id: map['id']?.toString() ?? '',
      semesterId: map['semesterId']?.toString(),
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      colorHex: map['colorHex']?.toString() ?? '#3B82F6',
      credits: (map['credits'] as num?)?.toDouble() ?? 3.0,
      instructor: map['instructor']?.toString(),
      room: map['room']?.toString(),
      requiredAttendancePct:
          (map['requiredAttendancePct'] as num?)?.toDouble() ?? 0.75,
      gradeScale: map['gradeScale']?.toString() ?? 'cgpa10',
      gradeComponents: comps,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'].toString())
          : null,
    );
  }
}

/// Timetable recurring slot (e.g. Mon 09:00 - 10:00)
class TimetableSlotItem {
  final String id;
  final String courseId;
  final int dayOfWeek; // 1 = Mon .. 7 = Sun
  final int startMinutes; // Minutes from midnight (e.g. 540 = 09:00)
  final int endMinutes; // Minutes from midnight (e.g. 600 = 10:00)
  final String? room;
  final String weekPattern; // 'every', 'weekA', 'weekB'
  final String? batch;

  const TimetableSlotItem({
    required this.id,
    required this.courseId,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.room,
    this.weekPattern = 'every',
    this.batch,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'courseId': courseId,
        'dayOfWeek': dayOfWeek,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'room': room,
        'weekPattern': weekPattern,
        'batch': batch,
      };

  factory TimetableSlotItem.fromMap(Map map) => TimetableSlotItem(
        id: map['id']?.toString() ?? '',
        courseId: map['courseId']?.toString() ?? '',
        dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? 1,
        startMinutes: (map['startMinutes'] as num?)?.toInt() ?? 540,
        endMinutes: (map['endMinutes'] as num?)?.toInt() ?? 600,
        room: map['room']?.toString(),
        weekPattern: map['weekPattern']?.toString() ?? 'every',
        batch: map['batch']?.toString(),
      );
}

/// A specific class instance log for attendance tracking
class ClassSessionLog {
  final String id;
  final String slotId;
  final String courseId;
  final String dateIso; // 'YYYY-MM-DD'
  final String status; // 'scheduled', 'cancelled', 'extra', 'rescheduled'
  final String attendance; // 'present', 'absent', 'unmarked'
  final String? notes;

  const ClassSessionLog({
    required this.id,
    required this.slotId,
    required this.courseId,
    required this.dateIso,
    this.status = 'scheduled',
    this.attendance = 'unmarked',
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'slotId': slotId,
        'courseId': courseId,
        'dateIso': dateIso,
        'status': status,
        'attendance': attendance,
        'notes': notes,
      };

  factory ClassSessionLog.fromMap(Map map) => ClassSessionLog(
        id: map['id']?.toString() ?? '',
        slotId: map['slotId']?.toString() ?? '',
        courseId: map['courseId']?.toString() ?? '',
        dateIso: map['dateIso']?.toString() ?? '',
        status: map['status']?.toString() ?? 'scheduled',
        attendance: map['attendance']?.toString() ?? 'unmarked',
        notes: map['notes']?.toString(),
      );
}

/// Syllabus topic for an exam
class ExamTopicItem {
  final String id;
  final String title;
  final int confidence; // 0 = None, 1 = Low, 2 = Medium, 3 = High
  final DateTime? lastStudiedAt;
  final DateTime? nextReviewAt;

  const ExamTopicItem({
    required this.id,
    required this.title,
    this.confidence = 0,
    this.lastStudiedAt,
    this.nextReviewAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'confidence': confidence,
        'lastStudiedAt': lastStudiedAt?.toIso8601String(),
        'nextReviewAt': nextReviewAt?.toIso8601String(),
      };

  factory ExamTopicItem.fromMap(Map map) => ExamTopicItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        confidence: (map['confidence'] as num?)?.toInt() ?? 0,
        lastStudiedAt: map['lastStudiedAt'] != null
            ? DateTime.tryParse(map['lastStudiedAt'].toString())
            : null,
        nextReviewAt: map['nextReviewAt'] != null
            ? DateTime.tryParse(map['nextReviewAt'].toString())
            : null,
      );
}

/// Exam model with spaced revision topics
class ExamItem {
  final String id;
  final String courseId;
  final String title;
  final DateTime examDate;
  final String? venue;
  final double? weightage;
  final List<ExamTopicItem> topics;
  final DateTime? deletedAt;

  const ExamItem({
    required this.id,
    required this.courseId,
    required this.title,
    required this.examDate,
    this.venue,
    this.weightage,
    this.topics = const [],
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'courseId': courseId,
        'title': title,
        'examDate': examDate.toIso8601String(),
        'venue': venue,
        'weightage': weightage,
        'topics': topics.map((t) => t.toMap()).toList(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory ExamItem.fromMap(Map map) {
    final topicsList = <ExamTopicItem>[];
    if (map['topics'] is List) {
      for (var t in map['topics']) {
        if (t is Map) topicsList.add(ExamTopicItem.fromMap(t));
      }
    }

    return ExamItem(
      id: map['id']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      examDate: map['examDate'] != null
          ? DateTime.tryParse(map['examDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      venue: map['venue']?.toString(),
      weightage: (map['weightage'] as num?)?.toDouble(),
      topics: topicsList,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'].toString())
          : null,
    );
  }
}

/// A scheduled block of time for study or task execution
class ScheduledBlockItem {
  final String id;
  final String? taskId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String source; // 'user', 'ai'
  final String? reason;
  final String status; // 'proposed', 'accepted', 'done', 'skipped'

  const ScheduledBlockItem({
    required this.id,
    this.taskId,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.source = 'user',
    this.reason,
    this.status = 'proposed',
  });

  Duration get duration => endAt.difference(startAt);

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'title': title,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'source': source,
        'reason': reason,
        'status': status,
      };

  factory ScheduledBlockItem.fromMap(Map map) => ScheduledBlockItem(
        id: map['id']?.toString() ?? '',
        taskId: map['taskId']?.toString(),
        title: map['title']?.toString() ?? '',
        startAt: map['startAt'] != null
            ? DateTime.tryParse(map['startAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        endAt: map['endAt'] != null
            ? DateTime.tryParse(map['endAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        source: map['source']?.toString() ?? 'user',
        reason: map['reason']?.toString(),
        status: map['status']?.toString() ?? 'proposed',
      );
}

/// Full day AI plan proposal
class PlanProposalItem {
  final String id;
  final String dateIso;
  final List<ScheduledBlockItem> blocks;
  final String workloadStatus; // 'safe', 'heavy', 'overloaded'
  final String? overloadReason;
  final DateTime createdAt;

  const PlanProposalItem({
    required this.id,
    required this.dateIso,
    this.blocks = const [],
    this.workloadStatus = 'safe',
    this.overloadReason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateIso': dateIso,
        'blocks': blocks.map((b) => b.toMap()).toList(),
        'workloadStatus': workloadStatus,
        'overloadReason': overloadReason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlanProposalItem.fromMap(Map map) {
    final blockList = <ScheduledBlockItem>[];
    if (map['blocks'] is List) {
      for (var b in map['blocks']) {
        if (b is Map) blockList.add(ScheduledBlockItem.fromMap(b));
      }
    }

    return PlanProposalItem(
      id: map['id']?.toString() ?? '',
      dateIso: map['dateIso']?.toString() ?? '',
      blocks: blockList,
      workloadStatus: map['workloadStatus']?.toString() ?? 'safe',
      overloadReason: map['overloadReason']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Log of a focus/Pomodoro timer session
class FocusSessionLog {
  final String id;
  final String? taskId;
  final String? courseId;
  final DateTime startAt;
  final DateTime endAt;
  final int plannedMin;
  final int actualMin;
  final int interruptions;

  const FocusSessionLog({
    required this.id,
    this.taskId,
    this.courseId,
    required this.startAt,
    required this.endAt,
    required this.plannedMin,
    required this.actualMin,
    this.interruptions = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'courseId': courseId,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'plannedMin': plannedMin,
        'actualMin': actualMin,
        'interruptions': interruptions,
      };

  factory FocusSessionLog.fromMap(Map map) => FocusSessionLog(
        id: map['id']?.toString() ?? '',
        taskId: map['taskId']?.toString(),
        courseId: map['courseId']?.toString(),
        startAt: map['startAt'] != null
            ? DateTime.tryParse(map['startAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        endAt: map['endAt'] != null
            ? DateTime.tryParse(map['endAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        plannedMin: (map['plannedMin'] as num?)?.toInt() ?? 25,
        actualMin: (map['actualMin'] as num?)?.toInt() ?? 25,
        interruptions: (map['interruptions'] as num?)?.toInt() ?? 0,
      );
}

/// Habit with streak freeze and flexible rest days
class ForgivingHabitItem {
  final String id;
  final String name;
  final int targetPerWeek; // e.g. 5 days a week
  final int freezesLeft; // e.g. 2 freezes available
  final List<int> restDays; // e.g. [7] for Sunday
  final List<String> completedDatesIso; // 'YYYY-MM-DD'
  final List<String> frozenDatesIso; // Dates where streak freeze was used
  final DateTime? deletedAt;

  const ForgivingHabitItem({
    required this.id,
    required this.name,
    this.targetPerWeek = 5,
    this.freezesLeft = 2,
    this.restDays = const [7],
    this.completedDatesIso = const [],
    this.frozenDatesIso = const [],
    this.deletedAt,
  });

  bool isCompletedOn(String dateIso) => completedDatesIso.contains(dateIso);
  bool isFrozenOn(String dateIso) => frozenDatesIso.contains(dateIso);

  ForgivingHabitItem copyWith({
    String? id,
    String? name,
    int? targetPerWeek,
    int? freezesLeft,
    List<int>? restDays,
    List<String>? completedDatesIso,
    List<String>? frozenDatesIso,
    DateTime? deletedAt,
  }) {
    return ForgivingHabitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      targetPerWeek: targetPerWeek ?? this.targetPerWeek,
      freezesLeft: freezesLeft ?? this.freezesLeft,
      restDays: restDays ?? this.restDays,
      completedDatesIso: completedDatesIso ?? this.completedDatesIso,
      frozenDatesIso: frozenDatesIso ?? this.frozenDatesIso,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'targetPerWeek': targetPerWeek,
        'freezesLeft': freezesLeft,
        'restDays': restDays,
        'completedDatesIso': completedDatesIso,
        'frozenDatesIso': frozenDatesIso,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory ForgivingHabitItem.fromMap(Map map) {
    final completed = <String>[];
    if (map['completedDatesIso'] is List) {
      for (var d in map['completedDatesIso']) {
        if (d != null) completed.add(d.toString());
      }
    }

    final frozen = <String>[];
    if (map['frozenDatesIso'] is List) {
      for (var f in map['frozenDatesIso']) {
        if (f != null) frozen.add(f.toString());
      }
    }

    final rest = <int>[];
    if (map['restDays'] is List) {
      for (var r in map['restDays']) {
        if (r is num) rest.add(r.toInt());
      }
    }

    return ForgivingHabitItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      targetPerWeek: (map['targetPerWeek'] as num?)?.toInt() ?? 5,
      freezesLeft: (map['freezesLeft'] as num?)?.toInt() ?? 2,
      restDays: rest.isEmpty ? const [7] : rest,
      completedDatesIso: completed,
      frozenDatesIso: frozen,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'].toString())
          : null,
    );
  }
}

/// Global rules for smart scheduling
class SchedulingRules {
  final int workStartHour; // default 8 (08:00)
  final int workEndHour; // default 22 (22:00)
  final bool lightSundays; // default true
  final int minBlockMin; // default 25 min
  final int maxContinuousMin; // default 90 min
  final int breakMin; // default 15 min
  final int deadlineBufferHours; // default 24h
  final String autonomyLevel; // 'manual', 'suggest', 'autoWithApproval', 'auto'

  const SchedulingRules({
    this.workStartHour = 8,
    this.workEndHour = 22,
    this.lightSundays = true,
    this.minBlockMin = 25,
    this.maxContinuousMin = 90,
    this.breakMin = 15,
    this.deadlineBufferHours = 24,
    this.autonomyLevel = 'suggest',
  });

  Map<String, dynamic> toMap() => {
        'workStartHour': workStartHour,
        'workEndHour': workEndHour,
        'lightSundays': lightSundays,
        'minBlockMin': minBlockMin,
        'maxContinuousMin': maxContinuousMin,
        'breakMin': breakMin,
        'deadlineBufferHours': deadlineBufferHours,
        'autonomyLevel': autonomyLevel,
      };

  factory SchedulingRules.fromMap(Map map) => SchedulingRules(
        workStartHour: (map['workStartHour'] as num?)?.toInt() ?? 8,
        workEndHour: (map['workEndHour'] as num?)?.toInt() ?? 22,
        lightSundays: map['lightSundays'] != false,
        minBlockMin: (map['minBlockMin'] as num?)?.toInt() ?? 25,
        maxContinuousMin: (map['maxContinuousMin'] as num?)?.toInt() ?? 90,
        breakMin: (map['breakMin'] as num?)?.toInt() ?? 15,
        deadlineBufferHours:
            (map['deadlineBufferHours'] as num?)?.toInt() ?? 24,
        autonomyLevel: map['autonomyLevel']?.toString() ?? 'suggest',
      );
}
