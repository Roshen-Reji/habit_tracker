import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  double get progressFraction =>
      totalPages > 0 ? (lastPage / totalPages).clamp(0.0, 1.0) : 0.0;
}

class ReaderService {
  static const String progressBoxName = 'reader_progress';
  static const String foldersSettingsKey = 'reader_folders';

  /// Generates a stable deterministic key for a book path.
  static String getBookKey(String path) {
    return md5.convert(utf8.encode(path.toLowerCase())).toString();
  }

  /// Generates a deterministic cache key for a book cover based on path and modified time.
  static String getCoverCacheKey(String path, DateTime mtime) {
    final input = '${path.toLowerCase()}_${mtime.millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Requests all-files storage permission on Android (Default §5.9).
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

    // Sort: recently opened first, then by modified desc
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

  /// Asynchronous folder scanner that can be run on compute isolate.
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

    Box<BookProgress>? progressBox;
    if (Hive.isBoxOpen(progressBoxName)) {
      progressBox = Hive.box<BookProgress>(progressBoxName);
    }

    return scanFoldersSync(
      folderPaths,
      progressBox: progressBox,
    );
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

  // --- Reading Progress & Bookmarks ---

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
    );

    await box.put(key, progress);
  }

  static Future<void> toggleBookmark(String path, int page) async {
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
    if (bookmarks.contains(page)) {
      bookmarks.remove(page);
    } else {
      bookmarks.add(page);
      bookmarks.sort();
    }

    existing.bookmarks = bookmarks;
    existing.lastOpened = DateTime.now();
    await existing.save();
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
}
