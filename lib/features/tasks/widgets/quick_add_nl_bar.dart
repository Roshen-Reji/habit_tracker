import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/features/tasks/engine/native_task_ai_engine.dart';
import 'package:habit_tracker/features/tasks/widgets/task_action_pill.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/task_nl_parser.dart';
import 'package:habit_tracker/features/tasks/widgets/smart_scanner_sheet.dart';

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
    SmartScannerSheet.show(context);
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

/// Live Interactive Voice / Dictation Brain Dump Review Sheet (Zero Placeholders)
class _BrainDumpReviewSheet extends StatefulWidget {
  const _BrainDumpReviewSheet();

  @override
  State<_BrainDumpReviewSheet> createState() => _BrainDumpReviewSheetState();
}

class _BrainDumpReviewSheetState extends State<_BrainDumpReviewSheet> {
  final TextEditingController _voiceTextController = TextEditingController();
  bool _isExtracting = false;
  List<ExtractedTaskCandidate> _extractedTasks = [];
  final Set<int> _selectedIndices = {};

  void _extractTasks() async {
    final text = _voiceTextController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _extractedTasks = [];
        _selectedIndices.clear();
      });
      return;
    }

    setState(() => _isExtracting = true);
    HapticFeedback.lightImpact();

    try {
      final rawList = await AiService.instance.extractTasksWithAi(text);
      final candidates = rawList
          .map((m) => ExtractedTaskCandidate.fromMap(m))
          .where((c) => c.title.trim().isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _extractedTasks = candidates;
          _selectedIndices
            ..clear()
            ..addAll(List.generate(candidates.length, (i) => i));
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback to purely local native engine
        final fallback = NativeTaskAiEngine.extractTasksFromBrainDump(
          text,
          DateTime.now(),
        );
        setState(() {
          _extractedTasks = fallback;
          _selectedIndices
            ..clear()
            ..addAll(List.generate(fallback.length, (i) => i));
          _isExtracting = false;
        });
      }
    }
  }

  void _saveSelected() async {
    if (_selectedIndices.isEmpty) return;
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    int savedCount = 0;

    for (final idx in _selectedIndices) {
      if (idx < _extractedTasks.length) {
        final candidate = _extractedTasks[idx];
        final taskItem = candidate.toTaskItem(
          id: 'dump_${DateTime.now().millisecondsSinceEpoch}_$idx',
          now: now,
        );
        await TaskOsRepository.instance.saveTask(taskItem);
        savedCount++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Added $savedCount tasks from brain dump'),
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
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                  'Voice & Dictation Brain Dump',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _voiceTextController,
              maxLines: 3,
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'Speak or type anything freely (e.g., "Submit OS lab by Friday 5pm #OS !high, call IEEE team at 7pm ~30m, and review trees on Friday")...',
                hintStyle: TextStyle(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
                filled: true,
                fillColor: BentoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TaskActionPill(
                  label: _isExtracting ? 'Extracting...' : '✨ Extract Tasks',
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(LucideIcons.sparkles, size: 14),
                  isPrimary: true,
                  height: 36,
                  horizontalPadding: 14,
                  onTap: _isExtracting ? null : _extractTasks,
                ),
                if (_extractedTasks.isNotEmpty) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedIndices.length == _extractedTasks.length) {
                          _selectedIndices.clear();
                        } else {
                          _selectedIndices.addAll(
                              List.generate(_extractedTasks.length, (i) => i));
                        }
                      });
                    },
                    child: Text(
                      _selectedIndices.length == _extractedTasks.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_extractedTasks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Extracted Tasks (${_selectedIndices.length}/${_extractedTasks.length} selected):',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _extractedTasks.length,
                  itemBuilder: (ctx, idx) {
                    final task = _extractedTasks[idx];
                    final isSelected = _selectedIndices.contains(idx);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _selectedIndices.remove(idx);
                          } else {
                            _selectedIndices.add(idx);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? BentoTheme.accent.withValues(alpha: 0.12)
                              : BentoTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? BentoTheme.accent
                                : BentoTheme.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? LucideIcons.checkSquare
                                  : LucideIcons.square,
                              size: 16,
                              color: isSelected
                                  ? BentoTheme.accent
                                  : BentoTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      color: BentoTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (task.courseCode != null)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.purple
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '#${task.courseCode}',
                                            style: const TextStyle(
                                              color: Colors.purpleAccent,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (task.dueAt != null)
                                        Text(
                                          'Due: ${task.dueAt!.day}/${task.dueAt!.month}',
                                          style: TextStyle(
                                            color: BentoTheme.accent,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(task.confidence * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              TaskActionPill(
                label: 'Add Selected (${_selectedIndices.length}) Tasks',
                isPrimary: true,
                height: 42,
                horizontalPadding: 16,
                borderRadius: 12,
                onTap: _selectedIndices.isEmpty ? null : _saveSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live Syllabus / Noticeboard Document & Photo Scanner Sheet (Zero Placeholders)
class _SyllabusImportSheet extends StatefulWidget {
  const _SyllabusImportSheet();

  @override
  State<_SyllabusImportSheet> createState() => _SyllabusImportSheetState();
}

class _SyllabusImportSheetState extends State<_SyllabusImportSheet> {
  final TextEditingController _documentTextController = TextEditingController();
  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  bool _isExtracting = false;
  List<ExtractedTaskCandidate> _extractedTasks = [];
  final Set<int> _selectedIndices = {};

  void _pickDocument() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'md'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _pickedFileName = file.name;
        _pickedFileBytes = file.bytes;
      });

      // If text or markdown, load into controller
      if (file.extension == 'txt' || file.extension == 'md') {
        if (file.bytes != null) {
          try {
            _documentTextController.text = utf8.decode(file.bytes!);
          } catch (_) {}
        }
      }

      // Automatically trigger extraction
      _extractDeadlines();
    }
  }

  void _extractDeadlines() async {
    final text = _documentTextController.text.trim();
    if (text.isEmpty && (_pickedFileBytes == null || _pickedFileBytes!.isEmpty)) {
      return;
    }

    setState(() => _isExtracting = true);
    HapticFeedback.lightImpact();

    String? mimeType;
    if (_pickedFileName != null) {
      final ext = _pickedFileName!.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        mimeType = 'application/pdf';
      } else if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        mimeType = 'image/jpeg';
      }
    }

    try {
      final rawList = await AiService.instance.extractTasksWithAi(
        text.isNotEmpty
            ? text
            : 'Please scan and extract all syllabus deadlines from this file.',
        imageBytes: _pickedFileBytes,
        mimeType: mimeType,
      );

      final candidates = rawList
          .map((m) => ExtractedTaskCandidate.fromMap(m))
          .where((c) => c.title.trim().isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _extractedTasks = candidates;
          _selectedIndices
            ..clear()
            ..addAll(List.generate(candidates.length, (i) => i));
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final fallback = NativeTaskAiEngine.extractTasksFromDocumentText(
          text,
          DateTime.now(),
        );
        setState(() {
          _extractedTasks = fallback;
          _selectedIndices
            ..clear()
            ..addAll(List.generate(fallback.length, (i) => i));
          _isExtracting = false;
        });
      }
    }
  }

  void _confirmImport() async {
    if (_selectedIndices.isEmpty) return;
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    int importedCount = 0;

    for (final idx in _selectedIndices) {
      if (idx < _extractedTasks.length) {
        final candidate = _extractedTasks[idx];
        final taskItem = candidate.toTaskItem(
          id: 'syl_${DateTime.now().millisecondsSinceEpoch}_$idx',
          now: now,
        );
        await TaskOsRepository.instance.saveTask(taskItem);
        importedCount++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Imported $importedCount deadlines into Tasks'),
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
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                  'Syllabus & Document Scanner',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // File picker trigger
            PressScale(
              onTap: _pickDocument,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pickedFileName != null
                        ? BentoTheme.accent
                        : BentoTheme.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickedFileName != null
                          ? LucideIcons.fileCheck
                          : LucideIcons.uploadCloud,
                      size: 18,
                      color: _pickedFileName != null
                          ? BentoTheme.accent
                          : BentoTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedFileName ??
                            'Pick PDF / Syllabus Image / Noticeboard text',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _pickedFileName != null
                              ? BentoTheme.textPrimary
                              : BentoTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: _pickedFileName != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Browse',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _documentTextController,
              maxLines: 3,
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'Or paste syllabus text, exam schedules, or assignment notices here...',
                hintStyle: TextStyle(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
                filled: true,
                fillColor: BentoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TaskActionPill(
                  label: _isExtracting ? 'Scanning...' : '✨ Scan & Extract',
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(LucideIcons.scanLine, size: 14),
                  isPrimary: true,
                  height: 36,
                  horizontalPadding: 14,
                  onTap: _isExtracting ? null : _extractDeadlines,
                ),
                if (_extractedTasks.isNotEmpty) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedIndices.length == _extractedTasks.length) {
                          _selectedIndices.clear();
                        } else {
                          _selectedIndices.addAll(
                              List.generate(_extractedTasks.length, (i) => i));
                        }
                      });
                    },
                    child: Text(
                      _selectedIndices.length == _extractedTasks.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_extractedTasks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Extracted Deadlines (${_selectedIndices.length}/${_extractedTasks.length} selected):',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _extractedTasks.length,
                  itemBuilder: (ctx, idx) {
                    final item = _extractedTasks[idx];
                    final isSelected = _selectedIndices.contains(idx);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _selectedIndices.remove(idx);
                          } else {
                            _selectedIndices.add(idx);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? BentoTheme.accent.withValues(alpha: 0.12)
                              : BentoTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? BentoTheme.accent
                                : BentoTheme.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? LucideIcons.checkSquare
                                  : LucideIcons.square,
                              size: 16,
                              color: isSelected
                                  ? BentoTheme.accent
                                  : BentoTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      color: BentoTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (item.courseCode != null)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.purple
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '#${item.courseCode}',
                                            style: const TextStyle(
                                              color: Colors.purpleAccent,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (item.dueAt != null)
                                        Text(
                                          'Due: ${item.dueAt!.day}/${item.dueAt!.month}/${item.dueAt!.year}',
                                          style: TextStyle(
                                            color: BentoTheme.accent,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(item.confidence * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              TaskActionPill(
                label:
                    'Import Selected (${_selectedIndices.length}) Deadlines',
                isPrimary: true,
                height: 42,
                horizontalPadding: 16,
                borderRadius: 12,
                onTap: _selectedIndices.isEmpty ? null : _confirmImport,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
