// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryRuleAdapter extends TypeAdapter<CategoryRule> {
  @override
  final int typeId = 42;

  @override
  CategoryRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryRule(
      id: fields[0] as String,
      pattern: fields[1] as String,
      matchType: fields[2] as String,
      categoryId: fields[3] as String,
      priority: fields[4] as int,
      createdFromCorrection: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryRule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pattern)
      ..writeByte(2)
      ..write(obj.matchType)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.createdFromCorrection);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
