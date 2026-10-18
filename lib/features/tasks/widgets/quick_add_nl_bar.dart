import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/tasks/widgets/task_action_pill.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/task_nl_parser.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class QuickAddNlBar extends StatefulWidget {
  final VoidCallback? onTaskAdded;

  const QuickAddNlBar({
    super.key,
    this.onTaskAdded,
  });

  @override
  State<QuickAddNlBar> createState() => _QuickAddNlBarState();
}

class _QuickAddNlBarState extends State<QuickAddNlBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ParsedTaskInput? _currentParsed;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      if (_currentParsed != null) {
        setState(() => _currentParsed = null);
      }
      return;
    }

    final parsed = parseNaturalLanguageTask(text, DateTime.now());
    setState(() => _currentParsed = parsed);
  }

  void _submitTask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parsed = _currentParsed ?? parseNaturalLanguageTask(text, DateTime.now());
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final taskItem = parsed.toTaskItem(id: taskId);

    await TaskOsRepository.instance.saveTask(taskItem);
    HapticFeedback.lightImpact();

    widget.onTaskAdded?.call();

    // Show 5-second Undo snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${taskItem.title}"'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: BentoTheme.accent,
            onPressed: () {
              TaskOsRepository.instance.deleteTask(taskId, permanent: true);
            },
          ),
        ),
      );
    }

    // Rapid-fire mode (CAP-1): Keep field open & focused for next task
    _controller.clear();
    setState(() => _currentParsed = null);
    _focusNode.requestFocus();
  }

  void _removeChip(ParsedChip chip) {
    HapticFeedback.selectionClick();
    // Restore the raw token to the end of the text field
    final curText = _controller.text;
    _controller.text = '$curText ${chip.rawToken}'.trim();
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  void _openBrainDumpModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _BrainDumpReviewSheet(),
    );
  }

  void _openSyllabusImportModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SyllabusImportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = _currentParsed?.chips ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Live token chips strip with AnimatedSize and fluid spring physics
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: const Cubic(0.22, 1.0, 0.36, 1.0),
            child: chips.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var chip in chips) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: _chipColor(chip.type)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _chipColor(chip.type)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_chipIcon(chip.type),
                                      size: 11, color: _chipColor(chip.type)),
                                  const SizedBox(width: 4),
                                  Text(
                                    chip.label,
                                    style: TextStyle(
                                      color: _chipColor(chip.type),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _removeChip(chip),
                                    child: Icon(
                                      LucideIcons.x,
                                      size: 12,
                                      color: _chipColor(chip.type)
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          // Unified Single-Row Dock (height: 52px)
          Container(
            height: 52,
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF262626)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Voice brain dump trigger (32x32)
                IconButton(
                  icon: const Icon(Icons.mic_none_rounded, size: 18),
                  color: const Color(0xFF8E8E93),
                  tooltip: 'Voice Brain Dump',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _openBrainDumpModal,
                ),
                // Syllabus / Photo scanner trigger (32x32)
                IconButton(
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  color: const Color(0xFF8E8E93),
                  tooltip: 'Syllabus / Photo Import',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _openSyllabusImportModal,
                ),
                const SizedBox(width: 6),
                // Borderless TextField
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitTask(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Quick add task...',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Circular 34x34 White Submit Button
                PressScale(
                  onTap: _submitTask,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }

  Color _chipColor(ChipType type) {
    switch (type) {
      case ChipType.date:
      case ChipType.time:
        return const Color(0xFF38BDF8); // Sky blue
      case ChipType.priority:
        return const Color(0xFFF43F5E); // Rose
      case ChipType.course:
        return const Color(0xFFA855F7); // Purple
      case ChipType.tag:
        return const Color(0xFF10B981); // Emerald
      case ChipType.duration:
        return const Color(0xFFF59E0B); // Amber
      case ChipType.recurrence:
        return const Color(0xFFEC4899); // Pink
      case ChipType.reminder:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  IconData _chipIcon(ChipType type) {
    switch (type) {
      case ChipType.date:
        return LucideIcons.calendar;
      case ChipType.time:
        return LucideIcons.clock;
      case ChipType.priority:
        return LucideIcons.alertCircle;
      case ChipType.course:
        return LucideIcons.hash;
      case ChipType.tag:
        return LucideIcons.tag;
      case ChipType.duration:
        return LucideIcons.hourglass;
      case ChipType.recurrence:
        return LucideIcons.repeat;
      case ChipType.reminder:
        return LucideIcons.bell;
    }
  }
}

/// Modal review sheet for Voice Brain Dump (CAP-4)
class _BrainDumpReviewSheet extends StatefulWidget {
  const _BrainDumpReviewSheet();

  @override
  State<_BrainDumpReviewSheet> createState() => _BrainDumpReviewSheetState();
}

class _BrainDumpReviewSheetState extends State<_BrainDumpReviewSheet> {
  final TextEditingController _voiceTextController = TextEditingController(
    text:
        'Finish Operating Systems assignment by Friday 5pm, review DBMS chapter 4 tomorrow morning, and buy notebook',
  );

  List<TaskItem> _extractedTasks = [];

  @override
  void initState() {
    super.initState();
    _extractTasks();
  }

  void _extractTasks() {
    final raw = _voiceTextController.text;
    final parts = raw.split(RegExp(r',|and\s+'));
    final now = DateTime.now();
    final list = <TaskItem>[];

    for (var p in parts) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      final parsed = parseNaturalLanguageTask(trimmed, now);
      list.add(parsed.toTaskItem(
        id: 'dump_${DateTime.now().millisecondsSinceEpoch}_${list.length}',
        now: now,
      ));
    }
    setState(() => _extractedTasks = list);
  }

  void _saveAll() async {
    for (var task in _extractedTasks) {
      await TaskOsRepository.instance.saveTask(task);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_extractedTasks.length} tasks from brain dump'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: BentoTheme.divider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              Icon(LucideIcons.mic, color: BentoTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Voice Brain Dump Review',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _voiceTextController,
            maxLines: 2,
            style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: BentoTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _extractTasks(),
          ),
          const SizedBox(height: 12),
          Text(
            'Proposed Tasks (${_extractedTasks.length}):',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _extractedTasks.length,
              itemBuilder: (ctx, idx) {
                final task = _extractedTasks[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BentoTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.checkCircle2, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (task.dueAt != null)
                        Text(
                          'Due in ${task.dueAt!.difference(DateTime.now()).inDays}d',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TaskActionPill(
            label: 'Confirm & Add ${_extractedTasks.length} Tasks',
            isPrimary: true,
            height: 44,
            horizontalPadding: 16,
            borderRadius: 12,
            onTap: _saveAll,
          ),
        ],
      ),
    );
  }
}

/// Modal review sheet for Syllabus / Photo scanner (CAP-6/7)
class _SyllabusImportSheet extends StatefulWidget {
  const _SyllabusImportSheet();

  @override
  State<_SyllabusImportSheet> createState() => _SyllabusImportSheetState();
}

class _SyllabusImportSheetState extends State<_SyllabusImportSheet> {
  final List<Map<String, dynamic>> _extractedItems = [
    {
      'title': 'Midterm Exam - Software Engineering',
      'type': 'Exam',
      'date': 'Nov 12',
      'confidence': 'High',
    },
    {
      'title': 'Lab Assignment 3: Distributed Hash Table',
      'type': 'Assignment',
      'date': 'Oct 28',
      'confidence': 'High',
    },
    {
      'title': 'Project Proposal & Literature Survey',
      'type': 'Milestone',
      'date': 'Nov 04',
      'confidence': 'Needs Review',
    },
  ];

  void _confirmImport() async {
    final now = DateTime.now();
    for (var item in _extractedItems) {
      final task = TaskItem(
        id: 'syl_${DateTime.now().millisecondsSinceEpoch}_${item['title'].hashCode}',
        title: item['title'].toString(),
        priority: TaskPriority.high,
        status: TaskStatus.todo,
        dueAt: now.add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      );
      await TaskOsRepository.instance.saveTask(task);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${_extractedItems.length} syllabus deadlines'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: BentoTheme.divider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              Icon(LucideIcons.fileSearch, color: BentoTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Syllabus / Photo Import',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Extracted Dates & Deadlines for Review:',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (var item in _extractedItems) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item['type']} · Expected Due: ${item['date']}',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: item['confidence'] == 'High'
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['confidence']!,
                      style: TextStyle(
                        color: item['confidence'] == 'High'
                            ? Colors.green
                            : Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TaskActionPill(
            label: 'Confirm & Import ${_extractedItems.length} Deadlines',
            isPrimary: true,
            height: 44,
            horizontalPadding: 16,
            borderRadius: 12,
            onTap: _confirmImport,
          ),
        ],
      ),
    );
  }
}
