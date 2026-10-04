import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_service_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(35)) {
      Hive.registerAdapter(BookProgressAdapter());
    }
    await Hive.openBox<BookProgress>(ReaderService.progressBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box<BookProgress>(ReaderService.progressBoxName).clear();
  });

  group('ReaderService & PdfBook Upgrade Tests', () {
    test('PdfBook formatting helpers format size and time properly', () {
      final book1 = PdfBook(
        path: '/docs/small.pdf',
        name: 'small',
        sizeBytes: 512,
        modified: DateTime(2026, 1, 1),
      );
      expect(book1.formattedFileSize, '512 B');
      expect(book1.formattedReadingTime, '0s');

      final book2 = PdfBook(
        path: '/docs/med.pdf',
        name: 'med',
        sizeBytes: 250 * 1024,
        modified: DateTime(2026, 1, 1),
        progress: BookProgress(
          key: 'k2',
          lastOpened: DateTime(2026, 1, 1),
          totalReadingSeconds: 150,
        ),
      );
      expect(book2.formattedFileSize, '250.0 KB');
      expect(book2.formattedReadingTime, '2m');

      final book3 = PdfBook(
        path: '/docs/large.pdf',
        name: 'large',
        sizeBytes: 15 * 1024 * 1024,
        modified: DateTime(2026, 1, 1),
        progress: BookProgress(
          key: 'k3',
          lastOpened: DateTime(2026, 1, 1),
          totalReadingSeconds: 4500, // 1h 15m
        ),
      );
      expect(book3.formattedFileSize, '15.0 MB');
      expect(book3.formattedReadingTime, '1h 15m');
    });

    test('Reading state & back-to-previous-position history stack works', () async {
      const path = '/docs/textbook.pdf';

      // Record jumps: Page 142 -> Page 87
      await ReaderService.updateProgress(path, page: 142, totalPages: 400);
      await ReaderService.pushHistoryPage(path, 142);

      var progress = ReaderService.getProgress(path);
      expect(progress?.readingHistory, [142]);

      // Click reference jumping to Page 87
      await ReaderService.updateProgress(path, page: 87, totalPages: 400);

      // Back to previous position
      final prevPage = ReaderService.popHistoryPage(path, 87);
      expect(prevPage, 142);

      // History should now be empty
      progress = ReaderService.getProgress(path);
      expect(progress?.readingHistory.isEmpty, true);
    });

    test('Favorites and Finished toggling round-trip properly', () async {
      const path = '/docs/novel.pdf';
      await ReaderService.updateProgress(path, page: 20, totalPages: 100);

      expect(ReaderService.getProgress(path)?.isFavorite, false);
      expect(ReaderService.getProgress(path)?.isFinished, false);

      await ReaderService.toggleFavorite(path);
      expect(ReaderService.getProgress(path)?.isFavorite, true);

      await ReaderService.toggleFinished(path);
      expect(ReaderService.getProgress(path)?.isFinished, true);
      expect(ReaderService.getProgress(path)?.lastPage, 100);

      await ReaderService.resetProgress(path);
      expect(ReaderService.getProgress(path)?.lastPage, 1);
      expect(ReaderService.getProgress(path)?.isFinished, false);
    });

    test('Named bookmarks support notes and inline updating', () async {
      const path = '/docs/dsa.pdf';
      await ReaderService.updateProgress(path, page: 10, totalPages: 300);

      await ReaderService.toggleBookmark(path, 87, name: 'Linked Lists');
      await ReaderService.toggleBookmark(path, 143, name: 'Binary Trees');

      var progress = ReaderService.getProgress(path);
      expect(progress?.bookmarks, [87, 143]);
      expect(progress?.bookmarkNames[87], 'Linked Lists');
      expect(progress?.bookmarkNames[143], 'Binary Trees');

      // Update name
      await ReaderService.updateBookmarkName(path, 87, 'Doubly Linked Lists');
      progress = ReaderService.getProgress(path);
      expect(progress?.bookmarkNames[87], 'Doubly Linked Lists');

      // Untoggle bookmark
      await ReaderService.toggleBookmark(path, 143);
      progress = ReaderService.getProgress(path);
      expect(progress?.bookmarks, [87]);
      expect(progress?.bookmarkNames.containsKey(143), false);
    });

    test('filterAndSortBooks filters across All, Recent, Reading, Finished, Favorites', () {
      final b1 = PdfBook(
        path: '/docs/alpha.pdf',
        name: 'Alpha Guide',
        sizeBytes: 1000,
        modified: DateTime(2026, 1, 1),
        progress: BookProgress(
          key: 'k1',
          lastOpened: DateTime(2026, 1, 10),
          lastPage: 10,
          totalPages: 100,
          isFavorite: true,
        ),
      );

      final b2 = PdfBook(
        path: '/docs/beta.pdf',
        name: 'Beta Manual',
        sizeBytes: 5000,
        modified: DateTime(2026, 1, 2),
        progress: BookProgress(
          key: 'k2',
          lastOpened: DateTime(2026, 1, 15),
          lastPage: 100,
          totalPages: 100,
          isFinished: true,
        ),
      );

      final b3 = PdfBook(
        path: '/docs/gamma.pdf',
        name: 'Gamma Book',
        sizeBytes: 2000,
        modified: DateTime(2026, 1, 3),
        progress: null, // Unopened
      );

      final all = [b1, b2, b3];

      // Tab All
      expect(ReaderService.filterAndSortBooks(all, tab: ReaderTab.all).length, 3);

      // Tab Recent (opened)
      final recent = ReaderService.filterAndSortBooks(all, tab: ReaderTab.recent);
      expect(recent.length, 2);

      // Tab Reading (in progress)
      final reading = ReaderService.filterAndSortBooks(all, tab: ReaderTab.reading);
      expect(reading.length, 1);
      expect(reading.first.name, 'Alpha Guide');

      // Tab Finished
      final finished = ReaderService.filterAndSortBooks(all, tab: ReaderTab.finished);
      expect(finished.length, 1);
      expect(finished.first.name, 'Beta Manual');

      // Tab Favorites
      final favs = ReaderService.filterAndSortBooks(all, tab: ReaderTab.favorites);
      expect(favs.length, 1);
      expect(favs.first.name, 'Alpha Guide');

      // Search Query
      final search = ReaderService.filterAndSortBooks(all, query: 'manual');
      expect(search.length, 1);
      expect(search.first.name, 'Beta Manual');

      // Sort by Name Asc
      final sortedByName = ReaderService.filterAndSortBooks(all, sort: ReaderSort.nameAsc);
      expect(sortedByName.first.name, 'Alpha Guide');
      expect(sortedByName.last.name, 'Gamma Book');

      // Sort by File Size Desc
      final sortedBySize = ReaderService.filterAndSortBooks(all, sort: ReaderSort.fileSizeDesc);
      expect(sortedBySize.first.name, 'Beta Manual');
      expect(sortedBySize.last.name, 'Alpha Guide');
    });
  });
}
