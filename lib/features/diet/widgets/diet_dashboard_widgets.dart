import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/widgets/manual_food_input.dart';
import 'package:habit_tracker/features/diet/widgets/nutrition_profile_sheet.dart';

/// Legacy macro color tokens and helper bar.
class MacroBreakdownBar extends StatelessWidget {
  static const Color proteinColor = Color(0xFF448AFF);
  static const Color carbsColor = Color(0xFFFFD740);
  static const Color fatColor = Color(0xFFFF5252);

  const MacroBreakdownBar({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// ---------------------------------------------------------------------------
/// 1. ADAPTIVE SUMMARY HERO CARD
/// ---------------------------------------------------------------------------
/// Adapts seamlessly between Calorie-Tracking and Habit-Focus (Hide Calories) mode.
class AdaptiveSummaryHeroCard extends StatefulWidget {
  const AdaptiveSummaryHeroCard({super.key});

  @override
  State<AdaptiveSummaryHeroCard> createState() => _AdaptiveSummaryHeroCardState();
}

class _AdaptiveSummaryHeroCardState extends State<AdaptiveSummaryHeroCard> {
  bool _showMicros = false;

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final isDark = BentoTheme.isDark;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final profile = repo.profile;
        final targets = repo.dailyTargets;
        final today = DateTime.now().toIso8601String().split('T').first;
        final logs = repo.getLogsForDate(today);

        final consumedKcal = logs.fold(0.0, (sum, e) => sum + e.kcal);
        final consumedProtein = logs.fold(0.0, (sum, e) => sum + e.proteinG);
        final consumedCarbs = logs.fold(0.0, (sum, e) => sum + e.carbsG);
        final consumedFat = logs.fold(0.0, (sum, e) => sum + e.fatG);
        final consumedFibre = logs.fold(0.0, (sum, e) => sum + e.fibreG);

        final targetKcal = targets.targetKcal;
        final remainingKcal = (targetKcal - consumedKcal).round();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Goal / Mode Pill + Edit Targets Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          profile.hideCaloriesMode
                              ? LucideIcons.heartPulse
                              : LucideIcons.flame,
                          size: 13,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          profile.hideCaloriesMode
                              ? 'HABIT FOCUS MODE'
                              : 'TARGET: ${targetKcal.round()} KCAL',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // High contrast Edit Targets CTA
                  FilledButton.tonalIcon(
                    onPressed: () => NutritionProfileSheet.show(context),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Edit Targets'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mode Branching: Standard Calorie view vs Habit Focus Plate view
              if (!profile.hideCaloriesMode) ...[
                // Big Calorie Ring & Intake Numbers
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${consumedKcal.round()}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Consumed Today',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                          if (targets.clinicalFloorApplied) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Clinical safety floor active',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _miniProgressRing(
                      progress: targetKcal > 0 ? (consumedKcal / targetKcal).clamp(0.0, 1.5) : 0.0,
                      color: remainingKcal >= 0 ? accent : AppColors.warning,
                      label: '${((consumedKcal / (targetKcal > 0 ? targetKcal : 1)) * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4 Progress Bars: Protein, Carbs, Fat, Fibre
                _macroLinearBar(
                  label: 'Protein',
                  consumed: consumedProtein,
                  target: targets.proteinG,
                  unit: 'g',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                _macroLinearBar(
                  label: 'Dietary Fibre',
                  consumed: consumedFibre,
                  target: targets.fibreG,
                  unit: 'g',
                  color: AppColors.success,
                ),
                const SizedBox(height: 8),
                _macroLinearBar(
                  label: 'Carbohydrates',
                  consumed: consumedCarbs,
                  target: targets.carbsG,
                  unit: 'g',
                  color: AppColors.warning,
                ),
                const SizedBox(height: 8),
                _macroLinearBar(
                  label: 'Healthy Fats',
                  consumed: consumedFat,
                  target: targets.fatG,
                  unit: 'g',
                  color: const Color(0xFFE57373),
                ),
              ] else ...[
                // Habit Focus Mode: 4 Balanced Habit Rings (Zero Numbers)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _habitRing(
                      title: 'Protein Goal',
                      ratio: (consumedProtein / targets.proteinG).clamp(0.0, 1.0),
                      color: AppColors.primary,
                      icon: LucideIcons.dumbbell,
                    ),
                    _habitRing(
                      title: 'Fibre & Veg',
                      ratio: (consumedFibre / targets.fibreG).clamp(0.0, 1.0),
                      color: AppColors.success,
                      icon: LucideIcons.leaf,
                    ),
                    _habitRing(
                      title: 'Regularity',
                      ratio: (logs.map((l) => l.mealSlot).toSet().length / 3.0).clamp(0.0, 1.0),
                      color: accent,
                      icon: LucideIcons.clock,
                    ),
                    _habitRing(
                      title: 'Hydration',
                      ratio: (repo.waterDrankMl(today) / targets.waterMl).clamp(0.0, 1.0),
                      color: const Color(0xFF64B5F6),
                      icon: LucideIcons.droplets,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Consistency builds metabolic resilience. Eat mindful, balanced meals at your regular eating windows.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],

              // Expandable Micronutrients Toggle
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _showMicros = !_showMicros),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showMicros ? 'Hide Micronutrients' : 'View Essential Micronutrients',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showMicros ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 13,
                      color: accent,
                    ),
                  ],
                ),
              ),

              if (_showMicros) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _microStat('Iron', '${targets.ironMg.round()} mg', 'Energy & RBCs'),
                      _microStat('Calcium', '${targets.calciumMg.round()} mg', 'Bone Strength'),
                      _microStat('Water Target', '${(targets.waterMl / 1000).toStringAsFixed(1)} L', 'Cellular Flush'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _miniProgressRing({
    required double progress,
    required Color color,
    required String label,
  }) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 6,
            color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
          ),
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
            color: color,
          ),
          Text(
            label,
            style: TextStyle(
              color: BentoTheme.isDark ? Colors.white : Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLinearBar({
    required String label,
    required double consumed,
    required double target,
    required String unit,
    required Color color,
  }) {
    final ratio = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              '${consumed.round()} / ${target.round()} $unit',
              style: TextStyle(
                color: BentoTheme.isDark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: BentoTheme.isDark ? Colors.white10 : Colors.black12,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _habitRing({
    required String title,
    required double ratio,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 5,
                color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
              ),
              CircularProgressIndicator(
                value: ratio,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: color,
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _microStat(String name, String value, String benefit) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white60 : Colors.black54,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          benefit,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2. DOCTOR & GYM TRAINER SMART COACHING STRIP
/// ---------------------------------------------------------------------------
class DoctorTrainerCoachingStrip extends StatelessWidget {
  const DoctorTrainerCoachingStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final insights = repo.todayInsights;
        if (insights.isEmpty) return const SizedBox.shrink();

        final insight = insights.first;
        IconData icon = LucideIcons.sparkles;
        Color color = accent;

        if (insight.category == 'protein') {
          icon = LucideIcons.dumbbell;
          color = AppColors.primary;
        } else if (insight.category == 'fibre') {
          icon = LucideIcons.leaf;
          color = AppColors.success;
        } else if (insight.category == 'hydration') {
          icon = LucideIcons.droplets;
          color = const Color(0xFF64B5F6);
        }

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    insight.title,
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      insight.category.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                insight.message,
                style: TextStyle(
                  color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              if (insight.actionPillText != null) ...[
                const SizedBox(height: 10),
                PressScale(
                  onTap: () {
                    if (insight.category == 'hydration') {
                      repo.addWater(250);
                    } else {
                      ManualFoodInputWidget.show(context, defaultSlot: MealSlot.lunch);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      insight.actionPillText!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// 3. HYDRATION & QUICK WEIGHT STRIP
/// ---------------------------------------------------------------------------
class HydrationAndQuickWeightStrip extends StatelessWidget {
  const HydrationAndQuickWeightStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now().toIso8601String().split('T').first;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final water = repo.waterDrankMl(today);
        final targetWater = repo.dailyTargets.waterMl;

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop_rounded, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Hydration',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${water.round()} / ${targetWater.round()} ml',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: () => repo.addWater(250),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('+250 ml'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => repo.addWater(500),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('+500 ml'),
                  ),
                  const SizedBox(width: 8),
                  if (water >= 250)
                    IconButton.filledTonal(
                      onPressed: () => repo.addWater(-250),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// 4. MEAL SLOT CARDS WITH LOGGED ITEMS & ADD FOOD CTA
/// ---------------------------------------------------------------------------
class TodayMealSlotsView extends StatelessWidget {
  const TodayMealSlotsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now().toIso8601String().split('T').first;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final logs = repo.getLogsForDate(today);

        return Column(
          children: MealSlot.values.map((slot) {
            final slotLogs = logs.where((l) => l.mealSlot == slot).toList();
            final slotKcal = slotLogs.fold(0.0, (sum, e) => sum + e.kcal);
            final slotProtein = slotLogs.fold(0.0, (sum, e) => sum + e.proteinG);

            return Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slot Header
                  Row(
                    children: [
                      Text(
                        '${slot.emoji} ${slot.title}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (slotKcal > 0 && !repo.profile.hideCaloriesMode)
                        Text(
                          '${slotKcal.round()} kcal · P: ${slotProtein.round()}g',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(width: 8),
                      // High-contrast Add Food Pill
                      FilledButton.tonalIcon(
                        onPressed: () => ManualFoodInputWidget.show(context, defaultSlot: slot),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Add Food'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),

                  // Logged food entries
                  if (slotLogs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...slotLogs.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.quantity}x ${entry.title}',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${entry.unit.symbol} · ${entry.gramsTotal.round()}g · P: ${entry.proteinG.round()}g',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!repo.profile.hideCaloriesMode)
                              Text(
                                '${entry.kcal.round()} kcal',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                              onPressed: () => repo.deleteFoodLog(entry.id),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'No foods logged yet.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
