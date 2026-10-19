import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/attendance_gpa_engine.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';

/// Cross-sector domains recognized by the unified personal OS assistant.
enum AiSector { diet, finance, tasks, habits, academics, health, journal }

class AiContext {
  /// Fast on-device keyword classifier to determine which sectors are relevant to user input.
  static Set<AiSector> classifyPromptSectors(String prompt) {
    final lower = prompt.toLowerCase();
    final sectors = <AiSector>{};

    // Diet indicators
    if (RegExp(r'\b(eat|ate|eating|diet|food|meal|calorie|calories|kcal|protein|carbs|fat|fats|water|drink|drank|breakfast|lunch|dinner|snack|hungry|nutrition|macro|macros)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.diet);
    }

    // Finance indicators
    if (RegExp(r'\b(spend|spent|spending|money|expense|expenses|income|budget|save|savings|cost|buy|bought|paid|pay|rupee|rupees|rs|₹|salary|bill|bills|tx|transaction|transfer|sip|emi|invest|investment|account|wallet|kharcha)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.finance);
    }

    // Task indicators (one-time items)
    if (RegExp(r'\b(task|tasks|todo|finish|complete|assignment|assignments|deadline|due|remind|reminder|hw|homework|record|submission)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.tasks);
    }

    // Habit indicators (recurring routines)
    if (RegExp(r'\b(habit|habits|streak|streaks|daily|routine|everyday|every\s+day|weekly|routine)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.habits);
    }

    // Academic indicators
    if (RegExp(r'\b(class|classes|lecture|lectures|attendance|course|courses|subject|subjects|exam|exams|semester|syllabus|timetable|slot|professor|college)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.academics);
    }

    // Health & Wearables indicators
    if (RegExp(r'\b(step|steps|sleep|sleeping|wake|wakeup|woke|workout|hr|heart\s*rate|weight|kg|wearable|watch|galaxy)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.health);
    }

    // Journal indicators
    if (RegExp(r'\b(journal|diary|note|notes|reflect|reflection|thought|thoughts|log\s+note)\b')
        .hasMatch(lower)) {
      sectors.add(AiSector.journal);
    }

    return sectors;
  }

  /// Minified JSON delta payload (<150 tokens) containing ONLY the relevant sectors.
  static String buildDeltaContext(Set<AiSector> sectors) {
    if (sectors.isEmpty) return '';

    final delta = <String, dynamic>{};
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Diet delta
    if (sectors.contains(AiSector.diet)) {
      try {
        final repo = DietRepository.instance;
        final logs = repo.getLogsForDate(today);
        final targets = repo.dailyTargets;
        final calIn = logs.fold(0.0, (sum, e) => sum + e.kcal).round();
        final pIn = logs.fold(0.0, (sum, e) => sum + e.proteinG).round();

        delta['d'] = {
          'cal': calIn,
          'tgt': targets.targetKcal.round(),
          'p': pIn,
          'p_tgt': targets.proteinG.round(),
          'w': repo.waterDrankMl(today).round(),
        };
      } catch (_) {}
    }

    // 2. Finance delta
    if (sectors.contains(AiSector.finance)) {
      try {
        bool allowed = true;
        if (Hive.isBoxOpen('finance_settings')) {
          allowed = Hive.box('finance_settings')
              .get('ai_finance_privacy', defaultValue: true);
        }
        if (allowed) {
          final snapshot = MoneyState().value;
          delta['f'] = {
            'bal': snapshot.mainBalanceRupees.round(),
            'safe': snapshot.freeToSpend.freeToSpendRupees.round(),
            'inc': snapshot.monthReceivedRupees.round(),
            'exp': snapshot.monthSpentRupees.round(),
          };
        }
      } catch (_) {}
    }

    // 3. Tasks delta
    if (sectors.contains(AiSector.tasks)) {
      try {
        final repo = TaskOsRepository.instance;
        final todayTasks = repo.getTasksForDate(today);
        final overdue = repo.getOverdueTasks(DateTime.now());
        delta['t'] = {
          'due': todayTasks.where((t) => !t.isDone).map((t) => t.title).take(5).toList(),
          'od': overdue.length,
        };
      } catch (_) {}
    }

    // 4. Habits delta
    if (sectors.contains(AiSector.habits)) {
      try {
        final repo = TaskOsRepository.instance;
        delta['h'] = repo.habits.take(5).map((h) => {
          't': h.title,
          's': h.computeCurrentStreak(),
          'd': h.isCompletedToday,
        }).toList();
      } catch (_) {}
    }

    // 5. Academics delta
    if (sectors.contains(AiSector.academics)) {
      try {
        final repo = TaskOsRepository.instance;
        final logs = repo.sessionLogs;
        final lowAtt = <Map<String, dynamic>>[];
        for (final c in repo.courses) {
          final stats = AttendanceGpaEngine.calculateAttendanceStats(
            course: c,
            sessionLogs: logs,
          );
          if (stats.attendedPct < 0.75 && stats.total > 0) {
            lowAtt.add({'c': c.code, 'att': (stats.attendedPct * 100).round()});
          }
        }
        if (lowAtt.isNotEmpty) {
          delta['a'] = {'low_att': lowAtt};
        }
      } catch (_) {}
    }

    // 6. Health & Wearable delta
    if (sectors.contains(AiSector.health)) {
      try {
        if (WearableSettings.aiShare) {
          final view = WearableRepository.instance.dayView(today);
          delta['w'] = {
            'stp': view.totalSteps,
            if (view.mainSleep != null) 'slp_min': view.mainSleep!.durationMin,
            if (view.latestWeight != null) 'wt': view.latestWeight,
          };
        }
      } catch (_) {}
    }

    return delta.isEmpty ? '' : jsonEncode(delta);
  }

  /// Compact system prompt enforcing unified multi-action schema (<200 tokens).
  static String buildSystemPrompt() {
    return '''Habit OS AI. JSON ONLY without markdown:
{"reply":"Concise response","actions":[{"sector":"","op":"","data":{}}]}
Valid action operations:
- sector "diet", op "log_meal", data: {"name":"str","cal":num,"p":num,"c":num,"f":num,"slot":"breakfast|lunch|dinner|snack"}
- sector "diet", op "log_water", data: {"ml":num}
- sector "finance", op "add_tx", data: {"amount":num,"title":"str","category":"str","is_expense":bool}
- sector "tasks", op "add_task", data: {"title":"str","date":"YYYY-MM-DD","priority":"low|medium|high"}
- sector "habits", op "add_habit", data: {"title":"str","frequency":"daily|weekly"}
- sector "journal", op "add_note", data: {"text":"str"}
No actions needed -> "actions":[]. Keep replies friendly and under 2 sentences.''';
  }

  // --- Backward-compatible fallbacks for legacy consumers ---
  static String buildDietContext(double t) {
    try {
      final repo = DietRepository.instance;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final logs = repo.getLogsForDate(today);
      final targets = repo.dailyTargets;
      final consumedKcal = logs.fold(0.0, (sum, e) => sum + e.kcal).round();
      final consumedProtein = logs.fold(0.0, (sum, e) => sum + e.proteinG).round();
      final targetProtein = targets.proteinG.round();

      if (repo.profile.hideCaloriesMode) {
        return '[DIET-HABIT] Mode:HabitFocus Protein: $consumedProtein / $targetProtein g Water: ${repo.waterDrankMl(today).round()}ml';
      }

      final targetKcal = targets.targetKcal.round();
      return '[DIET] In: $consumedKcal kcal Tgt: $targetKcal kcal Prot: $consumedProtein / $targetProtein g Water: ${repo.waterDrankMl(today).round()}ml';
    } catch (_) {
      return '';
    }
  }

  static String buildFinanceContext() {
    try {
      if (Hive.isBoxOpen('finance_settings')) {
        final allowed = Hive.box('finance_settings')
            .get('ai_finance_privacy', defaultValue: true);
        if (allowed == false) return '';
      }
      final snapshot = MoneyState().value;
      return '[FIN] Main:${snapshot.mainBalanceRupees.round()} Free:${snapshot.freeToSpend.freeToSpendRupees.round()} Inc:${snapshot.monthReceivedRupees.round()} Exp:${snapshot.monthSpentRupees.round()}';
    } catch (_) {
      return '';
    }
  }

  static String buildTaskContext() {
    try {
      final goals = Hive.box<Goal>('mission_box_v4').values.toList();
      int c = goals.where((g) => g.isCompleted == true).length;
      int a = goals.where((g) => g.isCompleted != true && g.isArchived != true).length;
      return '[TASK] Act:$a Dn:$c';
    } catch (_) {
      return '';
    }
  }

  static String buildWearContext() {
    try {
      if (!WearableSettings.aiShare) return '';
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final view = WearableRepository.instance.dayView(todayKey);
      final parts = <String>[];
      if (view.totalSteps > 0) parts.add('Stp:${view.totalSteps}');
      if (view.mainSleep?.durationMin != null && view.mainSleep!.durationMin > 0) {
        parts.add('Slp:${view.mainSleep!.durationMin ~/ 60}h${view.mainSleep!.durationMin % 60}m');
      }
      if (parts.isEmpty) return '';
      return '[WEAR] ${parts.join(" ")}';
    } catch (_) {
      return '';
    }
  }
}

