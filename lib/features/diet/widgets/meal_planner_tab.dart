import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/engine/native_diet_ai_engine.dart';
import 'package:habit_tracker/data/services/ai_service.dart';

/// Day & 7-Day Flexible Meal Planner Tab.
/// Supports 1-tap swaps, non-judgmental eaten/skipped/ate-out status,
/// auto-generation from pantry, and instant grocery list building.
class MealPlannerTab extends StatefulWidget {
  const MealPlannerTab({super.key});

  @override
  State<MealPlannerTab> createState() => _MealPlannerTabState();
}

class _MealPlannerTabState extends State<MealPlannerTab> {
  late DateTime _selectedDate;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _dateIso => DateFormat('yyyy-MM-dd').format(_selectedDate);

  void _openSwapSheet(PlannedMealItem meal) {
    final repo = DietRepository.instance;
    final swaps = NativeDietAiEngine.suggestMealSwaps(
      current: meal,
      profile: repo.profile,
      foods: repo.foods,
    );

    SpringSheet.show(
      context: context,
      title: 'Swap ${meal.mealSlot.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: ${meal.title} (${meal.kcal.round()} kcal, ${meal.proteinG.round()}g protein)',
            style: TextStyle(
              color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Top 3 Balanced Alternatives:',
            style: TextStyle(
              color: BentoTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...swaps.map((alt) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: BentoTheme.isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alt.title,
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          alt.whySuggested,
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white60 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${alt.kcal.round()} kcal · P: ${alt.proteinG.round()}g · ~${alt.prepTimeMin}m · ₹${alt.estimatedCostInr.round()}',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PressScale(
                    onTap: () {
                      final updated = alt.copyWith(
                        id: meal.id,
                        dateIso: meal.dateIso,
                        mealSlot: meal.mealSlot,
                      );
                      repo.savePlannedMeal(updated);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: BentoTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Swap In',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _autoGeneratePlan() async {
    setState(() => _isGenerating = true);
    final repo = DietRepository.instance;
    final pantry = repo.groceryList.where((g) => g.inPantry).map((g) => g.name).toList();

    try {
      final fallbackItems = repo.foods.take(5).map((f) => f.name).toList();
      final newPlan = await AiService.instance.generateSmartMealPlanWithAi(
        profile: repo.profile,
        pantryItems: pantry.isNotEmpty ? pantry : fallbackItems,
        dateIso: _dateIso,
      );
      await repo.setPlannedMealsForDate(_dateIso, newPlan);
    } catch (_) {}

    if (mounted) setState(() => _isGenerating = false);
  }

  void _copyYesterday() async {
    final repo = DietRepository.instance;
    final yDate = _selectedDate.subtract(const Duration(days: 1));
    final yKey = DateFormat('yyyy-MM-dd').format(yDate);
    final yMeals = repo.getPlannedMealsForDate(yKey);

    if (yMeals.isNotEmpty) {
      final copied = yMeals.map((m) {
        return m.copyWith(
          id: 'copy_${DateTime.now().millisecondsSinceEpoch}_${m.mealSlot.name}',
          dateIso: _dateIso,
          status: PlannedMealStatus.planned,
        );
      }).toList();
      await repo.setPlannedMealsForDate(_dateIso, copied);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied yesterday\'s meal plan')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final meals = repo.getPlannedMealsForDate(_dateIso);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // Top Control Strip: Auto-Generate, Copy, Grocery List
            Row(
              children: [
                Expanded(
                  child: PressScale(
                    onTap: _isGenerating ? null : _autoGeneratePlan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: _isGenerating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.sparkles, size: 13, color: accent),
                                const SizedBox(width: 5),
                                Text(
                                  'Auto-Generate',
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressScale(
                    onTap: _copyYesterday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: BentoTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: BentoTheme.isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.copy, size: 13, color: BentoTheme.isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 5),
                          Text(
                            'Copy Prior Day',
                            style: TextStyle(
                              color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PressScale(
                  onTap: () async {
                    await repo.regenerateGroceryList();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Updated grocery list from meal plan!')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: BentoTheme.isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: const Icon(LucideIcons.shoppingBag, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Date selector strip
            _buildDateStrip(accent),
            const SizedBox(height: 16),

            // Meal Slot Cards
            ...MealSlot.values.map((slot) {
              final slotMeal = meals.firstWhere(
                (m) => m.mealSlot == slot,
                orElse: () => PlannedMealItem(
                  id: 'plan_default_${slot.name}_$_dateIso',
                  dateIso: _dateIso,
                  mealSlot: slot,
                  title: 'No meal planned yet',
                  kcal: 0,
                  proteinG: 0,
                  carbsG: 0,
                  fatG: 0,
                ),
              );

              return _buildMealSlotCard(slot, slotMeal, accent);
            }),

            const SizedBox(height: 16),
            // Medical Disclaimer Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nutritional meal plans are estimated guidelines for sustainable habits. Adjust portions according to your appetite and clinical advice.',
                      style: TextStyle(
                        color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateStrip(Color accent) {
    final now = DateTime.now();
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = now.subtract(const Duration(days: 2)).add(Duration(days: index));
          final isSelected = DateFormat('yyyy-MM-dd').format(date) == _dateIso;
          final isToday = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(now);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PressScale(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : (isToday ? accent.withValues(alpha: 0.15) : BentoTheme.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : (BentoTheme.isDark ? Colors.white10 : Colors.black12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date).toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : (BentoTheme.isDark ? Colors.white54 : Colors.black45),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : (BentoTheme.isDark ? Colors.white : Colors.black87),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealSlotCard(MealSlot slot, PlannedMealItem meal, Color accent) {
    final isAssigned = meal.kcal > 0;
    final repo = DietRepository.instance;

    Color statusColor = Colors.grey;
    if (meal.status == PlannedMealStatus.eaten) statusColor = AppColors.success;
    if (meal.status == PlannedMealStatus.skipped) statusColor = Colors.grey;
    if (meal.status == PlannedMealStatus.ateOut) statusColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: meal.status == PlannedMealStatus.eaten
              ? AppColors.success.withValues(alpha: 0.4)
              : (BentoTheme.isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${slot.emoji} ${slot.title.toUpperCase()}',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (isAssigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    meal.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            meal.title,
            style: TextStyle(
              color: BentoTheme.isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (meal.whySuggested.isNotEmpty && isAssigned) ...[
            const SizedBox(height: 3),
            Text(
              meal.whySuggested,
              style: TextStyle(
                color: BentoTheme.isDark ? Colors.white60 : Colors.black54,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),

          if (isAssigned) ...[
            Row(
              children: [
                if (!repo.profile.hideCaloriesMode) ...[
                  Text(
                    '${meal.kcal.round()} kcal',
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white70 : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Protein: ${meal.proteinG.round()}g',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '⏱ ${meal.prepTimeMin}m',
                  style: TextStyle(
                    color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${meal.estimatedCostInr.round()}',
                  style: TextStyle(
                    color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions row: ✓ Eaten | 🔄 Swap | 🍽️ Ate Out | ⏭️ Skip
            Row(
              children: [
                PressScale(
                  onTap: () => repo.updateMealStatus(meal.id, PlannedMealStatus.eaten),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: meal.status == PlannedMealStatus.eaten
                          ? AppColors.success
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.check,
                          size: 13,
                          color: meal.status == PlannedMealStatus.eaten
                              ? Colors.black
                              : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Eaten',
                          style: TextStyle(
                            color: meal.status == PlannedMealStatus.eaten
                                ? Colors.black
                                : AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PressScale(
                  onTap: () => _openSwapSheet(meal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.refreshCw, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Swap', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PressScale(
                  onTap: () => repo.updateMealStatus(meal.id, PlannedMealStatus.ateOut),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Ate Out', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 6),
                PressScale(
                  onTap: () => repo.updateMealStatus(meal.id, PlannedMealStatus.skipped),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            PressScale(
              onTap: () => ManualFoodInputWidget.show(
                context,
                defaultSlot: slot,
                dateIso: _dateIso,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 12, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'Plan / Log Food',
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
        ],
      ),
    );
  }
}
