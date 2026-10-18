import 'dart:async';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
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
import 'package:habit_tracker/features/money/data/plan_runner.dart';

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
      unawaited(PlanRunner().runDuePlans().catchError((e) {
        debugPrint('PlanRunner error on resume: $e');
        return 0;
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
          backgroundColor: Color(0xFF000000),
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box('settings')
          .listenable(keys: ['theme_mode', 'color_scheme_preset']),
      builder: (context, Box settings, _) {
        final modeStr = settings.get('theme_mode', defaultValue: 'dark');
        final ThemeMode mode;
        if (modeStr == 'light') {
          mode = ThemeMode.light;
        } else if (modeStr == 'system') {
          mode = ThemeMode.system;
        } else {
          mode = ThemeMode.dark;
        }
        final presetStr =
            settings.get('color_scheme_preset', defaultValue: 'monochrome');
        final preset =
            AppColorSchemePreset.fromString(presetStr?.toString());

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
          theme: AppTheme.buildLightTheme(preset),
          darkTheme: AppTheme.buildDarkTheme(preset),
          home: const HomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
