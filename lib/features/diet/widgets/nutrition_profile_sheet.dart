import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/engine/nutrition_science_engine.dart';

/// Modal bottom sheet for configuring the user's physiological profile,
/// dietary pattern, allergies, budget, cook time, and Habit Focus (Hide Calories) mode.
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

  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _currentWeightCtrl;
  late TextEditingController _targetWeightCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _cookTimeCtrl;
  late TextEditingController _customProteinCtrl;

  static const List<String> _commonAllergens = [
    'Gluten',
    'Dairy',
    'Nuts',
    'Eggs',
    'Fish',
    'Soy',
    'Shellfish',
  ];

  static const List<String> _commonCuisines = [
    'Kerala / South Indian',
    'North Indian',
    'High-Protein Quick',
    'Mediterranean',
  ];

  @override
  void initState() {
    super.initState();
    _profile = DietRepository.instance.profile;
    _ageCtrl = TextEditingController(text: _profile.age.toString());
    _heightCtrl = TextEditingController(text: _profile.heightCm.toStringAsFixed(0));
    _currentWeightCtrl =
        TextEditingController(text: _profile.currentWeightKg.toStringAsFixed(1));
    _targetWeightCtrl =
        TextEditingController(text: _profile.targetWeightKg.toStringAsFixed(1));
    _budgetCtrl =
        TextEditingController(text: _profile.weeklyBudgetInr.toStringAsFixed(0));
    _cookTimeCtrl =
        TextEditingController(text: _profile.maxCookTimeMin.toString());
    _customProteinCtrl = TextEditingController(
        text: _profile.customProteinTargetG != null
            ? _profile.customProteinTargetG!.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _budgetCtrl.dispose();
    _cookTimeCtrl.dispose();
    _customProteinCtrl.dispose();
    super.dispose();
  }

  DailyTargets _previewTargets() {
    return NutritionScienceEngine.computeDailyTargets(_profile);
  }

  void _saveProfile() async {
    final age = int.tryParse(_ageCtrl.text) ?? _profile.age;
    final height = double.tryParse(_heightCtrl.text) ?? _profile.heightCm;
    final currentWeight =
        double.tryParse(_currentWeightCtrl.text) ?? _profile.currentWeightKg;
    final targetWeight =
        double.tryParse(_targetWeightCtrl.text) ?? _profile.targetWeightKg;
    final budget = double.tryParse(_budgetCtrl.text) ?? _profile.weeklyBudgetInr;
    final cookTime = int.tryParse(_cookTimeCtrl.text) ?? _profile.maxCookTimeMin;
    final customProtein = double.tryParse(_customProteinCtrl.text);

    final updated = _profile.copyWith(
      age: age,
      heightCm: height,
      currentWeightKg: currentWeight,
      targetWeightKg: targetWeight,
      weeklyBudgetInr: budget,
      maxCookTimeMin: cookTime,
      customProteinTargetG: customProtein,
    );

    await DietRepository.instance.updateProfile(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewTargets();
    final accent = BentoTheme.accent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic calculation banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      _profile.hideCaloriesMode
                          ? 'Habit Focus Mode Active'
                          : 'Target: ${preview.targetKcal.round()} kcal / day',
                      style: TextStyle(
                        color: BentoTheme.isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  preview.explanation,
                  style: TextStyle(
                    color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _macroPreviewPill('Protein', '${preview.proteinG.round()}g', AppColors.primary),
                    _macroPreviewPill('Fibre', '${preview.fibreG.round()}g', AppColors.success),
                    _macroPreviewPill('Carbs', '${preview.carbsG.round()}g', AppColors.warning),
                    _macroPreviewPill('Fats', '${preview.fatG.round()}g', const Color(0xFFE57373)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Habit Mode (Hide Calories) Switch
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _profile.hideCaloriesMode
                    ? accent.withValues(alpha: 0.6)
                    : (BentoTheme.isDark ? Colors.white10 : Colors.black12),
              ),
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
                          color: BentoTheme.isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Focuses on plate balance, protein portions, and regularity without displaying calorie numbers.',
                        style: TextStyle(
                          color: BentoTheme.isDark ? Colors.white60 : Colors.black45,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _profile.hideCaloriesMode,
                  activeColor: accent,
                  onChanged: (val) {
                    setState(() {
                      _profile = _profile.copyWith(hideCaloriesMode: val);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Biological Sex
          _sectionTitle('Biological Sex (Mifflin-St Jeor)'),
          const SizedBox(height: 8),
          Row(
            children: BiologicalSex.values.map((sex) {
              final isSel = _profile.sex == sex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PressScale(
                    onTap: () => setState(() => _profile = _profile.copyWith(sex: sex)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? accent : BentoTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel
                              ? accent
                              : (BentoTheme.isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sex.name[0].toUpperCase() + sex.name.substring(1),
                        style: TextStyle(
                          color: isSel ? Colors.black : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
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

          // Physical metrics row
          _sectionTitle('Physical Metrics'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _inputBox(
                  label: 'Age',
                  ctrl: _ageCtrl,
                  suffix: 'yrs',
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) setState(() => _profile = _profile.copyWith(age: n));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inputBox(
                  label: 'Height',
                  ctrl: _heightCtrl,
                  suffix: 'cm',
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) setState(() => _profile = _profile.copyWith(heightCm: n));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inputBox(
                  label: 'Weight',
                  ctrl: _currentWeightCtrl,
                  suffix: 'kg',
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) setState(() => _profile = _profile.copyWith(currentWeightKg: n));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Goal
          _sectionTitle('Primary Goal'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DietGoal.values.map((goal) {
              final isSel = _profile.goal == goal;
              return PressScale(
                onTap: () => setState(() => _profile = _profile.copyWith(goal: goal)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? accent.withValues(alpha: 0.2) : BentoTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? accent : (BentoTheme.isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Text(
                    goal.label,
                    style: TextStyle(
                      color: isSel ? accent : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Activity Level
          _sectionTitle('Activity Level (Training & Work)'),
          const SizedBox(height: 8),
          ...PhysicalActivityLevel.values.map((lvl) {
            final isSel = _profile.activityLevel == lvl;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PressScale(
                onTap: () => setState(() => _profile = _profile.copyWith(activityLevel: lvl)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? accent.withValues(alpha: 0.15) : BentoTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? accent : (BentoTheme.isDark ? Colors.white10 : Colors.black12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSel ? LucideIcons.checkCircle2 : LucideIcons.circle,
                        size: 16,
                        color: isSel ? accent : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lvl.label,
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        '${lvl.multiplier}x',
                        style: TextStyle(
                          color: isSel ? accent : Colors.grey,
                          fontSize: 11,
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

          // Dietary Pattern
          _sectionTitle('Dietary Pattern'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DietaryPattern.values.map((pat) {
              final isSel = _profile.dietaryPattern == pat;
              return PressScale(
                onTap: () => setState(() => _profile = _profile.copyWith(dietaryPattern: pat)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? accent : BentoTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? accent : (BentoTheme.isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Text(
                    pat.label,
                    style: TextStyle(
                      color: isSel ? Colors.black : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Allergies & Intolerances
          _sectionTitle('Allergens to Avoid (Strict Filter)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonAllergens.map((alg) {
              final isSel = _profile.allergies.contains(alg);
              return PressScale(
                onTap: () {
                  final list = List<String>.from(_profile.allergies);
                  if (isSel) {
                    list.remove(alg);
                  } else {
                    list.add(alg);
                  }
                  setState(() => _profile = _profile.copyWith(allergies: list));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.error.withValues(alpha: 0.2) : BentoTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? AppColors.error : (BentoTheme.isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSel) ...[
                        Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.error),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        alg,
                        style: TextStyle(
                          color: isSel ? AppColors.error : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Preferred Cuisines
          _sectionTitle('Preferred Cuisines'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonCuisines.map((c) {
              final isSel = _profile.preferredCuisines.contains(c);
              return PressScale(
                onTap: () {
                  final list = List<String>.from(_profile.preferredCuisines);
                  if (isSel) {
                    list.remove(c);
                  } else {
                    list.add(c);
                  }
                  setState(() => _profile = _profile.copyWith(preferredCuisines: list));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? accent.withValues(alpha: 0.2) : BentoTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? accent : (BentoTheme.isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      color: isSel ? accent : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Budget & Cook time row
          Row(
            children: [
              Expanded(
                child: _inputBox(
                  label: 'Weekly Budget',
                  ctrl: _budgetCtrl,
                  suffix: '₹',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _inputBox(
                  label: 'Max Cook Time',
                  ctrl: _cookTimeCtrl,
                  suffix: 'min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save button
          PressScale(
            onTap: _saveProfile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Save Profile & Recalculate Targets',
                style: TextStyle(
                  color: Colors.black,
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _inputBox({
    required String label,
    required TextEditingController ctrl,
    required String suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white60 : Colors.black45,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: BentoTheme.isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: BentoTheme.isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: onChanged,
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _macroPreviewPill(String name, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
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
        ],
      ),
    );
  }
}
