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

/// Card sizes for wallet stack cards in MVP 5.
enum HomeCardSize {
  compact,
  large,
  hero,
}

/// Specification for a card in the wallet-stack home screen.
class HomeCardSpec {
  final String id;
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context) compactBuilder;
  final Widget Function(BuildContext context)? largeBuilder;
  final Widget Function(BuildContext context)? heroBuilder;
  final HomeCardSize defaultSize;
  final void Function(BuildContext context)? onTap;
  final int defaultOrder;
  final bool defaultVisible;

  const HomeCardSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.compactBuilder,
    this.largeBuilder,
    this.heroBuilder,
    this.defaultSize = HomeCardSize.compact,
    this.onTap,
    required this.defaultOrder,
    this.defaultVisible = true,
  });

  Widget buildWidget(BuildContext context, HomeCardSize size) {
    if (size == HomeCardSize.hero && heroBuilder != null) {
      return heroBuilder!(context);
    }
    if ((size == HomeCardSize.large || size == HomeCardSize.hero) &&
        largeBuilder != null) {
      return largeBuilder!(context);
    }
    return compactBuilder(context);
  }

  bool supportsSize(HomeCardSize size) {
    switch (size) {
      case HomeCardSize.compact:
        return true;
      case HomeCardSize.large:
        return largeBuilder != null;
      case HomeCardSize.hero:
        return heroBuilder != null;
    }
  }

  List<HomeCardSize> get supportedSizes {
    final list = [HomeCardSize.compact];
    if (largeBuilder != null) list.add(HomeCardSize.large);
    if (heroBuilder != null) list.add(HomeCardSize.hero);
    return list;
  }
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
      compactBuilder: (context) => const QuoteCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const QuoteCard(size: HomeCardSize.large),
      defaultOrder: 0,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'momentum',
      title: 'Momentum Signal',
      icon: LucideIcons.activity,
      compactBuilder: (context) =>
          const MomentumCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const MomentumCard(size: HomeCardSize.large),
      defaultOrder: 1,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'missions',
      title: 'Daily Missions',
      icon: LucideIcons.checkSquare,
      compactBuilder: (context) =>
          const MissionsCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const MissionsCard(size: HomeCardSize.large),
      defaultOrder: 2,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'finance',
      title: 'Finance Summary',
      icon: LucideIcons.wallet,
      defaultSize: HomeCardSize.large,
      compactBuilder: (context) =>
          const FinanceCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const FinanceCard(size: HomeCardSize.large),
      heroBuilder: (context) => const FinanceCard(size: HomeCardSize.hero),
      defaultOrder: 3,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'calories',
      title: 'Diet & Calories',
      icon: LucideIcons.utensils,
      compactBuilder: (context) =>
          const CaloriesCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const CaloriesCard(size: HomeCardSize.large),
      heroBuilder: (context) => const CaloriesCard(size: HomeCardSize.hero),
      defaultOrder: 4,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'score',
      title: 'XP Totals',
      icon: LucideIcons.trophy,
      compactBuilder: (context) => const ScoreCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const ScoreCard(size: HomeCardSize.large),
      defaultOrder: 5,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'score_delta',
      title: 'XP Velocity',
      icon: LucideIcons.trendingUp,
      compactBuilder: (context) =>
          const ScoreDeltaCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const ScoreDeltaCard(size: HomeCardSize.large),
      defaultOrder: 6,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'music',
      title: 'Music Controller',
      icon: LucideIcons.music,
      compactBuilder: (context) => const MusicCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const MusicCard(size: HomeCardSize.large),
      heroBuilder: (context) => const MusicCard(size: HomeCardSize.hero),
      defaultOrder: 7,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'medicine',
      title: 'Medicine Reminder',
      icon: LucideIcons.pill,
      compactBuilder: (context) =>
          const MedicineCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const MedicineCard(size: HomeCardSize.large),
      defaultOrder: 8,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'weight',
      title: 'Weight Journey',
      icon: LucideIcons.scale,
      compactBuilder: (context) => const WeightCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const WeightCard(size: HomeCardSize.large),
      defaultOrder: 9,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'health',
      title: 'Health Summary',
      icon: LucideIcons.heartPulse,
      compactBuilder: (context) =>
          const HealthSummaryCard(size: HomeCardSize.compact),
      largeBuilder: (context) =>
          const HealthSummaryCard(size: HomeCardSize.large),
      heroBuilder: (context) =>
          const HealthSummaryCard(size: HomeCardSize.hero),
      defaultOrder: 10,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'journal',
      title: 'Private Journal',
      icon: LucideIcons.bookLock,
      compactBuilder: (context) =>
          const JournalCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const JournalCard(size: HomeCardSize.large),
      defaultOrder: 11,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'brainstorm',
      title: 'Brainstorm',
      icon: LucideIcons.lightbulb,
      compactBuilder: (context) =>
          const BrainstormCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const BrainstormCard(size: HomeCardSize.large),
      defaultOrder: 12,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'reader',
      title: 'Document Reader',
      icon: LucideIcons.bookOpen,
      compactBuilder: (context) => const ReaderCard(size: HomeCardSize.compact),
      largeBuilder: (context) => const ReaderCard(size: HomeCardSize.large),
      defaultOrder: 13,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'safe_to_spend',
      title: 'Safe to Spend',
      icon: LucideIcons.shieldCheck,
      compactBuilder: (context) =>
          const SafeToSpendCard(size: HomeCardSize.compact),
      largeBuilder: (context) =>
          const SafeToSpendCard(size: HomeCardSize.large),
      heroBuilder: (context) => const SafeToSpendCard(size: HomeCardSize.hero),
      defaultOrder: 14,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'net_worth',
      title: 'Net Worth',
      icon: LucideIcons.lineChart,
      compactBuilder: (context) =>
          const NetWorthHomeCard(size: HomeCardSize.compact),
      largeBuilder: (context) =>
          const NetWorthHomeCard(size: HomeCardSize.large),
      heroBuilder: (context) => const NetWorthHomeCard(size: HomeCardSize.hero),
      defaultOrder: 15,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'upcoming_bills',
      title: 'Upcoming Bills',
      icon: LucideIcons.calendarClock,
      compactBuilder: (context) =>
          const UpcomingBillsCard(size: HomeCardSize.compact),
      largeBuilder: (context) =>
          const UpcomingBillsCard(size: HomeCardSize.large),
      defaultOrder: 16,
      defaultVisible: true,
    ));
    register(HomeCardSpec(
      id: 'galaxy_watch',
      title: 'Activity',
      icon: LucideIcons.watch,
      compactBuilder: (context) =>
          const GalaxyWatchCard(size: HomeCardSize.compact),
      largeBuilder: (context) =>
          const GalaxyWatchCard(size: HomeCardSize.large),
      heroBuilder: (context) => const GalaxyWatchCard(size: HomeCardSize.hero),
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

  /// Retrieves persisted size for [id], falling back to defaults per P8-4:
  /// - New installs: 'finance' is large, everything else compact.
  /// - Existing installs (with home_layout but no home_card_sizes): compact for all.
  static HomeCardSize getCardSize(Box settingsBox, String id) {
    final raw = settingsBox.get('home_card_sizes');
    if (raw is Map && raw.containsKey(id)) {
      final str = raw[id]?.toString();
      if (str == 'hero') return HomeCardSize.hero;
      if (str == 'large') return HomeCardSize.large;
      return HomeCardSize.compact;
    }

    final bool isExistingInstall = settingsBox.containsKey('home_layout') &&
        !settingsBox.containsKey('home_card_sizes');
    if (isExistingInstall) {
      return HomeCardSize.compact;
    }

    final spec = get(id);
    return spec?.defaultSize ?? HomeCardSize.compact;
  }

  /// Persists card size for [id] in settings box.
  static Future<void> setCardSize(
      Box settingsBox, String id, HomeCardSize size) async {
    final raw = settingsBox.get('home_card_sizes');
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    map[id] = size.name;
    await settingsBox.put('home_card_sizes', map);
  }
}
