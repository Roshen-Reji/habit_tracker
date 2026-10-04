// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 10;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      title: fields[0] as String,
      amount: fields[1] as double,
      category: fields[2] as String,
      date: fields[3] as DateTime,
      mode: fields[4] as String,
      icon: fields[5] as String,
      id: fields[6] as String?,
      kind: fields[7] as String?,
      accountId: fields[8] as String?,
      toAccountId: fields[9] as String?,
      categoryId: fields[10] as String?,
      merchant: fields[11] as String?,
      paymentMethod: fields[12] as String?,
      notes: fields[13] as String?,
      tags: (fields[14] as List?)?.cast<String>(),
      splits: fields[15] as String?,
      receiptPaths: (fields[16] as List?)?.cast<String>(),
      recurringRuleId: fields[17] as String?,
      sourceRef: fields[18] as String?,
      createdAt: fields[19] as DateTime?,
      goalId: fields[20] as String?,
      interestAmount: fields[21] as double?,
      refundOfId: fields[22] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.mode)
      ..writeByte(5)
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.id)
      ..writeByte(7)
      ..write(obj.kind)
      ..writeByte(8)
      ..write(obj.accountId)
      ..writeByte(9)
      ..write(obj.toAccountId)
      ..writeByte(10)
      ..write(obj.categoryId)
      ..writeByte(11)
      ..write(obj.merchant)
      ..writeByte(12)
      ..write(obj.paymentMethod)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.tags)
      ..writeByte(15)
      ..write(obj.splits)
      ..writeByte(16)
      ..write(obj.receiptPaths)
      ..writeByte(17)
      ..write(obj.recurringRuleId)
      ..writeByte(18)
      ..write(obj.sourceRef)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.goalId)
      ..writeByte(21)
      ..write(obj.interestAmount)
      ..writeByte(22)
      ..write(obj.refundOfId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssetVaultAdapter extends TypeAdapter<AssetVault> {
  @override
  final int typeId = 11;

  @override
  AssetVault read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssetVault(
      name: fields[0] as String,
      balance: fields[1] as double,
      bank: fields[2] as String,
      type: fields[3] as String,
      colorValue: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AssetVault obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.balance)
      ..writeByte(2)
      ..write(obj.bank)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetVaultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
