// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringRuleAdapter extends TypeAdapter<RecurringRule> {
  @override
  final int typeId = 43;

  @override
  RecurringRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringRule(
      id: fields[0] as String,
      name: fields[1] as String,
      kind: fields[2] as String,
      amount: fields[3] as double,
      amountIsVariable: fields[4] as bool,
      categoryId: fields[5] as String?,
      accountId: fields[6] as String?,
      toAccountId: fields[7] as String?,
      frequency: fields[8] as String,
      interval: fields[9] as int,
      anchorDate: fields[10] as DateTime?,
      dayOfMonth: fields[11] as int?,
      startDate: fields[12] as DateTime,
      endDate: fields[13] as DateTime?,
      autoPost: fields[14] as bool,
      reminderDaysBefore: fields[15] as int,
      status: fields[16] as String,
      folio: fields[17] as String?,
      notes: fields[18] as String?,
      createdAt: fields[19] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringRule obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.amountIsVariable)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.accountId)
      ..writeByte(7)
      ..write(obj.toAccountId)
      ..writeByte(8)
      ..write(obj.frequency)
      ..writeByte(9)
      ..write(obj.interval)
      ..writeByte(10)
      ..write(obj.anchorDate)
      ..writeByte(11)
      ..write(obj.dayOfMonth)
      ..writeByte(12)
      ..write(obj.startDate)
      ..writeByte(13)
      ..write(obj.endDate)
      ..writeByte(14)
      ..write(obj.autoPost)
      ..writeByte(15)
      ..write(obj.reminderDaysBefore)
      ..writeByte(16)
      ..write(obj.status)
      ..writeByte(17)
      ..write(obj.folio)
      ..writeByte(18)
      ..write(obj.notes)
      ..writeByte(19)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
