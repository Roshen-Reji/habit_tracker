import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/reader/pdf_reader_page.dart';
import 'package:habit_tracker/features/reader/reader_library_page.dart';
import 'package:habit_tracker/features/reader/widgets/book_cover_thumbnail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderCard extends StatefulWidget {
  const ReaderCard({super.key});

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
    const accent = Color(0xFF38BDF8); // Sky blue accent

    return ValueListenableBuilder(
      valueListenable:
          Hive.box<BookProgress>(ReaderService.progressBoxName).listenable(),
      builder: (context, _, __) {
        // Books are already sorted by recently opened then modified
        final displayBooks = _books.take(3).toList();
        final mostRecentBook =
            displayBooks.isNotEmpty ? displayBooks.first : null;

        return HomeCardFrame(
          icon: LucideIcons.bookOpen,
          title: 'Document Reader',
          accentColor: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReaderLibraryPage(),
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
              style: const TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) ...[
                const SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                ),
              ] else if (displayBooks.isNotEmpty) ...[
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
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  style: BorderStyle.solid,
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

                // Quick Continue Reading bar for the top book
                if (mostRecentBook != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusSm),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfReaderPage(book: mostRecentBook),
                          ),
                        ).then((_) => _loadBooks());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(ExpressiveTokens.radiusSm),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.playCircle,
                              color: accent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Continue: ${mostRecentBook.name}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Page ${mostRecentBook.lastPage} of ${mostRecentBook.totalPages} (${(mostRecentBook.progressFraction * 100).toInt()}%)',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              LucideIcons.chevronRight,
                              color: accent,
                              size: 14,
                            ),
                          ],
                        ),
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
              // View all button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.surfaceElevated,
                    foregroundColor: BentoTheme.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusSm),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  icon: const Icon(LucideIcons.library, size: 15),
                  label: Text(
                    displayBooks.isNotEmpty
                        ? 'View Library (${_books.length})'
                        : 'Configure PDF Folders',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReaderLibraryPage(),
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
            MaterialPageRoute(
              builder: (_) => PdfReaderPage(book: book),
            ),
          ).then((_) => _loadBooks());
        },
        child: Container(
          decoration: BoxDecoration(
            color: BentoTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
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
              // Cover area with real rendered PDF thumbnail
              Expanded(
                child: BookCoverThumbnail(
                  book: book,
                  showProgressBadge: true,
                  showSpine: true,
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: book.progressFraction,
                        minHeight: 2.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
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
