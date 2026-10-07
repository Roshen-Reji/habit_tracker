import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class JournalEditorPage extends StatefulWidget {
  final JournalEntry? initialEntry;

  const JournalEditorPage({super.key, this.initialEntry});

  @override
  State<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends State<JournalEditorPage> {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;

  late String _id;
  late bool _isPinned;
  late List<String> _tags;
  late DateTime _createdAt;
  String? _dayKey;
  String? _autoLogJson;
  String? _mergedInto;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
    _editorScrollController = ScrollController();

    if (widget.initialEntry != null) {
      final entry = widget.initialEntry!;
      _id = entry.id;
      _titleController = TextEditingController(text: entry.title);
      _isPinned = entry.pinned;
      _tags = List.from(entry.tags);
      _createdAt = entry.createdAt;
      _dayKey =
          entry.dayKey ?? DateFormat('yyyy-MM-dd').format(entry.createdAt);
      _autoLogJson = entry.autoLogJson;
      _mergedInto = entry.mergedInto;

      try {
        final deltaJson = jsonDecode(entry.bodyDelta);
        final doc = Document.fromJson(deltaJson);
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _quillController = QuillController.basic();
      }
    } else {
      final now = DateTime.now();
      _dayKey = DateFormat('yyyy-MM-dd').format(now);
      _id = 'day_$_dayKey';
      _titleController = TextEditingController(
          text: DateFormat('EEEE, d MMM yyyy').format(now));
      _isPinned = false;
      _tags = [];
      _createdAt = now;
      _autoLogJson = '[]';
      _quillController = QuillController.basic();
    }

    _titleController.addListener(_onChanged);
    _quillController.document.changes.listen((_) => _onChanged());
  }

  void _onChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _save();
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();

    // If completely empty and new, don't create an empty entry
    if (title.isEmpty && plainText.isEmpty && widget.initialEntry == null) {
      return;
    }

    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    final effectiveTitle = title.isNotEmpty
        ? title
        : (plainText.isNotEmpty
            ? (plainText.length > 30
                ? '${plainText.substring(0, 30)}...'
                : plainText)
            : 'Untitled Note');

    final entry = JournalEntry(
      id: _id,
      title: effectiveTitle,
      bodyDelta: deltaJson,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      pinned: _isPinned,
      tags: _tags,
      dayKey: _dayKey,
      autoLogJson: _autoLogJson,
      mergedInto: _mergedInto,
    );

    await JournalService.instance.saveEntry(entry);
    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
    }
  }

  void _addTagDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusDialog),
        ),
        title: Text(
          'Add Tag',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: BentoTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. reflection, project, idea',
            hintStyle: TextStyle(color: BentoTheme.textSecondary),
            filled: true,
            fillColor: BentoTheme.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: BentoTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BentoTheme.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final tag = textController.text.trim();
              if (tag.isNotEmpty && !_tags.contains(tag)) {
                setState(() {
                  _tags.add(tag);
                  _hasUnsavedChanges = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _save();
        }
      },
      child: Scaffold(
        backgroundColor: BentoTheme.background,
        appBar: AppBar(
          backgroundColor: BentoTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            widget.initialEntry != null ? 'EDIT JOURNAL' : 'NEW JOURNAL',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPinned ? LucideIcons.pin : LucideIcons.pinOff,
                color:
                    _isPinned ? Colors.amberAccent : BentoTheme.textSecondary,
                size: 20,
              ),
              tooltip: _isPinned ? 'Unpin' : 'Pin to top',
              onPressed: () {
                setState(() {
                  _isPinned = !_isPinned;
                  _hasUnsavedChanges = true;
                });
              },
            ),
            if (widget.initialEntry != null)
              IconButton(
                icon: const Icon(LucideIcons.trash2,
                    color: Colors.redAccent, size: 20),
                tooltip: 'Delete Journal',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: BentoTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            ExpressiveTokens.radiusDialog),
                      ),
                      title: Text(
                        'Delete Entry?',
                        style: TextStyle(color: BentoTheme.textPrimary),
                      ),
                      content: Text(
                        'Are you sure you want to permanently delete this journal entry?',
                        style: TextStyle(color: BentoTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style:
                                  TextStyle(color: BentoTheme.textSecondary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await JournalService.instance.deleteEntry(_id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            IconButton(
              icon: Icon(
                _hasUnsavedChanges ? LucideIcons.save : LucideIcons.check,
                color:
                    _hasUnsavedChanges ? BentoTheme.accent : Colors.greenAccent,
                size: 20,
              ),
              tooltip: 'Save',
              onPressed: () async {
                await _save();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Journal saved securely (AES-256)'),
                    backgroundColor: BentoTheme.surfaceElevated,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Expressive Toolbar
            Container(
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: QuillSimpleToolbar(
                  controller: _quillController,
                  config: const QuillSimpleToolbarConfig(
                    multiRowsDisplay: false,
                    showDividers: true,
                    showFontFamily: false,
                    showFontSize: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showInlineCode: true,
                    showLink: true,
                    showSearchButton: true,
                    showListCheck: true,
                    showCodeBlock: true,
                    showQuote: true,
                    showIndent: false,
                  ),
                ),
              ),
            ),

            // Content Area (Title + Tags + QuillEditor)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Entry Title...',
                        hintStyle: TextStyle(
                          color:
                              BentoTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tags row
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._tags.map(
                          (tag) => Chip(
                            label: Text(
                              '#$tag',
                              style: TextStyle(
                                color: BentoTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor:
                                BentoTheme.accent.withValues(alpha: 0.12),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            deleteIcon: Icon(LucideIcons.x,
                                size: 13, color: BentoTheme.accent),
                            onDeleted: () {
                              setState(() {
                                _tags.remove(tag);
                                _hasUnsavedChanges = true;
                              });
                            },
                          ),
                        ),
                        ActionChip(
                          avatar: Icon(LucideIcons.plus,
                              size: 13, color: BentoTheme.textSecondary),
                          label: Text(
                            'Add tag',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          backgroundColor: BentoTheme.surfaceElevated,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          onPressed: _addTagDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    const SizedBox(height: 12),

                    // Auto-Log Section (Read-only chips / Swipe or tap to remove)
                    _buildAutoLogSection(),

                    // Legacy Merge Banner (if unmerged entries exist for this day)
                    _buildLegacyMergeBanner(),

                    // Rich Text Editor Body
                    Expanded(
                      child: QuillEditor.basic(
                        controller: _quillController,
                        focusNode: _editorFocusNode,
                        scrollController: _editorScrollController,
                        config: QuillEditorConfig(
                          placeholder:
                              'Write your thoughts, reflections, or notes...',
                          padding: EdgeInsets.zero,
                          autoFocus: false,
                          expands: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoLogSection() {
    final entry = JournalEntry(
      id: _id,
      title: '',
      bodyDelta: '',
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      autoLogJson: _autoLogJson,
    );
    final events = JournalDayRepository.instance.getAutoLogs(entry);
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 13, color: BentoTheme.accent),
              const SizedBox(width: 6),
              Text(
                'AUTO-LOG',
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                'Tap × to remove',
                style: TextStyle(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: events.map((event) {
              return Chip(
                avatar: Icon(_getIconForKind(event.kind),
                    size: 14, color: BentoTheme.accent),
                label: Text(
                  event.text,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: BentoTheme.surfaceElevated,
                side: BorderSide.none,
                deleteIcon: Icon(LucideIcons.x,
                    size: 12, color: BentoTheme.textSecondary),
                onDeleted: () async {
                  if (_dayKey != null) {
                    await JournalDayRepository.instance
                        .removeAutoLog(_dayKey!, event.key);
                    final updatedEntry = await JournalDayRepository.instance
                        .getOrCreateDay(_dayKey!);
                    setState(() {
                      _autoLogJson = updatedEntry.autoLogJson;
                      _hasUnsavedChanges = true;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyMergeBanner() {
    if (_dayKey == null) return const SizedBox.shrink();
    final legacy = JournalDayRepository.instance.legacyEntriesFor(_dayKey!);
    if (legacy.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.gitMerge, color: Colors.amberAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${legacy.length} earlier entry${legacy.length > 1 ? 's' : ''} on this day',
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () async {
              await JournalDayRepository.instance.mergeLegacyEntries(_dayKey!);
              final updated =
                  await JournalDayRepository.instance.getOrCreateDay(_dayKey!);
              try {
                final deltaJson = jsonDecode(updated.bodyDelta);
                _quillController.document = Document.fromJson(deltaJson);
              } catch (e) {
                debugPrint('JournalEditorPage legacy Delta parse error: $e');
              }
              setState(() {
                _hasUnsavedChanges = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Entries merged into today’s document'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        await JournalDayRepository.instance
                            .undoMergeLegacyEntries(_dayKey!);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text('Merge',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForKind(String kind) {
    switch (kind) {
      case 'wake':
        return LucideIcons.sunMedium;
      case 'sleep':
        return LucideIcons.moon;
      case 'workout':
        return LucideIcons.dumbbell;
      case 'steps':
        return LucideIcons.footprints;
      case 'energy':
        return LucideIcons.zap;
      default:
        return LucideIcons.stickyNote;
    }
  }
}
