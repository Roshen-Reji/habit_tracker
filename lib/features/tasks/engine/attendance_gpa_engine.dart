import 'dart:math' as math;
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class AttendanceStats {
  final int present;
  final int absent;
  final int remaining;
  final int total;
  final double attendedPct; // Current attendance fraction e.g. 0.83
  final double requiredPct; // Required attendance e.g. 0.75
  final int maxMissable; // Classes you can still miss without dropping below requiredPct
  final int mustAttendNext; // Consecutively needed if currently below requiredPct
  final bool canNoLongerReachMin; // True if even 100% future attendance cannot meet requiredPct
  final String statusLabel; // 'Safe', 'Warning', 'Danger', 'Unreachable'

  const AttendanceStats({
    required this.present,
    required this.absent,
    required this.remaining,
    required this.total,
    required this.attendedPct,
    required this.requiredPct,
    required this.maxMissable,
    required this.mustAttendNext,
    required this.canNoLongerReachMin,
    required this.statusLabel,
  });
}

class GradeTargetResult {
  final double currentWeightedScore; // e.g. 45.0 out of 50.0 completed
  final double completedWeightPct; // e.g. 50.0%
  final double remainingWeightPct; // e.g. 50.0%
  final double targetCoursePct; // e.g. 85.0%
  final double requiredFinalScorePct; // e.g. 80.0% needed on final
  final bool isTargetAchievable;
  final String analysis;

  const GradeTargetResult({
    required this.currentWeightedScore,
    required this.completedWeightPct,
    required this.remainingWeightPct,
    required this.targetCoursePct,
    required this.requiredFinalScorePct,
    required this.isTargetAchievable,
    required this.analysis,
  });
}

/// Academic Attendance and GPA Target Engine (ACA-7, ACA-8)
class AttendanceGpaEngine {
  /// Computes accurate attendance metrics and risk indicators (ACA-7)
  static AttendanceStats computeAttendanceStats({
    required int present,
    required int absent,
    required int remaining,
    double requiredPct = 0.75,
  }) {
    final attendedClasses = present + absent;
    final total = attendedClasses + remaining;

    final double attendedPct =
        attendedClasses == 0 ? 1.0 : (present / attendedClasses);

    // Can we reach the required minimum even with 100% attendance from now on?
    final maxPossiblePresents = present + remaining;
    final minRequiredPresents = total * requiredPct;
    final bool canNoLongerReachMin = maxPossiblePresents < minRequiredPresents;

    // How many classes can still be missed out of remaining?
    // (present + remaining - miss) / total >= requiredPct
    // present + remaining - miss >= requiredPct * total
    // miss <= present + remaining - (requiredPct * total)
    final int maxMissable = canNoLongerReachMin
        ? 0
        : math.max(0, (maxPossiblePresents - minRequiredPresents).floor());

    // If currently below requiredPct, how many consecutive classes must be attended?
    // (present + x) / (attendedClasses + x) >= requiredPct
    // present + x >= requiredPct * attendedClasses + requiredPct * x
    // x * (1 - requiredPct) >= requiredPct * attendedClasses - present
    int mustAttendNext = 0;
    if (attendedPct < requiredPct && requiredPct < 1.0) {
      final numerator = (requiredPct * attendedClasses) - present;
      final denominator = 1.0 - requiredPct;
      mustAttendNext = math.max(0, (numerator / denominator).ceil());
    }

    String statusLabel = 'Safe';
    if (canNoLongerReachMin) {
      statusLabel = 'Unreachable';
    } else if (attendedPct < requiredPct) {
      statusLabel = 'Danger';
    } else if (maxMissable <= 1) {
      statusLabel = 'Warning';
    }

    return AttendanceStats(
      present: present,
      absent: absent,
      remaining: remaining,
      total: total,
      attendedPct: attendedPct,
      requiredPct: requiredPct,
      maxMissable: maxMissable,
      mustAttendNext: mustAttendNext,
      canNoLongerReachMin: canNoLongerReachMin,
      statusLabel: statusLabel,
    );
  }

  /// Calculates the required score on final exam to achieve target course grade (ACA-8)
  static GradeTargetResult computeRequiredFinalScore({
    required List<GradeComponentItem> components,
    required double finalExamWeightPct,
    required double targetCoursePct,
  }) {
    double completedWeight = 0.0;
    double currentWeightedSum = 0.0;

    for (var comp in components) {
      if (comp.scoreObtained != null && comp.maxMarks > 0) {
        final compScoreFraction = comp.scoreObtained! / comp.maxMarks;
        currentWeightedSum += compScoreFraction * comp.weightagePct;
        completedWeight += comp.weightagePct;
      }
    }

    final remainingWeight = finalExamWeightPct;
    if (remainingWeight <= 0) {
      return GradeTargetResult(
        currentWeightedScore: currentWeightedSum,
        completedWeightPct: completedWeight,
        remainingWeightPct: 0.0,
        targetCoursePct: targetCoursePct,
        requiredFinalScorePct: 0.0,
        isTargetAchievable: currentWeightedSum >= targetCoursePct,
        analysis: currentWeightedSum >= targetCoursePct
            ? 'Target already secured!'
            : 'No remaining weightage available.',
      );
    }

    // currentWeightedSum + (reqScore * remainingWeight) = targetCoursePct
    // reqScore * remainingWeight = targetCoursePct - currentWeightedSum
    final neededWeightScore = targetCoursePct - currentWeightedSum;
    final requiredFraction = neededWeightScore / remainingWeight;
    final requiredScorePct = requiredFraction * 100.0;

    final isAchievable = requiredScorePct <= 100.0;

    String analysis;
    if (requiredScorePct <= 0) {
      analysis = 'Target already locked in with current scores!';
    } else if (isAchievable) {
      analysis =
          'You need ${requiredScorePct.toStringAsFixed(1)}% on the final to achieve ${targetCoursePct.toStringAsFixed(0)}% overall.';
    } else {
      analysis =
          'Target of ${targetCoursePct.toStringAsFixed(0)}% mathematically unreachable (needs ${requiredScorePct.toStringAsFixed(1)}%).';
    }

    return GradeTargetResult(
      currentWeightedScore: currentWeightedSum,
      completedWeightPct: completedWeight,
      remainingWeightPct: remainingWeight,
      targetCoursePct: targetCoursePct,
      requiredFinalScorePct: math.max(0.0, requiredScorePct),
      isTargetAchievable: isAchievable,
      analysis: analysis,
    );
  }

  /// Computes cumulative GPA given completed course credits and scores
  static double computeSemesterGpa(List<CourseItem> courses) {
    double totalQualityPoints = 0.0;
    double totalCredits = 0.0;

    for (var c in courses) {
      if (c.deletedAt != null || c.gradeComponents.isEmpty) continue;

      double courseWeightedPct = 0.0;
      double weightSum = 0.0;
      for (var comp in c.gradeComponents) {
        if (comp.scoreObtained != null && comp.maxMarks > 0) {
          final frac = comp.scoreObtained! / comp.maxMarks;
          courseWeightedPct += frac * comp.weightagePct;
          weightSum += comp.weightagePct;
        }
      }

      if (weightSum > 0) {
        final finalPct = (courseWeightedPct / weightSum) * 100.0;
        final gradePoints = _pctToGradePoints(finalPct, c.gradeScale);
        totalQualityPoints += (gradePoints * c.credits);
        totalCredits += c.credits;
      }
    }

    if (totalCredits == 0) return 0.0;
    return totalQualityPoints / totalCredits;
  }

  static double _pctToGradePoints(double pct, String scale) {
    if (scale == 'cgpa10') {
      // 10-point scale: 90+ -> 10, 80-89 -> 9, etc.
      if (pct >= 90) return 10.0;
      if (pct >= 80) return 9.0;
      if (pct >= 70) return 8.0;
      if (pct >= 60) return 7.0;
      if (pct >= 50) return 6.0;
      if (pct >= 40) return 5.0;
      return 0.0;
    } else {
      // 4.0 scale
      if (pct >= 93) return 4.0;
      if (pct >= 90) return 3.7;
      if (pct >= 87) return 3.3;
      if (pct >= 83) return 3.0;
      if (pct >= 80) return 2.7;
      if (pct >= 75) return 2.3;
      if (pct >= 70) return 2.0;
      return 0.0;
    }
  }
}
