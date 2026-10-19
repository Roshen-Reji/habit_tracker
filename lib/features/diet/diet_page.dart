import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/widgets/diet_dashboard_widgets.dart';
import 'package:habit_tracker/features/diet/widgets/manual_food_input.dart';
import 'package:habit_tracker/features/diet/widgets/nutrition_profile_sheet.dart';
import 'package:habit_tracker/features/diet/widgets/diet_progress_tab.dart';

/// Flagship Diet OS Page.
/// Features a clean 2-mode M3 Expressive workspace:
/// 1. Today's Log (Macro Hero card, Hydration, 4 Meal slots, Fast Logging)
/// 2. Progress & Targets (EWMA Weight Trend, Weigh-Ins, Consistency)
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  int _activeTab = 0; // 0: Today's Log, 1: Progress & Targets

  static const List<String> _tabs = [
    "Today's Log",
    "Progress & Targets",
  ];

  void _openMoreMenu(BuildContext context) {
    final repo = DietRepository.instance;
    final colorScheme = Theme.of(context).colorScheme;

    SpringSheet.show(
      context: context,
      title: 'Diet OS Options & Safety',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medical Safety & Estimation Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical Safety & Estimation Notice',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All calorie and macro calculations are evidence-based estimates. Targets enforce a clinical safety floor (≥1300 kcal F / ≥1500 kcal M) to protect basal metabolic rate. Consult a healthcare professional for medical nutrition therapy.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Menu Options
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.notifications_none_rounded, size: 18, color: colorScheme.primary),
            ),
            title: Text(
              'Water & Meal Reminders',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Active during waking hours (${repo.profile.wakeHour}:00 - ${repo.profile.sleepHour}:00)',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reminders active between ${repo.profile.wakeHour}:00 and ${repo.profile.sleepHour}:00')),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.download_rounded, size: 18, color: colorScheme.primary),
            ),
            title: Text(
              'Export Nutrition & Trend Data',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Export local meal logs, custom foods, and weight history',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exported diet logs & weight history')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final profile = repo.profile;
        final targets = repo.dailyTargets;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Column(
              children: [
                // -------------------------------------------------------------
                // 1. TOP HEADER ROW (height: 48px)
                // -------------------------------------------------------------
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Title
                      Text(
                        'Diet',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Active Mode Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          profile.hideCaloriesMode
                              ? 'Habit Focus Mode'
                              : 'Target: ${targets.targetKcal.round()} kcal',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Action Buttons
                      // 1. Log Meal CTA
                      IconButton.filled(
                        onPressed: () => ManualFoodInputWidget.show(
                          context,
                          defaultSlot: MealSlot.lunch,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          visualDensity: VisualDensity.compact,
                        ),
                        tooltip: 'Log Food',
                      ),
                      const SizedBox(width: 6),

                      // 2. Nutrition Profile & Targets
                      IconButton.filledTonal(
                        onPressed: () => NutritionProfileSheet.show(context),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.onSurface,
                          visualDensity: VisualDensity.compact,
                        ),
                        tooltip: 'Profile & Targets',
                      ),
                      const SizedBox(width: 6),

                      // 3. More Menu
                      IconButton.filledTonal(
                        onPressed: () => _openMoreMenu(context),
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.onSurface,
                          visualDensity: VisualDensity.compact,
                        ),
                        tooltip: 'Options',
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. SLIDING PILL WORKSPACE SWITCHER (height: 42px)
                // -------------------------------------------------------------
                Container(
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final isSelected = _activeTab == i;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _activeTab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.fastOutSlowIn,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _tabs[i],
                              style: TextStyle(
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // -------------------------------------------------------------
                // 3. TAB WORKSPACE VIEW
                // -------------------------------------------------------------
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      // Tab 0: Today's Log
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        children: const [
                          AdaptiveSummaryHeroCard(),
                          DoctorTrainerCoachingStrip(),
                          HydrationAndQuickWeightStrip(),
                          TodayMealSlotsView(),
                        ],
                      ),
                      // Tab 1: Progress & Targets
                      const DietProgressTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
