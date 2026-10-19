import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/widgets/manual_food_input.dart';

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
    final accent = BentoTheme.accent;
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
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Goal / Mode Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          profile.hideCaloriesMode
                              ? LucideIcons.heartPulse
                              : LucideIcons.flame,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          profile.hideCaloriesMode
                              ? 'HABIT FOCUS MODE'
                              : 'TARGET: ${targetKcal.round()} KCAL',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!profile.hideCaloriesMode)
                    Text(
                      remainingKcal >= 0
                          ? '$remainingKcal kcal remaining'
                          : '${remainingKcal.abs()} kcal over target',
                      style: TextStyle(
                        color: remainingKcal >= 0 ? Colors.grey : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text(
                      'Balanced Plate Tracking',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
    final today = DateTime.now().toIso8601String().split('T').first;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final water = repo.waterDrankMl(today);
        final targetWater = repo.dailyTargets.waterMl;

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.droplets, size: 16, color: Color(0xFF64B5F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Hydration',
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${water.round()} / ${targetWater.round()} ml',
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  PressScale(
                    onTap: () => repo.addWater(250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF64B5F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '+250 ml',
                        style: TextStyle(
                          color: Color(0xFF64B5F6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressScale(
                    onTap: () => repo.addWater(500),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF64B5F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '+500 ml',
                        style: TextStyle(
                          color: Color(0xFF64B5F6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (water >= 250)
                    PressScale(
                      onTap: () => repo.addWater(-250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.undo2, size: 14, color: Colors.grey),
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
/// 4. MEAL SLOT CARDS WITH LOGGED ITEMS & 1-TAP PLANNED LOGGING
/// ---------------------------------------------------------------------------
class TodayMealSlotsView extends StatelessWidget {
  const TodayMealSlotsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;
    final today = DateTime.now().toIso8601String().split('T').first;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final logs = repo.getLogsForDate(today);
        final plannedMeals = repo.getPlannedMealsForDate(today);

        return Column(
          children: MealSlot.values.map((slot) {
            final slotLogs = logs.where((l) => l.mealSlot == slot).toList();
            final slotPlanned = plannedMeals.firstWhere(
              (m) => m.mealSlot == slot,
              orElse: () => PlannedMealItem(
                id: 'none',
                dateIso: today,
                mealSlot: slot,
                title: '',
                kcal: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
              ),
            );

            final slotKcal = slotLogs.fold(0.0, (sum, e) => sum + e.kcal);
            final slotProtein = slotLogs.fold(0.0, (sum, e) => sum + e.proteinG);

            return Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
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
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (slotKcal > 0 && !repo.profile.hideCaloriesMode)
                        Text(
                          '${slotKcal.round()} kcal · P: ${slotProtein.round()}g',
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(width: 8),
                      PressScale(
                        onTap: () => ManualFoodInputWidget.show(context, defaultSlot: slot),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.plus, size: 12, color: accent),
                              const SizedBox(width: 3),
                              Text(
                                'Log',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Planned Meal for this slot (if assigned)
                  if (slotPlanned.kcal > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BentoTheme.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.calendarCheck, size: 14, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Planned: ${slotPlanned.title}',
                                  style: TextStyle(
                                    color: BentoTheme.isDark ? Colors.white : Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${slotPlanned.kcal.round()} kcal · P: ${slotPlanned.proteinG.round()}g',
                                  style: TextStyle(
                                    color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (slotPlanned.status != PlannedMealStatus.eaten)
                            PressScale(
                              onTap: () => repo.updateMealStatus(slotPlanned.id, PlannedMealStatus.eaten),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Mark Eaten',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              '✓ Eaten',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Logged food entries
                  if (slotLogs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...slotLogs.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.quantity}x ${entry.title}',
                                    style: TextStyle(
                                      color: BentoTheme.isDark ? Colors.white : Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${entry.unit.symbol} · ${entry.gramsTotal.round()}g',
                                    style: TextStyle(
                                      color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
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
                                  color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => repo.deleteFoodLog(entry.id),
                              child: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else if (slotPlanned.kcal == 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'No foods logged yet.',
                      style: TextStyle(
                        color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
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
