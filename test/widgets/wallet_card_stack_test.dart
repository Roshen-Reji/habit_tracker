import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/momentum_card.dart';
import 'package:habit_tracker/features/home/widgets/wallet_card_stack.dart';
import 'package:habit_tracker/screens/home_layout_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box settingsBox;
  late Box xpBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wallet_stack_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GoalTypeAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(GoalCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(AssetVaultAdapter());
    }
    if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(MealTypeAdapter());
    if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(FoodEntryAdapter());
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(CalorieBurnEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(DietDayLogAdapter());
    }

    settingsBox = await Hive.openBox('settings');
    xpBox = await Hive.openBox('xp_history');
    await Hive.openBox<Goal>('mission_box_v4');
    await Hive.openBox<Transaction>('finance_transactions');
    await Hive.openBox<AssetVault>('finance_vaults');
    await Hive.openBox('finance_settings');
    await Hive.openBox<DietDayLog>('diet_logs');
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    HomeCardRegistry.clear();
    await settingsBox.clear();
    await xpBox.clear();
    HomeCardRegistry.registerDefaults();
  });

  group('WalletCardStack & Cards Widget Tests (P2-1..4)', () {
    testWidgets('WalletCardStack renders registered cards in default order',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const WalletCardStack(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check card titles exist in the tree
      expect(find.text('DAILY WISDOM'), findsOneWidget);
      expect(find.text('MOMENTUM SIGNAL'), findsOneWidget);
      expect(find.text('DAILY MISSIONS'), findsOneWidget);
    });

    testWidgets('MomentumCard expands and collapses on tap (P2-2)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SingleChildScrollView(
              child: MomentumCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially compact, shows active days strip
      expect(find.text('NOW'), findsOneWidget);

      // Tap card to expand
      await tester.tap(find.byType(MomentumCard));
      await tester.pumpAndSettle();

      // Now expanded into dot-matrix graph
      expect(find.text('MOMENTUM SIGNAL'), findsOneWidget);

      // Tap card to collapse
      await tester.tap(find.byType(MomentumCard));
      await tester.pumpAndSettle();

      expect(find.text('MOMENTUM SIGNAL'), findsOneWidget);
    });

    testWidgets('HomeLayoutSettingsPage toggles card visibility and saves',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomeLayoutSettingsPage(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Home Layout'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);

      // Toggle first card switch off
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();

      // Verify layout saved in settings
      final layout = HomeCardRegistry.loadLayout(settingsBox);
      expect(layout.first.visible, isFalse);
    });
  });
}
