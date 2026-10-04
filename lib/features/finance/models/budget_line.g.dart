// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_line.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetLineAdapter extends TypeAdapter<BudgetLine> {
  @override
  final int typeId = 44;

  @override
  BudgetLine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetLine(
      id: fields[0] as String,
      categoryId: fields[1] as String?,
      bucketRef: fields[2] as String?,
      amount: fields[3] as double,
      rollover: fields[4] as bool,
      essential: fields[5] as bool,
      startMonth: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetLine obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.bucketRef)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.rollover)
      ..writeByte(5)
      ..write(obj.essential)
      ..writeByte(6)
      ..write(obj.startMonth);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetLineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
