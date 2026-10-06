import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/reader/pdf_reader_page.dart';
import 'package:habit_tracker/features/reader/widgets/book_cover_thumbnail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderLibraryPage extends StatefulWidget {
  const ReaderLibraryPage({super.key});

  @override
  State<ReaderLibraryPage> createState() => _ReaderLibraryPageState();
}

class _ReaderLibraryPageState extends State<ReaderLibraryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PdfBook> _books = [];
  bool _isLoading = false;
  bool _isGridView = true;

  ReaderTab _currentTab = ReaderTab.all;
  ReaderSort _currentSort = ReaderSort.lastOpenedDesc;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
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

  Future<void> _pickFolder() async {
    await ReaderService.requestStorageAccess();
    final selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null && selectedDir.isNotEmpty) {
      await ReaderService.addFolder(selectedDir);
      await _loadBooks();
    }
  }

  Future<void> _openSinglePdf() async {
    final book = await ReaderService.importPdfFromPicker();
    if (book != null) {
      await _loadBooks();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfReaderPage(book: book),
          ),
        ).then((_) => _loadBooks());
      }
    }
  }

  void _showFolderSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final folders = ReaderService.getConfiguredFolders();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.folder,
                        color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'CONFIGURED PDF FOLDERS',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.plus,
                          color: Color(0xFF38BDF8)),
                      onPressed: () async {
                        await _pickFolder();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (folders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No document folders configured yet.\nTap "+" to add a folder containing PDFs.',
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
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.folderGit2,
                              color: Color(0xFF38BDF8), size: 20),
                          title: Text(
                            folder,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.trash2,
                                color: Colors.redAccent, size: 18),
                            onPressed: () async {
                              await ReaderService.removeFolder(folder);
                              setModalState(() {});
                              await _loadBooks();
                            },
                          ),
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

  void _showFileInfoSheet(PdfBook book) {
    const accent = Color(0xFF38BDF8);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

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
                const Icon(LucideIcons.info, color: accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'DOCUMENT INFORMATION',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('File Name', book.name),
            _buildInfoRow('File Size', book.formattedFileSize),
            _buildInfoRow('Total Pages', '${book.totalPages} pages'),
            _buildInfoRow('Current Position',
                'Page ${book.lastPage} (${(book.progressFraction * 100).toInt()}%)'),
            _buildInfoRow('Time Read', book.formattedReadingTime),
            _buildInfoRow(
              'Status',
              book.isFinished
                  ? 'Finished'
                  : (book.isCurrentlyReading ? 'In Progress' : 'Not Started'),
            ),
            _buildInfoRow(
              'Last Opened',
              book.progress != null
                  ? dateFormat.format(book.progress!.lastOpened)
                  : 'Never',
            ),
            _buildInfoRow(
              'Date Modified',
              dateFormat.format(book.modified),
            ),
            _buildInfoRow('Path', book.path),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showBookActions(PdfBook book) {
    const accent = Color(0xFF38BDF8);

    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 48,
                      child: BookCoverThumbnail(
                        book: book,
                        showProgressBadge: false,
                        showSpine: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.name,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Page ${book.lastPage} of ${book.totalPages} • ${book.formattedFileSize}',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),

              // Read / Continue
              ListTile(
                leading: const Icon(LucideIcons.bookOpen, color: accent),
                title: Text(
                  book.progress != null ? 'Continue Reading' : 'Start Reading',
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfReaderPage(book: book),
                    ),
                  ).then((_) => _loadBooks());
                },
              ),

              // Favorite toggle
              ListTile(
                leading: Icon(
                  book.isFavorite ? LucideIcons.heartCrack : LucideIcons.heart,
                  color: book.isFavorite ? Colors.redAccent : accent,
                ),
                title: Text(
                  book.isFavorite
                      ? 'Remove from Favorites'
                      : 'Add to Favorites',
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ReaderService.toggleFavorite(book.path);
                  await _loadBooks();
                },
              ),

              // Finished toggle
              ListTile(
                leading: Icon(
                  book.isFinished
                      ? LucideIcons.rotateCcw
                      : LucideIcons.checkCircle2,
                  color: const Color(0xFF10B981),
                ),
                title: Text(
                  book.isFinished ? 'Mark as Unfinished' : 'Mark as Finished',
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ReaderService.toggleFinished(book.path);
                  await _loadBooks();
                },
              ),

              // File info
              ListTile(
                leading:
                    const Icon(LucideIcons.info, color: Colors.amberAccent),
                title: Text(
                  'Document Details',
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFileInfoSheet(book);
                },
              ),

              // Reset progress
              if (book.progress != null)
                ListTile(
                  leading: const Icon(LucideIcons.refreshCcw,
                      color: Colors.orangeAccent),
                  title: Text(
                    'Reset Reading Progress',
                    style: TextStyle(color: BentoTheme.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ReaderService.resetProgress(book.path);
                    await _loadBooks();
                  },
                ),

              // Delete file
              ListTile(
                leading:
                    const Icon(LucideIcons.trash2, color: Colors.redAccent),
                title: const Text(
                  'Delete Document',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteBook(book);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBook(PdfBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text(
          'Delete Document?',
          style: TextStyle(color: BentoTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${book.name}.pdf" from your storage?',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(ctx);
              await ReaderService.deletePdfFile(book.path);
              await _loadBooks();
            },
          ),
        ],
      ),
    );
  }

  void _showSortMenu() {
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
            Text(
              'SORT DOCUMENTS BY',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildSortOption('Recently Opened', ReaderSort.lastOpenedDesc,
                LucideIcons.clock),
            _buildSortOption(
                'Name (A to Z)', ReaderSort.nameAsc, LucideIcons.arrowDownAZ),
            _buildSortOption(
                'Name (Z to A)', ReaderSort.nameDesc, LucideIcons.arrowUpZA),
            _buildSortOption('Date Modified', ReaderSort.dateModifiedDesc,
                LucideIcons.calendar),
            _buildSortOption('File Size (Largest first)',
                ReaderSort.fileSizeDesc, LucideIcons.hardDrive),
            _buildSortOption('Reading Progress %', ReaderSort.progressDesc,
                LucideIcons.barChart2),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, ReaderSort sort, IconData icon) {
    const accent = Color(0xFF38BDF8);
    final isSelected = _currentSort == sort;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          Icon(icon, color: isSelected ? accent : BentoTheme.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? accent : BentoTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: accent, size: 18)
          : null,
      onTap: () {
        setState(() => _currentSort = sort);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38BDF8); // Sky blue accent

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DOCUMENT LIBRARY',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filePlus, color: accent),
            tooltip: 'Open PDF File',
            onPressed: _openSinglePdf,
          ),
          IconButton(
            icon: Icon(
              _isGridView ? LucideIcons.list : LucideIcons.layoutGrid,
              color: BentoTheme.textSecondary,
              size: 20,
            ),
            tooltip:
                _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: Icon(LucideIcons.arrowUpDown,
                color: BentoTheme.textSecondary, size: 20),
            tooltip: 'Sort Documents',
            onPressed: _showSortMenu,
          ),
          IconButton(
            icon: Icon(LucideIcons.folderCog, color: BentoTheme.textSecondary),
            tooltip: 'Manage Folders',
            onPressed: _showFolderSettings,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable:
            Hive.box<BookProgress>(ReaderService.progressBoxName).listenable(),
        builder: (context, Box<BookProgress> box, _) {
          final displayBooks = ReaderService.filterAndSortBooks(
            _books,
            query: _searchQuery,
            tab: _currentTab,
            sort: _currentSort,
          );

          final countAll = _books.length;
          final countRecent = _books.where((b) => b.progress != null).length;
          final countReading = _books.where((b) => b.isCurrentlyReading).length;
          final countFinished = _books.where((b) => b.isFinished).length;
          final countFavorites = _books.where((b) => b.isFavorite).length;

          return Column(
            children: [
              // Search input
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search documents by title...',
                    hintStyle: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(LucideIcons.search,
                        color: BentoTheme.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(LucideIcons.x,
                                color: BentoTheme.textSecondary, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: BentoTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Tabs Bar
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildTabChip('All', ReaderTab.all, countAll),
                    _buildTabChip('Recent', ReaderTab.recent, countRecent),
                    _buildTabChip('Reading', ReaderTab.reading, countReading),
                    _buildTabChip(
                        'Finished', ReaderTab.finished, countFinished),
                    _buildTabChip(
                        'Favorites', ReaderTab.favorites, countFavorites),
                  ],
                ),
              ),

              // Library Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: accent))
                    : (displayBooks.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.bookOpen,
                                        color: accent, size: 30),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No Documents in this Tab'
                                        : 'No documents matching "$_searchQuery"',
                                    style: TextStyle(
                                      color: BentoTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'Configure your folders or change the filter tab.'
                                        : 'Try another keyword or rescan your folders.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: BentoTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_books.isEmpty) ...[
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                      ),
                                      icon: const Icon(LucideIcons.filePlus,
                                          size: 18),
                                      label: const Text('Open PDF File',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      onPressed: _openSinglePdf,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: BentoTheme.textPrimary,
                                        side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.15)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 12),
                                      ),
                                      icon: const Icon(LucideIcons.folderPlus,
                                          size: 18),
                                      label: const Text('Add PDF Folder'),
                                      onPressed: _pickFolder,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: accent,
                            backgroundColor: BentoTheme.surface,
                            onRefresh: _loadBooks,
                            child: _isGridView
                                ? GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 8, 20, 40),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: 0.68,
                                    ),
                                    itemCount: displayBooks.length,
                                    itemBuilder: (context, index) {
                                      final book = displayBooks[index];
                                      return _buildBookGridItem(book);
                                    },
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 8, 20, 40),
                                    itemCount: displayBooks.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final book = displayBooks[index];
                                      return _buildBookListItem(book);
                                    },
                                  ),
                          )),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        icon: const Icon(LucideIcons.filePlus, size: 18),
        label: const Text('Open PDF',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openSinglePdf,
      ),
    );
  }

  Widget _buildTabChip(String label, ReaderTab tab, int count) {
    const accent = Color(0xFF38BDF8);
    final isSelected = _currentTab == tab;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : BentoTheme.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        selectedColor: accent,
        backgroundColor: BentoTheme.surface,
        checkmarkColor: Colors.black,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        onSelected: (_) {
          setState(() => _currentTab = tab);
        },
      ),
    );
  }

  Widget _buildBookGridItem(PdfBook book) {
    const accent = Color(0xFF38BDF8);

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfReaderPage(book: book),
              ),
            ).then((_) => _loadBooks());
          },
          onLongPress: () => _showBookActions(book),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover area with real thumbnail
                Expanded(
                  child: BookCoverThumbnail(
                    book: book,
                    showProgressBadge: true,
                    showSpine: true,
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        book.name,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.moreVertical, size: 14),
                      color: BentoTheme.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showBookActions(book),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Progress bar
                ProgressBarX(
                  value: book.progressFraction,
                  height: 3,
                  color: accent,
                ),
                const SizedBox(height: 4),
                // Details info (page & size)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'p. ${book.lastPage} / ${book.totalPages}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      book.formattedFileSize,
                      style: TextStyle(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookListItem(PdfBook book) {
    const accent = Color(0xFF38BDF8);

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusSm),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
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
          onLongPress: () => _showBookActions(book),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Thumbnail
                SizedBox(
                  width: 52,
                  height: 72,
                  child: BookCoverThumbnail(
                    book: book,
                    showProgressBadge: false,
                    showSpine: true,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              book.name,
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (book.isFavorite) ...[
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.heart,
                                color: Colors.redAccent, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Page ${book.lastPage} of ${book.totalPages} • ${(book.progressFraction * 100).toInt()}% complete',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ProgressBarX(
                        value: book.progressFraction,
                        height: 4,
                        color: accent,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            book.formattedFileSize,
                            style: TextStyle(
                              color: BentoTheme.textSecondary
                                  .withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                          if (book.totalReadingSeconds > 0) ...[
                            Text(
                              ' • Read ${book.formattedReadingTime}',
                              style: TextStyle(
                                color: accent.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing 3-dots
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                  color: BentoTheme.textSecondary,
                  onPressed: () => _showBookActions(book),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
