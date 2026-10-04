// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 40;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as String,
      name: fields[1] as String,
      kind: fields[2] as String,
      institution: fields[3] as String?,
      openingBalance: fields[4] as double,
      openingDate: fields[5] as DateTime,
      colorValue: fields[6] as int,
      archived: fields[7] as bool,
      includeInNetWorth: fields[8] as bool,
      spendable: fields[9] as bool,
      creditLimit: fields[10] as double?,
      statementDay: fields[11] as int?,
      dueDay: fields[12] as int?,
      principal: fields[13] as double?,
      annualRate: fields[14] as double?,
      emi: fields[15] as double?,
      tenureMonths: fields[16] as int?,
      startDate: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.institution)
      ..writeByte(4)
      ..write(obj.openingBalance)
      ..writeByte(5)
      ..write(obj.openingDate)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.archived)
      ..writeByte(8)
      ..write(obj.includeInNetWorth)
      ..writeByte(9)
      ..write(obj.spendable)
      ..writeByte(10)
      ..write(obj.creditLimit)
      ..writeByte(11)
      ..write(obj.statementDay)
      ..writeByte(12)
      ..write(obj.dueDay)
      ..writeByte(13)
      ..write(obj.principal)
      ..writeByte(14)
      ..write(obj.annualRate)
      ..writeByte(15)
      ..write(obj.emi)
      ..writeByte(16)
      ..write(obj.tenureMonths)
      ..writeByte(17)
      ..write(obj.startDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
