import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:habit_tracker/screens/home_page.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/services/music_manager.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class CommanderApp extends StatelessWidget {
  const CommanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['theme_mode']),
      builder: (context, box, child) {
        return StreamBuilder(
          stream: MusicManager().audioPlayer.sequenceStateStream,
          builder: (context, snapshot) {
            return MaterialApp(
              navigatorKey: globalNavigatorKey,
              title: 'Commander Habit Tracker',
              themeMode: NeuTheme.currentMode,
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
