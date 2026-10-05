// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'productivity_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 33;

  @override
  JournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      bodyDelta: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      pinned: fields[5] as bool,
      tags: (fields[6] as List).cast<String>(),
      dayKey: fields[7] as String?,
      autoLogJson: fields[8] as String?,
      mergedInto: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.bodyDelta)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.pinned)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.dayKey)
      ..writeByte(8)
      ..write(obj.autoLogJson)
      ..writeByte(9)
      ..write(obj.mergedInto);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IdeaAdapter extends TypeAdapter<Idea> {
  @override
  final int typeId = 34;

  @override
  Idea read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Idea(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Idea obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdeaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookProgressAdapter extends TypeAdapter<BookProgress> {
  @override
  final int typeId = 35;

  @override
  BookProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookProgress(
      key: fields[0] as String,
      lastPage: fields[1] as int,
      totalPages: fields[2] as int,
      bookmarks: (fields[3] as List).cast<int>(),
      lastOpened: fields[4] as DateTime,
      isFavorite: fields[5] as bool,
      isFinished: fields[6] as bool,
      bookmarkNames: (fields[7] as Map).cast<int, String>(),
      totalReadingSeconds: fields[8] as int,
      viewMode: fields[9] as String,
      themeMode: fields[10] as String,
      readingHistory: (fields[11] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, BookProgress obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.lastPage)
      ..writeByte(2)
      ..write(obj.totalPages)
      ..writeByte(3)
      ..write(obj.bookmarks)
      ..writeByte(4)
      ..write(obj.lastOpened)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.isFinished)
      ..writeByte(7)
      ..write(obj.bookmarkNames)
      ..writeByte(8)
      ..write(obj.totalReadingSeconds)
      ..writeByte(9)
      ..write(obj.viewMode)
      ..writeByte(10)
      ..write(obj.themeMode)
      ..writeByte(11)
      ..write(obj.readingHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
