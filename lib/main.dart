import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/models/speech_model.dart';
import 'package:habit_tracker/data/services/task_reset_service.dart';
// import 'package:habit_tracker/data/services/sip_service.dart';
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
import 'package:habit_tracker/features/wearables/data/wearable_cleanup_service.dart';
import 'package:habit_tracker/features/finance/engine/recurring_runner.dart';
import 'package:pdfrx/pdfrx.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize pdfrx engine & cache directory for PDF reading
  try {
    await pdfrxFlutterInitialize();
  } catch (e) {
    debugPrint('pdfrxFlutterInitialize warning: $e');
  }

  // Custom ErrorWidget so release builds never render raw stack traces
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint(
        'Global Flutter Error: ${details.exceptionAsString()}\n${details.stack}');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please restart the app or try again.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        details.exceptionAsString(),
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    // Initialize Hive for Flutter
    await Hive.initFlutter();

    // Register Type Adapters for Goal models
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(GoalTypeAdapter());
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(GoalCategoryAdapter());
    if (!Hive.isAdapterRegistered(3))
      Hive.registerAdapter(SpeechModelAdapter());

    // Register Diet Type Adapters
    if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(MealTypeAdapter());
    if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(FoodEntryAdapter());
    if (!Hive.isAdapterRegistered(22))
      Hive.registerAdapter(CalorieBurnEntryAdapter());
    if (!Hive.isAdapterRegistered(23))
      Hive.registerAdapter(DietDayLogAdapter());

    // Register Health Type Adapters (typeIds 30+)
    if (!Hive.isAdapterRegistered(30)) Hive.registerAdapter(MedicineAdapter());
    if (!Hive.isAdapterRegistered(31))
      Hive.registerAdapter(MedicineLogAdapter());
    if (!Hive.isAdapterRegistered(32))
      Hive.registerAdapter(WeightEntryAdapter());

    // Register Productivity Type Adapters (typeIds 33+)
    if (!Hive.isAdapterRegistered(33))
      Hive.registerAdapter(JournalEntryAdapter());
    if (!Hive.isAdapterRegistered(34)) Hive.registerAdapter(IdeaAdapter());
    if (!Hive.isAdapterRegistered(35))
      Hive.registerAdapter(BookProgressAdapter());

    // Register Finance Type Adapters (10, 11, 40-50)
    FinanceStorage.registerAdapters();

    // Register Wearable, Task, and Ledger Adapters (typeIds 60-68)
    WearableRepository.registerAdapters();
    TaskDayLogRepository.registerAdapter();
    WakeLogRepository.registerAdapter();
    XpLedger.registerAdapter();

    // Open essential root boxes
    await Hive.openBox('settings');
    await Hive.openBox<Goal>('mission_box_v4');
    await Hive.openBox<SpeechModel>('speech_vault');
    await Hive.openBox('xp_history');

    // Register default home cards
    HomeCardRegistry.registerDefaults();

    // Open Finance boxes and run migration before anything posts money
    try {
      await FinanceStorage().init();
      await FinanceMigrator().migrateIfNeeded();
    } catch (e) {
      debugPrint('FinanceStorage init / migration warning: $e');
    }

    // Open Diet boxes
    try {
      await Hive.openBox<DietDayLog>('diet_logs');
    } catch (e) {
      debugPrint('diet_logs box warning: $e');
    }

    // Open Health boxes
    try {
      await Hive.openBox<Medicine>('medicines');
      await Hive.openBox<MedicineLog>('medicine_logs');
      await Hive.openBox<WeightEntry>('weight_entries');
    } catch (e) {
      debugPrint('Health boxes warning: $e');
    }

    // Open Productivity & Reader boxes
    try {
      await Hive.openBox<Idea>('ideas');
      await Hive.openBox<BookProgress>('reader_progress');
    } catch (e) {
      debugPrint('Productivity boxes warning: $e');
    }

    // Open Wearables, TaskDayLogs, WakeLogs, and XpLedger
    try {
      await WearableRepository.openBoxes();
      await TaskDayLogRepository.openBox();
      await WakeLogRepository.openBox();
      await XpLedger.openBox();
    } catch (e) {
      debugPrint('Wearable boxes warning: $e');
    }
  } catch (e, st) {
    debugPrint('Fatal initialization error in main(): $e\n$st');
  }

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('NotificationService warning: $e');
    }
    try {
      TaskResetService.checkAndResetTasks();
    } catch (e) {
      debugPrint('TaskResetService warning: $e');
    }
    try {
      await WakeService.instance.rolloverMissedDays(DateTime.now());
    } catch (e) {
      debugPrint('WakeService warning: $e');
    }
    try {
      await RecurringRunner.run();
    } catch (e) {
      debugPrint('RecurringRunner warning: $e');
    }
    try {
      await MedicineService.rescheduleAll();
    } catch (e) {
      debugPrint('MedicineService warning: $e');
    }
    try {
      await JournalService.instance.openEncryptedBox();
    } catch (e) {
      debugPrint('JournalService warning: $e');
    }
    try {
      if (WearableCleanupService.shouldRunPurge()) {
        await WearableCleanupService.runPurge();
      }
    } catch (e) {
      debugPrint('WearableCleanupService purge warning: $e');
    }
  });

  // runApp MUST ALWAYS execute after initializations
  runApp(const HabitTrackerApp());
}
