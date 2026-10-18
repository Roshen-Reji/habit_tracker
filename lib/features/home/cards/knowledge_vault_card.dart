import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/reader/pdf_reader_page.dart';
import 'package:habit_tracker/features/reader/reader_library_page.dart';
import 'package:habit_tracker/features/speech_vault/speech_vault_page.dart';
import 'package:habit_tracker/models/speech_model.dart';

enum KnowledgeVaultMode {
  books,
  speeches,
}

/// Fallback quotes/speeches when the Hive box is empty.
class _VaultSpeechItem {
  final String title;
  final String speaker;
  final String category;
  final String previewText;
  final String? youtubeVideoId;

  const _VaultSpeechItem({
    required this.title,
    required this.speaker,
    required this.category,
    required this.previewText,
    this.youtubeVideoId,
  });
}

class KnowledgeVaultCard extends StatefulWidget {
  final HomeCardSize size;

  const KnowledgeVaultCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  State<KnowledgeVaultCard> createState() => _KnowledgeVaultCardState();
}

class _KnowledgeVaultCardState extends State<KnowledgeVaultCard> {
  KnowledgeVaultMode _mode = KnowledgeVaultMode.books;
  List<PdfBook> _books = [];
  bool _isLoadingBooks = true;
  int _activeSpeechIndex = 0;
  int _selectedBookIndex = 0;

  static const List<_VaultSpeechItem> _fallbackSpeeches = [
    _VaultSpeechItem(
      title: 'The Psychology of Self-Motivation',
      speaker: 'Scott Geller',
      category: 'Psychology',
      previewText:
          'When you believe you can do it, have the autonomy to choose, and feel community support, you unlock true internal self-motivation.',
      youtubeVideoId: '7sxpKhIbr0E',
    ),
    _VaultSpeechItem(
      title: 'Stay Hungry, Stay Foolish',
      speaker: 'Steve Jobs',
      category: 'Life & Mindset',
      previewText:
          'Your time is limited, so don’t waste it living someone else’s life. Don’t be trapped by dogma — which is living with the results of other people’s thinking.',
      youtubeVideoId: 'UF8uR6Z6KLc',
    ),
    _VaultSpeechItem(
      title: 'Make Your Bed (Change the World)',
      speaker: 'Adm. William McRaven',
      category: 'Discipline',
      previewText:
          'If you want to change the world, start by making your bed. Completing the first task of the day gives you pride to complete another and another.',
      youtubeVideoId: 'TBuIGBCF9jc',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      final books = await ReaderService.scanConfiguredFolders();
      if (mounted) {
        setState(() {
          _books = books;
          _isLoadingBooks = false;
          if (_selectedBookIndex >= _books.length) {
            _selectedBookIndex = 0;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBooks = false);
    }
  }

  Future<void> _importPdf() async {
    HapticFeedback.lightImpact();
    try {
      final book = await ReaderService.importPdfFromPicker();
      if (book != null && mounted) {
        await _loadBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "${book.name}" successfully'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import PDF: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openReader(PdfBook book) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageTransitions.containerTransform(
        PdfReaderPage(book: book),
      ),
    ).then((_) => _loadBooks());
  }

  void _openFullLibrary() {
    HapticFeedback.selectionClick();
    if (_mode == KnowledgeVaultMode.books) {
      Navigator.push(
        context,
        PageTransitions.containerTransform(const ReaderLibraryPage()),
      ).then((_) => _loadBooks());
    } else {
      Navigator.push(
        context,
        PageTransitions.containerTransform(const SpeechVaultPage()),
      );
    }
  }

  List<_VaultSpeechItem> _getSpeechItems() {
    if (Hive.isBoxOpen('speech_vault')) {
      final box = Hive.box<SpeechModel>('speech_vault');
      if (box.isNotEmpty) {
        return box.values.map((s) {
          return _VaultSpeechItem(
            title: s.title,
            speaker: s.speaker,
            category: s.durationLabel.isNotEmpty ? s.durationLabel : 'Speech',
            previewText:
                'Intelligence entry from ${s.speaker}. Open to watch video and read insights.',
            youtubeVideoId: s.youtubeVideoId,
          );
        }).toList();
      }
    }
    return _fallbackSpeeches;
  }

  void _cycleSpeech(int delta) {
    final items = _getSpeechItems();
    if (items.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeSpeechIndex = (_activeSpeechIndex + delta) % items.length;
      if (_activeSpeechIndex < 0) {
        _activeSpeechIndex += items.length;
      }
    });
  }

  void _showAddSpeechModal() {
    HapticFeedback.lightImpact();
    final titleController = TextEditingController();
    final speakerController = TextEditingController();
    final linkController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
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
                  Icon(LucideIcons.sparkles,
                      size: 20, color: BentoTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Add Knowledge Item',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: BentoTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Title or Concept',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: speakerController,
                style: TextStyle(color: BentoTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Author or Speaker',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkController,
                style: TextStyle(color: BentoTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'YouTube / Note Link (Optional)',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TactileButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  final speaker = speakerController.text.trim().isEmpty
                      ? 'Self-Added'
                      : speakerController.text.trim();
                  final link = linkController.text.trim();

                  if (Hive.isBoxOpen('speech_vault')) {
                    final box = Hive.box<SpeechModel>('speech_vault');
                    final id = 'vault_${DateTime.now().millisecondsSinceEpoch}';
                    box.add(SpeechModel(
                      id: id,
                      title: title,
                      speaker: speaker,
                      youtubeVideoId: link.isNotEmpty ? link : '',
                      thumbnailUrl: '',
                      durationLabel: 'Note',
                    ));
                  }
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to Knowledge Vault'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Save to Vault',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReadFullModal(_VaultSpeechItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: BentoTheme.divider),
        ),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: TextStyle(
                      color: BentoTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: BentoTheme.textSecondary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'by ${item.speaker}',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: Text(
                item.previewText,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (item.youtubeVideoId != null &&
                item.youtubeVideoId!.isNotEmpty) ...[
              TactileButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SamsungVideoAssistant(
                        speech: SpeechModel(
                          id: item.youtubeVideoId!,
                          title: item.title,
                          speaker: item.speaker,
                          youtubeVideoId: item.youtubeVideoId!,
                          thumbnailUrl:
                              'https://img.youtube.com/vi/${item.youtubeVideoId}/hqdefault.jpg',
                          durationLabel: item.category,
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.play, color: Colors.black, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Watch Video / Transcript',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              TactileButton(
                onPressed: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;

    Widget cardContent;
    if (_mode == KnowledgeVaultMode.books) {
      cardContent = _buildBooksBody(context);
    } else {
      cardContent = _buildSpeechesBody(context);
    }

    return HomeCardFrame(
      domain: HomeCardDomain.editorial,
      icon: Icons.auto_stories_rounded,
      title: 'Knowledge Vault',
      accentColor: accent,
      onTap: _openFullLibrary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Inline Segmented Pill Toggle: Books | Speeches
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: BentoTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BentoTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentPill(
                  label: 'Books',
                  icon: LucideIcons.bookOpen,
                  isActive: _mode == KnowledgeVaultMode.books,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _mode = KnowledgeVaultMode.books);
                  },
                ),
                _buildSegmentPill(
                  label: 'Speeches',
                  icon: LucideIcons.flame,
                  isActive: _mode == KnowledgeVaultMode.speeches,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _mode = KnowledgeVaultMode.speeches);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Expand IconButton: Opens full Reader or SpeechVault
          IconButton(
            icon: const Icon(LucideIcons.maximize2, size: 16),
            color: BentoTheme.textSecondary,
            tooltip: 'Expand Library',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _openFullLibrary,
          ),
        ],
      ),
      child: cardContent,
    );
  }

  Widget _buildSegmentPill({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? BentoTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isActive ? Colors.black : BentoTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.black : BentoTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooksBody(BuildContext context) {
    if (_isLoadingBooks) {
      return SizedBox(
        height: 130,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: BentoTheme.accent,
          ),
        ),
      );
    }

    if (_books.isEmpty) {
      return SizedBox(
        height: 130,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.bookOpen, size: 28, color: BentoTheme.textMuted),
            const SizedBox(height: 8),
            Text(
              'No PDF documents found',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TactileButton(
              onPressed: _importPdf,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: BentoTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: BentoTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14, color: BentoTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Import PDF',
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
          ],
        ),
      );
    }

    final activeBook = _selectedBookIndex < _books.length
        ? _books[_selectedBookIndex]
        : _books.first;
    final otherBooks = _books
        .asMap()
        .entries
        .where((e) => e.key != _selectedBookIndex)
        .take(2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Book cover / thumbnail placeholder
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: const Icon(
                LucideIcons.fileText,
                size: 20,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeBook.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Page ${activeBook.lastPage} of ${activeBook.totalPages}',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${(activeBook.progressFraction * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Primary Resume Button
            TactileButton(
              onPressed: () => _openReader(activeBook),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.play, size: 13, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      'Resume',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ProgressBarX(
          value: activeBook.progressFraction,
          color: BentoTheme.accent,
          customTrackColor: BentoTheme.surfaceElevated,
          height: 5,
        ),
        const SizedBox(height: 10),
        // Quick switch chips + Import PDF button
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (var entry in otherBooks) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedBookIndex = entry.key);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: BentoTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: BentoTheme.divider),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              entry.value.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Inline + Import PDF button
            TactileButton(
              onPressed: _importPdf,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: BentoTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 12, color: BentoTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Import PDF',
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
      ],
    );
  }

  Widget _buildSpeechesBody(BuildContext context) {
    final speeches = _getSpeechItems();
    if (speeches.isEmpty) {
      return SizedBox(
        height: 130,
        child: Center(
          child: Text(
            'No speeches in vault',
            style: TextStyle(color: BentoTheme.textSecondary),
          ),
        ),
      );
    }

    final safeIndex = _activeSpeechIndex % speeches.length;
    final item = speeches[safeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BentoTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.category.toUpperCase(),
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'by ${item.speaker}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Text(
              '${safeIndex + 1}/${speeches.length}',
              style: TextStyle(
                color: BentoTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.previewText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 11,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Prev button
            TactileButton(
              onPressed: () => _cycleSpeech(-1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BentoTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.chevronLeft,
                        size: 13, color: BentoTheme.textSecondary),
                    Text(
                      'Prev',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Next button
            TactileButton(
              onPressed: () => _cycleSpeech(1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BentoTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Next',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(LucideIcons.chevronRight,
                        size: 13, color: BentoTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Read Full trigger
            TactileButton(
              onPressed: () => _showReadFullModal(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: BentoTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Read Full',
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // + Add inline trigger
            TactileButton(
              onPressed: _showAddSpeechModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BentoTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus,
                        size: 11, color: BentoTheme.textPrimary),
                    const SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
