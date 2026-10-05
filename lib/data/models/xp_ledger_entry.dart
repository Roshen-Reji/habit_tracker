import 'package:hive/hive.dart';

@HiveType(typeId: 68)
class XpLedgerEntry extends HiveObject {
  @HiveField(0)
  final String id; // yyyy-MM-dd|ruleId

  @HiveField(1)
  final String dayKey;

  @HiveField(2)
  final String ruleId;

  @HiveField(3)
  int amount;

  @HiveField(4)
  DateTime updatedAt;

  XpLedgerEntry({
    required this.id,
    required this.dayKey,
    required this.ruleId,
    required this.amount,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  static String generateId(String dayKey, String ruleId) => '$dayKey|$ruleId';
}

class XpLedgerEntryAdapter extends TypeAdapter<XpLedgerEntry> {
  @override
  final int typeId = 68;

  @override
  XpLedgerEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return XpLedgerEntry(
      id: fields[0] as String,
      dayKey: fields[1] as String,
      ruleId: fields[2] as String,
      amount: (fields[3] as int?) ?? 0,
      updatedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, XpLedgerEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayKey)
      ..writeByte(2)
      ..write(obj.ruleId)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XpLedgerEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
