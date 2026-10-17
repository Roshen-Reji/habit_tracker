import 'minor.dart';
import 'plan_engine.dart';

/// Calculation result for Law L7: Free to spend.
class FreeToSpendResult {
  final int availableMinor; // Main balance
  final int comingUpMinor; // Plans due before month end (not yet posted)
  final int freeToSpendMinor; // available - comingUp
  final List<PlanOccurrence> upcomingPlansThisMonth;

  const FreeToSpendResult({
    required this.availableMinor,
    required this.comingUpMinor,
    required this.freeToSpendMinor,
    required this.upcomingPlansThisMonth,
  });

  bool get isShort => freeToSpendMinor < 0;
  int get shortByMinor => isShort ? freeToSpendMinor.abs() : 0;

  double get availableRupees => Minor.fromMinor(availableMinor);
  double get comingUpRupees => Minor.fromMinor(comingUpMinor);
  double get freeToSpendRupees => Minor.fromMinor(freeToSpendMinor);
  double get shortByRupees => Minor.fromMinor(shortByMinor);
}

/// Pure Dart calculator for Free to Spend (Law L7).
class FreeToSpendCalculator {
  FreeToSpendCalculator._();

  /// Calculates the 3-line Free to Spend breakdown for the current month.
  ///
  /// Law L7: Free to spend = Main balance - Plans still due before month end.
  static FreeToSpendResult calculate({
    required int mainBalanceMinor,
    required Iterable<CorePlan> plans,
    required Set<String> postedKeys,
    DateTime? clock,
  }) {
    final now = clock ?? DateTime.now();
    final endOfMonth = DateTime(
      now.year,
      now.month,
      PlanEngine.daysInMonth(now.year, now.month),
      23,
      59,
      59,
      999,
    );

    final upcoming = <PlanOccurrence>[];
    int comingUpTotal = 0;

    for (final plan in plans) {
      if (plan.isPaused) continue;
      // Only outflow plans (SIP, EMI, Bill) reduce Free to Spend
      if (plan.kind == PlanKind.income) continue;

      final occurrenceDate = PlanEngine.resolveOccurrenceDate(
        now.year,
        now.month,
        plan.dayOfMonth,
      );

      // Must be within the current month, after or on now, and not before plan start
      final isDueThisMonth = !occurrenceDate.isBefore(
            DateTime(now.year, now.month, now.day),
          ) &&
          !occurrenceDate.isAfter(endOfMonth) &&
          !occurrenceDate.isBefore(
            DateTime(
              plan.startDate.year,
              plan.startDate.month,
              plan.startDate.day,
            ),
          );

      if (isDueThisMonth) {
        final key = CorePlan.formatKey(plan.id, occurrenceDate);
        if (!postedKeys.contains(key)) {
          final occ = PlanOccurrence(
            plan: plan,
            dueDate: occurrenceDate,
            idempotentKey: key,
            amountMinor: plan.amountMinor,
          );
          upcoming.add(occ);
          comingUpTotal += plan.amountMinor;
        }
      }
    }

    // Sort upcoming plans by due date
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return FreeToSpendResult(
      availableMinor: mainBalanceMinor,
      comingUpMinor: comingUpTotal,
      freeToSpendMinor: mainBalanceMinor - comingUpTotal,
      upcomingPlansThisMonth: upcoming,
    );
  }
}
