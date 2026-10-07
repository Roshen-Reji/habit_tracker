import 'package:flutter/foundation.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import '../core/minor.dart';
import '../core/plan_engine.dart';
import '../state/money_state.dart';
import 'money_service.dart';

/// Runner responsible for evaluating and executing scheduled plans automatically (Law L6).
///
/// Runs:
/// 1. After the first frame of app launch.
/// 2. When the app resumes from the background.
/// 3. Immediately after a plan is added or updated.
class PlanRunner {
  static final PlanRunner _instance = PlanRunner._internal();
  factory PlanRunner({MoneyService? service, MoneyState? state}) {
    if (service != null) _instance._service = service;
    if (state != null) _instance._state = state;
    return _instance;
  }

  PlanRunner._internal()
      : _service = MoneyService(),
        _state = MoneyState();

  MoneyService _service;
  MoneyState _state;
  bool _isRunning = false;

  /// Runs all due automatic plans up to [clock].
  Future<void> runDuePlans({DateTime? clock}) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final now = clock ?? DateTime.now();
      final mainId = _state.mainAccountId;
      final plans =
          _state.plans.where((p) => p.autoPost && !p.isPaused).toList();

      final existingKeys = <String>{};
      for (final e in _state.entries) {
        if (e.sourceRef != null && e.sourceRef!.startsWith('plan:')) {
          existingKeys.add(e.sourceRef!);
        }
      }

      int postedCount = 0;
      final needsFundsPlans = <PlanOccurrence>[];

      for (final plan in plans) {
        try {
          // Default: starts from today/current month to avoid silent back-charges
          final currentMonthStart = DateTime(now.year, now.month, 1);
          final effectiveStart = plan.startDate.isBefore(currentMonthStart)
              ? currentMonthStart
              : plan.startDate;

          final dueList = PlanEngine.evaluateDue(
            plan: plan,
            effectiveStartDate: effectiveStart,
            clock: now,
            existingKeys: existingKeys,
            mainBalanceMinor: _state.value.mainBalanceMinor,
          );

          for (final occ in dueList) {
            if (occ.needsFunds) {
              needsFundsPlans.add(occ);
              continue; // Do not post if Main cannot cover
            }

            // Post occurrence via MoneyService
            switch (plan.kind) {
              case PlanKind.sip:
                if (plan.toAccountId != null) {
                  await _service.move(
                    amountMinor: occ.amountMinor,
                    fromAccountId: plan.fromAccountId ?? mainId,
                    toAccountId: plan.toAccountId!,
                    title: plan.title,
                    category: 'Investment',
                    date: occ.dueDate,
                    sourceRef: occ.idempotentKey,
                  );
                  existingKeys.add(occ.idempotentKey);
                  postedCount++;
                }
                break;
              case PlanKind.emi:
                if (plan.toAccountId != null) {
                  await _service.move(
                    amountMinor: occ.amountMinor,
                    fromAccountId: plan.fromAccountId ?? mainId,
                    toAccountId: plan.toAccountId!,
                    title: plan.title,
                    category: 'Debt',
                    date: occ.dueDate,
                    sourceRef: occ.idempotentKey,
                  );
                  existingKeys.add(occ.idempotentKey);
                  postedCount++;
                }
                break;
              case PlanKind.bill:
                await _service.spend(
                  amountMinor: occ.amountMinor,
                  accountId: plan.fromAccountId ?? mainId,
                  title: plan.title,
                  category: plan.category ?? 'Bills',
                  categoryId: plan.categoryId,
                  date: occ.dueDate,
                  sourceRef: occ.idempotentKey,
                );
                existingKeys.add(occ.idempotentKey);
                postedCount++;
                break;
              case PlanKind.income:
                await _service.receive(
                  amountMinor: occ.amountMinor,
                  accountId: plan.toAccountId ?? mainId,
                  title: plan.title,
                  category: plan.category ?? 'Income',
                  categoryId: plan.categoryId,
                  date: occ.dueDate,
                  sourceRef: occ.idempotentKey,
                );
                existingKeys.add(occ.idempotentKey);
                postedCount++;
                break;
            }
          }
        } catch (e) {
          debugPrint('PlanRunner: Error processing plan ${plan.id}: $e');
        }
      }

      // One summary notification per run (Law L6)
      if (postedCount > 0 || needsFundsPlans.isNotEmpty) {
        final messages = <String>[];
        if (postedCount > 0) {
          messages.add('Processed $postedCount scheduled payments.');
        }
        if (needsFundsPlans.isNotEmpty) {
          final totalNeeded = needsFundsPlans.fold<int>(
            0,
            (sum, p) => sum + p.amountMinor,
          );
          messages.add(
            '${needsFundsPlans.length} plans need funds (${Minor.format(totalNeeded)}).',
          );
        }

        try {
          await NotificationService().showInstantNotification(
            id: 889901,
            title: 'Money Automation',
            body: messages.join(' '),
          );
        } catch (notifErr) {
          debugPrint('PlanRunner notification error: $notifErr');
        }
      }

      _state.recomputeSnapshot(clock: now);
    } finally {
      _isRunning = false;
    }
  }
}
