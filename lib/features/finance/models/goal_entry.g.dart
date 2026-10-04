// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalEntryAdapter extends TypeAdapter<GoalEntry> {
  @override
  final int typeId = 47;

  @override
  GoalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalEntry(
      id: fields[0] as String,
      goalId: fields[1] as String,
      date: fields[2] as DateTime,
      amount: fields[3] as double,
      note: fields[4] as String?,
      sourceRef: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, GoalEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goalId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.sourceRef);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
