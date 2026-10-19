import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/models/scanner_models.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

/// Context-Aware Digital Scanner & Smart Auto-Router Sheet.
///
/// Features:
/// 1. File (PDF, image, text) & pasted text input.
/// 2. Context Filter input (e.g. "CS S3") persisted in user settings.
/// 3. Local on-device text extraction via [ReaderService] before AI parsing.
/// 4. Auto-detection of document category (Timetable, Syllabus, Exam Schedule, Expenses).
/// 5. High-contrast review list with pre-selected matching items and manual override checkboxes.
/// 6. Automatic routing to Timetable, Courses, Tasks, or Finance repositories.
class SmartScannerSheet extends StatefulWidget {
  final String? initialContextFilter;

  const SmartScannerSheet({
    super.key,
    this.initialContextFilter,
  });

  static Future<void> show(BuildContext context, {String? initialFilter}) {
    HapticFeedback.lightImpact();
    return SpringSheet.show(
      context: context,
      builder: (ctx) => SmartScannerSheet(initialContextFilter: initialFilter),
    );
  }

  @override
  State<SmartScannerSheet> createState() => _SmartScannerSheetState();
}

class _SmartScannerSheetState extends State<SmartScannerSheet> {
  final TextEditingController _textController = TextEditingController();
  late final TextEditingController _contextFilterController;

  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  String? _pickedFilePath;

  bool _isProcessing = false;
  ScannedDocumentResult? _scanResult;
  bool _filterRelevantOnly = true;

  @override
  void initState() {
    super.initState();
    String defaultFilter = widget.initialContextFilter ?? '';
    if (defaultFilter.isEmpty && Hive.isBoxOpen('settings')) {
      defaultFilter = Hive.box('settings')
          .get('academic_context_filter', defaultValue: 'CS S3')
          .toString();
    }
    if (defaultFilter.isEmpty) defaultFilter = 'CS S3';
    _contextFilterController = TextEditingController(text: defaultFilter);
  }

  @override
  void dispose() {
    _textController.dispose();
    _contextFilterController.dispose();
    super.dispose();
  }

  void _saveContextFilter(String value) {
    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').put('academic_context_filter', value.trim());
    }
  }

  Future<void> _pickFile() async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'md'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    setState(() {
      _pickedFileName = file.name;
      _pickedFileBytes = file.bytes;
      _pickedFilePath = file.path;
      _scanResult = null;
    });

    // Try extracting local text immediately
    if (file.extension == 'pdf') {
      _isProcessing = true;
      setState(() {});
      try {
        final localText = await ReaderService.extractTextFromPdf(
          _pickedFilePath ?? _pickedFileBytes,
        );
        if (localText.isNotEmpty) {
          _textController.text = localText;
        }
      } catch (e) {
        debugPrint('PDF text extract error: $e');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else if (file.extension == 'txt' || file.extension == 'md') {
      if (file.bytes != null) {
        try {
          _textController.text = utf8.decode(file.bytes!);
        } catch (_) {}
      } else if (file.path != null) {
        try {
          _textController.text = await File(file.path!).readAsString();
        } catch (_) {}
      }
    }
  }

  Future<void> _runScanPipeline() async {
    final text = _textController.text.trim();
    if (text.isEmpty &&
        (_pickedFileBytes == null || _pickedFileBytes!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file or paste document text'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    final filter = _contextFilterController.text.trim();
    _saveContextFilter(filter);

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
      final result = await AiService.instance.parseDocumentWithFilter(
        rawText: text,
        contextFilter: filter,
        imageBytes: _pickedFileBytes,
        mimeType: mimeType,
      );

      if (mounted) {
        setState(() {
          _scanResult = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _overrideAllDestinations(String newModule) {
    if (_scanResult == null) return;
    setState(() {
      for (var item in _scanResult!.items) {
        item.targetModule = newModule;
      }
    });
  }

  void _confirmImport() async {
    if (_scanResult == null) return;
    final selectedItems =
        _scanResult!.items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items selected for import'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    int timetableCount = 0;
    int courseCount = 0;
    int taskCount = 0;
    int financeCount = 0;

    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      final uniqueSuffix = '${DateTime.now().millisecondsSinceEpoch}_$i';

      switch (item.targetModule) {
        case 'timetable':
          final startM = item.startMinutes ?? 540;
          final durM = item.durationMinutes ?? 50;
          final slot = TimetableSlotItem(
            id: 'slot_$uniqueSuffix',
            courseId: item.code ?? item.title,
            dayOfWeek: item.dayOfWeek ?? 1,
            startMinutes: startM,
            endMinutes: startM + durM,
            room: item.venue,
            batch: item.slot,
          );
          await TaskOsRepository.instance.saveTimetableSlot(slot);
          timetableCount++;
          break;

        case 'course':
          final now = DateTime.now();
          final course = CourseItem(
            id: item.code ?? 'crs_$uniqueSuffix',
            name: item.title,
            code: item.code ?? '',
            credits: (item.credits != null) ? item.credits!.toDouble() : 3.0,
            colorHex: '#5CE1E6',
            createdAt: now,
            updatedAt: now,
          );
          await TaskOsRepository.instance.saveCourse(course);
          courseCount++;
          break;

        case 'finance':
          if (item.amount != null && item.amount! > 0) {
            final now = DateTime.now();
            final date = item.dateStr != null
                ? (DateTime.tryParse(item.dateStr!) ?? now)
                : now;
            await FinanceRepository().addTransaction(
              TxDraft(
                title: item.title,
                amount: item.amount!,
                category: item.category ?? 'Academics',
                date: date,
                mode: 'expense',
                kind: 'expense',
              ),
            );
            financeCount++;
          }
          break;

        case 'task':
        default:
          final now = DateTime.now();
          final task = TaskItem(
            id: 'scan_task_$uniqueSuffix',
            title: item.title,
            isHabit: false,
            dueAt: item.dateStr != null
                ? (DateTime.tryParse(item.dateStr!) ?? now)
                : now,
            courseId: item.code,
            priority: TaskPriority.high,
            estimateMin: 45,
            status: TaskStatus.todo,
            notes: item.subtitle,
            createdAt: now,
            updatedAt: now,
          );
          await TaskOsRepository.instance.saveTask(task);
          taskCount++;
          break;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      final parts = <String>[
        if (timetableCount > 0) '$timetableCount Timetable Slots',
        if (courseCount > 0) '$courseCount Courses',
        if (taskCount > 0) '$taskCount Tasks',
        if (financeCount > 0) '$financeCount Expenses',
      ];
      final summary = parts.isNotEmpty ? parts.join(', ') : 'Items imported';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported: $summary'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header title
            Row(
              children: [
                Icon(Icons.document_scanner_rounded,
                    color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Context-Aware Digital Scanner',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main body: Input view vs Review view
            Expanded(
              child: _scanResult == null
                  ? _buildInputStage(colorScheme)
                  : _buildReviewStage(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputStage(ColorScheme colorScheme) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Context Filter Field
        Text(
          'USER CONTEXT FILTER (ACADEMIC PROFILE)',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _contextFilterController,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. CS S3, Semester 3 CSE, Batch A',
            hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            prefixIcon: Icon(Icons.filter_alt_rounded,
                size: 18, color: colorScheme.primary),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          onChanged: _saveContextFilter,
        ),
        const SizedBox(height: 14),

        // 2. File / Image Picker Button
        Text(
          'SELECT DOCUMENT OR IMAGE',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        PressScale(
          onTap: _pickFile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pickedFileName != null
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _pickedFileName != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: _pickedFileName != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pickedFileName ?? 'Choose Timetable / Syllabus PDF or Image',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _pickedFileName != null
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Supports PDF text-layer extraction, photos & receipts',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Or Paste Raw Text
        Text(
          'OR PASTE RAW TEXT',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _textController,
          maxLines: 4,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Paste timetable slots, courses, exam dates, or expense items...',
            hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Scan CTA
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _isProcessing ? null : _runScanPipeline,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isProcessing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Scan & Context Filter',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStage(ColorScheme colorScheme) {
    final result = _scanResult!;
    final displayedItems = _filterRelevantOnly
        ? result.items.where((i) => i.isRelevant).toList()
        : result.items;

    final selectedCount = result.selectedCount;

    return Column(
      children: [
        // Destination Badge & Override Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.route_rounded,
                  color: colorScheme.onPrimaryContainer, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Auto-Routing to: ${result.detectedDestination}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.tune_rounded,
                    color: colorScheme.onPrimaryContainer, size: 18),
                tooltip: 'Change Destination',
                onSelected: _overrideAllDestinations,
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                      value: 'timetable', child: Text('Route to: Timetable')),
                  PopupMenuItem(
                      value: 'course', child: Text('Route to: Courses')),
                  PopupMenuItem(
                      value: 'task', child: Text('Route to: One-Time Tasks')),
                  PopupMenuItem(
                      value: 'finance', child: Text('Route to: Transactions')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Filter / Selection Toolbar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildReviewPill(
                label: 'Relevant Only (${result.relevantCount})',
                isActive: _filterRelevantOnly,
                onTap: () => setState(() => _filterRelevantOnly = true),
                colorScheme: colorScheme,
              ),
              _buildReviewPill(
                label: 'Show All (${result.items.length})',
                isActive: !_filterRelevantOnly,
                onTap: () => setState(() => _filterRelevantOnly = false),
                colorScheme: colorScheme,
              ),
              _buildReviewPill(
                label: 'Select All',
                isActive: false,
                onTap: () => setState(() {
                  for (var i in result.items) {
                    i.isSelected = true;
                  }
                }),
                colorScheme: colorScheme,
              ),
              _buildReviewPill(
                label: 'Deselect All',
                isActive: false,
                onTap: () => setState(() {
                  for (var i in result.items) {
                    i.isSelected = false;
                  }
                }),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Review Items List
        Expanded(
          child: displayedItems.isEmpty
              ? Center(
                  child: Text(
                    'No items match your filter.\nTap "Show All" to see everything extracted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayedItems.length,
                  itemBuilder: (ctx, idx) {
                    final item = displayedItems[idx];
                    return _buildReviewTile(item, colorScheme);
                  },
                ),
        ),
        const SizedBox(height: 10),

        // Bottom Actions: Re-scan / Import Selected
        Row(
          children: [
            TactileButton(
              onPressed: () => setState(() => _scanResult = null),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isProcessing || selectedCount == 0
                      ? null
                      : _confirmImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          'Import Selected ($selectedCount)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isActive ? colorScheme.primary : colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewTile(ScannedExtractItem item, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: item.isSelected
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSelected
              ? colorScheme.outlineVariant
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: CheckboxListTile(
        value: item.isSelected,
        activeColor: colorScheme.primary,
        checkColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onChanged: (val) {
          HapticFeedback.selectionClick();
          setState(() => item.isSelected = val ?? false);
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (item.isRelevant) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.matchedContextTag ?? 'Match',
                  style: TextStyle(
                    color: colorScheme.onTertiaryContainer,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.subtitle.isNotEmpty)
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.targetModule.toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _editItemDialog(item),
                  child: Icon(Icons.edit_outlined,
                      size: 15, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editItemDialog(ScannedExtractItem item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final subtitleCtrl = TextEditingController(text: item.subtitle);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Extracted Row'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subtitleCtrl,
              decoration: const InputDecoration(labelText: 'Details / Subtitle'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        item.title = titleCtrl.text.trim();
        item.subtitle = subtitleCtrl.text.trim();
      });
    }
  }
}
