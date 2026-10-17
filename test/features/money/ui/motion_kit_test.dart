import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/money/ui/motion/motion_tokens.dart';
import 'package:habit_tracker/features/money/ui/motion/motion_scope.dart';
import 'package:habit_tracker/features/money/ui/motion/press_scale.dart';
import 'package:habit_tracker/features/money/ui/motion/animated_money_text.dart';
import 'package:habit_tracker/features/money/ui/widgets/money_progress_bar.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/money/ui/today/today_tab.dart';
import 'package:habit_tracker/features/money/ui/activity/activity_tab.dart';
import 'package:habit_tracker/features/money/ui/plans/plans_tab.dart';
import 'package:habit_tracker/features/money/ui/accounts/accounts_tab.dart';
import 'package:habit_tracker/features/money/ui/shell/money_shell.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('money_m4_test_');
    Hive.init(tempDir.path);
    FinanceStorage.registerAdapters();
    await Hive.openBox('settings');
    final storage = FinanceStorage();
    await storage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone M4: Motion Kit & UI Foundation', () {
    testWidgets('MotionScope adapts durations when animations are disabled',
        (tester) async {
      late Duration normalDuration;
      late Duration disabledDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              normalDuration =
                  MotionScope.duration(context, MoneyMotionTokens.standard);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(normalDuration, equals(MoneyMotionTokens.standard));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                disabledDuration =
                    MotionScope.duration(context, MoneyMotionTokens.standard);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(disabledDuration, equals(MoneyMotionTokens.instant));
    });

    testWidgets(
        'AnimatedMoneyText counts smoothly and displays tabular figures',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedMoneyText(
              amountMinor: 100000, // ₹1,000.00
              decimals: 0,
            ),
          ),
        ),
      );

      // First frame
      expect(find.text('₹1,000'), findsOneWidget);

      // Verify tabular figures font feature is present on Text widget
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.style?.fontFeatures, isNotNull);
      expect(
        textWidget.style!.fontFeatures!.any((f) => f.feature == 'tnum'),
        isTrue,
      );

      // Pump update to ₹2,500.00
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedMoneyText(
              amountMinor: 250000,
              decimals: 0,
            ),
          ),
        ),
      );

      // Midway through animation (~225ms)
      await tester.pump(const Duration(milliseconds: 225));
      // Should not be old value or final value yet
      expect(find.text('₹1,000'), findsNothing);

      // Complete animation (450ms)
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('₹2,500'), findsOneWidget);
    });

    testWidgets('PressScale micro-interaction executes tap and callback',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                onTap: () => tapped = true,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('MoneyProgressBar animates progress changes cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoneyProgressBar(
              progress: 0.5,
              height: 8.0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MoneyProgressBar), findsOneWidget);

      // Change progress
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoneyProgressBar(
              progress: 0.8,
              height: 8.0,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byType(MoneyProgressBar), findsOneWidget);
    });

    testWidgets('MoneyShell switches tabs lazily and preserves PageStorage',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShell(initialTab: 0),
        ),
      );

      await tester.pumpAndSettle();

      // Starts at Today Tab
      expect(find.byType(TodayTab), findsOneWidget);
      expect(find.byType(ActivityTab), findsNothing);

      // Tap Activity tab
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.byType(ActivityTab), findsOneWidget);

      // Tap Plans tab
      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      expect(find.byType(PlansTab), findsOneWidget);

      // Tap Accounts tab
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountsTab), findsOneWidget);
    });

    testWidgets('MoneyShell deep-linking opens requested tab on start',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MoneyShell(deepLink: 'plans'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PlansTab), findsOneWidget);
    });
  });
}
