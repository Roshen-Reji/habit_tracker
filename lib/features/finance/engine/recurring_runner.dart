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
    
    if (!force && lastRun == todayKey) {
      return;
    }
    
    final repo = FinanceRepository(storage: storage);
    await repo.postRecurringDue(now: clock);
    
    await settingsBox.put('recurring_last_run', todayKey);
  }
}
