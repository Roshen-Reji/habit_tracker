import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:habit_tracker/screens/home_page.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/services/music_manager.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final modeStr = settings.get('theme_mode', defaultValue: 'dark');
        final mode = modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
        
        return ValueListenableBuilder<Color?>(
          valueListenable: MusicManager().currentDominantColor,
          builder: (context, color, snapshot) {
            return MaterialApp(
              navigatorKey: globalNavigatorKey,
              title: 'Habit Tracker',
              themeMode: mode,
              scrollBehavior: const MaterialScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              ),
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: NeuTheme.background,
                fontFamily: 'Roboto',
                colorScheme: ColorScheme.light(
                  primary: NeuTheme.accent,
                  surface: NeuTheme.background,
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: NeuTheme.background,
                fontFamily: 'Roboto',
                colorScheme: ColorScheme.dark(
                  primary: NeuTheme.accent,
                  surface: NeuTheme.background,
                ),
              ),
              home: const HomePage(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
