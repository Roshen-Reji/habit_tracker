import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

/// Modal dialog for creating strictly separated One-Time Tasks vs. Recurring Habits.
/// Adheres strictly to Material 3 Expressive guidelines:
/// - High-contrast tonal surfaces (surfaceContainer, surfaceContainerHigh)
/// - Segmented pill switch: One-Time Task vs. Recurring Habit
/// - Solid secondaryContainer fill for all secondary chips and date/time pickers
/// - Full-width high-contrast FilledButton primary CTA (colorScheme.primary)
class AddTaskDialog extends StatefulWidget {
  final GoalType defaultType;
  final bool initialIsHabit;
  final DateTime? initialDate;

  const AddTaskDialog({
    super.key,
    this.defaultType = GoalType.daily,
    this.initialIsHabit = false,
    this.initialDate,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late bool _isHabit;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  // One-Time Task State
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  int _selectedPriority = TaskPriority.medium;
  int _estimateMin = 30;

  // Recurring Habit State
  String _selectedFrequency = 'daily'; // 'daily', 'weekly', 'monthly'
  final Set<int> _selectedDaysOfWeek = {1, 2, 3, 4, 5, 6, 7}; // 1 = Mon .. 7 = Sun
  int _selectedDayOfMonth = 1;
  GoalCategory _selectedCategory = GoalCategory.productivity;
  TimeOfDay? _habitReminderTime;

  @override
  void initState() {
    super.initState();
    _isHabit = widget.initialIsHabit ||
        (widget.defaultType != GoalType.today &&
            widget.defaultType == GoalType.daily);
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickHabitReminder() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _habitReminderTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
    if (picked != null) {
      setState(() => _habitReminderTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    final now = DateTime.now();

    if (!_isHabit) {
      // 1. Create One-Time Task (Strictly single day, no recurrence)
      DateTime? dueAt;
      if (_selectedTime != null) {
        dueAt = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      } else {
        dueAt = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
        );
      }

      final task = TaskItem(
        id: 'task_${now.millisecondsSinceEpoch}',
        title: title,
        notes: notes.isNotEmpty ? notes : null,
        status: TaskStatus.todo,
        priority: _selectedPriority,
        dueAt: dueAt,
        hasDueTime: _selectedTime != null,
        estimateMin: _estimateMin,
        isHabit: false,
        recurrenceRule: null,
        recurrenceFrequency: 'none',
        createdAt: now,
        updatedAt: now,
      );

      await TaskOsRepository.instance.saveTask(task);

      // Save to mission_box_v4 for legacy widgets
      try {
        final box = Hive.box<Goal>('mission_box_v4');
        final legacyGoal = Goal(
          id: task.id,
          title: title,
          type: GoalType.today,
          category: _selectedCategory,
          targetValue: 1.0,
          unit: 'task',
          createdDate: now,
          endDate: dueAt,
        );
        await box.put(legacyGoal.id, legacyGoal);
      } catch (_) {}
    } else {
      // 2. Create Recurring Habit
      final targetPerWeek = _selectedFrequency == 'daily'
          ? 7
          : (_selectedFrequency == 'weekly'
              ? _selectedDaysOfWeek.length.clamp(1, 7)
              : 1);

      final habit = ForgivingHabitItem(
        id: 'habit_${now.millisecondsSinceEpoch}',
        name: title,
        targetPerWeek: targetPerWeek,
        freezesLeft: 2,
        restDays: _selectedDaysOfWeek.length < 7
            ? [1, 2, 3, 4, 5, 6, 7]
                .where((d) => !_selectedDaysOfWeek.contains(d))
                .toList()
            : const [7],
        completedDatesIso: const [],
        frozenDatesIso: const [],
        frequency: _selectedFrequency,
        daysOfWeek: _selectedDaysOfWeek.toList()..sort(),
        dayOfMonth:
            _selectedFrequency == 'monthly' ? _selectedDayOfMonth : null,
        reminderTime: _habitReminderTime != null
            ? '${_habitReminderTime!.hour.toString().padLeft(2, '0')}:${_habitReminderTime!.minute.toString().padLeft(2, '0')}'
            : null,
        category: _selectedCategory.name,
      );

      await TaskOsRepository.instance.saveHabit(habit);

      // Save to mission_box_v4 for legacy widgets
      try {
        final box = Hive.box<Goal>('mission_box_v4');
        final reminderDt = _habitReminderTime != null
            ? DateTime(now.year, now.month, now.day, _habitReminderTime!.hour,
                _habitReminderTime!.minute)
            : null;

        final legacyGoal = Goal(
          id: habit.id,
          title: title,
          type: _selectedFrequency == 'monthly'
              ? GoalType.monthly
              : (_selectedFrequency == 'weekly'
                  ? GoalType.weekly
                  : GoalType.daily),
          category: _selectedCategory,
          targetValue: targetPerWeek.toDouble(),
          unit: 'days',
          createdDate: now,
          reminderTime: reminderDt,
        );
        await box.put(legacyGoal.id, legacyGoal);
        if (legacyGoal.reminderTime != null) {
          NotificationService().scheduleTaskReminder(legacyGoal);
        }
      } catch (_) {}
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isHabit ? 'New Habit' : 'New Task',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: colorScheme.onSurfaceVariant,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Top Segmented Switcher: One-Time Task vs Recurring Habit
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isHabit = false);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isHabit
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'One-Time Task',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_isHabit
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isHabit = true);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isHabit
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Recurring Habit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isHabit
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: _isHabit ? 'Habit Title' : 'Task Title',
                    hintText: _isHabit
                        ? 'e.g. Read 20 pages, Gym Workout'
                        : 'e.g. Finish OS Record, Submit Assignment',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Conditional Form: One-Time Task vs Recurring Habit
                if (!_isHabit)
                  _buildOneTimeTaskControls(colorScheme)
                else
                  _buildRecurringHabitControls(colorScheme),

                const SizedBox(height: 24),

                // Action Buttons: Cancel & High-Contrast Primary FilledButton
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isHabit ? 'Create Habit' : 'Create Task',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= 1. ONE-TIME TASK CONTROLS =================
  Widget _buildOneTimeTaskControls(ColorScheme colorScheme) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateLabel = isToday
        ? 'Today (${DateFormat('MMM d').format(_selectedDate)})'
        : DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

    final timeLabel = _selectedTime != null
        ? _selectedTime!.format(context)
        : 'Optional Time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scheduled Date & Time Row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: colorScheme.outlineVariant, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTime != null
                      ? colorScheme.primaryContainer
                      : colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: colorScheme.outlineVariant, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: _selectedTime != null
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _selectedTime != null
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Priority Selector (P1..P4)
        Text(
          'Priority',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildPriorityChip(TaskPriority.urgent, 'P1 Urgent',
                const Color(0xFFEF4444), colorScheme),
            const SizedBox(width: 6),
            _buildPriorityChip(TaskPriority.high, 'P2 High',
                const Color(0xFFF97316), colorScheme),
            const SizedBox(width: 6),
            _buildPriorityChip(TaskPriority.medium, 'P3 Med',
                const Color(0xFF3B82F6), colorScheme),
            const SizedBox(width: 6),
            _buildPriorityChip(TaskPriority.low, 'P4 Low',
                const Color(0xFF10B981), colorScheme),
          ],
        ),
        const SizedBox(height: 16),

        // Estimate duration chips
        Text(
          'Estimate Duration',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [15, 30, 45, 60].map((min) {
            final isSelected = _estimateMin == min;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${min}m'),
                selected: isSelected,
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _estimateMin = min),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriorityChip(
      int priority, String label, Color accentColor, ColorScheme colorScheme) {
    final isSelected = _selectedPriority == priority;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPriority = priority);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.22)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? accentColor : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ================= 2. RECURRING HABIT CONTROLS =================
  Widget _buildRecurringHabitControls(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frequency Selector: Daily vs Weekly vs Monthly
        Text(
          'Recurrence Frequency',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildFreqOption('daily', 'Every Day', colorScheme),
            const SizedBox(width: 8),
            _buildFreqOption('weekly', 'Specific Days', colorScheme),
            const SizedBox(width: 8),
            _buildFreqOption('monthly', 'Monthly', colorScheme),
          ],
        ),
        const SizedBox(height: 16),

        // Day of Week Selector if Weekly
        if (_selectedFrequency == 'weekly') ...[
          Text(
            'Active Days of Week (${_selectedDaysOfWeek.length} days / week)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayCircle(1, 'M', colorScheme),
              _buildDayCircle(2, 'T', colorScheme),
              _buildDayCircle(3, 'W', colorScheme),
              _buildDayCircle(4, 'T', colorScheme),
              _buildDayCircle(5, 'F', colorScheme),
              _buildDayCircle(6, 'S', colorScheme),
              _buildDayCircle(7, 'S', colorScheme),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Day of Month Selector if Monthly
        if (_selectedFrequency == 'monthly') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day of Month: $_selectedDayOfMonth',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: colorScheme.primary,
                    onPressed: _selectedDayOfMonth > 1
                        ? () => setState(() => _selectedDayOfMonth--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: colorScheme.primary,
                    onPressed: _selectedDayOfMonth < 31
                        ? () => setState(() => _selectedDayOfMonth++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Category & Reminder Row
        Row(
          children: [
            // Category Dropdown
            Expanded(
              child: DropdownButtonFormField<GoalCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: GoalCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(
                      _categoryName(cat),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
            const SizedBox(width: 12),

            // Reminder Time Picker
            Expanded(
              child: GestureDetector(
                onTap: _pickHabitReminder,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _habitReminderTime != null
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: colorScheme.outlineVariant, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.alarmClock,
                        size: 16,
                        color: _habitReminderTime != null
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _habitReminderTime != null
                            ? _habitReminderTime!.format(context)
                            : 'Reminder',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _habitReminderTime != null
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFreqOption(String key, String label, ColorScheme colorScheme) {
    final isSelected = _selectedFrequency == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFrequency = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCircle(int dayIndex, String label, ColorScheme colorScheme) {
    final isSelected = _selectedDaysOfWeek.contains(dayIndex);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            if (_selectedDaysOfWeek.length > 1) {
              _selectedDaysOfWeek.remove(dayIndex);
            }
          } else {
            _selectedDaysOfWeek.add(dayIndex);
          }
        });
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _categoryName(GoalCategory cat) {
    switch (cat) {
      case GoalCategory.health:
        return 'Health & Wellness';
      case GoalCategory.productivity:
        return 'Productivity';
      case GoalCategory.learning:
        return 'Learning & Academics';
      case GoalCategory.fitness:
        return 'Fitness & Sport';
      case GoalCategory.hobby:
        return 'Hobbies & Lifestyle';
    }
  }
}
