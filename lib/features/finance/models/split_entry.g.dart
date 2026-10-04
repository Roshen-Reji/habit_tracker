// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SplitEntryAdapter extends TypeAdapter<SplitEntry> {
  @override
  final int typeId = 50;

  @override
  SplitEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SplitEntry(
      id: fields[0] as String,
      groupId: fields[1] as String,
      date: fields[2] as DateTime,
      title: fields[3] as String,
      amount: fields[4] as double,
      paidBy: fields[5] as String,
      shares: (fields[6] as Map).cast<String, double>(),
      txId: fields[7] as String?,
      settled: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SplitEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.paidBy)
      ..writeByte(6)
      ..write(obj.shares)
      ..writeByte(7)
      ..write(obj.txId)
      ..writeByte(8)
      ..write(obj.settled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
