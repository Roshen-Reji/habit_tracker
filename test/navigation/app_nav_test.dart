import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/screens/home_page.dart';
import 'package:habit_tracker/features/finance/finance_page.dart';

import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/services/music_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('app_nav_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GoalTypeAdapter());
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(GoalCategoryAdapter());
    if (!Hive.isAdapterRegistered(10))
      Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(11))
      Hive.registerAdapter(AssetVaultAdapter());
    if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(MealTypeAdapter());
    if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(FoodEntryAdapter());
    if (!Hive.isAdapterRegistered(22))
      Hive.registerAdapter(CalorieBurnEntryAdapter());
    if (!Hive.isAdapterRegistered(23))
      Hive.registerAdapter(DietDayLogAdapter());

    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('username', 'COMMANDER');
    await Hive.openBox<Goal>('mission_box_v4');
    await Hive.openBox<Transaction>('finance_transactions');
    await Hive.openBox<AssetVault>('finance_vaults');
    await Hive.openBox('finance_settings');
    await Hive.openBox<DietDayLog>('diet_logs');
    await Hive.openBox('xp_history');
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() {
    AppNav.goTo(AppTab.home, sub: TasksSubview.missions);
  });

  group('AppNav Unit Tests (P1-2)', () {
    test('AppNav state updates properly with goTo enum and string', () {
      expect(AppNav.instance.currentTab, 0);
      expect(AppNav.instance.tasksSubview, 'missions');

      AppNav.goTo(AppTab.tasks, sub: TasksSubview.finance);
      expect(AppNav.instance.currentTab, 1);
      expect(AppNav.instance.tasksSubview, 'finance');

      AppNav.goTo(AppTab.diet);
      expect(AppNav.instance.currentTab, 2);
      expect(AppNav.instance.tasksSubview, 'finance'); // unchanged subview

      AppNav.goTo('tasks', sub: 'vault');
      expect(AppNav.instance.currentTab, 1);
      expect(AppNav.instance.tasksSubview, 'vault');

      AppNav.goTo(0);
      expect(AppNav.instance.currentTab, 0);
    });

    testWidgets(
        'Calling goTo(tasks, sub: finance) from dashboard ends on finance sub-view',
        (WidgetTester tester) async {
      // Set initial state to home dashboard
      AppNav.goTo(AppTab.home, sub: TasksSubview.missions);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Initially on Dashboard
      expect(find.byType(FinanceDashboard), findsNothing);

      // Programmatically navigate to tasks with finance subview
      AppNav.goTo(AppTab.tasks, sub: TasksSubview.finance);
      await tester.pump(const Duration(milliseconds: 600));

      // Verify FinanceDashboard is present on screen
      expect(find.byType(FinanceDashboard), findsOneWidget);

      // Unmount to dispose active tickers
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
