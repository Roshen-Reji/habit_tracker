import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/reader/pdf_reader_page.dart';
import 'package:habit_tracker/features/reader/reader_library_page.dart';
import 'package:habit_tracker/features/reader/widgets/book_cover_thumbnail.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderCard extends StatefulWidget {
  final HomeCardSize size;

  const ReaderCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  State<ReaderCard> createState() => _ReaderCardState();
}

class _ReaderCardState extends State<ReaderCard> {
  List<PdfBook> _books = [];
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;

    return ValueListenableBuilder(
      valueListenable:
          Hive.box<BookProgress>(ReaderService.progressBoxName).listenable(),
      builder: (context, _, __) {
        // Books are already sorted by recently opened then modified
        final displayBooks = _books.take(3).toList();
        final mostRecentBook =
            displayBooks.isNotEmpty ? displayBooks.first : null;

        return HomeCardFrame(
          domain: HomeCardDomain.editorial,
          icon: LucideIcons.bookOpen,
          title: 'Document Reader',
          accentColor: accent,
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.containerTransform(
                const ReaderLibraryPage(),
              ),
            ).then((_) => _loadBooks());
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_books.length} files',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) ...[
                SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                ),
              ] else if (displayBooks.isNotEmpty) ...[
                if (widget.size == HomeCardSize.large ||
                    mostRecentBook == null) ...[
                  // Last 3 book covers row
                  SizedBox(
                    height: 144,
                    child: Row(
                      children: [
                        for (int i = 0; i < displayBooks.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _buildBookCoverCard(
                              context,
                              displayBooks[i],
                              accent,
                            ),
                          ),
                        ],
                        if (displayBooks.length < 3)
                          for (int k = 0; k < (3 - displayBooks.length); k++)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(left: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(
                                    ExpressiveTokens.radiusSm,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    LucideIcons.filePlus,
                                    color: Colors.white.withValues(alpha: 0.15),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],

                // 1-Tap Resume Reading button for the top book
                if (mostRecentBook != null) ...[
                  const SizedBox(height: 12),
                  TactileButton(
                    label: 'Resume: ${mostRecentBook.name}',
                    icon: LucideIcons.playCircle,
                    variant: TactileButtonVariant.primary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransitions.containerTransform(
                          PdfReaderPage(book: mostRecentBook),
                        ),
                      ).then((_) => _loadBooks());
                    },
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'Page ${mostRecentBook.lastPage} of ${mostRecentBook.totalPages} · ${(mostRecentBook.progressFraction * 100).toInt()}% completed',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  'Read PDFs, books & documents with continuous scroll, bookmarking, search, and reading themes.',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 12),
              // View all / Open button
              if (displayBooks.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: TactileButton.icon(
                        size: TactileButtonSize.small,
                        variant: TactileButtonVariant.primary,
                        icon: LucideIcons.filePlus,
                        label: 'Open PDF',
                        onPressed: () async {
                          final book =
                              await ReaderService.importPdfFromPicker();
                          if (book != null && context.mounted) {
                            await _loadBooks();
                            Navigator.push(
                              context,
                              PageTransitions.containerTransform(
                                PdfReaderPage(book: book),
                              ),
                            ).then((_) => _loadBooks());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TactileButton.icon(
                        size: TactileButtonSize.small,
                        variant: TactileButtonVariant.secondary,
                        icon: LucideIcons.library,
                        label: 'Library',
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageTransitions.containerTransform(
                              const ReaderLibraryPage(),
                            ),
                          ).then((_) => _loadBooks());
                        },
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: TactileButton.icon(
                    size: TactileButtonSize.small,
                    variant: TactileButtonVariant.secondary,
                    icon: LucideIcons.library,
                    label: 'View Library (${_books.length})',
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransitions.containerTransform(
                          const ReaderLibraryPage(),
                        ),
                      ).then((_) => _loadBooks());
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookCoverCard(
    BuildContext context,
    PdfBook book,
    Color accent,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
        onTap: () {
          Navigator.push(
            context,
            PageTransitions.containerTransform(
              PdfReaderPage(book: book),
            ),
          ).then((_) => _loadBooks());
        },
        child: Container(
          decoration: BoxDecoration(
            color: BentoTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover area with real rendered PDF thumbnail and physical bookmark ribbon
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: BookCoverThumbnail(
                        book: book,
                        showProgressBadge: true,
                        showSpine: true,
                      ),
                    ),
                    if (book.progressFraction > 0.05)
                      const Positioned(
                        top: -1,
                        right: 12,
                        child: BookmarkRibbon(),
                      ),
                  ],
                ),
              ),
              // Bottom progress & name strip
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    ProgressBarX(
                      value: book.progressFraction,
                      height: 3,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Physical editorial bookmark ribbon indicator hanging from book cover edge.
class BookmarkRibbon extends StatelessWidget {
  final Color color;

  const BookmarkRibbon({
    super.key,
    this.color = const Color(0xFFE11D48),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 2,
          height: 12,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

