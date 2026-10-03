import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:habit_tracker/features/reader/pdf_reader_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderLibraryPage extends StatefulWidget {
  const ReaderLibraryPage({super.key});

  @override
  State<ReaderLibraryPage> createState() => _ReaderLibraryPageState();
}

class _ReaderLibraryPageState extends State<ReaderLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PdfBook> _books = [];
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38BDF8); // Sky blue accent

    final filtered = _books.where((book) {
      if (_searchQuery.isEmpty) return true;
      return book.name.toLowerCase().contains(_searchQuery);
    }).toList();

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
          'DOCUMENT READER',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.folderCog, color: accent),
            tooltip: 'Manage Folders',
            onPressed: _showFolderSettings,
          ),
          IconButton(
            icon: Icon(LucideIcons.refreshCw,
                color: BentoTheme.textSecondary, size: 20),
            tooltip: 'Rescan Folders',
            onPressed: _loadBooks,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable:
            Hive.box<BookProgress>(ReaderService.progressBoxName).listenable(),
        builder: (context, Box<BookProgress> box, _) {
          return Column(
            children: [
              // Search input
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search documents & books...',
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.6)),
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

              // Library Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: accent))
                    : (filtered.isEmpty
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
                                        ? 'No PDF Documents Found'
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
                                        ? 'Add a directory with PDF files in Settings to start reading.'
                                        : 'Try another keyword or rescan your folders.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: BentoTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        foregroundColor: Colors.black,
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
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final book = filtered[index];
                              return _buildBookGridItem(book);
                            },
                          )),
              ),
            ],
          );
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusSm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          LucideIcons.fileText,
                          color: accent.withValues(alpha: 0.4),
                          size: 42,
                        ),
                        if (book.progress != null &&
                            book.progress!.bookmarks.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              LucideIcons.bookmarkCheck,
                              color: accent,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  book.name,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Progress
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: book.progressFraction,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(book.progressFraction * 100).toInt()}%',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
}
