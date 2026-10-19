import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/engine/nutrition_science_engine.dart';

/// Modal bottom sheet for configuring the user's physiological profile,
/// body metrics, auto-calculated targets with clinical safety floor,
/// and direct manual calorie/macro targets editing.
class NutritionProfileSheet extends StatefulWidget {
  const NutritionProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return SpringSheet.show(
      context: context,
      title: 'Nutrition Profile & Targets',
      child: const NutritionProfileSheet(),
    );
  }

  @override
  State<NutritionProfileSheet> createState() => _NutritionProfileSheetState();
}

class _NutritionProfileSheetState extends State<NutritionProfileSheet> {
  late NutritionProfile _profile;

  // Body Metrics
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _currentWeightCtrl;
  late TextEditingController _targetWeightCtrl;

  // Daily Targets (Manual Overrides or Auto-Calculated)
  late TextEditingController _targetCaloriesCtrl;
  late TextEditingController _targetProteinCtrl;
  late TextEditingController _targetCarbsCtrl;
  late TextEditingController _targetFatCtrl;
  late TextEditingController _targetWaterCtrl;

  @override
  void initState() {
    super.initState();
    _profile = DietRepository.instance.profile;
    final targets = DietRepository.instance.dailyTargets;

    _ageCtrl = TextEditingController(text: _profile.age.toString());
    _heightCtrl = TextEditingController(text: _profile.heightCm.toStringAsFixed(0));
    _currentWeightCtrl =
        TextEditingController(text: _profile.currentWeightKg.toStringAsFixed(1));
    _targetWeightCtrl =
        TextEditingController(text: _profile.targetWeightKg.toStringAsFixed(1));

    _targetCaloriesCtrl = TextEditingController(
      text: (_profile.targetCalories ?? targets.targetKcal).round().toString(),
    );
    _targetProteinCtrl = TextEditingController(
      text: (_profile.targetProteinG ?? targets.proteinG).round().toString(),
    );
    _targetCarbsCtrl = TextEditingController(
      text: (_profile.targetCarbsG ?? targets.carbsG).round().toString(),
    );
    _targetFatCtrl = TextEditingController(
      text: (_profile.targetFatG ?? targets.fatG).round().toString(),
    );
    _targetWaterCtrl = TextEditingController(
      text: (_profile.targetWaterMl ?? targets.waterMl).round().toString(),
    );
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _targetCaloriesCtrl.dispose();
    _targetProteinCtrl.dispose();
    _targetCarbsCtrl.dispose();
    _targetFatCtrl.dispose();
    _targetWaterCtrl.dispose();
    super.dispose();
  }

  void _autoCalculateFromMetrics() {
    final age = int.tryParse(_ageCtrl.text) ?? _profile.age;
    final height = double.tryParse(_heightCtrl.text) ?? _profile.heightCm;
    final currentWeight =
        double.tryParse(_currentWeightCtrl.text) ?? _profile.currentWeightKg;
    final targetWeight =
        double.tryParse(_targetWeightCtrl.text) ?? _profile.targetWeightKg;

    final tempProfile = _profile.copyWith(
      age: age,
      heightCm: height,
      currentWeightKg: currentWeight,
      targetWeightKg: targetWeight,
    );

    final auto = NutritionScienceEngine.calculateTargetsFromMetrics(tempProfile);

    setState(() {
      _profile = tempProfile;
      _targetCaloriesCtrl.text = auto.targetKcal.round().toString();
      _targetProteinCtrl.text = auto.proteinG.round().toString();
      _targetCarbsCtrl.text = auto.carbsG.round().toString();
      _targetFatCtrl.text = auto.fatG.round().toString();
      _targetWaterCtrl.text = auto.waterMl.round().toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Calculated: ${auto.targetKcal.round()} kcal (${auto.explanation})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveProfile() async {
    final age = int.tryParse(_ageCtrl.text) ?? _profile.age;
    final height = double.tryParse(_heightCtrl.text) ?? _profile.heightCm;
    final currentWeight =
        double.tryParse(_currentWeightCtrl.text) ?? _profile.currentWeightKg;
    final targetWeight =
        double.tryParse(_targetWeightCtrl.text) ?? _profile.targetWeightKg;

    final targetCalories = double.tryParse(_targetCaloriesCtrl.text);
    final targetProtein = double.tryParse(_targetProteinCtrl.text);
    final targetCarbs = double.tryParse(_targetCarbsCtrl.text);
    final targetFat = double.tryParse(_targetFatCtrl.text);
    final targetWater = double.tryParse(_targetWaterCtrl.text);

    final updated = _profile.copyWith(
      age: age,
      heightCm: height,
      currentWeightKg: currentWeight,
      targetWeightKg: targetWeight,
      targetCalories: targetCalories,
      targetProteinG: targetProtein,
      customProteinTargetG: targetProtein,
      targetCarbsG: targetCarbs,
      targetFatG: targetFat,
      targetWaterMl: targetWater,
    );

    await DietRepository.instance.updateProfile(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Physical Metrics
          _sectionHeader('BODY METRICS', Icons.straighten_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _m3TextField(
                  label: 'Age',
                  controller: _ageCtrl,
                  suffix: 'yrs',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _m3TextField(
                  label: 'Height',
                  controller: _heightCtrl,
                  suffix: 'cm',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _m3TextField(
                  label: 'Weight',
                  controller: _currentWeightCtrl,
                  suffix: 'kg',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Biological Sex
          Text(
            'Biological Sex (BMR Calculation)',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: BiologicalSex.values.map((sex) {
              final isSelected = _profile.sex == sex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PressScale(
                    onTap: () => setState(() => _profile = _profile.copyWith(sex: sex)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sex.name[0].toUpperCase() + sex.name.substring(1),
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Goal (Cut / Maintain / Bulk)
          _sectionHeader('PRIMARY GOAL', Icons.flag_rounded),
          const SizedBox(height: 8),
          Row(
            children: [
              _goalPill('Cut', DietGoal.gradualLoss, 'Fat Loss'),
              const SizedBox(width: 8),
              _goalPill('Maintain', DietGoal.maintain, 'Maintain'),
              const SizedBox(width: 8),
              _goalPill('Bulk', DietGoal.gradualGain, 'Muscle Gain'),
            ],
          ),
          const SizedBox(height: 16),

          // Activity Level
          _sectionHeader('ACTIVITY LEVEL', Icons.fitness_center_rounded),
          const SizedBox(height: 8),
          ...PhysicalActivityLevel.values.map((lvl) {
            final isSelected = _profile.activityLevel == lvl;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PressScale(
                onTap: () => setState(() => _profile = _profile.copyWith(activityLevel: lvl)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lvl.label,
                          style: TextStyle(
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${lvl.multiplier}x',
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Section 2: Daily Targets & Auto-Calculation
          Row(
            children: [
              _sectionHeader('DAILY TARGETS', Icons.restaurant_rounded),
              const Spacer(),
              // Auto-Calculate CTA
              FilledButton.tonalIcon(
                onPressed: _autoCalculateFromMetrics,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: const Text('Auto-Calculate'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Target Calories input (Big Callout)
          _m3TextField(
            label: 'Daily Calories (kcal)',
            controller: _targetCaloriesCtrl,
            suffix: 'kcal',
            keyboardType: TextInputType.number,
            isHighlight: true,
          ),
          const SizedBox(height: 10),

          // Macro Row: Protein, Carbs, Fats
          Row(
            children: [
              Expanded(
                child: _m3TextField(
                  label: 'Protein',
                  controller: _targetProteinCtrl,
                  suffix: 'g',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _m3TextField(
                  label: 'Carbs',
                  controller: _targetCarbsCtrl,
                  suffix: 'g',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _m3TextField(
                  label: 'Fats',
                  controller: _targetFatCtrl,
                  suffix: 'g',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Water Target
          _m3TextField(
            label: 'Daily Hydration Target (ml)',
            controller: _targetWaterCtrl,
            suffix: 'ml',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Habit Mode Toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Habit Focus Mode (Hide Calories)',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hides numbers to focus purely on plate balance and habit consistency.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _profile.hideCaloriesMode,
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    setState(() => _profile = _profile.copyWith(hideCaloriesMode: val));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Save Profile & Targets',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _goalPill(String title, DietGoal goal, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _profile.goal == goal;
    return Expanded(
      child: PressScale(
        onTap: () => setState(() => _profile = _profile.copyWith(goal: goal)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                      : colorScheme.onSurfaceVariant,
                  fontSize: 10,
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
    required String suffix,
    TextInputType keyboardType = TextInputType.text,
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: isHighlight ? 16 : 14,
        fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
        filled: true,
        fillColor: isHighlight
            ? colorScheme.primaryContainer.withValues(alpha: 0.25)
            : colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isHighlight ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
