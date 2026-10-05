import 'package:flutter/material.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/features/wearables/data/wake_service.dart';

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
  DateTime? selectedEndDate;
  bool _isWakeup = false;
  TimeOfDay _wakeupTargetTime = const TimeOfDay(hour: 5, minute: 0);
  String? _metricKey;
  String? _metricOp;

  @override
  void initState() {
    super.initState();
    selectedType = widget.defaultType;
  }

  String _getCategoryName(GoalCategory category) {
    switch (category) {
      case GoalCategory.health:
        return 'Health & Wellness';
      case GoalCategory.productivity:
        return 'Productivity';
      case GoalCategory.learning:
        return 'Learning & Growth';
      case GoalCategory.fitness:
        return 'Fitness';
      case GoalCategory.hobby:
        return 'Hobbies & Fun';
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.health:
        return LucideIcons.heartPulse;
      case GoalCategory.productivity:
        return LucideIcons.zap;
      case GoalCategory.learning:
        return LucideIcons.bookOpen;
      case GoalCategory.fitness:
        return LucideIcons.dumbbell;
      case GoalCategory.hobby:
        return LucideIcons.puzzle;
    }
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.health:
        return AppColors.health;
      case GoalCategory.productivity:
        return AppColors.productivity;
      case GoalCategory.learning:
        return AppColors.learning;
      case GoalCategory.fitness:
        return AppColors.fitness;
      case GoalCategory.hobby:
        return AppColors.hobby;
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

  Future<void> _pickEndDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
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
    if (date != null) {
      setState(() {
        selectedEndDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BentoContainer(
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
                    style: TextStyle(
                        color: BentoTheme.textPrimary,
                        letterSpacing: 1.5,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isAiMode = !_isAiMode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAiMode
                          ? BentoTheme.accent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isAiMode
                            ? BentoTheme.accent
                            : BentoTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.sparkles,
                          color: _isAiMode
                              ? BentoTheme.accent
                              : BentoTheme.textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "AI",
                          style: TextStyle(
                            color: _isAiMode
                                ? BentoTheme.accent
                                : BentoTheme.textSecondary,
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
                    child: Text("CANCEL",
                        style: TextStyle(color: BentoTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  BentoButton(
                    onTap: () {
                      if (_isWakeup) {
                        final targetMinutes = _wakeupTargetTime.hour * 60 +
                            _wakeupTargetTime.minute;
                        WakeService.instance.createOrUpdateWakeupTask(
                          targetMinutes: targetMinutes,
                          title: titleController.text.isNotEmpty
                              ? titleController.text
                              : null,
                        );
                        Navigator.pop(context);
                        return;
                      }

                      final title = titleController.text;
                      final target = double.tryParse(targetController.text);

                      if (title.isNotEmpty && target != null && target > 0) {
                        DateTime? reminderDate;
                        if (selectedReminderTime != null) {
                          final now = DateTime.now();
                          reminderDate = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              selectedReminderTime!.hour,
                              selectedReminderTime!.minute);
                        }

                        final newGoal = Goal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          type: selectedType,
                          category: selectedCategory,
                          targetValue: target,
                          unit: _metricKey == 'steps'
                              ? 'steps'
                              : (_metricKey?.contains('minutes') == true ? 'mins' : 'units'),
                          createdDate: DateTime.now(),
                          reminderTime: reminderDate,
                          endDate: selectedEndDate,
                          kind: _isWakeup ? 'wakeup' : (_metricKey != null ? 'metric' : null),
                          metricKey: _metricKey,
                          metricOp: _metricOp ?? '>=',
                        );
                        Hive.box<Goal>('mission_box_v4')
                            .put(newGoal.id, newGoal);
                        if (newGoal.reminderTime != null) {
                          NotificationService().scheduleTaskReminder(newGoal);
                        }
                        Navigator.pop(context);
                      }
                    },
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Text("ENGAGE",
                        style: TextStyle(
                            color: BentoTheme.accent,
                            fontWeight: FontWeight.bold)),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: _isWakeup,
                avatar: Icon(
                  LucideIcons.alarmClock,
                  size: 14,
                  color: _isWakeup ? Colors.black : BentoTheme.accent,
                ),
                label: const Text('Wake-Up Task'),
                selectedColor: BentoTheme.accent,
                backgroundColor: BentoTheme.background,
                labelStyle: TextStyle(
                  color: _isWakeup ? Colors.black : BentoTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _isWakeup = val;
                    if (val) {
                      _metricKey = null;
                      selectedType = GoalType.daily;
                      selectedCategory = GoalCategory.health;
                      final h =
                          _wakeupTargetTime.hour.toString().padLeft(2, '0');
                      final m =
                          _wakeupTargetTime.minute.toString().padLeft(2, '0');
                      titleController.text = 'Wake up at $h:$m';
                      targetController.text = '1';
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _metricKey == 'steps',
                avatar: Icon(
                  LucideIcons.footprints,
                  size: 14,
                  color: _metricKey == 'steps' ? Colors.black : BentoTheme.accent,
                ),
                label: const Text('10,000 steps'),
                selectedColor: BentoTheme.accent,
                backgroundColor: BentoTheme.background,
                labelStyle: TextStyle(
                  color: _metricKey == 'steps' ? Colors.black : BentoTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _isWakeup = false;
                    _metricKey = val ? 'steps' : null;
                    _metricOp = '>=';
                    if (val) {
                      selectedType = GoalType.daily;
                      selectedCategory = GoalCategory.fitness;
                      titleController.text = '10,000 steps';
                      targetController.text = '10000';
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _metricKey == 'active_minutes',
                avatar: Icon(
                  LucideIcons.flame,
                  size: 14,
                  color: _metricKey == 'active_minutes' ? Colors.black : BentoTheme.accent,
                ),
                label: const Text('30 active mins'),
                selectedColor: BentoTheme.accent,
                backgroundColor: BentoTheme.background,
                labelStyle: TextStyle(
                  color: _metricKey == 'active_minutes' ? Colors.black : BentoTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _isWakeup = false;
                    _metricKey = val ? 'active_minutes' : null;
                    _metricOp = '>=';
                    if (val) {
                      selectedType = GoalType.daily;
                      selectedCategory = GoalCategory.fitness;
                      titleController.text = '30 active minutes';
                      targetController.text = '30';
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _metricKey == 'sleep_minutes',
                avatar: Icon(
                  LucideIcons.moon,
                  size: 14,
                  color: _metricKey == 'sleep_minutes' ? Colors.black : BentoTheme.accent,
                ),
                label: const Text('Sleep 7 h'),
                selectedColor: BentoTheme.accent,
                backgroundColor: BentoTheme.background,
                labelStyle: TextStyle(
                  color: _metricKey == 'sleep_minutes' ? Colors.black : BentoTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _isWakeup = false;
                    _metricKey = val ? 'sleep_minutes' : null;
                    _metricOp = '>=';
                    if (val) {
                      selectedType = GoalType.daily;
                      selectedCategory = GoalCategory.health;
                      titleController.text = 'Sleep 7 h';
                      targetController.text = '420';
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _metricKey == 'workout_minutes',
                avatar: Icon(
                  LucideIcons.dumbbell,
                  size: 14,
                  color: _metricKey == 'workout_minutes' ? Colors.black : BentoTheme.accent,
                ),
                label: const Text('Workout today'),
                selectedColor: BentoTheme.accent,
                backgroundColor: BentoTheme.background,
                labelStyle: TextStyle(
                  color: _metricKey == 'workout_minutes' ? Colors.black : BentoTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  setState(() {
                    _isWakeup = false;
                    _metricKey = val ? 'workout_minutes' : null;
                    _metricOp = '>=';
                    if (val) {
                      selectedType = GoalType.daily;
                      selectedCategory = GoalCategory.fitness;
                      titleController.text = 'Workout today';
                      targetController.text = '30';
                    }
                  });
                },
              ),
              if (_isWakeup) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _wakeupTargetTime,
                    );
                    if (picked != null) {
                      setState(() {
                        _wakeupTargetTime = picked;
                        final h = picked.hour.toString().padLeft(2, '0');
                        final m = picked.minute.toString().padLeft(2, '0');
                        titleController.text = 'Wake up at $h:$m';
                      });
                    }
                  },
                  icon: const Icon(LucideIcons.clock, size: 14),
                  label: Text('${_wakeupTargetTime.format(context)} (Target)'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<GoalType>(
          initialValue: selectedType,
          dropdownColor: BentoTheme.background,
          onChanged: (GoalType? newValue) {
            if (newValue != null) setState(() => selectedType = newValue);
          },
          decoration: InputDecoration(
              labelText: 'Mission Cycle',
              labelStyle: TextStyle(color: BentoTheme.textSecondary)),
          items: GoalType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.name.toUpperCase(),
                  style: TextStyle(color: BentoTheme.textPrimary)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleController,
          style: TextStyle(color: BentoTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Mission title...",
            hintStyle: TextStyle(color: BentoTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.3))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: BentoTheme.accent)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: targetController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: BentoTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Target value (e.g., 20)...",
            hintStyle: TextStyle(color: BentoTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.3))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: BentoTheme.accent)),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<GoalCategory>(
          initialValue: selectedCategory,
          dropdownColor: BentoTheme.background,
          onChanged: (GoalCategory? newValue) {
            if (newValue != null) setState(() => selectedCategory = newValue);
          },
          decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: BentoTheme.textSecondary)),
          items: GoalCategory.values.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Row(
                children: [
                  Icon(_getCategoryIcon(category),
                      color: _getCategoryColor(category), size: 20),
                  const SizedBox(width: 8),
                  Text(_getCategoryName(category),
                      style: TextStyle(color: BentoTheme.textPrimary)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Reminder Alert",
                style: TextStyle(color: BentoTheme.textSecondary)),
            TextButton.icon(
              onPressed: _pickTime,
              icon: Icon(LucideIcons.alarmClock,
                  color: BentoTheme.accent, size: 20),
              label: Text(
                selectedReminderTime != null
                    ? selectedReminderTime!.format(context)
                    : "Set Time",
                style: TextStyle(color: BentoTheme.accent),
              ),
            )
          ],
        ),
        if (selectedReminderTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("Plays default system notification sound.",
                style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Mission Deadline",
                style: TextStyle(color: BentoTheme.textSecondary)),
            TextButton.icon(
              onPressed: _pickEndDate,
              icon: Icon(LucideIcons.calendar,
                  color: BentoTheme.accent, size: 20),
              label: Text(
                selectedEndDate != null
                    ? "${selectedEndDate!.day}/${selectedEndDate!.month}/${selectedEndDate!.year}"
                    : "Set End Date",
                style: TextStyle(color: BentoTheme.accent),
              ),
            )
          ],
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
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aiController,
          style: TextStyle(color: BentoTheme.textPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "e.g., Today I want to finish 2 lectures of physics",
            hintStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.3)),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: BentoTheme.accent),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: BentoButton(
            onTap: _isAiLoading ? () {} : _processAiTask,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAiLoading)
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BentoTheme.accent))
                else
                  Icon(LucideIcons.sparkles,
                      size: 18, color: BentoTheme.accent),
                const SizedBox(width: 8),
                Text(
                  _isAiLoading ? "ANALYZING..." : "CREATE MISSION",
                  style: TextStyle(
                      color: BentoTheme.accent, fontWeight: FontWeight.bold),
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
            _buildQuickSuggestion("Wake up at 5:00 AM"),
            _buildQuickSuggestion("10,000 steps"),
            _buildQuickSuggestion("30 active minutes"),
            _buildQuickSuggestion("Sleep 7 h"),
            _buildQuickSuggestion("Workout today"),
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
          color: BentoTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.15)),
        ),
        child: Text(text,
            style: TextStyle(color: BentoTheme.accent, fontSize: 11)),
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
          content: Text(
              "✓ Mission created: ${response.actions.first.payload['title'] ?? 'New Mission'}"),
          backgroundColor: BentoTheme.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: BentoTheme.background,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
