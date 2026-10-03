import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/reader/pdf_reader_page.dart';
import 'package:habit_tracker/features/reader/reader_library_page.dart';
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
        final displayBooks = _books.take(3).toList();

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
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                ),
              ] else if (displayBooks.isNotEmpty) ...[
                // Up to 3 book covers row
                SizedBox(
                  height: 112,
                  child: Row(
                    children: [
                      for (int i = 0; i < displayBooks.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _buildBookCoverItem(
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
                                    ExpressiveTokens.radiusSm),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Read PDFs, books & manuals with continuous scrolling, bookmarks, and night mode.',
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
                        ? 'View All in Library'
                        : 'Configure PDF Folders',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildBookCoverItem(
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: BentoTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    LucideIcons.fileText,
                    color: accent.withValues(alpha: 0.6),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.name,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'p. ${book.lastPage}',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
