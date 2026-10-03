import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/models/speech_model.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/data/services/task_reset_service.dart';
import 'package:habit_tracker/data/services/sip_service.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/launcher_icon',
  );

  // Initialize Hive for Flutter
  await Hive.initFlutter();

  // Register Type Adapters for Goal models
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GoalTypeAdapter());
  Hive.registerAdapter(GoalCategoryAdapter());
  Hive.registerAdapter(SpeechModelAdapter());

  // Register Finance Type Adapters
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(AssetVaultAdapter());

  // Register Diet Type Adapters
  Hive.registerAdapter(MealTypeAdapter());
  Hive.registerAdapter(FoodEntryAdapter());
  Hive.registerAdapter(CalorieBurnEntryAdapter());
  Hive.registerAdapter(DietDayLogAdapter());

  // Open necessary boxes for data persistence
  await Hive.openBox<Goal>('mission_box_v4');
  await Hive.openBox('settings');
  await Hive.openBox<SpeechModel>('speech_vault');

  // Open Finance boxes
  await Hive.openBox<Transaction>('finance_transactions');
  await Hive.openBox<AssetVault>('finance_vaults');
  await Hive.openBox('finance_settings');

  // Open Diet boxes
  await Hive.openBox<DietDayLog>('diet_logs');

  // Open XP box
  await Hive.openBox('xp_history');

  // Check and reset tasks daily/weekly/monthly based on date
  TaskResetService.checkAndResetTasks();

  // Process due SIP debits
  await SipService.runDue();

  // Initialize notifications
  await NotificationService().init();

  // Register default home cards
  HomeCardRegistry.registerDefaults();

  // runApp MUST be the last call after all async initializations
  runApp(const HabitTrackerApp());
}
