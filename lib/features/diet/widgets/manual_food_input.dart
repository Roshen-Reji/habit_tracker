import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/diet_models.dart';

class ManualFoodInputWidget extends StatefulWidget {
  final VoidCallback? onFoodAdded;

  const ManualFoodInputWidget({super.key, this.onFoodAdded});

  @override
  State<ManualFoodInputWidget> createState() => _ManualFoodInputWidgetState();
}

class _ManualFoodInputWidgetState extends State<ManualFoodInputWidget> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  MealType _selectedMeal = MealType.breakfast;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _addFood() {
    final name = _nameController.text.trim();
    final calories = double.tryParse(_caloriesController.text) ?? 0;

    if (name.isNotEmpty && calories > 0) {
      final entry = FoodEntry(
        id: DateTime.now().toString(),
        name: name,
        calories: calories,
        protein: double.tryParse(_proteinController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        fat: double.tryParse(_fatController.text) ?? 0,
        mealType: _selectedMeal,
        timestamp: DateTime.now(),
      );

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final box = Hive.box<DietDayLog>('diet_logs');
      var log = box.get(today);
      if (log == null) {
        log = DietDayLog(dateKey: today, targetCalories: 2000);
        box.put(today, log);
      }

      log.addFood(entry);
      log.save();

      _nameController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _carbsController.clear();
      _fatController.clear();

      widget.onFoodAdded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    return BentoContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "MANUAL LOG",
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Food Name",
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "kcal",
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMacroField(_proteinController, "P(g)")),
              const SizedBox(width: 4),
              Expanded(child: _buildMacroField(_carbsController, "C(g)")),
              const SizedBox(width: 4),
              Expanded(child: _buildMacroField(_fatController, "F(g)")),
              const SizedBox(width: 12),
              DropdownButton<MealType>(
                value: _selectedMeal,
                dropdownColor: BentoTheme.background,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                icon: Icon(Icons.arrow_drop_down, color: accent),
                items: MealType.values.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(m.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMeal = val);
                },
              ),
              const Spacer(),
              GestureDetector(
                onTap: _addFood,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.plus, color: accent, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}
