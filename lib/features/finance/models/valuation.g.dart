// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'valuation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ValuationAdapter extends TypeAdapter<Valuation> {
  @override
  final int typeId = 48;

  @override
  Valuation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Valuation(
      id: fields[0] as String,
      accountId: fields[1] as String,
      date: fields[2] as DateTime,
      value: fields[3] as double,
      units: fields[4] as double?,
      unitPrice: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Valuation obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.value)
      ..writeByte(4)
      ..write(obj.units)
      ..writeByte(5)
      ..write(obj.unitPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValuationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
