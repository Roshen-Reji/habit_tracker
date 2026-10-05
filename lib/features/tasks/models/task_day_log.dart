import 'package:hive/hive.dart';

@HiveType(typeId: 66)
class TaskDayLog extends HiveObject {
  @HiveField(0)
  final String id; // goalId|yyyy-MM-dd

  @HiveField(1)
  final String goalId;

  @HiveField(2)
  final String dayKey; // yyyy-MM-dd

  @HiveField(3)
  String status; // 'pending', 'done', 'missed', 'neutral'

  @HiveField(4)
  double? value;

  @HiveField(5)
  String? valueText;

  @HiveField(6)
  DateTime loggedAt;

  @HiveField(7)
  String source; // 'manual', 'chat', 'ai', 'sleep_infer', 'rollover', 'wearable'

  @HiveField(8)
  String? note;

  TaskDayLog({
    required this.id,
    required this.goalId,
    required this.dayKey,
    this.status = 'pending',
    this.value,
    this.valueText,
    DateTime? loggedAt,
    this.source = 'manual',
    this.note,
  }) : loggedAt = loggedAt ?? DateTime.now();

  static String generateId(String goalId, String dayKey) => '$goalId|$dayKey';
}

class TaskDayLogAdapter extends TypeAdapter<TaskDayLog> {
  @override
  final int typeId = 66;

  @override
  TaskDayLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskDayLog(
      id: fields[0] as String,
      goalId: fields[1] as String,
      dayKey: fields[2] as String,
      status: (fields[3] as String?) ?? 'pending',
      value: fields[4] as double?,
      valueText: fields[5] as String?,
      loggedAt: fields[6] as DateTime?,
      source: (fields[7] as String?) ?? 'manual',
      note: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskDayLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goalId)
      ..writeByte(2)
      ..write(obj.dayKey)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.value)
      ..writeByte(5)
      ..write(obj.valueText)
      ..writeByte(6)
      ..write(obj.loggedAt)
      ..writeByte(7)
      ..write(obj.source)
      ..writeByte(8)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskDayLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
