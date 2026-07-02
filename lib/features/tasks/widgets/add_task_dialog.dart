import 'package:flutter/material.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/data/services/ai_service.dart';

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
  bool _isAiMode = false;
  bool _isAiLoading = false;
  final _aiController = TextEditingController();

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
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isAiMode ? "AI MISSION" : "NEW MISSION",
              style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 1.5),
            ),
          ),
          if (AiService.instance.isConfigured)
            GestureDetector(
              onTap: () => setState(() => _isAiMode = !_isAiMode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAiMode ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAiMode ? AppColors.primary : AppColors.textTertiary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: _isAiMode ? AppColors.primary : AppColors.textTertiary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "AI",
                      style: TextStyle(
                        color: _isAiMode ? AppColors.primary : AppColors.textTertiary,
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
      content: SingleChildScrollView(
        child: _isAiMode ? _buildAiContent() : _buildManualContent(),
      ),
      actions: _isAiMode ? null : [
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

  Widget _buildManualContent() {
    return Column(
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
    );
  }

  Widget _buildAiContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Describe your mission in natural language",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiController,
          style: const TextStyle(color: AppColors.textPrimary),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "e.g., Today I want to finish 2 lectures of physics",
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.surfaceLight),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAiLoading ? null : _processAiTask,
            icon: _isAiLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_isAiLoading ? "Analyzing..." : "CREATE MISSION"),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildQuickSuggestion("Study 3 chapters today"),
            _buildQuickSuggestion("Workout 5hrs this week"),
            _buildQuickSuggestion("Read 20 pages daily"),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSuggestion(String text) {
    return GestureDetector(
      onTap: () {
        _aiController.text = text;
        _processAiTask();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 11)),
      ),
    );
  }

  Future<void> _processAiTask() async {
    if (_aiController.text.trim().isEmpty) return;

    setState(() => _isAiLoading = true);

    final response = await AiService.instance.processMessage(
      _aiController.text,
      contextHint: 'tasks',
    );

    setState(() => _isAiLoading = false);

    // Find task_create actions and execute them
    bool created = false;
    for (var action in response.actions) {
      if (action.type == 'task_create') {
        AiService.instance.executeTaskAction(action);
        created = true;
      }
    }

    if (created && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Mission created: ${response.actions.first.payload['title'] ?? 'New Mission'}"),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

