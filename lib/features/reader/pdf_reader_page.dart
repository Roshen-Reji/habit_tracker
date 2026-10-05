import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';

enum ReaderThemeMode {
  dark,
  light,
  sepia,
}

enum ReaderViewMode {
  continuous,
  horizontal,
  single,
}

class PdfReaderPage extends StatefulWidget {
  final PdfBook book;

  const PdfReaderPage({super.key, required this.book});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final PdfViewerController _pdfController;
  late final PdfTextSearcher _textSearcher;

  int _currentPage = 1;
  int _totalPages = 1;

  ReaderThemeMode _themeMode = ReaderThemeMode.dark;
  ReaderViewMode _viewMode = ReaderViewMode.continuous;

  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isBookmarked = false;
  bool _isSearchActive = false;

  final TextEditingController _searchController = TextEditingController();
  final List<int> _positionHistory = [];
  List<PdfOutlineNode> _outline = [];

  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  String? _resolvedPath;
  Uint8List? _pdfBytes;
  bool _isAttemptingFallback = false;

  @override
  void initState() {
    super.initState();
    _currentPage = math.max(1, widget.book.lastPage);
    _totalPages = widget.book.totalPages > 0 ? widget.book.totalPages : 1;
    _resolvedPath = widget.book.path;
    _resolveDocument();

    // Restore saved theme and view mode if available
    final progress = ReaderService.getProgress(widget.book.path);
    if (progress != null) {
      _isBookmarked = progress.bookmarks.contains(_currentPage);
      if (progress.themeMode == 'light') {
        _themeMode = ReaderThemeMode.light;
      } else if (progress.themeMode == 'sepia') {
        _themeMode = ReaderThemeMode.sepia;
      } else {
        _themeMode = ReaderThemeMode.dark;
      }

      if (progress.viewMode == 'horizontal') {
        _viewMode = ReaderViewMode.horizontal;
      } else if (progress.viewMode == 'single') {
        _viewMode = ReaderViewMode.single;
      } else {
        _viewMode = ReaderViewMode.continuous;
      }
    }

    _pdfController = PdfViewerController();
    _textSearcher = PdfTextSearcher(_pdfController);
    _textSearcher.addListener(() {
      if (mounted) setState(() {});
    });

    // Start session timer for reading statistics
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sessionSeconds++;
    });
  }

  Future<void> _resolveDocument() async {
    try {
      await ReaderService.ensurePdfrxInitialized();
      final resolved = await ReaderService.ensureFileInSandbox(widget.book.path);
      if (mounted && resolved != _resolvedPath) {
        setState(() {
          _resolvedPath = resolved;
        });
      }
    } catch (e) {
      debugPrint('Error resolving document: $e');
    }
  }

  Future<void> _attemptMemoryFallback() async {
    if (_isAttemptingFallback) return;
    setState(() => _isAttemptingFallback = true);
    try {
      await ReaderService.ensurePdfrxInitialized();
      final path = _resolvedPath ?? widget.book.path;
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isAttemptingFallback = false;
          });
          return;
        }
      }
      final newBook = await ReaderService.importPdfFromPicker();
      if (newBook != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PdfReaderPage(book: newBook)),
        );
      }
    } catch (e) {
      debugPrint('Memory fallback failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isAttemptingFallback = false);
      }
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    // Save reading time
    if (_sessionSeconds > 0) {
      ReaderService.addReadingTime(widget.book.path, _sessionSeconds);
    }
    // Restore system UI if in immersive mode
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _textSearcher.dispose();
    _searchController.dispose();
    super.dispose();
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

  void _recordJump(int fromPage) {
    if (_positionHistory.isEmpty || _positionHistory.last != fromPage) {
      setState(() {
        _positionHistory.add(fromPage);
        if (_positionHistory.length > 25) _positionHistory.removeAt(0);
      });
      ReaderService.pushHistoryPage(widget.book.path, fromPage);
    }
  }

  void _goBackToPreviousPosition() {
    if (_positionHistory.isNotEmpty) {
      final targetPage = _positionHistory.removeLast();
      setState(() {});
      _pdfController.goToPage(pageNumber: targetPage);
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _showControls = false;
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        _showControls = true;
      }
    });
  }

  Future<void> _toggleBookmark({String? name}) async {
    await ReaderService.toggleBookmark(
      widget.book.path,
      _currentPage,
      name: name,
    );
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

  void _showAddBookmarkDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text(
          'Bookmark Page $_currentPage',
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: BentoTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Bookmark title or note (optional)',
            hintStyle: TextStyle(color: BentoTheme.textSecondary),
            filled: true,
            fillColor: BentoTheme.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Bookmark'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _toggleBookmark(name: textController.text.trim());
            },
          ),
        ],
      ),
    );
  }

  void _showBookmarksDialog() {
    final progress = ReaderService.getProgress(widget.book.path);
    final bookmarks = progress?.bookmarks ?? [];
    final names = progress?.bookmarkNames ?? {};

    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.bookmarkCheck,
                        color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'BOOKMARKS (${bookmarks.length})',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.plus,
                          color: Color(0xFF38BDF8)),
                      tooltip: 'Bookmark Current Page',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddBookmarkDialog();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (bookmarks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
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
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final pageNum = bookmarks[index];
                        final bookmarkTitle = names[pageNum] ?? 'Page $pageNum';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.15),
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
                            bookmarkTitle,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: names.containsKey(pageNum)
                              ? Text(
                                  'Page $pageNum',
                                  style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.pencil,
                                    size: 16, color: Colors.white54),
                                onPressed: () {
                                  _editBookmarkNoteDialog(
                                      pageNum, names[pageNum] ?? '');
                                },
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2,
                                    size: 16, color: Colors.redAccent),
                                onPressed: () async {
                                  await ReaderService.toggleBookmark(
                                      widget.book.path, pageNum);
                                  setModalState(() {});
                                  setState(() {
                                    final updatedProgress =
                                        ReaderService.getProgress(
                                            widget.book.path);
                                    _isBookmarked = updatedProgress?.bookmarks
                                            .contains(_currentPage) ??
                                        false;
                                  });
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _recordJump(_currentPage);
                            _pdfController.goToPage(pageNumber: pageNum);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _editBookmarkNoteDialog(int pageNum, String currentName) {
    final textController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text(
          'Edit Bookmark Note (p. $pageNum)',
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 15),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: BentoTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter bookmark name',
            hintStyle: TextStyle(color: BentoTheme.textSecondary),
            filled: true,
            fillColor: BentoTheme.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
            onPressed: () async {
              Navigator.pop(ctx);
              await ReaderService.updateBookmarkName(
                widget.book.path,
                pageNum,
                textController.text.trim(),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showOutlineDialog() {
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
                const Icon(LucideIcons.listTree,
                    color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 10),
                Text(
                  'TABLE OF CONTENTS',
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
            if (_outline.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No table of contents embedded in this document.',
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
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _outline.length,
                  itemBuilder: (context, index) {
                    final node = _outline[index];
                    return _buildOutlineNodeTile(node, 0);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineNodeTile(PdfOutlineNode node, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: depth * 16.0),
          leading: Icon(
            node.children.isNotEmpty
                ? LucideIcons.folderClosed
                : LucideIcons.fileText,
            color: const Color(0xFF38BDF8),
            size: 16,
          ),
          title: Text(
            node.title,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 13,
              fontWeight: depth == 0 ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: node.dest?.pageNumber != null
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'p. ${node.dest!.pageNumber}',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                )
              : null,
          onTap: () {
            if (node.dest != null) {
              Navigator.pop(context);
              _recordJump(_currentPage);
              _pdfController.goToDest(node.dest);
            }
          },
        ),
        if (node.children.isNotEmpty)
          for (final child in node.children)
            _buildOutlineNodeTile(child, depth + 1),
      ],
    );
  }

  void _showGoToPageDialog() {
    final textController = TextEditingController(text: '$_currentPage');
    double sliderVal = _currentPage.toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: BentoTheme.surface,
          title: Text(
            'Jump to Page',
            style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Page',
                    style: TextStyle(color: BentoTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: textController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null &&
                            parsed >= 1 &&
                            parsed <= _totalPages) {
                          setDialogState(() {
                            sliderVal = parsed.toDouble();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of $_totalPages',
                    style: TextStyle(color: BentoTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: sliderVal.clamp(1.0, _totalPages.toDouble()),
                min: 1.0,
                max: _totalPages > 1 ? _totalPages.toDouble() : 1.0,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) {
                  setDialogState(() {
                    sliderVal = val;
                    textController.text = '${val.round()}';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
              ),
              child: const Text('Go'),
              onPressed: () {
                final target = int.tryParse(textController.text) ?? 1;
                final safePage = target.clamp(1, _totalPages);
                Navigator.pop(ctx);
                _recordJump(_currentPage);
                _pdfController.goToPage(pageNumber: safePage);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'READING PREFERENCES',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Theme Mode
                Text(
                  'Reading Theme',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildThemeOption(
                      'Dark',
                      ReaderThemeMode.dark,
                      Colors.black,
                      Colors.white,
                      setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _buildThemeOption(
                      'Light',
                      ReaderThemeMode.light,
                      Colors.white,
                      Colors.black,
                      setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _buildThemeOption(
                      'Sepia',
                      ReaderThemeMode.sepia,
                      const Color(0xFFFBF0D9),
                      const Color(0xFF4A3728),
                      setSheetState,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // View Mode
                Text(
                  'Scroll Layout Mode',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildViewOption(
                      'Vertical',
                      ReaderViewMode.continuous,
                      LucideIcons.arrowDownUp,
                      setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _buildViewOption(
                      'Horizontal',
                      ReaderViewMode.horizontal,
                      LucideIcons.arrowLeftRight,
                      setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _buildViewOption(
                      'Single Page',
                      ReaderViewMode.single,
                      LucideIcons.fileSpreadsheet,
                      setSheetState,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Zoom & Fit Controls
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.maximize2, size: 16),
                        label: const Text('Fit to Width'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BentoTheme.textPrimary,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (_pdfController.isReady) {
                            _pdfController.setZoom(
                                Offset.zero, _pdfController.coverScale);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.minimize2, size: 16),
                        label: const Text('Fit Page'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BentoTheme.textPrimary,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (_pdfController.isReady &&
                              _pdfController.alternativeFitScale != null) {
                            _pdfController.setZoom(Offset.zero,
                                _pdfController.alternativeFitScale!);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    ReaderThemeMode mode,
    Color bgColor,
    Color textColor,
    StateSetter setSheetState,
  ) {
    final isSelected = _themeMode == mode;
    const accent = Color(0xFF38BDF8);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _themeMode = mode;
            final themeStr = mode == ReaderThemeMode.light
                ? 'light'
                : (mode == ReaderThemeMode.sepia ? 'sepia' : 'dark');
            ReaderService.setThemeMode(widget.book.path, themeStr);
          });
          setSheetState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewOption(
    String label,
    ReaderViewMode mode,
    IconData icon,
    StateSetter setSheetState,
  ) {
    final isSelected = _viewMode == mode;
    const accent = Color(0xFF38BDF8);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _viewMode = mode;
            final modeStr = mode == ReaderViewMode.horizontal
                ? 'horizontal'
                : (mode == ReaderViewMode.single ? 'single' : 'continuous');
            ReaderService.setViewMode(widget.book.path, modeStr);
          });
          setSheetState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.15)
                : BentoTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? accent : BentoTheme.textSecondary,
                  size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? accent : BentoTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatsSheet() {
    final totalSec = widget.book.totalReadingSeconds + _sessionSeconds;
    final totalMins = totalSec ~/ 60;
    final sessionMins = _sessionSeconds ~/ 60;
    final sessionRemSec = _sessionSeconds % 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.timer,
                    color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 10),
                Text(
                  'READING STATS & TIMER',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard('Current Session',
                '${sessionMins}m ${sessionRemSec}s', LucideIcons.hourglass),
            const SizedBox(height: 8),
            _buildStatCard(
                'Total Reading Time',
                totalMins >= 60
                    ? '${totalMins ~/ 60}h ${totalMins % 60}m'
                    : '${totalMins}m',
                LucideIcons.clock),
            const SizedBox(height: 8),
            _buildStatCard(
                'Reading Progress',
                'Page $_currentPage of $_totalPages (${((_currentPage / _totalPages) * 100).toInt()}%)',
                LucideIcons.barChart2),
            const SizedBox(height: 8),
            _buildStatCard(
                'Pages Remaining',
                '${math.max(0, _totalPages - _currentPage)} pages to finish',
                LucideIcons.bookOpen),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    const accent = Color(0xFF38BDF8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  ColorFilter? get _currentColorFilter {
    switch (_themeMode) {
      case ReaderThemeMode.dark:
        return const ColorFilter.matrix([
          -0.85,
          0,
          0,
          0,
          230,
          0,
          -0.85,
          0,
          0,
          230,
          0,
          0,
          -0.85,
          0,
          230,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ReaderThemeMode.sepia:
        return const ColorFilter.matrix([
          0.393 * 1.15,
          0.769 * 0.90,
          0.189 * 0.85,
          0,
          35,
          0.349 * 1.15,
          0.686 * 0.90,
          0.168 * 0.85,
          0,
          25,
          0.272 * 1.05,
          0.534 * 0.85,
          0.131 * 0.75,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ReaderThemeMode.light:
        return null;
    }
  }

  Color get _currentBackgroundColor {
    switch (_themeMode) {
      case ReaderThemeMode.dark:
        return const Color(0xFF0F0F12);
      case ReaderThemeMode.sepia:
        return const Color(0xFFFBF0D9);
      case ReaderThemeMode.light:
        return const Color(0xFFF3F4F6);
    }
  }

  PdfPageLayoutFunction? get _currentLayoutPages {
    if (_viewMode == ReaderViewMode.horizontal) {
      return (pages, params) {
        final height =
            pages.fold(0.0, (prev, page) => math.max(prev, page.height)) +
                params.margin * 2;
        final pageLayouts = <Rect>[];
        double x = params.margin;
        for (final page in pages) {
          pageLayouts
              .add(Rect.fromLTWH(x, params.margin, page.width, page.height));
          x += page.width + params.margin;
        }
        return PdfPageLayout(
            pageLayouts: pageLayouts, documentSize: Size(x, height));
      };
    } else if (_viewMode == ReaderViewMode.single) {
      return (pages, params) {
        final height =
            pages.fold(0.0, (prev, page) => math.max(prev, page.height)) +
                params.margin * 2;
        final pageLayouts = <Rect>[];
        double x = params.margin;
        for (final page in pages) {
          pageLayouts
              .add(Rect.fromLTWH(x, params.margin, page.width, page.height));
          x += page.width + params.margin * 6;
        }
        return PdfPageLayout(
            pageLayouts: pageLayouts, documentSize: Size(x, height));
      };
    }
    return null; // Vertical continuous
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38BDF8); // Sky blue accent

    final activePath = _resolvedPath ?? widget.book.path;
    final file = File(activePath);
    if (!file.existsSync() && _pdfBytes == null) {
      return Scaffold(
        backgroundColor: _currentBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.book.name,
            style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.fileX, color: Colors.orangeAccent, size: 54),
                const SizedBox(height: 16),
                Text(
                  'Document Not Found',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The file at "${widget.book.path}" could not be opened. It may have been moved or storage permission might be required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(LucideIcons.keyRound, size: 16),
                      label: const Text('Grant Permission'),
                      onPressed: () async {
                        await ReaderService.requestStorageAccess();
                        await _resolveDocument();
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BentoTheme.surfaceElevated,
                        foregroundColor: BentoTheme.textPrimary,
                      ),
                      icon: const Icon(LucideIcons.folderInput, size: 16),
                      label: const Text('Locate / Re-import'),
                      onPressed: () async {
                        final newBook = await ReaderService.importPdfFromPicker();
                        if (newBook != null && mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => PdfReaderPage(book: newBook)),
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BentoTheme.textSecondary,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: const Text('Back to Library'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final viewerParams = PdfViewerParams(
      layoutPages: _currentLayoutPages,
      onPageChanged: _onPageChanged,
      calculateInitialPageNumber: (doc, controller) {
        if (doc.pages.isEmpty) return 1;
        return _currentPage.clamp(1, doc.pages.length);
      },
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: accent),
            const SizedBox(height: 16),
            Text(
              'Loading document...',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
      errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to Render PDF',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Retry Memory Stream'),
                    onPressed: () async {
                      await _attemptMemoryFallback();
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BentoTheme.textPrimary,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    icon: const Icon(LucideIcons.arrowLeft, size: 16),
                    label: const Text('Back'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      pagePaintCallbacks: [
        _textSearcher.pageTextMatchPaintCallback,
      ],
      linkHandlerParams: PdfLinkHandlerParams(
        onLinkTap: (link) {
          if (link.dest != null) {
            _recordJump(_currentPage);
            _pdfController.goToDest(link.dest);
          }
        },
      ),
      onDocumentChanged: (doc) async {
        if (doc != null) {
          setState(() {
            _totalPages = doc.pages.length;
          });
          ReaderService.updateProgress(
            widget.book.path,
            page: _currentPage,
            totalPages: doc.pages.length,
          );
          try {
            final outline = await doc.loadOutline();
            if (mounted) {
              setState(() {
                _outline = outline;
              });
            }
          } catch (_) {}
        }
      },
    );

    final Widget viewer = _pdfBytes != null
        ? PdfViewer.data(
            _pdfBytes!,
            sourceName: widget.book.name,
            key: ValueKey('${_viewMode.name}_data_${_pdfBytes!.length}'),
            controller: _pdfController,
            initialPageNumber: _currentPage,
            params: viewerParams,
          )
        : PdfViewer.file(
            activePath,
            key: ValueKey('${_viewMode.name}_$activePath'),
            controller: _pdfController,
            initialPageNumber: _currentPage,
            params: viewerParams,
          );

    final viewerWidget = ColorFiltered(
      colorFilter: _currentColorFilter ??
          const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
      child: viewer,
    );

    return Scaffold(
      backgroundColor: _currentBackgroundColor,
      body: Stack(
        children: [
          // Center Gesture Detector for Viewer + tap center to toggle controls
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_isSearchActive) {
                setState(() => _isSearchActive = false);
                _textSearcher.resetTextSearch();
              } else {
                setState(() => _showControls = !_showControls);
              }
            },
            child: viewerWidget,
          ),

          // Edge tap buttons for horizontal / single-page mode
          if (_viewMode != ReaderViewMode.continuous) ...[
            // Left edge (previous page)
            Positioned(
              left: 0,
              top: 100,
              bottom: 100,
              width: 50,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_currentPage > 1) {
                    _pdfController.goToPage(pageNumber: _currentPage - 1);
                  }
                },
              ),
            ),
            // Right edge (next page)
            Positioned(
              right: 0,
              top: 100,
              bottom: 100,
              width: 50,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_currentPage < _totalPages) {
                    _pdfController.goToPage(pageNumber: _currentPage + 1);
                  }
                },
              ),
            ),
          ],

          // Floating "Back to previous position" button (Prompt Highlight Feature!)
          if (_positionHistory.isNotEmpty)
            Positioned(
              bottom: _showControls ? 90 : 25,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: 1.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _goBackToPreviousPosition,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            BentoTheme.surfaceElevated.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.arrowLeft,
                              color: accent, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'Back to p. ${_positionHistory.last}',
                            style: const TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() => _positionHistory.clear());
                            },
                            child: Icon(
                              LucideIcons.x,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top App Bar Controls
          if (_showControls && !_isSearchActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.of(context).padding.top + 4,
                  8,
                  8,
                ),
                decoration: BoxDecoration(
                  color: BentoTheme.background.withValues(alpha: 0.94),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.name,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Page $_currentPage of $_totalPages • ${((_currentPage / _totalPages) * 100).toInt()}%',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search in PDF
                    IconButton(
                      icon: const Icon(LucideIcons.search, size: 19),
                      color: BentoTheme.textSecondary,
                      tooltip: 'Search Document',
                      onPressed: () => setState(() => _isSearchActive = true),
                    ),
                    // Table of Contents
                    IconButton(
                      icon: const Icon(LucideIcons.listTree, size: 19),
                      color: BentoTheme.textSecondary,
                      tooltip: 'Table of Contents',
                      onPressed: _showOutlineDialog,
                    ),
                    // Bookmarks
                    IconButton(
                      icon: Icon(
                        _isBookmarked
                            ? LucideIcons.bookmarkCheck
                            : LucideIcons.bookmark,
                        color:
                            _isBookmarked ? accent : BentoTheme.textSecondary,
                        size: 19,
                      ),
                      tooltip: 'Toggle Bookmark',
                      onPressed: _toggleBookmark,
                      onLongPress: _showAddBookmarkDialog,
                    ),
                    // Reading stats & timer
                    IconButton(
                      icon: const Icon(LucideIcons.timer, size: 19),
                      color: BentoTheme.textSecondary,
                      tooltip: 'Reading Stats',
                      onPressed: _showStatsSheet,
                    ),
                    // Reading preferences / theme
                    IconButton(
                      icon: const Icon(LucideIcons.sliders, size: 19),
                      color: BentoTheme.textSecondary,
                      tooltip: 'Reader Preferences',
                      onPressed: _showSettingsSheet,
                    ),
                  ],
                ),
              ),
            ),

          // Active Search Top Bar
          if (_isSearchActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  12,
                  MediaQuery.of(context).padding.top + 6,
                  12,
                  8,
                ),
                decoration: BoxDecoration(
                  color: BentoTheme.background.withValues(alpha: 0.96),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search text in PDF...',
                          hintStyle: TextStyle(
                            color:
                                BentoTheme.textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(LucideIcons.search,
                              color: accent, size: 17),
                          isDense: true,
                          filled: true,
                          fillColor: BentoTheme.surfaceElevated,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (query) {
                          if (query.trim().isNotEmpty) {
                            _textSearcher.startTextSearch(
                              query.trim(),
                              caseInsensitive: true,
                              goToFirstMatch: true,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Match counter
                    if (_textSearcher.matches.isNotEmpty) ...[
                      Text(
                        '${(_textSearcher.currentIndex ?? 0) + 1}/${_textSearcher.matches.length}',
                        style: const TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronUp, size: 18),
                        color: BentoTheme.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _textSearcher.goToPrevMatch(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronDown, size: 18),
                        color: BentoTheme.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _textSearcher.goToNextMatch(),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      color: BentoTheme.textSecondary,
                      onPressed: () {
                        setState(() => _isSearchActive = false);
                        _textSearcher.resetTextSearch();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Floating Page Slider & Nav Bar
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: BentoTheme.background.withValues(alpha: 0.94),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Slider & Page button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _showGoToPageDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: BentoTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'p. $_currentPage / $_totalPages',
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(LucideIcons.chevronsUpDown,
                                    size: 11, color: accent),
                              ],
                            ),
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
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                            ),
                            child: Slider(
                              value: _currentPage
                                  .toDouble()
                                  .clamp(1.0, _totalPages.toDouble()),
                              min: 1.0,
                              max: _totalPages > 1
                                  ? _totalPages.toDouble()
                                  : 1.0,
                              onChanged: (val) {
                                final targetPage = val.round();
                                if (targetPage != _currentPage) {
                                  _pdfController.goToPage(
                                      pageNumber: targetPage);
                                }
                              },
                            ),
                          ),
                        ),
                        // Fullscreen / Immersive Toggle
                        IconButton(
                          icon: Icon(
                            _isFullscreen
                                ? LucideIcons.minimize
                                : LucideIcons.maximize,
                            size: 16,
                            color: BentoTheme.textSecondary,
                          ),
                          tooltip:
                              _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                          onPressed: _toggleFullscreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Quick Action Row: Prev page, Next page, Zoom In, Zoom Out, Bookmarks List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous page
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft, size: 20),
                          color: _currentPage > 1
                              ? BentoTheme.textPrimary
                              : BentoTheme.textSecondary.withValues(alpha: 0.3),
                          onPressed: _currentPage > 1
                              ? () => _pdfController.goToPage(
                                  pageNumber: _currentPage - 1)
                              : null,
                        ),
                        // Zoom Out
                        IconButton(
                          icon: const Icon(LucideIcons.zoomOut, size: 18),
                          color: BentoTheme.textSecondary,
                          onPressed: () => _pdfController.zoomDown(),
                        ),
                        // Bookmarks view
                        TextButton.icon(
                          icon: const Icon(LucideIcons.bookmarkCheck,
                              size: 14, color: accent),
                          label: Text(
                            'Bookmarks',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: _showBookmarksDialog,
                        ),
                        // Zoom In
                        IconButton(
                          icon: const Icon(LucideIcons.zoomIn, size: 18),
                          color: BentoTheme.textSecondary,
                          onPressed: () => _pdfController.zoomUp(),
                        ),
                        // Next page
                        IconButton(
                          icon: const Icon(LucideIcons.chevronRight, size: 20),
                          color: _currentPage < _totalPages
                              ? BentoTheme.textPrimary
                              : BentoTheme.textSecondary.withValues(alpha: 0.3),
                          onPressed: _currentPage < _totalPages
                              ? () => _pdfController.goToPage(
                                  pageNumber: _currentPage + 1)
                              : null,
                        ),
                      ],
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
