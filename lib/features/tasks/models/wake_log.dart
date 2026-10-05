import 'package:hive/hive.dart';

@HiveType(typeId: 67)
class WakeLog extends HiveObject {
  @HiveField(0)
  final String dayKey; // yyyy-MM-dd

  @HiveField(1)
  DateTime wakeAt;

  @HiveField(2)
  String source; // 'manual', 'chat', 'sleep_infer', etc.

  @HiveField(3)
  String? sleepSessionId;

  @HiveField(4)
  int? targetMinutesAtLog;

  @HiveField(5)
  bool onTime;

  @HiveField(6)
  DateTime editedAt;

  @HiveField(7)
  String? undoOf;

  WakeLog({
    required this.dayKey,
    required this.wakeAt,
    this.source = 'manual',
    this.sleepSessionId,
    this.targetMinutesAtLog,
    required this.onTime,
    DateTime? editedAt,
    this.undoOf,
  }) : editedAt = editedAt ?? DateTime.now();
}

class WakeLogAdapter extends TypeAdapter<WakeLog> {
  @override
  final int typeId = 67;

  @override
  WakeLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WakeLog(
      dayKey: fields[0] as String,
      wakeAt: fields[1] as DateTime,
      source: (fields[2] as String?) ?? 'manual',
      sleepSessionId: fields[3] as String?,
      targetMinutesAtLog: fields[4] as int?,
      onTime: (fields[5] as bool?) ?? false,
      editedAt: fields[6] as DateTime?,
      undoOf: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WakeLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.dayKey)
      ..writeByte(1)
      ..write(obj.wakeAt)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.sleepSessionId)
      ..writeByte(4)
      ..write(obj.targetMinutesAtLog)
      ..writeByte(5)
      ..write(obj.onTime)
      ..writeByte(6)
      ..write(obj.editedAt)
      ..writeByte(7)
      ..write(obj.undoOf);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WakeLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
