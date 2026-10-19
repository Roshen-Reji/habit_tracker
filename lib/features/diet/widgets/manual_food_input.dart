import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';

/// Clean Material 3 Meal Logging Sheet.
/// Features 2 fast modes:
/// 1. Quick Entry Form (Food Name, Calories, Protein, Carbs, Fats, Servings, Save to My Foods)
/// 2. My Saved Foods (User's own CustomFoodItem library for 1-tap logging)
class ManualFoodInputWidget extends StatefulWidget {
  final MealSlot defaultSlot;
  final String? dateIso;
  final VoidCallback? onFoodAdded;

  const ManualFoodInputWidget({
    super.key,
    this.defaultSlot = MealSlot.lunch,
    this.dateIso,
    this.onFoodAdded,
  });

  static Future<void> show(
    BuildContext context, {
    MealSlot defaultSlot = MealSlot.lunch,
    String? dateIso,
    VoidCallback? onFoodAdded,
  }) {
    return SpringSheet.show(
      context: context,
      title: 'Log Meal (${defaultSlot.title})',
      child: ManualFoodInputWidget(
        defaultSlot: defaultSlot,
        dateIso: dateIso,
        onFoodAdded: onFoodAdded,
      ),
    );
  }

  @override
  State<ManualFoodInputWidget> createState() => _ManualFoodInputWidgetState();
}

class _ManualFoodInputWidgetState extends State<ManualFoodInputWidget> {
  int _activeTab = 0; // 0: Quick Entry, 1: My Saved Foods
  late MealSlot _selectedSlot;

  // Quick Entry controllers
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  double _servings = 1.0;
  bool _saveToMyFoods = false;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.defaultSlot;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  String get _effectiveDate =>
      widget.dateIso ?? DateTime.now().toIso8601String().split('T').first;

  Future<void> _logQuickMeal() async {
    final name = _nameCtrl.text.trim();
    final kcal = double.tryParse(_kcalCtrl.text) ?? 0.0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter food name')),
      );
      return;
    }
    if (kcal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid calories (kcal)')),
      );
      return;
    }

    final protein = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final carbs = double.tryParse(_carbsCtrl.text) ?? 0.0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0.0;

    // Scale by servings
    final totalKcal = kcal * _servings;
    final totalProtein = protein * _servings;
    final totalCarbs = carbs * _servings;
    final totalFat = fat * _servings;

    final entry = DietLogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      dateIso: _effectiveDate,
      mealSlot: _selectedSlot,
      title: name,
      quantity: _servings,
      unit: HouseholdUnit.serving,
      gramsTotal: 100.0 * _servings,
      kcal: totalKcal,
      proteinG: totalProtein,
      carbsG: totalCarbs,
      fatG: totalFat,
      confidence: FoodConfidence.userSubmitted,
    );

    await DietRepository.instance.logFood(entry);

    if (_saveToMyFoods) {
      final customItem = CustomFoodItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        servingLabel: '1 serving',
        calories: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      );
      await DietRepository.instance.upsertCustomFood(customItem);
    }

    if (mounted) {
      widget.onFoodAdded?.call();
      Navigator.pop(context);
    }
  }

  Future<void> _logFromCustomFood(CustomFoodItem item) async {
    final entry = DietLogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      dateIso: _effectiveDate,
      mealSlot: _selectedSlot,
      title: item.name,
      quantity: 1.0,
      unit: HouseholdUnit.serving,
      gramsTotal: 100.0,
      kcal: item.calories,
      proteinG: item.proteinG,
      carbsG: item.carbsG,
      fatG: item.fatG,
      confidence: FoodConfidence.userSubmitted,
    );

    await DietRepository.instance.logFood(entry);

    if (mounted) {
      widget.onFoodAdded?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${item.name} to ${_selectedSlot.title}!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal slot selector chips
          Row(
            children: MealSlot.values.map((s) {
              final isSelected = _selectedSlot == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: PressScale(
                    onTap: () => setState(() => _selectedSlot = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${s.emoji} ${s.name[0].toUpperCase() + s.name.substring(1)}',
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Sliding Tab Switcher: Quick Entry vs My Saved Foods
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                _tabPill(index: 0, title: 'Quick Entry', icon: Icons.bolt_rounded),
                _tabPill(index: 1, title: 'My Saved Foods', icon: Icons.bookmark_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mode 0: Quick Entry
          if (_activeTab == 0) ...[
            _m3TextField(
              label: 'Food Name',
              controller: _nameCtrl,
              hint: 'e.g. Scrambled Eggs with Toast',
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _m3TextField(
                    label: 'Calories (kcal)',
                    controller: _kcalCtrl,
                    suffix: 'kcal',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _m3TextField(
                    label: 'Protein',
                    controller: _proteinCtrl,
                    suffix: 'g',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _m3TextField(
                    label: 'Carbs',
                    controller: _carbsCtrl,
                    suffix: 'g',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _m3TextField(
                    label: 'Fats',
                    controller: _fatCtrl,
                    suffix: 'g',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Servings stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Text(
                    'Servings',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _servings > 0.5
                        ? () => setState(() => _servings = (_servings - 0.5).clamp(0.5, 10.0))
                        : null,
                    icon: const Icon(Icons.remove, size: 16),
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${_servings == _servings.roundToDouble() ? _servings.toInt() : _servings}x',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () =>
                        setState(() => _servings = (_servings + 0.5).clamp(0.5, 10.0)),
                    icon: const Icon(Icons.plus_one, size: 16),
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Save to My Foods checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveToMyFoods,
              onChanged: (val) => setState(() => _saveToMyFoods = val ?? false),
              title: Text(
                'Save to My Foods for 1-tap logging',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Log Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _logQuickMeal,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Log ${_selectedSlot.title}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Mode 1: My Saved Foods
            AnimatedBuilder(
              animation: DietRepository.instance,
              builder: (context, _) {
                final savedFoods = DietRepository.instance.customFoods;
                if (savedFoods.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Saved Foods Yet',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Save meals from Quick Entry with the "Save to My Foods" checkbox for instant 1-tap logging.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: savedFoods.map((food) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food.name,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${food.calories.round()} kcal · P: ${food.proteinG.round()}g · C: ${food.carbsG.round()}g · F: ${food.fatG.round()}g',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Log CTA
                          FilledButton.tonal(
                            onPressed: () => _logFromCustomFood(food),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Log'),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                            onPressed: () => DietRepository.instance.deleteCustomFood(food.id),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabPill({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _m3TextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
        suffixText: suffix,
        suffixStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
