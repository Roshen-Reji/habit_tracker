import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/smart_scheduler_engine.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class TaskDetailSheet extends StatefulWidget {
  final TaskItem task;

  const TaskDetailSheet({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _estimateController;
  late TextEditingController _weightageController;
  late int _priority;
  DateTime? _dueAt;
  bool _hasDueTime = false;
  String? _courseId;
  late List<SubtaskItem> _subtasks;
  late List<String> _tags;
  String? _recurrenceRule;
  late String _recurrenceMode;

  final TextEditingController _newSubtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _estimateController = TextEditingController(
        text: (widget.task.estimateMin ?? 30).toString());
    _weightageController = TextEditingController(
        text: widget.task.weightage != null
            ? widget.task.weightage!.toStringAsFixed(0)
            : '');
    _priority = widget.task.priority;
    _dueAt = widget.task.dueAt;
    _hasDueTime = widget.task.hasDueTime;
    _courseId = widget.task.courseId;
    _subtasks = List.from(widget.task.subtasks);
    _tags = List.from(widget.task.tags);
    _recurrenceRule = widget.task.recurrenceRule;
    _recurrenceMode = widget.task.recurrenceMode;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _estimateController.dispose();
    _weightageController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  void _breakDownBigTask() {
    HapticFeedback.lightImpact();
    final due = _dueAt ?? DateTime.now().add(const Duration(days: 7));
    final est = int.tryParse(_estimateController.text) ?? 120;

    final proposed = SmartSchedulerEngine.proposeBackwardsMilestones(
      title: _titleController.text.trim(),
      estimateMin: est,
      dueAt: due,
    );

    setState(() {
      _subtasks.addAll(proposed);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Generated 4 backwards milestone subtasks'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addSubtask() {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _subtasks.add(SubtaskItem(
        id: 'sub_${DateTime.now().millisecondsSinceEpoch}_${_subtasks.length}',
        title: title,
        order: _subtasks.length,
      ));
      _newSubtaskController.clear();
    });
  }

  void _saveTask() async {
    final updated = widget.task.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.task.title
          : _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      priority: _priority,
      dueAt: _dueAt,
      hasDueTime: _hasDueTime,
      courseId: _courseId,
      estimateMin: int.tryParse(_estimateController.text) ?? 30,
      weightage: double.tryParse(_weightageController.text),
      subtasks: _subtasks,
      tags: _tags,
      recurrenceRule: _recurrenceRule,
      recurrenceMode: _recurrenceMode,
      updatedAt: DateTime.now(),
    );

    await TaskOsRepository.instance.saveTask(updated);
    if (mounted) Navigator.pop(context);
  }

  void _deleteTask() async {
    await TaskOsRepository.instance.deleteTask(widget.task.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: BentoTheme.divider),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BentoTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Task Title',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  color: Colors.redAccent,
                  onPressed: _deleteTask,
                ),
              ],
            ),
            const Divider(),
            // Priority Row
            Row(
              children: [
                Text(
                  'Priority: ',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 8),
                for (int p = 1; p <= 4; p++) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _priority = p);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priority == p
                            ? _priorityColor(p).withValues(alpha: 0.2)
                            : BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _priority == p
                              ? _priorityColor(p)
                              : BentoTheme.divider,
                        ),
                      ),
                      child: Text(
                        'P$p',
                        style: TextStyle(
                          color: _priority == p
                              ? _priorityColor(p)
                              : BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Estimate & Weightage inputs
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _estimateController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Estimate (min)',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      isDense: true,
                      filled: true,
                      fillColor: BentoTheme.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightageController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Grade Weight (%)',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      isDense: true,
                      filled: true,
                      fillColor: BentoTheme.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Subtasks Section Header & Big Task Breakdown Trigger
            Row(
              children: [
                Text(
                  'Subtasks (${_subtasks.length})',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // ⚡ Break Down Big Task button (PLAN-7)
                TactileButton(
                  onPressed: _breakDownBigTask,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: BentoTheme.accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles,
                            size: 12, color: BentoTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          '⚡ Break Down (PLAN-7)',
                          style: TextStyle(
                            color: BentoTheme.accent,
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
            const SizedBox(height: 8),
            // Subtask list
            for (int i = 0; i < _subtasks.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _subtasks[i] = _subtasks[i].copyWith(
                            isCompleted: !_subtasks[i].isCompleted,
                          );
                        });
                      },
                      child: Icon(
                        _subtasks[i].isCompleted
                            ? LucideIcons.checkSquare
                            : LucideIcons.square,
                        size: 16,
                        color: _subtasks[i].isCompleted
                            ? BentoTheme.accent
                            : BentoTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _subtasks[i].title,
                        style: TextStyle(
                          color: _subtasks[i].isCompleted
                              ? BentoTheme.textMuted
                              : BentoTheme.textPrimary,
                          decoration: _subtasks[i].isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _subtasks.removeAt(i));
                      },
                      child: Icon(LucideIcons.x,
                          size: 14, color: BentoTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
            // Add subtask input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubtaskController,
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a subtask...',
                      hintStyle: TextStyle(color: BentoTheme.textSecondary),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.plus, size: 16),
                  color: BentoTheme.accent,
                  onPressed: _addSubtask,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Notes input
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Notes (Markdown supported)',
                labelStyle: TextStyle(color: BentoTheme.textSecondary),
                filled: true,
                fillColor: BentoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Save button
            TactileButton(
              onPressed: _saveTask,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Save Task',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 1:
        return const Color(0xFFF43F5E);
      case 2:
        return const Color(0xFFFB923C);
      case 3:
        return const Color(0xFF38BDF8);
      default:
        return BentoTheme.textSecondary;
    }
  }
}
