import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

/// Recurrence Engine supporting RFC-5545 RRULE logic and 'afterCompletion' mode (TSK-5)
class RruleRecurrenceEngine {
  /// Computes the next occurrence DateTime for a given task
  static DateTime? computeNextDueDate({
    required TaskItem task,
    required DateTime completedAt,
  }) {
    if (task.recurrenceRule == null || task.recurrenceRule!.isEmpty) {
      return null;
    }

    final rrule = task.recurrenceRule!.toUpperCase();
    final parts = _parseRrule(rrule);

    final freq = parts['FREQ'] ?? 'DAILY';
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    final byDays = parts['BYDAY']?.split(',') ?? [];

    // Base date to compute from
    final baseDate = (task.recurrenceMode == 'afterCompletion')
        ? completedAt
        : (task.dueAt ?? completedAt);

    DateTime candidate;

    switch (freq) {
      case 'DAILY':
        candidate = baseDate.add(Duration(days: interval));
        break;

      case 'WEEKLY':
        if (byDays.isNotEmpty) {
          candidate = _nextByDayOccurrence(baseDate, byDays, interval);
        } else {
          candidate = baseDate.add(Duration(days: 7 * interval));
        }
        break;

      case 'MONTHLY':
        candidate = DateTime(
          baseDate.year,
          baseDate.month + interval,
          baseDate.day,
          baseDate.hour,
          baseDate.minute,
        );
        break;

      default:
        candidate = baseDate.add(Duration(days: interval));
        break;
    }

    // Preserve time if original task had an explicit due time
    if (task.hasDueTime && task.dueAt != null) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        task.dueAt!.hour,
        task.dueAt!.minute,
      );
    }

    return candidate;
  }

  /// Handles completion of a recurring task by returning a spawned next occurrence
  static TaskItem? spawnNextRecurringInstance({
    required TaskItem task,
    required DateTime completedAt,
  }) {
    if (!task.isRecurring) return null;

    final nextDue = computeNextDueDate(task: task, completedAt: completedAt);
    if (nextDue == null) return null;

    final nextId = 'task_${DateTime.now().millisecondsSinceEpoch}_rec';

    // Reset subtasks to uncompleted for the new occurrence
    final resetSubtasks = task.subtasks
        .map((s) => s.copyWith(isCompleted: false))
        .toList();

    return task.copyWith(
      id: nextId,
      status: TaskStatus.todo,
      dueAt: nextDue,
      completedAt: null,
      subtasks: resetSubtasks,
      actualMin: 0,
      createdAt: completedAt,
      updatedAt: completedAt,
    );
  }

  static Map<String, String> _parseRrule(String rrule) {
    final map = <String, String>{};
    final pairs = rrule.split(';');
    for (var pair in pairs) {
      final kv = pair.split('=');
      if (kv.length == 2) {
        map[kv[0].trim()] = kv[1].trim();
      }
    }
    return map;
  }

  static DateTime _nextByDayOccurrence(
      DateTime baseDate, List<String> byDays, int interval) {
    const dayMap = {
      'MO': DateTime.monday,
      'TU': DateTime.tuesday,
      'WE': DateTime.wednesday,
      'TH': DateTime.thursday,
      'FR': DateTime.friday,
      'SA': DateTime.saturday,
      'SU': DateTime.sunday,
    };

    final targetWeekdays = byDays
        .map((d) => dayMap[d.trim()])
        .where((d) => d != null)
        .cast<int>()
        .toList();

    if (targetWeekdays.isEmpty) {
      return baseDate.add(Duration(days: 7 * interval));
    }

    targetWeekdays.sort();

    // Look for next weekday in current week
    for (var day in targetWeekdays) {
      if (day > baseDate.weekday) {
        return DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day + (day - baseDate.weekday),
          baseDate.hour,
          baseDate.minute,
        );
      }
    }

    // Otherwise, wrap around to first target day in next cycle (after interval weeks)
    final daysUntilEndOfWeek = 7 - baseDate.weekday;
    final firstTargetDay = targetWeekdays.first;
    final additionalDays =
        daysUntilEndOfWeek + ((interval - 1) * 7) + firstTargetDay;

    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day + additionalDays,
      baseDate.hour,
      baseDate.minute,
    );
  }
}
