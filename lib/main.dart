import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/models/speech_model.dart';
import 'package:habit_tracker/data/services/task_reset_service.dart';
import 'package:habit_tracker/data/services/sip_service.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/data/migrations/finance_migrator.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/tasks/data/task_day_log_repository.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/data/services/xp_ledger.dart';
import 'package:habit_tracker/features/wearables/data/wake_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for Flutter
  await Hive.initFlutter();

  // Register Type Adapters for Goal models
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GoalTypeAdapter());
  Hive.registerAdapter(GoalCategoryAdapter());
  Hive.registerAdapter(SpeechModelAdapter());

  // Register Diet Type Adapters
  Hive.registerAdapter(MealTypeAdapter());
  Hive.registerAdapter(FoodEntryAdapter());
  Hive.registerAdapter(CalorieBurnEntryAdapter());
  Hive.registerAdapter(DietDayLogAdapter());

  // Register Health Type Adapters (typeIds 30+)
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(MedicineLogAdapter());
  Hive.registerAdapter(WeightEntryAdapter());

  // Register Productivity Type Adapters (typeIds 33+)
  Hive.registerAdapter(JournalEntryAdapter());
  Hive.registerAdapter(IdeaAdapter());
  Hive.registerAdapter(BookProgressAdapter());

  // Open necessary boxes for data persistence
  await Hive.openBox<Goal>('mission_box_v4');
  await Hive.openBox('settings');
  await Hive.openBox<SpeechModel>('speech_vault');

  // Register Finance Type Adapters and open boxes via FinanceStorage
  FinanceStorage.registerAdapters();
  await FinanceStorage().init();
  await FinanceMigrator().migrateIfNeeded();

  // Open Diet boxes
  await Hive.openBox<DietDayLog>('diet_logs');

  // Open Health boxes
  await Hive.openBox<Medicine>('medicines');
  await Hive.openBox<MedicineLog>('medicine_logs');
  await Hive.openBox<WeightEntry>('weight_entries');

  // Open Productivity & Reader boxes
  await Hive.openBox<Idea>('ideas');
  await Hive.openBox<BookProgress>('reader_progress');
  try {
    await JournalService.instance.openEncryptedBox();
  } catch (_) {
    // Graceful fallback if secure storage is unavailable at boot
  }

  // Open XP box
  await Hive.openBox('xp_history');

  // Open Wearables, TaskDayLogs, WakeLogs, and XpLedger
  await WearableRepository.openBoxes();
  await TaskDayLogRepository.openBox();
  await WakeLogRepository.openBox();
  await XpLedger.openBox();

  // Check and reset tasks daily/weekly/monthly based on date
  TaskResetService.checkAndResetTasks();
  await WakeService.instance.rolloverMissedDays(DateTime.now());

  // Process due SIP debits
  await SipService.runDue();

  // Initialize notifications
  await NotificationService().init();

  // Reschedule medicine reminders
  await MedicineService.rescheduleAll();

  // Register default home cards
  HomeCardRegistry.registerDefaults();

  // runApp MUST be the last call after all async initializations
  runApp(const HabitTrackerApp());
}
