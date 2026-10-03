import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/screens/home_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:habit_tracker/data/services/task_reset_service.dart';
import 'package:habit_tracker/data/services/sip_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

class HabitTrackerApp extends StatefulWidget {
  const HabitTrackerApp({super.key});

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TaskResetService.checkAndResetTasks();
      SipService.runDue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final modeStr = settings.get('theme_mode', defaultValue: 'dark');
        final mode = modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

        return ValueListenableBuilder<Color?>(
          valueListenable: NowPlayingService.instance.currentDominantColor,
          builder: (context, color, snapshot) {
            return MaterialApp(
              navigatorKey: globalNavigatorKey,
              title: 'Habit Tracker',
              themeMode: mode,
              scrollBehavior: const MaterialScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
              ),
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: BentoTheme.background,
                fontFamily: 'Roboto',
                colorScheme: ColorScheme.light(
                  primary: BentoTheme.accent,
                  surface: BentoTheme.background,
                ),
                cardTheme: const CardThemeData(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: ExpressiveTokens.borderL,
                  ),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: BentoTheme.background,
                fontFamily: 'Roboto',
                colorScheme: ColorScheme.dark(
                  primary: BentoTheme.accent,
                  surface: BentoTheme.background,
                ),
                cardTheme: const CardThemeData(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: ExpressiveTokens.borderL,
                  ),
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
