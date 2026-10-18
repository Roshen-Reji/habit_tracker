import 'dart:math' as math;
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class UrgencyScoreBreakdown {
  final double totalScore;
  final double dueProximityScore; // Max 40
  final double priorityScore; // Max 25
  final double weightageScore; // Max 15
  final double overdueScore; // Max 10
  final double effortPressureScore; // Max 10
  final String explanation;

  const UrgencyScoreBreakdown({
    required this.totalScore,
    required this.dueProximityScore,
    required this.priorityScore,
    required this.weightageScore,
    required this.overdueScore,
    required this.effortPressureScore,
    required this.explanation,
  });
}

/// Compute the deterministic urgency score (0.0 to 100.0) for a task (PLAN-1)
double computeUrgency(TaskItem task, DateTime now) {
  return computeUrgencyBreakdown(task, now).totalScore;
}

/// Computes the full breakdown and explanation for a task's urgency
UrgencyScoreBreakdown computeUrgencyBreakdown(TaskItem task, DateTime now) {
  if (task.isDone || task.isDeleted) {
    return const UrgencyScoreBreakdown(
      totalScore: 0.0,
      dueProximityScore: 0.0,
      priorityScore: 0.0,
      weightageScore: 0.0,
      overdueScore: 0.0,
      effortPressureScore: 0.0,
      explanation: 'Completed or archived',
    );
  }

  // 1. Due Proximity (Max 40 points)
  double dueProximity = 0.05;
  double overdueFactor = 0.0;
  double hoursUntilDue = 168.0;

  if (task.dueAt != null) {
    final diff = task.dueAt!.difference(now);
    final hoursDiff = diff.inMinutes / 60.0;
    hoursUntilDue = math.max(0.0, hoursDiff);

    if (hoursDiff <= 0) {
      // Overdue
      dueProximity = 1.0;
      final daysOverdue = (-hoursDiff) / 24.0;
      overdueFactor = (daysOverdue.clamp(0.0, 7.0)) / 7.0;
    } else if (hoursDiff <= 24.0) {
      // Due today
      dueProximity = 1.0;
    } else {
      // Decaying linearly toward 0.0 over 7 days (168 hours)
      dueProximity = (1.0 - (hoursDiff / 168.0)).clamp(0.0, 1.0);
    }
  }

  // 2. Priority Weight (Max 25 points)
  double priorityWeight = 0.0;
  switch (task.priority) {
    case TaskPriority.urgent: // P1
      priorityWeight = 1.0;
      break;
    case TaskPriority.high: // P2
      priorityWeight = 0.66;
      break;
    case TaskPriority.medium: // P3
      priorityWeight = 0.33;
      break;
    case TaskPriority.low: // P4
    default:
      priorityWeight = 0.0;
      break;
  }

  // 3. Weightage Factor (Max 15 points)
  final weightageFactor =
      ((task.weightage ?? 0.0).clamp(0.0, 100.0)) / 100.0;

  // 4. Overdue Factor (Max 10 points - computed above)

  // 5. Effort Pressure (Max 10 points)
  final effortHours = (task.estimateMin ?? 30) / 60.0;
  final divisor = math.max(1.0, hoursUntilDue);
  final effortPressure = (effortHours / divisor).clamp(0.0, 1.0);

  final dueProximityScore = 40.0 * dueProximity;
  final priorityScore = 25.0 * priorityWeight;
  final weightageScore = 15.0 * weightageFactor;
  final overdueScore = 10.0 * overdueFactor;
  final effortPressureScore = 10.0 * effortPressure;

  final totalScore = (dueProximityScore +
          priorityScore +
          weightageScore +
          overdueScore +
          effortPressureScore)
      .clamp(0.0, 100.0);

  // Generate deterministic explanation string
  final explanationParts = <String>[];
  if (task.dueAt != null) {
    final diff = task.dueAt!.difference(now);
    if (diff.isNegative) {
      final days = (-diff.inDays);
      explanationParts.add(days == 0 ? 'Overdue today' : 'Overdue by ${days}d');
    } else if (diff.inHours < 24) {
      explanationParts.add('Due in ${diff.inHours}h');
    } else {
      explanationParts.add('Due in ${diff.inDays}d');
    }
  }

  if (task.priority <= TaskPriority.high) {
    explanationParts.add('${TaskPriority.label(task.priority)} priority');
  }

  if (task.weightage != null && task.weightage! > 0) {
    explanationParts.add('${task.weightage!.toStringAsFixed(0)}% grade weight');
  }

  if (effortPressure > 0.5) {
    explanationParts.add('Tight effort window');
  }

  final explanation = explanationParts.isEmpty
      ? 'Next prioritized task'
      : explanationParts.join(' · ');

  return UrgencyScoreBreakdown(
    totalScore: totalScore,
    dueProximityScore: dueProximityScore,
    priorityScore: priorityScore,
    weightageScore: weightageScore,
    overdueScore: overdueScore,
    effortPressureScore: effortPressureScore,
    explanation: explanation,
  );
}

/// Ranks open tasks descending by urgency score; ties broken by oldest createdAt
List<TaskItem> rankTasksByUrgency(List<TaskItem> tasks, DateTime now) {
  final openTasks = tasks.where((t) => !t.isDone && !t.isDeleted).toList();

  openTasks.sort((a, b) {
    final scoreA = computeUrgency(a, now);
    final scoreB = computeUrgency(b, now);
    final diff = scoreB.compareTo(scoreA);
    if (diff != 0) return diff;
    // Tie-break by oldest createdAt
    return a.createdAt.compareTo(b.createdAt);
  });

  return openTasks;
}
