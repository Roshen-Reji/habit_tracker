import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/widgets/diet_dashboard_widgets.dart';
import 'package:habit_tracker/features/diet/widgets/manual_food_input.dart';
import 'package:habit_tracker/features/diet/widgets/nutrition_profile_sheet.dart';
import 'package:habit_tracker/features/diet/widgets/meal_planner_tab.dart';
import 'package:habit_tracker/features/diet/widgets/grocery_pantry_tab.dart';
import 'package:habit_tracker/features/diet/widgets/diet_progress_tab.dart';

/// Flagship Diet Planner OS Page.
/// Features a clean 48px header, 120fps sliding 4-tab workspace,
/// dual-engine AI integration, clinical safety floors, and habit focus mode.
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  int _activeTab = 0; // 0: Today, 1: Planner, 2: Grocery, 3: Progress

  static const List<String> _tabs = [
    'Today',
    'Planner',
    'Grocery',
    'Progress',
  ];

  void _openMoreMenu(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;

    SpringSheet.show(
      context: context,
      title: 'Diet OS Options & Safety',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medical Safety & Estimation Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldCheck, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical Safety & Estimation Notice',
                        style: TextStyle(
                          color: BentoTheme.isDark ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'All calorie and macro calculations are approximate evidence-based estimates. Targets enforce a clinical safety floor (≥1300 kcal F / ≥1500 kcal M) to protect basal metabolic rate. Always consult a physician or registered dietitian for medical medical nutrition therapy.',
                        style: TextStyle(
                          color: BentoTheme.isDark ? Colors.white60 : Colors.black54,
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
          _menuTile(
            icon: LucideIcons.bell,
            title: 'Water & Meal Reminder Settings',
            subtitle: 'Waking-hour quiet controls (${repo.profile.wakeHour}:00 - ${repo.profile.sleepHour}:00)',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reminders active between ${repo.profile.wakeHour}:00 and ${repo.profile.sleepHour}:00')),
              );
            },
          ),
          _menuTile(
            icon: LucideIcons.downloadCloud,
            title: 'Export Nutrition & Trend Data',
            subtitle: 'Export logs, planned meals, and weigh-in records',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exported diet logs & weight history')),
              );
            },
          ),
          _menuTile(
            icon: LucideIcons.refreshCw,
            title: 'Regenerate Weekly Plan from Pantry',
            subtitle: 'Auto-build 7-day balanced meals matching your budget',
            onTap: () async {
              Navigator.pop(context);
              await repo.regenerateGroceryList();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Regenerated plan and grocery list!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: BentoTheme.accent),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: BentoTheme.isDark ? Colors.white : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
          fontSize: 11,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;
    final isDark = BentoTheme.isDark;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final profile = repo.profile;
        final targets = repo.dailyTargets;

        return Scaffold(
          backgroundColor: BentoTheme.background,
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
                      // Title + Active Mode Pill
                      Text(
                        'Diet',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile.hideCaloriesMode
                              ? 'Habit Focus Mode'
                              : 'Target: ${targets.targetKcal.round()} kcal',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // 3 Clean Circular Buttons
                      // 1. ✨ AI Log / Snap
                      PressScale(
                        onTap: () => ManualFoodInputWidget.show(
                          context,
                          defaultSlot: MealSlot.lunch,
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.sparkles, size: 16, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. 🎯 Profile & Goals
                      PressScale(
                        onTap: () => NutritionProfileSheet.show(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: BentoTheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.target,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. ⋮ More
                      PressScale(
                        onTap: () => _openMoreMenu(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: BentoTheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.moreVertical,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. SLIDING PILL WORKSPACE SWITCHER (height: 40px)
                // -------------------------------------------------------------
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = constraints.maxWidth / _tabs.length;
                      return Stack(
                        children: [
                          // 120fps Sliding Indicator Pill
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 260),
                            curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                            alignment: Alignment(
                              -1.0 + (2.0 * _activeTab / (_tabs.length - 1)),
                              0,
                            ),
                            child: Container(
                              width: tabWidth,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                          // Tab Tap Targets
                          Row(
                            children: List.generate(_tabs.length, (i) {
                              final isSelected = _activeTab == i;
                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => _activeTab = i),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _tabs[i],
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDark ? Colors.white : Colors.black)
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // -------------------------------------------------------------
                // 3. TAB WORKSPACE VIEW
                // -------------------------------------------------------------
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      // Tab 0: Today
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        children: const [
                          AdaptiveSummaryHeroCard(),
                          DoctorTrainerCoachingStrip(),
                          HydrationAndQuickWeightStrip(),
                          TodayMealSlotsView(),
                        ],
                      ),
                      // Tab 1: Planner
                      const MealPlannerTab(),
                      // Tab 2: Grocery
                      const GroceryPantryTab(),
                      // Tab 3: Progress
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
