import 'package:flutter/material.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/services/notification_service.dart';

class AddTaskDialog extends StatefulWidget {
  final GoalType defaultType;

  const AddTaskDialog({super.key, required this.defaultType});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final titleController = TextEditingController();
  final targetController = TextEditingController();
  GoalCategory selectedCategory = GoalCategory.productivity;
  GoalType selectedType = GoalType.daily;
  TimeOfDay? selectedReminderTime;

  @override
  void initState() {
    super.initState();
    selectedType = widget.defaultType;
  }

  String _getCategoryName(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return 'Health & Wellness';
      case GoalCategory.productivity: return 'Productivity';
      case GoalCategory.learning: return 'Learning & Growth';
      case GoalCategory.fitness: return 'Fitness';
      case GoalCategory.hobby: return 'Hobbies & Fun';
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return Icons.favorite;
      case GoalCategory.productivity: return Icons.bolt;
      case GoalCategory.learning: return Icons.menu_book;
      case GoalCategory.fitness: return Icons.fitness_center;
      case GoalCategory.hobby: return Icons.extension;
    }
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return AppColors.health;
      case GoalCategory.productivity: return AppColors.productivity;
      case GoalCategory.learning: return AppColors.learning;
      case GoalCategory.fitness: return AppColors.fitness;
      case GoalCategory.hobby: return AppColors.hobby;
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.background,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        selectedReminderTime = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "NEW MISSION",
        style: TextStyle(color: AppColors.textPrimary, letterSpacing: 1.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<GoalType>(
              value: selectedType,
              dropdownColor: AppColors.surfaceLight,
              onChanged: (GoalType? newValue) {
                if (newValue != null) setState(() => selectedType = newValue);
              },
              decoration: const InputDecoration(labelText: 'Mission Cycle', labelStyle: TextStyle(color: AppColors.textSecondary)),
              items: GoalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase(), style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: "Mission title...",
                hintStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceLight)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: "Target value (e.g., 20)...",
                hintStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceLight)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GoalCategory>(
              value: selectedCategory,
              dropdownColor: AppColors.surfaceLight,
              onChanged: (GoalCategory? newValue) {
                if (newValue != null) setState(() => selectedCategory = newValue);
              },
              decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: AppColors.textSecondary)),
              items: GoalCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 20),
                      const SizedBox(width: 8),
                      Text(_getCategoryName(category), style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Reminder Alert", style: TextStyle(color: AppColors.textSecondary)),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.alarm, color: AppColors.primary, size: 20),
                  label: Text(
                    selectedReminderTime != null ? selectedReminderTime!.format(context) : "Set Time",
                    style: const TextStyle(color: AppColors.primary),
                  ),
                )
              ],
            ),
            if (selectedReminderTime != null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("Plays default system notification sound.", style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: AppColors.textTertiary)),
        ),
        ElevatedButton(
          onPressed: () {
            final title = titleController.text;
            final target = double.tryParse(targetController.text);

            if (title.isNotEmpty && target != null && target > 0) {
              DateTime? reminderDate;
              if (selectedReminderTime != null) {
                final now = DateTime.now();
                reminderDate = DateTime(now.year, now.month, now.day, selectedReminderTime!.hour, selectedReminderTime!.minute);
              }

              final newGoal = Goal(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                type: selectedType,
                category: selectedCategory,
                targetValue: target,
                unit: 'units',
                createdDate: DateTime.now(),
                reminderTime: reminderDate,
              );
              Hive.box<Goal>('mission_box_v4').put(newGoal.id, newGoal);
              if (newGoal.reminderTime != null) {
                NotificationService().scheduleTaskReminder(newGoal);
              }
              Navigator.pop(context);
            }
          },
          child: const Text("ENGAGE"),
        ),
      ],
    );
  }
}
