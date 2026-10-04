// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_group.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SplitGroupAdapter extends TypeAdapter<SplitGroup> {
  @override
  final int typeId = 49;

  @override
  SplitGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SplitGroup(
      id: fields[0] as String,
      name: fields[1] as String,
      kind: fields[2] as String,
      members: (fields[3] as List).cast<String>(),
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SplitGroup obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.members)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
