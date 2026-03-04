import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/goals.dart';
import 'package:habit_tracker/screens/home_page.dart';
import 'package:habit_tracker/models/speech_model.dart';
// ADDED: Import the finance models so main.dart knows what they are
import 'package:habit_tracker/models/finance_model.dart'; 

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  // Open necessary boxes for data persistence
  await Hive.openBox<Goal>('mission_box_v3');
  await Hive.openBox('settings');
  await Hive.openBox<SpeechModel>('speech_vault'); 
  
  // Open Finance boxes
  await Hive.openBox<Transaction>('finance_transactions');
  await Hive.openBox<AssetVault>('finance_vaults');
  await Hive.openBox('finance_settings');

  // runApp MUST be the last call after all async initializations
  runApp(const CommanderApp());
}

class CommanderApp extends StatelessWidget {
  const CommanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Commander Habit Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.tealAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}