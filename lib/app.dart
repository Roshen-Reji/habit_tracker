import 'dart:async';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/screens/home_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/services/task_reset_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
// import 'package:habit_tracker/data/services/sip_service.dart';
import 'package:habit_tracker/features/wearables/data/sync_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/wearables/data/wake_service.dart';
import 'package:habit_tracker/features/finance/engine/recurring_runner.dart';
import 'package:habit_tracker/data/services/reminder_scheduler.dart';

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
      WakeService.instance.rolloverMissedDays(DateTime.now());
      unawaited(RecurringRunner.run().catchError((e) {
        debugPrint('RecurringRunner error on resume: $e');
      }));
      unawaited(ReminderScheduler.syncIfThrottleElapsed().catchError((e) {
        debugPrint('ReminderScheduler error on resume: $e');
      }));
      if (WearableSettings.isEnabled && WearableSettings.autoSyncOnResume) {
        SyncService.instance.sync(days: 7);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      JournalService.instance.onAppLifecycleChanged(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('settings')) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['theme_mode']),
      builder: (context, Box settings, _) {
        final modeStr = settings.get('theme_mode', defaultValue: 'dark');
        final mode = modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

        return MaterialApp(
          navigatorKey: globalNavigatorKey,
          title: 'Habitify',
          themeMode: mode,
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
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
  }
}
