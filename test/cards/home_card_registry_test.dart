import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('home_card_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings_card_test');
  });

  tearDownAll(() async {
    await settingsBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    HomeCardRegistry.clear();
    await settingsBox.clear();
  });

  group('HomeCardRegistry Layout Merge Tests (P1-3)', () {
    test('Fresh install: returns all registered cards in default order', () {
      HomeCardRegistry.register(HomeCardSpec(
        id: 'finance',
        title: 'Finance',
        icon: Icons.wallet,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 2,
      ));
      HomeCardRegistry.register(HomeCardSpec(
        id: 'momentum',
        title: 'Momentum',
        icon: Icons.show_chart,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 1,
      ));
      HomeCardRegistry.register(HomeCardSpec(
        id: 'calories',
        title: 'Calories',
        icon: Icons.restaurant,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 3,
        defaultVisible: false,
      ));

      final layout = HomeCardRegistry.loadLayout(settingsBox);

      expect(layout.length, 3);
      expect(layout[0].id, 'momentum');
      expect(layout[0].visible, isTrue);

      expect(layout[1].id, 'finance');
      expect(layout[1].visible, isTrue);

      expect(layout[2].id, 'calories');
      expect(layout[2].visible, isFalse);
    });

    test(
        'New card added: appends new cards at end while preserving existing order',
        () async {
      HomeCardRegistry.register(HomeCardSpec(
        id: 'card_a',
        title: 'Card A',
        icon: Icons.abc,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 1,
      ));
      HomeCardRegistry.register(HomeCardSpec(
        id: 'card_b',
        title: 'Card B',
        icon: Icons.bolt,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 2,
      ));

      // User saved custom order: card_b first (hidden), card_a second
      await settingsBox.put('home_layout', [
        {'id': 'card_b', 'visible': false},
        {'id': 'card_a', 'visible': true},
      ]);

      // Now developer registers a new card_c in an update
      HomeCardRegistry.register(HomeCardSpec(
        id: 'card_c',
        title: 'Card C',
        icon: Icons.cabin,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 3,
        defaultVisible: true,
      ));

      final layout = HomeCardRegistry.loadLayout(settingsBox);

      expect(layout.length, 3);
      // Existing custom order preserved
      expect(layout[0].id, 'card_b');
      expect(layout[0].visible, isFalse);
      expect(layout[1].id, 'card_a');
      expect(layout[1].visible, isTrue);
      // New card appended at the end
      expect(layout[2].id, 'card_c');
      expect(layout[2].visible, isTrue);
    });

    test('Card removed: drops unknown ids no longer in registry', () async {
      HomeCardRegistry.register(HomeCardSpec(
        id: 'card_active',
        title: 'Active Card',
        icon: Icons.check,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 1,
      ));

      // User stored layout has an old deprecated card 'card_deprecated'
      await settingsBox.put('home_layout', [
        {'id': 'card_deprecated', 'visible': true},
        {'id': 'card_active', 'visible': true},
      ]);

      final layout = HomeCardRegistry.loadLayout(settingsBox);

      expect(layout.length, 1);
      expect(layout[0].id, 'card_active');
    });

    test('Save and reset layout works as expected', () async {
      HomeCardRegistry.register(HomeCardSpec(
        id: 'card_1',
        title: 'Card 1',
        icon: Icons.looks_one,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 1,
      ));
      HomeCardRegistry.register(HomeCardSpec(
        id: 'card_2',
        title: 'Card 2',
        icon: Icons.looks_two,
        compactBuilder: (context) => const SizedBox(),
        defaultOrder: 2,
      ));

      // Save custom
      await HomeCardRegistry.saveLayout(settingsBox, [
        HomeCardLayoutItem(id: 'card_2', visible: false),
        HomeCardLayoutItem(id: 'card_1', visible: true),
      ]);

      var layout = HomeCardRegistry.loadLayout(settingsBox);
      expect(layout[0].id, 'card_2');
      expect(layout[0].visible, isFalse);

      // Reset
      await HomeCardRegistry.resetLayout(settingsBox);
      layout = HomeCardRegistry.loadLayout(settingsBox);
      expect(layout[0].id, 'card_1');
      expect(layout[0].visible, isTrue);
      expect(layout[1].id, 'card_2');
      expect(layout[1].visible, isTrue);
    });
  });
}
