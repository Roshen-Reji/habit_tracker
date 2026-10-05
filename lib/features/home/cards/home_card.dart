import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/home/cards/calories_card.dart';
import 'package:habit_tracker/features/home/cards/finance_card.dart';
import 'package:habit_tracker/features/home/cards/missions_card.dart';
import 'package:habit_tracker/features/home/cards/momentum_card.dart';
import 'package:habit_tracker/features/home/cards/quote_card.dart';
import 'package:habit_tracker/features/home/cards/score_card.dart';
import 'package:habit_tracker/features/home/cards/score_delta_card.dart';
import 'package:habit_tracker/features/home/cards/medicine_card.dart';
import 'package:habit_tracker/features/home/cards/weight_card.dart';
import 'package:habit_tracker/features/home/cards/health_summary_card.dart';
import 'package:habit_tracker/features/home/cards/music_card.dart';
import 'package:habit_tracker/features/home/cards/journal_card.dart';
import 'package:habit_tracker/features/home/cards/brainstorm_card.dart';
import 'package:habit_tracker/features/home/cards/reader_card.dart';
import 'package:habit_tracker/features/home/cards/safe_to_spend_card.dart';
import 'package:habit_tracker/features/home/cards/net_worth_card.dart';
import 'package:habit_tracker/features/home/cards/upcoming_bills_card.dart';
import 'package:habit_tracker/features/home/cards/galaxy_watch_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Specification for a card in the wallet-stack home screen.
class HomeCardSpec {
  final String id;
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context) compactBuilder;
  final void Function(BuildContext context)? onTap;
  final int defaultOrder;
  final bool defaultVisible;

  const HomeCardSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.compactBuilder,
    this.onTap,
    required this.defaultOrder,
    this.defaultVisible = true,
  });
}

/// Represents the persisted order and visibility of a card in the home layout.
class HomeCardLayoutItem {
  final String id;
  bool visible;

  HomeCardLayoutItem({
    required this.id,
    this.visible = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'visible': visible,
      };

  factory HomeCardLayoutItem.fromMap(Map map) => HomeCardLayoutItem(
        id: map['id']?.toString() ?? '',
        visible: map['visible'] is bool ? map['visible'] as bool : true,
      );
}

/// Central registry managing home card specifications and layout merging.
class HomeCardRegistry {
  static final Map<String, HomeCardSpec> _specs = {};

  static void register(HomeCardSpec spec) {
    _specs[spec.id] = spec;
  }

  static void unregister(String id) {
    _specs.remove(id);
  }

  static void clear() {
    _specs.clear();
  }

  /// Registers default cards for the home screen if not already registered.
  static void registerDefaults() {
    register(HomeCardSpec(
      id: 'quote',
      title: 'Daily Wisdom',
      icon: LucideIcons.quote,
      compactBuilder: (context) => const QuoteCard(),
      defaultOrder: 0,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'momentum',
      title: 'Momentum Signal',
      icon: LucideIcons.activity,
      compactBuilder: (context) => const MomentumCard(),
      defaultOrder: 1,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'missions',
      title: 'Daily Missions',
      icon: LucideIcons.checkSquare,
      compactBuilder: (context) => const MissionsCard(),
      defaultOrder: 2,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'finance',
      title: 'Finance Summary',
      icon: LucideIcons.wallet,
      compactBuilder: (context) => const FinanceCard(),
      defaultOrder: 3,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'calories',
      title: 'Diet & Calories',
      icon: LucideIcons.utensils,
      compactBuilder: (context) => const CaloriesCard(),
      defaultOrder: 4,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'score',
      title: 'XP Totals',
      icon: LucideIcons.trophy,
      compactBuilder: (context) => const ScoreCard(),
      defaultOrder: 5,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'score_delta',
      title: 'XP Velocity',
      icon: LucideIcons.trendingUp,
      compactBuilder: (context) => const ScoreDeltaCard(),
      defaultOrder: 6,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'music',
      title: 'Music Controller',
      icon: LucideIcons.music,
      compactBuilder: (context) => const MusicCard(),
      defaultOrder: 7,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'medicine',
      title: 'Medicine Reminder',
      icon: LucideIcons.pill,
      compactBuilder: (context) => const MedicineCard(),
      defaultOrder: 8,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'weight',
      title: 'Weight Journey',
      icon: LucideIcons.scale,
      compactBuilder: (context) => const WeightCard(),
      defaultOrder: 9,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'health',
      title: 'Health Summary',
      icon: LucideIcons.heartPulse,
      compactBuilder: (context) => const HealthSummaryCard(),
      defaultOrder: 10,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'journal',
      title: 'Private Journal',
      icon: LucideIcons.bookLock,
      compactBuilder: (context) => const JournalCard(),
      defaultOrder: 11,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'brainstorm',
      title: 'Brainstorm',
      icon: LucideIcons.lightbulb,
      compactBuilder: (context) => const BrainstormCard(),
      defaultOrder: 12,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'reader',
      title: 'Document Reader',
      icon: LucideIcons.bookOpen,
      compactBuilder: (context) => const ReaderCard(),
      defaultOrder: 13,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'safe_to_spend',
      title: 'Safe to Spend',
      icon: LucideIcons.shieldCheck,
      compactBuilder: (context) => const SafeToSpendCard(),
      defaultOrder: 14,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'net_worth',
      title: 'Net Worth',
      icon: LucideIcons.lineChart,
      compactBuilder: (context) => const NetWorthHomeCard(),
      defaultOrder: 15,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'upcoming_bills',
      title: 'Upcoming Bills',
      icon: LucideIcons.calendarClock,
      compactBuilder: (context) => const UpcomingBillsCard(),
      defaultOrder: 16,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'galaxy_watch',
      title: 'Galaxy Watch 7',
      icon: LucideIcons.watch,
      compactBuilder: (context) => const GalaxyWatchCard(),
      defaultOrder: 17,
      defaultVisible: true,
    ));
  }

  static HomeCardSpec? get(String id) => _specs[id];

  static bool contains(String id) => _specs.containsKey(id);

  static List<HomeCardSpec> get allSpecs {
    final list = _specs.values.toList();
    list.sort((a, b) => a.defaultOrder.compareTo(b.defaultOrder));
    return list;
  }

  /// Merges stored layout with current registry:
  /// - Stored order and visibility preserved for known ids.
  /// - Unknown ids in stored layout are dropped.
  /// - Newly registered cards missing from stored layout are appended at the end.
  /// - Fresh install returns all registered cards in default order.
  static List<HomeCardLayoutItem> loadLayout(Box settingsBox) {
    final rawList = settingsBox.get('home_layout');
    final allRegistered = allSpecs;

    if (rawList == null || rawList is! List || rawList.isEmpty) {
      return allRegistered
          .map((spec) => HomeCardLayoutItem(
                id: spec.id,
                visible: spec.defaultVisible,
              ))
          .toList();
    }

    final result = <HomeCardLayoutItem>[];
    final seenIds = <String>{};

    for (final item in rawList) {
      if (item is Map) {
        final id = item['id']?.toString() ?? '';
        if (_specs.containsKey(id) && !seenIds.contains(id)) {
          seenIds.add(id);
          final visible =
              item['visible'] is bool ? item['visible'] as bool : true;
          result.add(HomeCardLayoutItem(id: id, visible: visible));
        }
      }
    }

    // Append newly registered cards not present in stored layout
    for (final spec in allRegistered) {
      if (!seenIds.contains(spec.id)) {
        result.add(HomeCardLayoutItem(
          id: spec.id,
          visible: spec.defaultVisible,
        ));
      }
    }

    return result;
  }

  /// Persists layout order and visibility to settings box.
  static Future<void> saveLayout(
      Box settingsBox, List<HomeCardLayoutItem> layout) async {
    final list = layout.map((item) => item.toMap()).toList();
    await settingsBox.put('home_layout', list);
  }

  /// Resets home layout back to default registered order and visibility.
  static Future<void> resetLayout(Box settingsBox) async {
    final defaultLayout = allSpecs
        .map((spec) => HomeCardLayoutItem(
              id: spec.id,
              visible: spec.defaultVisible,
            ))
        .toList();
    await saveLayout(settingsBox, defaultLayout);
  }
}
