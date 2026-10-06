import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:intl/intl.dart';

class RecurringRunner {
  static Future<void> run({DateTime? now, bool force = false}) async {
    final clock = now ?? DateTime.now();
    final storage = FinanceStorage();
    final settingsBox = storage.settingsBox;

    final lastRun = settingsBox.get('recurring_last_run');
    final todayKey = DateFormat('yyyy-MM-dd').format(clock);
    final lastResult = settingsBox.get('recurring_last_result');
    final hadFailures =
        lastResult is Map && ((lastResult['failed'] as int?) ?? 0) > 0;

    if (!force && lastRun == todayKey && !hadFailures) {
      return;
    }

    final repo = FinanceRepository(storage: storage);
    try {
      await repo.postRecurringDue(now: clock);
      // P2-4: Write recurring_last_run only after a full pass
      await settingsBox.put('recurring_last_run', todayKey);
    } catch (_) {
      // Re-throw so callers can log or handle, but do not record today as finished
      rethrow;
    }
  }
}
