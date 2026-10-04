// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_override.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetOverrideAdapter extends TypeAdapter<BudgetOverride> {
  @override
  final int typeId = 45;

  @override
  BudgetOverride read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetOverride(
      lineId: fields[0] as String,
      monthKey: fields[1] as String,
      amount: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetOverride obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.lineId)
      ..writeByte(1)
      ..write(obj.monthKey)
      ..writeByte(2)
      ..write(obj.amount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetOverrideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
