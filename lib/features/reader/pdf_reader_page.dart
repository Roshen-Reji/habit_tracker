import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfReaderPage extends StatefulWidget {
  final PdfBook book;

  const PdfReaderPage({super.key, required this.book});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final PdfViewerController _pdfController;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isNightMode = true;
  bool _showControls = true;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.lastPage;
    _totalPages = widget.book.totalPages > 0 ? widget.book.totalPages : 1;
    _pdfController = PdfViewerController();

    final progress = ReaderService.getProgress(widget.book.path);
    if (progress != null) {
      _isBookmarked = progress.bookmarks.contains(_currentPage);
    }
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    setState(() {
      _currentPage = page;
      final progress = ReaderService.getProgress(widget.book.path);
      _isBookmarked = progress?.bookmarks.contains(page) ?? false;
    });

    ReaderService.updateProgress(
      widget.book.path,
      page: page,
      totalPages: _totalPages,
    );
  }

  Future<void> _toggleBookmark() async {
    await ReaderService.toggleBookmark(widget.book.path, _currentPage);
    final progress = ReaderService.getProgress(widget.book.path);
    setState(() {
      _isBookmarked = progress?.bookmarks.contains(_currentPage) ?? false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked
              ? 'Page $_currentPage bookmarked'
              : 'Bookmark removed from page $_currentPage'),
          duration: const Duration(seconds: 1),
          backgroundColor: BentoTheme.surfaceElevated,
        ),
      );
    }
  }

  void _showBookmarksDialog() {
    final progress = ReaderService.getProgress(widget.book.path);
    final bookmarks = progress?.bookmarks ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.bookmark,
                    color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 10),
                Text(
                  'BOOKMARKS',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bookmarks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No bookmarks yet for this book.\nTap the bookmark icon on any page to bookmark it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final pageNum = bookmarks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$pageNum',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        'Page $pageNum',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight,
                          color: Colors.white38, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pdfController.goToPage(pageNumber: pageNum);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38BDF8); // Sky blue accent

    return Scaffold(
      backgroundColor: _isNightMode ? const Color(0xFF0F0F12) : Colors.white,
      body: Stack(
        children: [
          // PDF Viewer
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: ColorFiltered(
              colorFilter: _isNightMode
                  ? const ColorFilter.matrix([
                      -0.9, 0, 0, 0, 240, // R
                      0, -0.9, 0, 0, 240, // G
                      0, 0, -0.9, 0, 240, // B
                      0, 0, 0, 1, 0, // A
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply),
              child: PdfViewer.file(
                widget.book.path,
                controller: _pdfController,
                initialPageNumber: _currentPage,
                params: PdfViewerParams(
                  onPageChanged: _onPageChanged,
                  onDocumentChanged: (doc) {
                    if (doc != null) {
                      setState(() {
                        _totalPages = doc.pages.length;
                      });
                      ReaderService.updateProgress(
                        widget.book.path,
                        page: _currentPage,
                        totalPages: doc.pages.length,
                      );
                    }
                  },
                ),
              ),
            ),
          ),

          // Top App Bar
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    8, MediaQuery.of(context).padding.top + 4, 12, 10),
                decoration: BoxDecoration(
                  color: BentoTheme.background.withValues(alpha: 0.92),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.arrowLeft,
                          color: BentoTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.book.name,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isBookmarked
                            ? LucideIcons.bookmarkCheck
                            : LucideIcons.bookmark,
                        color:
                            _isBookmarked ? accent : BentoTheme.textSecondary,
                        size: 20,
                      ),
                      tooltip: 'Toggle Bookmark',
                      onPressed: _toggleBookmark,
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.bookmarkCheck,
                          color: BentoTheme.textSecondary, size: 20),
                      tooltip: 'View Bookmarks',
                      onPressed: _showBookmarksDialog,
                    ),
                    IconButton(
                      icon: Icon(
                        _isNightMode ? LucideIcons.sun : LucideIcons.moon,
                        color: _isNightMode
                            ? Colors.amberAccent
                            : BentoTheme.textSecondary,
                        size: 20,
                      ),
                      tooltip: _isNightMode ? 'Day Mode' : 'Night Mode',
                      onPressed: () =>
                          setState(() => _isNightMode = !_isNightMode),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Floating Page Slider
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: BentoTheme.background.withValues(alpha: 0.92),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Page $_currentPage / $_totalPages',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.12),
                          thumbColor: accent,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _currentPage
                              .toDouble()
                              .clamp(1.0, _totalPages.toDouble()),
                          min: 1.0,
                          max: _totalPages.toDouble() > 1.0
                              ? _totalPages.toDouble()
                              : 1.0,
                          onChanged: (val) {
                            final targetPage = val.round();
                            if (targetPage != _currentPage) {
                              _pdfController.goToPage(pageNumber: targetPage);
                            }
                          },
                        ),
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
}
