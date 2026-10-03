import 'package:hive/hive.dart';

part 'productivity_models.g.dart';

@HiveType(typeId: 33)
class JournalEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String bodyDelta; // JSON encoded Quill Delta

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  bool pinned;

  @HiveField(6)
  List<String> tags;

  JournalEntry({
    required this.id,
    required this.title,
    required this.bodyDelta,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.tags = const [],
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    String? bodyDelta,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pinned,
    List<String>? tags,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      bodyDelta: bodyDelta ?? this.bodyDelta,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      tags: tags ?? this.tags,
    );
  }
}

@HiveType(typeId: 34)
class Idea extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  Idea({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Idea copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Idea(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@HiveType(typeId: 35)
class BookProgress extends HiveObject {
  @override
  @HiveField(0)
  final String key; // Hash or normalized path

  @HiveField(1)
  int lastPage;

  @HiveField(2)
  int totalPages;

  @HiveField(3)
  List<int> bookmarks;

  @HiveField(4)
  DateTime lastOpened;

  BookProgress({
    required this.key,
    this.lastPage = 1,
    this.totalPages = 1,
    this.bookmarks = const [],
    required this.lastOpened,
  });

  BookProgress copyWith({
    String? key,
    int? lastPage,
    int? totalPages,
    List<int>? bookmarks,
    DateTime? lastOpened,
  }) {
    return BookProgress(
      key: key ?? this.key,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages ?? this.totalPages,
      bookmarks: bookmarks ?? this.bookmarks,
      lastOpened: lastOpened ?? this.lastOpened,
    );
  }
}
