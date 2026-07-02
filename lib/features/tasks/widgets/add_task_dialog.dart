import 'package:flutter/material.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      case GoalCategory.health: return LucideIcons.heartPulse;
      case GoalCategory.productivity: return LucideIcons.zap;
      case GoalCategory.learning: return LucideIcons.bookOpen;
      case GoalCategory.fitness: return LucideIcons.dumbbell;
      case GoalCategory.hobby: return LucideIcons.puzzle;
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: NeuContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isAiMode ? "AI MISSION" : "NEW MISSION",
                    style: TextStyle(color: NeuTheme.textPrimary, letterSpacing: 1.5, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (AiService.instance.isConfigured)
                  GestureDetector(
                    onTap: () => setState(() => _isAiMode = !_isAiMode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAiMode ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isAiMode ? NeuTheme.accent : NeuTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.sparkles,
                            color: _isAiMode ? NeuTheme.accent : NeuTheme.textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "AI",
                            style: TextStyle(
                              color: _isAiMode ? NeuTheme.accent : NeuTheme.textSecondary,
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
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: _isAiMode ? _buildAiContent() : _buildManualContent(),
              ),
            ),
            if (!_isAiMode) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("CANCEL", style: TextStyle(color: NeuTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  NeuButton(
                    onTap: () {
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text("ENGAGE", style: TextStyle(color: NeuTheme.accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<GoalType>(
          value: selectedType,
          dropdownColor: NeuTheme.background,
          onChanged: (GoalType? newValue) {
            if (newValue != null) setState(() => selectedType = newValue);
          },
          decoration: InputDecoration(labelText: 'Mission Cycle', labelStyle: TextStyle(color: NeuTheme.textSecondary)),
          items: GoalType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.name.toUpperCase(), style: TextStyle(color: NeuTheme.textPrimary)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleController,
          style: TextStyle(color: NeuTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Mission title...",
            hintStyle: TextStyle(color: NeuTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: NeuTheme.textSecondary.withValues(alpha: 0.3))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: NeuTheme.accent)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: targetController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: NeuTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Target value (e.g., 20)...",
            hintStyle: TextStyle(color: NeuTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: NeuTheme.textSecondary.withValues(alpha: 0.3))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: NeuTheme.accent)),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<GoalCategory>(
          value: selectedCategory,
          dropdownColor: NeuTheme.background,
          onChanged: (GoalCategory? newValue) {
            if (newValue != null) setState(() => selectedCategory = newValue);
          },
          decoration: InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: NeuTheme.textSecondary)),
          items: GoalCategory.values.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Row(
                children: [
                  Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 20),
                  const SizedBox(width: 8),
                  Text(_getCategoryName(category), style: TextStyle(color: NeuTheme.textPrimary)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Reminder Alert", style: TextStyle(color: NeuTheme.textSecondary)),
            TextButton.icon(
              onPressed: _pickTime,
              icon: Icon(LucideIcons.alarmClock, color: NeuTheme.accent, size: 20),
              label: Text(
                selectedReminderTime != null ? selectedReminderTime!.format(context) : "Set Time",
                style: TextStyle(color: NeuTheme.accent),
              ),
            )
          ],
        ),
        if (selectedReminderTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("Plays default system notification sound.", style: TextStyle(color: NeuTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildAiContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Describe your mission in natural language",
          style: TextStyle(color: NeuTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiController,
          style: TextStyle(color: NeuTheme.textPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "e.g., Today I want to finish 2 lectures of physics",
            hintStyle: TextStyle(color: NeuTheme.textSecondary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: NeuTheme.textSecondary.withValues(alpha: 0.3)),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: NeuTheme.accent),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: NeuButton(
            onTap: _isAiLoading ? () {} : _processAiTask,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAiLoading)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeuTheme.accent))
                else
                  Icon(LucideIcons.sparkles, size: 18, color: NeuTheme.accent),
                const SizedBox(width: 8),
                Text(
                  _isAiLoading ? "ANALYZING..." : "CREATE MISSION",
                  style: TextStyle(color: NeuTheme.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
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
          color: NeuTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.15)),
        ),
        child: Text(text, style: TextStyle(color: NeuTheme.accent, fontSize: 11)),
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
          backgroundColor: NeuTheme.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: NeuTheme.background,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

