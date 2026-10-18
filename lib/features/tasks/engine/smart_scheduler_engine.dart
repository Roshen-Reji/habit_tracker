import 'dart:math' as math;
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/engine/task_urgency_engine.dart';

class TimeWindow {
  final DateTime start;
  final DateTime end;

  const TimeWindow({required this.start, required this.end});

  Duration get duration => end.difference(start);
  int get durationMinutes => duration.inMinutes;

  @override
  String toString() =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - '
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

class DailyWorkloadDay {
  final DateTime date;
  final int totalMinutes;
  final int classMinutes;
  final int taskMinutes;
  final int examCount;
  final int deadlineCount;
  final String status; // 'safe', 'heavy', 'overloaded'
  final String? warningMessage;

  const DailyWorkloadDay({
    required this.date,
    required this.totalMinutes,
    required this.classMinutes,
    required this.taskMinutes,
    required this.examCount,
    required this.deadlineCount,
    required this.status,
    this.warningMessage,
  });
}

class WeeklyWorkloadSummary {
  final List<DailyWorkloadDay> days;
  final bool hasOverloadWarning;
  final String? overloadWarningBanner;

  const WeeklyWorkloadSummary({
    required this.days,
    required this.hasOverloadWarning,
    this.overloadWarningBanner,
  });
}

/// Smart Scheduler Engine implementing PLAN-2 through PLAN-12
class SmartSchedulerEngine {
  /// Generates free time windows for a given day by carving out fixed classes and exams (PLAN-2)
  static List<TimeWindow> computeFreeWindows({
    required DateTime date,
    required List<TimetableSlotItem> timetableSlots,
    required List<ExamItem> exams,
    SchedulingRules rules = const SchedulingRules(),
  }) {
    final dayOfWeek = date.weekday;
    final workStart = DateTime(date.year, date.month, date.day, rules.workStartHour, 0);
    final workEnd = DateTime(date.year, date.month, date.day, rules.workEndHour, 0);

    if (workEnd.isBefore(workStart)) return [];

    // Collect busy intervals
    final busyWindows = <TimeWindow>[];

    // 1. Add class timetable slots for today
    for (var slot in timetableSlots) {
      if (slot.dayOfWeek == dayOfWeek) {
        final slotStart = DateTime(date.year, date.month, date.day)
            .add(Duration(minutes: slot.startMinutes));
        final slotEnd = DateTime(date.year, date.month, date.day)
            .add(Duration(minutes: slot.endMinutes));
        if (slotEnd.isAfter(workStart) && slotStart.isBefore(workEnd)) {
          busyWindows.add(TimeWindow(
            start: slotStart.isBefore(workStart) ? workStart : slotStart,
            end: slotEnd.isAfter(workEnd) ? workEnd : slotEnd,
          ));
        }
      }
    }

    // 2. Add exams on this date
    for (var exam in exams) {
      if (exam.examDate.year == date.year &&
          exam.examDate.month == date.month &&
          exam.examDate.day == date.day) {
        final examStart = exam.examDate;
        final examEnd = examStart.add(const Duration(hours: 3)); // Standard exam block
        if (examEnd.isAfter(workStart) && examStart.isBefore(workEnd)) {
          busyWindows.add(TimeWindow(
            start: examStart.isBefore(workStart) ? workStart : examStart,
            end: examEnd.isAfter(workEnd) ? workEnd : examEnd,
          ));
        }
      }
    }

    // Sort busy windows chronologically
    busyWindows.sort((a, b) => a.start.compareTo(b.start));

    // Invert busy windows to produce free windows
    final freeWindows = <TimeWindow>[];
    DateTime cursor = workStart;

    for (var busy in busyWindows) {
      if (busy.start.isAfter(cursor)) {
        final gap = busy.start.difference(cursor).inMinutes;
        if (gap >= rules.minBlockMin) {
          freeWindows.add(TimeWindow(start: cursor, end: busy.start));
        }
      }
      if (busy.end.isAfter(cursor)) {
        cursor = busy.end;
      }
    }

    if (cursor.isBefore(workEnd)) {
      final gap = workEnd.difference(cursor).inMinutes;
      if (gap >= rules.minBlockMin) {
        freeWindows.add(TimeWindow(start: cursor, end: workEnd));
      }
    }

    return freeWindows;
  }

  /// Generates a complete daily plan proposal with structured scheduled blocks (PLAN-3..6)
  static PlanProposalItem generateDailyPlan({
    required DateTime date,
    required List<TaskItem> openTasks,
    required List<TimetableSlotItem> timetableSlots,
    required List<ExamItem> exams,
    SchedulingRules rules = const SchedulingRules(),
  }) {
    final freeWindows = computeFreeWindows(
      date: date,
      timetableSlots: timetableSlots,
      exams: exams,
      rules: rules,
    );

    // Rank tasks by urgency
    final rankedTasks = rankTasksByUrgency(openTasks, date);
    final List<ScheduledBlockItem> proposedBlocks = [];

    int windowIdx = 0;
    DateTime? currentCursor;

    for (var task in rankedTasks) {
      if (windowIdx >= freeWindows.length) break;

      int remainingTaskMin = task.estimateMin ?? 30;
      if (remainingTaskMin <= 0) remainingTaskMin = 30;

      while (remainingTaskMin > 0 && windowIdx < freeWindows.length) {
        final window = freeWindows[windowIdx];
        currentCursor ??= window.start;

        final availableMinInWindow =
            window.end.difference(currentCursor).inMinutes;
        if (availableMinInWindow < rules.minBlockMin) {
          windowIdx++;
          currentCursor = null;
          continue;
        }

        // Sliced block size: between minBlockMin and maxContinuousMin
        final blockSize = math.min(
          remainingTaskMin,
          math.min(rules.maxContinuousMin, availableMinInWindow),
        );

        final blockEnd = currentCursor.add(Duration(minutes: blockSize));

        // Deterministic reason string
        final dueText = task.dueAt != null
            ? (task.dueAt!.difference(date).inHours <= 24
                ? 'Due today/tomorrow'
                : 'Due in ${task.dueAt!.difference(date).inDays}d')
            : 'Priority task';
        final reason =
            '$dueText · ~${task.estimateMin ?? 30}m · fits free slot ${currentCursor.hour.toString().padLeft(2, '0')}:${currentCursor.minute.toString().padLeft(2, '0')}–${blockEnd.hour.toString().padLeft(2, '0')}:${blockEnd.minute.toString().padLeft(2, '0')}';

        proposedBlocks.add(ScheduledBlockItem(
          id: 'plan_${date.millisecondsSinceEpoch}_${task.id}_$blockSize',
          taskId: task.id,
          title: task.title,
          startAt: currentCursor,
          endAt: blockEnd,
          source: 'ai',
          reason: reason,
          status: 'proposed',
        ));

        remainingTaskMin -= blockSize;
        // Add break buffer
        currentCursor = blockEnd.add(Duration(minutes: rules.breakMin));

        if (currentCursor.isAfter(window.end) ||
            window.end.difference(currentCursor).inMinutes < rules.minBlockMin) {
          windowIdx++;
          currentCursor = null;
        }
      }
    }

    final dateIso =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return PlanProposalItem(
      id: 'proposal_$dateIso',
      dateIso: dateIso,
      blocks: proposedBlocks,
      workloadStatus: proposedBlocks.length > 5 ? 'heavy' : 'safe',
      createdAt: DateTime.now(),
    );
  }

  /// Proposes 4 backward-scheduled milestone subtasks for a big assignment or project (PLAN-7)
  static List<SubtaskItem> proposeBackwardsMilestones({
    required String title,
    required int estimateMin,
    required DateTime dueAt,
    int bufferHours = 24,
  }) {
    final effectiveDeadline = dueAt.subtract(Duration(hours: bufferHours));

    return [
      SubtaskItem(
        id: 'ms_1_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Phase 1: Outline, research & scope definition',
        dueAt: effectiveDeadline.subtract(const Duration(days: 4)),
        order: 1,
      ),
      SubtaskItem(
        id: 'ms_2_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Phase 2: First working draft / core implementation',
        dueAt: effectiveDeadline.subtract(const Duration(days: 2)),
        order: 2,
      ),
      SubtaskItem(
        id: 'ms_3_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Phase 3: Review, test edge cases & resolve doubts',
        dueAt: effectiveDeadline.subtract(const Duration(days: 1)),
        order: 3,
      ),
      SubtaskItem(
        id: 'ms_4_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Phase 4: Final formatting, checks & submission',
        dueAt: effectiveDeadline,
        order: 4,
      ),
    ];
  }

  /// Spaced-Repetition Exam Planner (PLAN-8)
  /// Schedules syllabus topics at 1, 3, 7, 14 days before exam date, prioritizing low confidence (0 or 1)
  static List<ScheduledBlockItem> generateExamRevisionSchedule({
    required ExamItem exam,
    required DateTime now,
    SchedulingRules rules = const SchedulingRules(),
  }) {
    final blocks = <ScheduledBlockItem>[];
    final examDate = exam.examDate;
    final totalDaysUntilExam = examDate.difference(now).inDays;
    if (totalDaysUntilExam <= 0) return [];

    // Sort topics: confidence 0 (None) first, then 1 (Low), 2 (Medium), 3 (High)
    final sortedTopics = List<ExamTopicItem>.from(exam.topics);
    sortedTopics.sort((a, b) => a.confidence.compareTo(b.confidence));

    // Spaced intervals in days before exam
    final intervals = [14, 7, 3, 1].where((d) => d < totalDaysUntilExam).toList();
    if (intervals.isEmpty && totalDaysUntilExam >= 1) {
      intervals.add(1);
    }

    for (var topic in sortedTopics) {
      for (var interval in intervals) {
        final sessionDate = examDate.subtract(Duration(days: interval));
        if (sessionDate.isBefore(now)) continue;

        final sessionStart = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          16, // Default afternoon revision slot
          0,
        );
        final sessionEnd = sessionStart.add(const Duration(minutes: 45));

        blocks.add(ScheduledBlockItem(
          id: 'exam_rev_${exam.id}_${topic.id}_$interval',
          title: 'Review: ${topic.title} (${exam.title})',
          startAt: sessionStart,
          endAt: sessionEnd,
          source: 'ai',
          reason: 'Spaced repetition (${interval}d before exam · confidence ${topic.confidence}/3)',
          status: 'proposed',
        ));
      }
    }

    return blocks;
  }

  /// Weekly Workload Heatmap & Overload Warning Engine (PLAN-10)
  static WeeklyWorkloadSummary computeWeeklyWorkload({
    required DateTime startDate,
    required List<TaskItem> tasks,
    required List<TimetableSlotItem> timetableSlots,
    required List<ExamItem> exams,
    int dailyCapacityHours = 8,
  }) {
    final days = <DailyWorkloadDay>[];
    bool hasOverload = false;
    String? warningBanner;

    for (int i = 0; i < 7; i++) {
      final curDate = startDate.add(Duration(days: i));
      final dayOfWeek = curDate.weekday;

      // 1. Calculate class minutes
      int classMin = 0;
      for (var s in timetableSlots) {
        if (s.dayOfWeek == dayOfWeek) {
          classMin += (s.endMinutes - s.startMinutes);
        }
      }

      // 2. Calculate task minutes due or scheduled
      int taskMin = 0;
      int deadlineCount = 0;
      for (var t in tasks) {
        if (!t.isDone && !t.isDeleted && t.dueAt != null) {
          if (t.dueAt!.year == curDate.year &&
              t.dueAt!.month == curDate.month &&
              t.dueAt!.day == curDate.day) {
            taskMin += (t.estimateMin ?? 30);
            deadlineCount++;
          }
        }
      }

      // 3. Exam count
      int examCount = 0;
      for (var e in exams) {
        if (e.examDate.year == curDate.year &&
            e.examDate.month == curDate.month &&
            e.examDate.day == curDate.day) {
          examCount++;
        }
      }

      final totalMin = classMin + taskMin + (examCount * 180);
      final totalHours = totalMin / 60.0;

      String status = 'safe';
      String? warning;
      if (totalHours > dailyCapacityHours || examCount > 1) {
        status = 'overloaded';
        hasOverload = true;
        warning =
            'Overloaded: ${totalHours.toStringAsFixed(1)}h total exceeds ${dailyCapacityHours}h daily capacity';
      } else if (totalHours > (dailyCapacityHours * 0.7)) {
        status = 'heavy';
      }

      days.add(DailyWorkloadDay(
        date: curDate,
        totalMinutes: totalMin,
        classMinutes: classMin,
        taskMinutes: taskMin,
        examCount: examCount,
        deadlineCount: deadlineCount,
        status: status,
        warningMessage: warning,
      ));
    }

    // Check 3-day window clustering (>= 3 deadlines/exams in 3 days)
    for (int i = 0; i <= days.length - 3; i++) {
      final clusterDeadlines = days[i].deadlineCount +
          days[i + 1].deadlineCount +
          days[i + 2].deadlineCount +
          days[i].examCount +
          days[i + 1].examCount +
          days[i + 2].examCount;
      if (clusterDeadlines >= 3) {
        hasOverload = true;
        warningBanner =
            '⚠️ High stress cluster detected: $clusterDeadlines major deadlines/exams fall within 3 consecutive days.';
        break;
      }
    }

    if (warningBanner == null && hasOverload) {
      warningBanner =
          '⚠️ Workload exceeds daily capacity on one or more days this week.';
    }

    return WeeklyWorkloadSummary(
      days: days,
      hasOverloadWarning: hasOverload,
      overloadWarningBanner: warningBanner,
    );
  }
}
