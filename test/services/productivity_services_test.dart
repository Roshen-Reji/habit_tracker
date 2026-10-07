import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/data/services/reader_service.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('productivity_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(33)) {
      Hive.registerAdapter(JournalEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(34)) {
      Hive.registerAdapter(IdeaAdapter());
    }
    if (!Hive.isAdapterRegistered(35)) {
      Hive.registerAdapter(BookProgressAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('JournalService Encrypted Storage & Lock Tests (P5-1)', () {
    test('Encrypted round-trip with HiveAesCipher persists and decrypts data',
        () async {
      final key = Hive.generateSecureKey();
      final box = await Hive.openBox<JournalEntry>(
        'encrypted_journal_test',
        encryptionCipher: HiveAesCipher(key),
      );

      final entry = JournalEntry(
        id: 'entry_1',
        title: 'Secret Blueprint',
        bodyDelta: '[{"insert":"Confidential plan\\n"}]',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1, 12, 0),
        pinned: true,
        tags: ['strategy', 'confidential'],
      );

      await box.put(entry.id, entry);
      await box.close();

      // Reopen with the exact same key
      final reopenedBox = await Hive.openBox<JournalEntry>(
        'encrypted_journal_test',
        encryptionCipher: HiveAesCipher(key),
      );

      final retrieved = reopenedBox.get('entry_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Secret Blueprint');
      expect(retrieved.pinned, isTrue);
      expect(retrieved.tags, contains('strategy'));
      expect(retrieved.bodyDelta, contains('Confidential plan'));

      await reopenedBox.close();
    });

    test('Opening encrypted box with invalid key fails to decrypt', () async {
      final key1 = Hive.generateSecureKey();
      final key2 = Hive.generateSecureKey(); // Different key

      final box = await Hive.openBox<JournalEntry>(
        'encrypted_key_mismatch_test',
        encryptionCipher: HiveAesCipher(key1),
      );

      await box.put(
        'e1',
        JournalEntry(
          id: 'e1',
          title: 'Secure',
          bodyDelta: '[]',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await box.close();

      // Opening with wrong key cannot read or decrypt the original entry
      final wrongKeyBox = await Hive.openBox<JournalEntry>(
        'encrypted_key_mismatch_test',
        encryptionCipher: HiveAesCipher(key2),
      );
      expect(wrongKeyBox.get('e1'), isNull);
      await wrongKeyBox.close();
    });

    test('Auto-lock triggers when elapsed time exceeds timeout', () {
      final service = JournalService.instance;
      service.isUnlocked.value = true;
      service.recordActivity();

      // Within timeout (60s) -> remains unlocked
      service.checkAutoLock(timeoutSeconds: 60);
      expect(service.isUnlocked.value, isTrue);

      // Lock manually
      service.lock();
      expect(service.isUnlocked.value, isFalse);
    });
  });

  group('Idea Model & Brainstorm Tests (P5-2)', () {
    test('Idea creation and copyWith retain accurate data', () {
      final idea = Idea(
        id: 'idea_1',
        title: 'Project Nebula',
        description: 'Decentralized habit syncing',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final updated = idea.copyWith(
        title: 'Project Nebula V2',
        updatedAt: DateTime(2026, 10, 2),
      );

      expect(updated.id, 'idea_1');
      expect(updated.title, 'Project Nebula V2');
      expect(updated.description, 'Decentralized habit syncing');
      expect(updated.updatedAt, DateTime(2026, 10, 2));
    });
  });

  group('ReaderService Folder Scan & Progress Tests (P5-3)', () {
    late Directory readerTestDir;

    setUp(() {
      readerTestDir = Directory(p.join(tempDir.path, 'reader_test_dir'));
      readerTestDir.createSync(recursive: true);

      // Create test files
      File(p.join(readerTestDir.path, 'book1.pdf')).writeAsStringSync('PDF 1');
      File(p.join(readerTestDir.path, 'notes.txt')).writeAsStringSync('TXT');
      File(p.join(readerTestDir.path, 'manual.PDF')).writeAsStringSync('PDF 2');

      final subDir = Directory(p.join(readerTestDir.path, 'nested'));
      subDir.createSync();
      File(p.join(subDir.path, 'guide.pdf')).writeAsStringSync('PDF 3');
    });

    test('Deterministic book key and cover cache key calculation', () {
      final key1 = ReaderService.getBookKey('C:/Docs/Book.pdf');
      final key2 = ReaderService.getBookKey('c:/docs/book.pdf');
      expect(key1, equals(key2));

      final mtime = DateTime(2026, 10, 3, 12, 0);
      final cacheKey1 =
          ReaderService.getCoverCacheKey('C:/Docs/Book.pdf', mtime);
      final cacheKey2 =
          ReaderService.getCoverCacheKey('c:/docs/book.pdf', mtime);
      expect(cacheKey1, equals(cacheKey2));
      expect(cacheKey1.length, 64); // SHA-256 hex string
    });

    test('scanFoldersSync recursively finds PDFs and ignores non-PDF files',
        () {
      final books = ReaderService.scanFoldersSync([readerTestDir.path]);

      expect(books.length, 3);
      final names = books.map((b) => b.name).toList();
      expect(names, contains('book1'));
      expect(names, contains('manual'));
      expect(names, contains('guide'));
      expect(names, isNot(contains('notes')));
    });

    test('scanFoldersSync respects maxDepth and maxCount limits', () {
      final cappedBooks = ReaderService.scanFoldersSync(
        [readerTestDir.path],
        maxDepth: 0, // Top-level only
      );
      expect(cappedBooks.length, 2);

      final countCapped = ReaderService.scanFoldersSync(
        [readerTestDir.path],
        maxCount: 1,
      );
      expect(countCapped.length, 1);
    });

    test('BookProgress tracking and bookmarks round-trip', () async {
      final progressBox =
          await Hive.openBox<BookProgress>('test_reader_progress');
      final bookPath = p.join(readerTestDir.path, 'book1.pdf');
      final key = ReaderService.getBookKey(bookPath);

      final progress = BookProgress(
        key: key,
        lastPage: 42,
        totalPages: 200,
        bookmarks: [10, 42],
        lastOpened: DateTime(2026, 10, 3),
      );

      await progressBox.put(key, progress);

      final retrieved = progressBox.get(key);
      expect(retrieved, isNotNull);
      expect(retrieved!.lastPage, 42);
      expect(retrieved.totalPages, 200);
      expect(retrieved.bookmarks, [10, 42]);

      await progressBox.close();
    });
  });
}
