import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum ReaderTab {
  all,
  recent,
  reading,
  finished,
  favorites,
}

enum ReaderSort {
  lastOpenedDesc,
  nameAsc,
  nameDesc,
  dateModifiedDesc,
  fileSizeDesc,
  progressDesc,
}

class PdfBook {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;
  final BookProgress? progress;

  const PdfBook({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
    this.progress,
  });

  String get bookKey => ReaderService.getBookKey(path);
  int get lastPage => progress?.lastPage ?? 1;
  int get totalPages => progress?.totalPages ?? 1;
  bool get isFavorite => progress?.isFavorite ?? false;
  bool get isFinished => progress?.isFinished ?? false;
  int get totalReadingSeconds => progress?.totalReadingSeconds ?? 0;
  String get viewMode => progress?.viewMode ?? 'continuous';
  String get themeMode => progress?.themeMode ?? 'dark';
  List<int> get bookmarks => progress?.bookmarks ?? const [];
  Map<int, String> get bookmarkNames => progress?.bookmarkNames ?? const {};
  List<int> get readingHistory => progress?.readingHistory ?? const [];

  double get progressFraction {
    if (isFinished) return 1.0;
    return totalPages > 0 ? (lastPage / totalPages).clamp(0.0, 1.0) : 0.0;
  }

  bool get isCurrentlyReading =>
      (progressFraction > 0.0 && progressFraction < 1.0) && !isFinished;

  String get formattedFileSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedReadingTime {
    if (totalReadingSeconds < 60) return '${totalReadingSeconds}s';
    final minutes = totalReadingSeconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remM = minutes % 60;
    return '${hours}h ${remM}m';
  }

  PdfBook copyWith({
    String? path,
    String? name,
    int? sizeBytes,
    DateTime? modified,
    BookProgress? progress,
  }) {
    return PdfBook(
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modified: modified ?? this.modified,
      progress: progress ?? this.progress,
    );
  }
}

class ReaderService {
  static const String progressBoxName = 'reader_progress';
  static const String foldersSettingsKey = 'reader_folders';
  static const String filesSettingsKey = 'reader_files';

  /// Generates a stable deterministic key for a book path.
  static String getBookKey(String path) {
    return md5.convert(utf8.encode(path.toLowerCase())).toString();
  }

  /// Generates a deterministic cache key for a book cover based on path and modified time.
  static String getCoverCacheKey(String path, DateTime mtime) {
    final input = '${path.toLowerCase()}_${mtime.millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Requests all-files storage permission on Android.
  static Future<bool> requestStorageAccess() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final status = await Permission.manageExternalStorage.status;
        if (status.isGranted) return true;
        final res = await Permission.manageExternalStorage.request();
        if (res.isGranted) return true;
      } catch (_) {}

      try {
        final storageRes = await Permission.storage.request();
        return storageRes.isGranted;
      } catch (_) {}
    }
    return true;
  }

  static bool _pdfrxInitialized = false;

  /// Ensures that pdfrx native engine and cache directory are properly initialized.
  static Future<void> ensurePdfrxInitialized() async {
    if (_pdfrxInitialized && Pdfrx.cacheDirectoryPath != null) return;
    try {
      await pdfrxFlutterInitialize();
      _pdfrxInitialized = true;
    } catch (e) {
      debugPrint('pdfrxFlutterInitialize error: $e');
    }
    if (Pdfrx.cacheDirectoryPath == null) {
      try {
        final tempDir = await getTemporaryDirectory();
        Pdfrx.cacheDirectoryPath = tempDir.path;
      } catch (_) {}
    }
  }

  /// Ensures that a PDF file is accessible to the app. If the file is on external storage
  /// or inaccessible via native posix, it copies or links it into the app's persistent sandbox.
  static Future<String> ensureFileInSandbox(String originalPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(appDir.path, 'pdf_books'));
      if (!booksDir.existsSync()) {
        booksDir.createSync(recursive: true);
      }

      final normOriginal = p.normalize(originalPath);
      final normBooksDir = p.normalize(booksDir.path);

      if (p.isWithin(normBooksDir, normOriginal)) {
        return normOriginal;
      }

      final originalFile = File(normOriginal);
      final fileName = p.basename(normOriginal);
      final targetPath = p.join(booksDir.path, fileName);
      final targetFile = File(targetPath);

      if (originalFile.existsSync()) {
        if (!targetFile.existsSync() || targetFile.lengthSync() != originalFile.lengthSync()) {
          if (targetFile.existsSync()) {
            try {
              targetFile.deleteSync();
            } catch (_) {}
          }
          await originalFile.copy(targetPath);
        }
        await addFile(targetPath);
        return targetPath;
      } else if (targetFile.existsSync()) {
        return targetPath;
      }
    } catch (e) {
      debugPrint('ensureFileInSandbox warning: $e');
    }
    return originalPath;
  }

  /// Scans configured directories recursively for PDF files.
  static List<PdfBook> scanFoldersSync(
    List<String> folderPaths, {
    int maxDepth = 4,
    int maxCount = 200,
    Box<BookProgress>? progressBox,
  }) {
    final List<PdfBook> books = [];
    final Set<String> seenPaths = {};

    for (final folderPath in folderPaths) {
      if (books.length >= maxCount) break;
      final dir = Directory(folderPath);
      if (!dir.existsSync()) continue;

      _scanDirectory(
        dir,
        currentDepth: 0,
        maxDepth: maxDepth,
        maxCount: maxCount,
        results: books,
        seenPaths: seenPaths,
        progressBox: progressBox,
      );
    }

    // Sort default: recently opened first, then by modified desc
    books.sort((a, b) {
      final aOpened = a.progress?.lastOpened;
      final bOpened = b.progress?.lastOpened;
      if (aOpened != null && bOpened != null) {
        return bOpened.compareTo(aOpened);
      }
      if (aOpened != null) return -1;
      if (bOpened != null) return 1;
      return b.modified.compareTo(a.modified);
    });

    return books;
  }

  static void _scanDirectory(
    Directory dir, {
    required int currentDepth,
    required int maxDepth,
    required int maxCount,
    required List<PdfBook> results,
    required Set<String> seenPaths,
    Box<BookProgress>? progressBox,
  }) {
    if (currentDepth > maxDepth || results.length >= maxCount) return;

    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        if (results.length >= maxCount) break;

        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.pdf') {
            final normalized = p.normalize(entity.path);
            if (!seenPaths.contains(normalized)) {
              seenPaths.add(normalized);
              final stat = entity.statSync();
              final key = getBookKey(normalized);
              final progress = progressBox?.get(key);

              results.add(PdfBook(
                path: normalized,
                name: p.basenameWithoutExtension(entity.path),
                sizeBytes: stat.size,
                modified: stat.modified,
                progress: progress,
              ));
            }
          }
        } else if (entity is Directory) {
          final dirName = p.basename(entity.path);
          // Skip hidden and system directories
          if (!dirName.startsWith('.')) {
            _scanDirectory(
              entity,
              currentDepth: currentDepth + 1,
              maxDepth: maxDepth,
              maxCount: maxCount,
              results: results,
              seenPaths: seenPaths,
              progressBox: progressBox,
            );
          }
        }
      }
    } catch (_) {
      // Permission denied or unreadable directory
    }
  }

  /// Asynchronous folder scanner that also includes individually imported PDFs
  /// and the app's persistent documents pdf_books directory.
  static Future<List<PdfBook>> scanConfiguredFolders() async {
    final settingsBox = Hive.box('settings');
    final rawFolders = settingsBox.get(foldersSettingsKey);
    final List<String> folderPaths = [];

    if (rawFolders is List) {
      for (final f in rawFolders) {
        if (f != null && f.toString().isNotEmpty) {
          folderPaths.add(f.toString());
        }
      }
    }

    // Automatically check the persistent app storage directory for imported PDFs
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final internalBooksDir = Directory(p.join(appDir.path, 'pdf_books'));
      if (internalBooksDir.existsSync()) {
        final norm = p.normalize(internalBooksDir.path);
        if (!folderPaths.contains(norm)) {
          folderPaths.add(norm);
        }
      }
    } catch (_) {}

    Box<BookProgress>? progressBox;
    if (Hive.isBoxOpen(progressBoxName)) {
      progressBox = Hive.box<BookProgress>(progressBoxName);
    }

    final books = scanFoldersSync(
      folderPaths,
      progressBox: progressBox,
    );

    // Also include any individually registered files
    final seenPaths = books.map((b) => b.path).toSet();
    final individualFiles = getConfiguredFiles();
    for (final filePath in individualFiles) {
      if (!seenPaths.contains(filePath)) {
        final file = File(filePath);
        if (file.existsSync()) {
          seenPaths.add(filePath);
          final stat = file.statSync();
          final key = getBookKey(filePath);
          final progress = progressBox?.get(key);

          books.add(PdfBook(
            path: filePath,
            name: p.basenameWithoutExtension(filePath),
            sizeBytes: stat.size,
            modified: stat.modified,
            progress: progress,
          ));
        }
      }
    }

    return books;
  }

  /// Gets the local disk path for a cached PDF cover thumbnail.
  static Future<File> getCoverCacheFile(String pdfPath, DateTime mtime) async {
    final cacheDir = await getTemporaryDirectory();
    final coversDir = Directory(p.join(cacheDir.path, 'pdf_covers'));
    if (!coversDir.existsSync()) {
      coversDir.createSync(recursive: true);
    }
    final key = getCoverCacheKey(pdfPath, mtime);
    return File(p.join(coversDir.path, '$key.png'));
  }

  /// Generates and caches page 1 of the PDF as a cover thumbnail.
  static Future<File?> getOrCreateCoverThumbnail(
    String pdfPath,
    DateTime mtime,
  ) async {
    try {
      await ensurePdfrxInitialized();

      final cacheFile = await getCoverCacheFile(pdfPath, mtime);
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 0) {
        return cacheFile;
      }

      final resolvedPath = await ensureFileInSandbox(pdfPath);
      final file = File(resolvedPath);
      if (!file.existsSync()) return null;

      PdfDocument? doc;
      try {
        doc = await PdfDocument.openFile(resolvedPath);
      } catch (e) {
        debugPrint('PdfDocument.openFile thumbnail fallback: $e');
        try {
          final bytes = await file.readAsBytes();
          doc = await PdfDocument.openData(bytes);
        } catch (e2) {
          debugPrint('PdfDocument.openData thumbnail error: $e2');
          return null;
        }
      }

      if (doc.pages.isEmpty) {
        await doc.dispose();
        return null;
      }

      try {
        final page = doc.pages[0];
        const double targetWidth = 280;
        final double targetHeight = (page.height / page.width) * targetWidth;

        final pdfImage = await page.render(
          fullWidth: targetWidth,
          fullHeight: targetHeight,
        );

        if (pdfImage == null) {
          return null;
        }

        final image = img.Image.fromBytes(
          width: pdfImage.width,
          height: pdfImage.height,
          bytes: pdfImage.pixels.buffer,
          order: img.ChannelOrder.bgra,
        );

        final pngBytes = img.encodePng(image);
        await cacheFile.writeAsBytes(pngBytes, flush: true);

        pdfImage.dispose();
        return cacheFile;
      } finally {
        await doc.dispose();
      }
    } catch (e) {
      debugPrint('Error generating PDF thumbnail: $e');
      return null;
    }
  }

  // --- Reading Progress, State & Bookmarks ---

  static BookProgress? getProgress(String path) {
    if (!Hive.isBoxOpen(progressBoxName)) return null;
    final key = getBookKey(path);
    return Hive.box<BookProgress>(progressBoxName).get(key);
  }

  static Future<void> updateProgress(
    String path, {
    required int page,
    required int totalPages,
  }) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);

    final progress = BookProgress(
      key: key,
      lastPage: page,
      totalPages: totalPages > 0 ? totalPages : (existing?.totalPages ?? 1),
      bookmarks: existing?.bookmarks ?? [],
      lastOpened: DateTime.now(),
      isFavorite: existing?.isFavorite ?? false,
      isFinished:
          existing?.isFinished ?? (totalPages > 0 && page >= totalPages),
      bookmarkNames: existing?.bookmarkNames ?? {},
      totalReadingSeconds: existing?.totalReadingSeconds ?? 0,
      viewMode: existing?.viewMode ?? 'continuous',
      themeMode: existing?.themeMode ?? 'dark',
      readingHistory: existing?.readingHistory ?? [],
    );

    await box.put(key, progress);
  }

  static Future<void> toggleFavorite(String path) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key) ??
        BookProgress(
          key: key,
          lastPage: 1,
          totalPages: 1,
          bookmarks: [],
          lastOpened: DateTime.now(),
        );

    existing.isFavorite = !existing.isFavorite;
    await box.put(key, existing);
  }

  static Future<void> toggleFinished(String path) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key) ??
        BookProgress(
          key: key,
          lastPage: 1,
          totalPages: 1,
          bookmarks: [],
          lastOpened: DateTime.now(),
        );

    existing.isFinished = !existing.isFinished;
    if (existing.isFinished && existing.totalPages > 0) {
      existing.lastPage = existing.totalPages;
    }
    await box.put(key, existing);
  }

  static Future<void> resetProgress(String path) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing != null) {
      existing.lastPage = 1;
      existing.isFinished = false;
      await existing.save();
    }
  }

  static Future<void> addReadingTime(String path, int seconds) async {
    if (!Hive.isBoxOpen(progressBoxName) || seconds <= 0) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing != null) {
      existing.totalReadingSeconds += seconds;
      await existing.save();
    }
  }

  static Future<void> setViewMode(String path, String mode) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing != null) {
      existing.viewMode = mode;
      await existing.save();
    }
  }

  static Future<void> setThemeMode(String path, String theme) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing != null) {
      existing.themeMode = theme;
      await existing.save();
    }
  }

  static Future<void> pushHistoryPage(String path, int page) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing != null) {
      final history = List<int>.from(existing.readingHistory);
      if (history.isNotEmpty && history.last == page) return;
      history.add(page);
      if (history.length > 25) {
        history.removeRange(0, history.length - 25);
      }
      existing.readingHistory = history;
      await existing.save();
    }
  }

  static int? popHistoryPage(String path, int currentPage) {
    if (!Hive.isBoxOpen(progressBoxName)) return null;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing == null) return null;

    final history = List<int>.from(existing.readingHistory);
    // Find the last page in history that is not currentPage
    while (history.isNotEmpty) {
      final candidate = history.removeLast();
      if (candidate != currentPage) {
        existing.readingHistory = history;
        existing.save();
        return candidate;
      }
    }
    return null;
  }

  static Future<void> toggleBookmark(
    String path,
    int page, {
    String? name,
  }) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key) ??
        BookProgress(
          key: key,
          lastPage: page,
          totalPages: 1,
          bookmarks: [],
          lastOpened: DateTime.now(),
        );

    final bookmarks = List<int>.from(existing.bookmarks);
    final bookmarkNames = Map<int, String>.from(existing.bookmarkNames);

    if (bookmarks.contains(page)) {
      bookmarks.remove(page);
      bookmarkNames.remove(page);
    } else {
      bookmarks.add(page);
      bookmarks.sort();
      if (name != null && name.trim().isNotEmpty) {
        bookmarkNames[page] = name.trim();
      }
    }

    existing.bookmarks = bookmarks;
    existing.bookmarkNames = bookmarkNames;
    existing.lastOpened = DateTime.now();
    await box.put(key, existing);
  }

  static Future<void> updateBookmarkName(
    String path,
    int page,
    String name,
  ) async {
    if (!Hive.isBoxOpen(progressBoxName)) return;
    final box = Hive.box<BookProgress>(progressBoxName);
    final key = getBookKey(path);
    final existing = box.get(key);
    if (existing != null) {
      final names = Map<int, String>.from(existing.bookmarkNames);
      if (name.trim().isEmpty) {
        names.remove(page);
      } else {
        names[page] = name.trim();
      }
      existing.bookmarkNames = names;
      await existing.save();
    }
  }

  static Future<bool> deletePdfFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      if (Hive.isBoxOpen(progressBoxName)) {
        final key = getBookKey(path);
        await Hive.box<BookProgress>(progressBoxName).delete(key);
      }
      await removeFile(path);
      return true;
    } catch (e) {
      debugPrint('Error deleting PDF: $e');
      return false;
    }
  }

  // --- Folder Management ---

  static List<String> getConfiguredFolders() {
    if (!Hive.isBoxOpen('settings')) return [];
    final raw = Hive.box('settings').get(foldersSettingsKey);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Future<void> addFolder(String path) async {
    final box = Hive.box('settings');
    final folders = getConfiguredFolders();
    final normalized = p.normalize(path);
    if (!folders.contains(normalized)) {
      folders.add(normalized);
      await box.put(foldersSettingsKey, folders);
    }
  }

  static Future<void> removeFolder(String path) async {
    final box = Hive.box('settings');
    final folders = getConfiguredFolders();
    final normalized = p.normalize(path);
    folders.remove(normalized);
    await box.put(foldersSettingsKey, folders);
  }

  // --- Single File Management ---

  static List<String> getConfiguredFiles() {
    if (!Hive.isBoxOpen('settings')) return [];
    final raw = Hive.box('settings').get(filesSettingsKey);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Future<void> addFile(String path) async {
    final box = Hive.box('settings');
    final files = getConfiguredFiles();
    final normalized = p.normalize(path);
    if (!files.contains(normalized)) {
      files.add(normalized);
      await box.put(filesSettingsKey, files);
    }
  }

  static Future<void> removeFile(String path) async {
    final box = Hive.box('settings');
    final files = getConfiguredFiles();
    final normalized = p.normalize(path);
    files.remove(normalized);
    await box.put(filesSettingsKey, files);
  }

  /// Opens the system file picker for the user to select any PDF file,
  /// copies it into the app's persistent storage sandbox, registers it,
  /// and returns the resulting PdfBook ready for viewing.
  static Future<PdfBook?> importPdfFromPicker() async {
    try {
      await ensurePdfrxInitialized();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.single;
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(appDir.path, 'pdf_books'));
      if (!booksDir.existsSync()) {
        booksDir.createSync(recursive: true);
      }

      String fileName = pickedFile.name;
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }
      fileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final targetPath = p.join(booksDir.path, fileName);
      final targetFile = File(targetPath);

      if (targetFile.existsSync()) {
        try {
          targetFile.deleteSync();
        } catch (_) {}
      }

      if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
        await targetFile.writeAsBytes(pickedFile.bytes!, flush: true);
      } else if (pickedFile.path != null && File(pickedFile.path!).existsSync()) {
        final sourceFile = File(pickedFile.path!);
        await sourceFile.copy(targetPath);
      } else if (pickedFile.readStream != null) {
        final sink = targetFile.openWrite();
        await sink.addStream(pickedFile.readStream!);
        await sink.close();
      } else {
        debugPrint('FilePicker returned no accessible data or path');
        return null;
      }

      if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
        debugPrint('Imported file is empty or missing after write');
        return null;
      }

      await addFile(targetFile.path);

      final stat = targetFile.statSync();
      final key = getBookKey(targetFile.path);
      Box<BookProgress>? progressBox;
      if (Hive.isBoxOpen(progressBoxName)) {
        progressBox = Hive.box<BookProgress>(progressBoxName);
      }
      final progress = progressBox?.get(key);

      return PdfBook(
        path: targetFile.path,
        name: p.basenameWithoutExtension(targetFile.path),
        sizeBytes: stat.size,
        modified: stat.modified,
        progress: progress,
      );
    } catch (e) {
      debugPrint('Error importing PDF from picker: $e');
      return null;
    }
  }

  // --- Filtering & Sorting ---

  static List<PdfBook> filterAndSortBooks(
    List<PdfBook> books, {
    String query = '',
    ReaderTab tab = ReaderTab.all,
    ReaderSort sort = ReaderSort.lastOpenedDesc,
  }) {
    // 1. Filter by Query
    final filtered = books.where((book) {
      if (query.isNotEmpty &&
          !book.name.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }

      switch (tab) {
        case ReaderTab.all:
          return true;
        case ReaderTab.recent:
          return book.progress != null;
        case ReaderTab.reading:
          return book.isCurrentlyReading;
        case ReaderTab.finished:
          return book.isFinished;
        case ReaderTab.favorites:
          return book.isFavorite;
      }
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      switch (sort) {
        case ReaderSort.lastOpenedDesc:
          final aOpened = a.progress?.lastOpened;
          final bOpened = b.progress?.lastOpened;
          if (aOpened != null && bOpened != null) {
            return bOpened.compareTo(aOpened);
          }
          if (aOpened != null) return -1;
          if (bOpened != null) return 1;
          return b.modified.compareTo(a.modified);
        case ReaderSort.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ReaderSort.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case ReaderSort.dateModifiedDesc:
          return b.modified.compareTo(a.modified);
        case ReaderSort.fileSizeDesc:
          return b.sizeBytes.compareTo(a.sizeBytes);
        case ReaderSort.progressDesc:
          return b.progressFraction.compareTo(a.progressFraction);
      }
    });

    return filtered;
  }
}
