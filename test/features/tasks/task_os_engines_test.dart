import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/task_nl_parser.dart';
import 'package:habit_tracker/features/tasks/engine/task_urgency_engine.dart';
import 'package:habit_tracker/features/tasks/engine/smart_scheduler_engine.dart';
import 'package:habit_tracker/features/tasks/engine/attendance_gpa_engine.dart';
import 'package:habit_tracker/features/tasks/engine/rrule_recurrence_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box taskBox;
  late Box syncBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('task_os_test_');
    Hive.init(tempDir.path);
    taskBox = await Hive.openBox('task_os_box_test');
    syncBox = await Hive.openBox('sync_op_log_box_test');
    await TaskOsRepository.instance.init(
      overrideBox: taskBox,
      overrideSyncBox: syncBox,
    );
  });

  tearDownAll(() async {
    await taskBox.close();
    await syncBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Tasks OS Engines Test Suite', () {
    test('CAP-2: Natural Language Parser token extraction & title cleaning', () {
      // Mock fixed reference date: Wednesday, 2026-10-14 10:00:00
      final fixedNow = DateTime(2026, 10, 14, 10, 0);

      final input = 'DBMS record fri 5pm #DBMS !high ~2h @lab';
      final parsed = parseNaturalLanguageTask(input, fixedNow);

      expect(parsed.cleanTitle, 'DBMS record');
      expect(parsed.courseCode, 'DBMS');
      expect(parsed.priority, TaskPriority.high); // 2
      expect(parsed.estimateMin, 120); // ~2h -> 120 min
      expect(parsed.tags, contains('lab'));
      expect(parsed.hasDueTime, isTrue);

      // Verify Friday 5pm (2026-10-16 17:00)
      expect(parsed.dueAt, isNotNull);
      expect(parsed.dueAt!.weekday, DateTime.friday);
      expect(parsed.dueAt!.hour, 17);
      expect(parsed.dueAt!.minute, 0);

      // Verify Chips count
      expect(parsed.chips.length, greaterThanOrEqualTo(5));
      expect(parsed.chips.any((c) => c.type == ChipType.course), isTrue);
      expect(parsed.chips.any((c) => c.type == ChipType.duration), isTrue);
      expect(parsed.chips.any((c) => c.type == ChipType.priority), isTrue);
    });

    test('ACA-7: Attendance Math maxMissable and unreachable minimum', () {
      // 30 present, 6 absent, 20 remaining, required: 75%
      // Total = 56
      // 75% of 56 = 42
      // Max presents possible = 30 + 20 = 50
      // maxMissable = (50 - 42) = 8
      final stats = AttendanceGpaEngine.computeAttendanceStats(
        present: 30,
        absent: 6,
        remaining: 20,
        requiredPct: 0.75,
      );

      expect(stats.total, 56);
      expect(stats.maxMissable, 8);
      expect(stats.canNoLongerReachMin, isFalse);
      expect(stats.statusLabel, 'Safe');

      // Unreachable minimum case:
      // 10 present, 20 absent, 10 remaining, req: 0.75
      // Total = 40. Required = 30 presents. Max possible = 20 presents.
      final unreachableStats = AttendanceGpaEngine.computeAttendanceStats(
        present: 10,
        absent: 20,
        remaining: 10,
        requiredPct: 0.75,
      );

      expect(unreachableStats.canNoLongerReachMin, isTrue);
      expect(unreachableStats.maxMissable, 0);
      expect(unreachableStats.statusLabel, 'Unreachable');
    });

    test('ACA-8: Grade and Final Target Score Calculator', () {
      final components = [
        const GradeComponentItem(
          id: 'c1',
          name: 'Midterm 1',
          weightagePct: 30.0,
          maxMarks: 100.0,
          scoreObtained: 85.0, // 25.5 points
        ),
        const GradeComponentItem(
          id: 'c2',
          name: 'Assignments',
          weightagePct: 20.0,
          maxMarks: 100.0,
          scoreObtained: 90.0, // 18.0 points
        ),
      ];
      // Total so far = 25.5 + 18.0 = 43.5 out of 50.0
      // Final exam weight = 50.0%
      // Target course pct = 85.0%
      // Needed from final = 85.0 - 43.5 = 41.5 points out of 50% = 83.0%

      final target = AttendanceGpaEngine.computeRequiredFinalScore(
        components: components,
        finalExamWeightPct: 50.0,
        targetCoursePct: 85.0,
      );

      expect(target.isTargetAchievable, isTrue);
      expect(target.requiredFinalScorePct, closeTo(83.0, 0.01));
    });

    test('PLAN-1: Task Urgency Engine Formula & Ranking', () {
      final now = DateTime(2026, 10, 18, 12, 0);

      final overdueHighWeight = TaskItem(
        id: 't1',
        title: 'Project Submission',
        priority: TaskPriority.urgent,
        dueAt: now.subtract(const Duration(hours: 6)), // 6h overdue
        weightage: 30.0,
        estimateMin: 120,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      );

      final distantLowTask = TaskItem(
        id: 't2',
        title: 'Read Article',
        priority: TaskPriority.low,
        dueAt: now.add(const Duration(days: 10)),
        weightage: 0.0,
        estimateMin: 30,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

      final urgency1 = computeUrgency(overdueHighWeight, now);
      final urgency2 = computeUrgency(distantLowTask, now);

      expect(urgency1, greaterThan(urgency2));
      expect(urgency1, greaterThan(70.0));

      final ranked = rankTasksByUrgency([distantLowTask, overdueHighWeight], now);
      expect(ranked.first.id, 't1');
    });

    test('TSK-5: Recurrence Engine fixed and afterCompletion modes', () {
      final now = DateTime(2026, 10, 18, 10, 0);

      // Fixed daily task due yesterday, completed today
      final fixedDaily = TaskItem(
        id: 'rec_fixed',
        title: 'Daily Workout',
        dueAt: DateTime(2026, 10, 17, 8, 0),
        recurrenceRule: 'FREQ=DAILY',
        recurrenceMode: 'fixed',
        hasDueTime: true,
        createdAt: now,
        updatedAt: now,
      );

      final nextFixed = RruleRecurrenceEngine.computeNextDueDate(
        task: fixedDaily,
        completedAt: now,
      );
      // Fixed computes from original dueAt: Oct 17 + 1 day = Oct 18 at 08:00
      expect(nextFixed, DateTime(2026, 10, 18, 8, 0));

      // After completion mode: computes strictly from completedAt
      final afterCompletionDaily = fixedDaily.copyWith(
        recurrenceMode: 'afterCompletion',
      );
      final nextAfterComp = RruleRecurrenceEngine.computeNextDueDate(
        task: afterCompletionDaily,
        completedAt: now,
      );
      // Completed Oct 18 10:00 + 1 day = Oct 19 at 08:00 (preserving due time)
      expect(nextAfterComp, DateTime(2026, 10, 19, 8, 0));

      // Spawning next occurrence
      final spawned = RruleRecurrenceEngine.spawnNextRecurringInstance(
        task: fixedDaily,
        completedAt: now,
      );
      expect(spawned, isNotNull);
      expect(spawned!.status, TaskStatus.todo);
      expect(spawned.dueAt, nextFixed);
    });

    test('PLAN-2 & PLAN-3: Smart Scheduler free windows & proposal', () {
      final testDate = DateTime(2026, 10, 19); // Monday
      const rules = SchedulingRules(
        workStartHour: 8,
        workEndHour: 18,
        minBlockMin: 25,
        maxContinuousMin: 90,
      );

      // Class 10:00 - 12:00 (600 to 720 minutes)
      final slots = [
        const TimetableSlotItem(
          id: 'slot_1',
          courseId: 'CS101',
          dayOfWeek: 1, // Monday
          startMinutes: 600, // 10:00
          endMinutes: 720, // 12:00
        ),
      ];

      final freeWindows = SmartSchedulerEngine.computeFreeWindows(
        date: testDate,
        timetableSlots: slots,
        exams: [],
        rules: rules,
      );

      // Expect two main free windows: 08:00–10:00 and 12:00–18:00
      expect(freeWindows.length, 2);
      expect(freeWindows[0].start.hour, 8);
      expect(freeWindows[0].end.hour, 10);
      expect(freeWindows[1].start.hour, 12);
      expect(freeWindows[1].end.hour, 18);

      final openTasks = [
        TaskItem(
          id: 'task_study',
          title: 'Study Data Structures',
          priority: TaskPriority.high,
          dueAt: testDate.add(const Duration(hours: 15)),
          estimateMin: 60,
          createdAt: testDate,
          updatedAt: testDate,
        ),
      ];

      final plan = SmartSchedulerEngine.generateDailyPlan(
        date: testDate,
        openTasks: openTasks,
        timetableSlots: slots,
        exams: [],
        rules: rules,
      );

      expect(plan.blocks.length, greaterThanOrEqualTo(1));
      expect(plan.blocks.first.taskId, 'task_study');
      expect(plan.blocks.first.title, contains('Data Structures'));
      expect(plan.blocks.first.reason, contains('fits free slot'));
    });

    test('PLAN-7 & PLAN-10: Milestones & Workload Heatmap', () {
      final due = DateTime(2026, 10, 30, 17, 0);
      final milestones = SmartSchedulerEngine.proposeBackwardsMilestones(
        title: 'Final Term Paper',
        estimateMin: 360,
        dueAt: due,
      );

      expect(milestones.length, 4);
      expect(milestones[0].order, 1);
      expect(milestones[3].order, 4);

      final weekly = SmartSchedulerEngine.computeWeeklyWorkload(
        startDate: DateTime(2026, 10, 19),
        tasks: [],
        timetableSlots: [],
        exams: [],
      );

      expect(weekly.days.length, 7);
      expect(weekly.hasOverloadWarning, isFalse);
    });
  });
}
