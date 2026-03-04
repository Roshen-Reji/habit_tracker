import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/goals.dart';
import 'package:habit_tracker/screens/home_page.dart';
import 'package:habit_tracker/models/speech_model.dart';

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

  // Open necessary boxes for data persistence
  await Hive.openBox<Goal>('mission_box_v3');
  await Hive.openBox('settings');
  await Hive.openBox<SpeechModel>('speech_vault'); // Box used for global username and preferences

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