import 'minor.dart';

/// The four scheduled plan automation types.
enum PlanKind {
  sip, // Main -> Fund
  emi, // Main -> Loan
  bill, // Main -> External
  income, // External -> Main
}

/// Pure Dart representation of an automation Plan.
class CorePlan {
  final String id;
  final String title;
  final PlanKind kind;
  final int amountMinor;
  final int dayOfMonth; // 1 - 31
  final String? fromAccountId;
  final String? toAccountId;
  final DateTime startDate;
  final DateTime? endDate;
  final bool autoPost;
  final bool isPaused;
  final String? category;
  final String? categoryId;

  const CorePlan({
    required this.id,
    required this.title,
    required this.kind,
    required this.amountMinor,
    required this.dayOfMonth,
    this.fromAccountId,
    this.toAccountId,
    required this.startDate,
    this.endDate,
    this.autoPost = true,
    this.isPaused = false,
    this.category,
    this.categoryId,
  });

  String get name => title;
  bool get isSIP => kind == PlanKind.sip;
  bool get isEMI => kind == PlanKind.emi;
  bool get isBill => kind == PlanKind.bill;
  bool get isIncome => kind == PlanKind.income;

  /// Generates the strictly idempotent occurrence key (Law L6): `plan:{id}:{yyyy-MM-dd}`.
  static String formatKey(String planId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'plan:$planId:$y-$m-$d';
  }
}

/// A specific scheduled occurrence of a Plan.
class PlanOccurrence {
  final CorePlan plan;
  final DateTime dueDate;
  final String idempotentKey;
  final int amountMinor;
  final bool needsFunds;

  const PlanOccurrence({
    required this.plan,
    required this.dueDate,
    required this.idempotentKey,
    required this.amountMinor,
    this.needsFunds = false,
  });

  double get amountRupees => Minor.fromMinor(amountMinor);
}

/// Pure Dart engine for scheduling, evaluating, and generating Plan occurrences (Law L6).
class PlanEngine {
  PlanEngine._();

  /// Calculates the last day of a given month/year.
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Clamps the specified day of month to the month's maximum valid day.
  /// Handles months with 28, 29, 30, or 31 days.
  static DateTime resolveOccurrenceDate(int year, int month, int targetDay) {
    final maxDay = daysInMonth(year, month);
    final clampedDay = targetDay.clamp(1, maxDay);
    return DateTime(year, month, clampedDay);
  }

  /// Generates all due occurrences for a plan up to [clock].
  ///
  /// Enforces Law L6:
  /// - Each occurrence has key `plan:{id}:{yyyy-MM-dd}`.
  /// - Only evaluates occurrences between [effectiveStartDate] and [clock].
  /// - Checks against [existingKeys] to ensure idempotency.
  /// - Marks [needsFunds] if Main account balance is insufficient for outflow plans.
  static List<PlanOccurrence> evaluateDue({
    required CorePlan plan,
    required DateTime effectiveStartDate,
    required DateTime clock,
    required Set<String> existingKeys,
    required int mainBalanceMinor,
  }) {
    if (plan.isPaused) return const [];

    final due = <PlanOccurrence>[];
    DateTime cursor =
        DateTime(effectiveStartDate.year, effectiveStartDate.month);
    final endLimit = DateTime(clock.year, clock.month);

    int runningMainBalance = mainBalanceMinor;

    while (!cursor.isAfter(endLimit)) {
      final dueDate = resolveOccurrenceDate(
        cursor.year,
        cursor.month,
        plan.dayOfMonth,
      );

      // Must be on or after startDate and on or before clock
      final isAfterStart = !dueDate.isBefore(
        DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day),
      );
      final isBeforeOrAtClock = !dueDate.isAfter(clock);
      final isBeforeEnd =
          plan.endDate == null || !dueDate.isAfter(plan.endDate!);

      if (isAfterStart && isBeforeOrAtClock && isBeforeEnd) {
        final key = CorePlan.formatKey(plan.id, dueDate);

        if (!existingKeys.contains(key)) {
          final isOutflow = plan.kind != PlanKind.income;
          final cannotCover =
              isOutflow && (runningMainBalance < plan.amountMinor);

          due.add(PlanOccurrence(
            plan: plan,
            dueDate: dueDate,
            idempotentKey: key,
            amountMinor: plan.amountMinor,
            needsFunds: cannotCover,
          ));

          if (!cannotCover && isOutflow) {
            runningMainBalance -= plan.amountMinor;
          }
        }
      }

      // Move to next month
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return due;
  }

  /// Returns the next occurrence of a plan strictly after [fromTime].
  static DateTime nextOccurrenceDate(CorePlan plan, {DateTime? fromTime}) {
    final start = fromTime ?? DateTime.now();
    var year = start.year;
    var month = start.month;

    var candidate = resolveOccurrenceDate(year, month, plan.dayOfMonth);
    if (!candidate.isAfter(start)) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
      candidate = resolveOccurrenceDate(year, month, plan.dayOfMonth);
    }

    return candidate;
  }
}
