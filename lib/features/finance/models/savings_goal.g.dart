// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavingsGoalAdapter extends TypeAdapter<SavingsGoal> {
  @override
  final int typeId = 46;

  @override
  SavingsGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavingsGoal(
      id: fields[0] as String,
      name: fields[1] as String,
      kind: fields[2] as String,
      targetAmount: fields[3] as double,
      deadline: fields[4] as DateTime?,
      dueDate: fields[5] as DateTime?,
      accountId: fields[6] as String?,
      colorValue: fields[7] as int,
      priority: fields[8] as int,
      autoContribute: fields[9] as bool,
      plannedMonthly: fields[10] as double?,
      linkedCategoryId: fields[11] as String?,
      archived: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SavingsGoal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.deadline)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.accountId)
      ..writeByte(7)
      ..write(obj.colorValue)
      ..writeByte(8)
      ..write(obj.priority)
      ..writeByte(9)
      ..write(obj.autoContribute)
      ..writeByte(10)
      ..write(obj.plannedMonthly)
      ..writeByte(11)
      ..write(obj.linkedCategoryId)
      ..writeByte(12)
      ..write(obj.archived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
