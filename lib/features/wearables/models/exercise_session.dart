import 'package:hive/hive.dart';

@HiveType(typeId: 62)
class ExerciseSession extends HiveObject {
  @HiveField(0)
  final String externalId;

  @HiveField(1)
  String dayKey; // yyyy-MM-dd

  @HiveField(2)
  String type; // 'running', 'walking', 'cycling', etc.

  @HiveField(3)
  String? title;

  @HiveField(4)
  DateTime start;

  @HiveField(5)
  DateTime end;

  @HiveField(6)
  int durationMin;

  @HiveField(7)
  double? activeKcal;

  @HiveField(8)
  double? totalKcal;

  @HiveField(9)
  int? avgHr;

  @HiveField(10)
  int? maxHr;

  @HiveField(11)
  double? distanceM;

  @HiveField(12)
  double? vo2Max;

  @HiveField(13)
  String? sourceDevice;

  @HiveField(14)
  String? linkedBurnId;

  @HiveField(15)
  bool deleted;

  ExerciseSession({
    required this.externalId,
    required this.dayKey,
    required this.type,
    this.title,
    required this.start,
    required this.end,
    required this.durationMin,
    this.activeKcal,
    this.totalKcal,
    this.avgHr,
    this.maxHr,
    this.distanceM,
    this.vo2Max,
    this.sourceDevice,
    this.linkedBurnId,
    this.deleted = false,
  });
}

class ExerciseSessionAdapter extends TypeAdapter<ExerciseSession> {
  @override
  final int typeId = 62;

  @override
  ExerciseSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseSession(
      externalId: fields[0] as String,
      dayKey: fields[1] as String,
      type: (fields[2] as String?) ?? 'workout',
      title: fields[3] as String?,
      start: fields[4] as DateTime,
      end: fields[5] as DateTime,
      durationMin: (fields[6] as int?) ?? 0,
      activeKcal: fields[7] as double?,
      totalKcal: fields[8] as double?,
      avgHr: fields[9] as int?,
      maxHr: fields[10] as int?,
      distanceM: fields[11] as double?,
      vo2Max: fields[12] as double?,
      sourceDevice: fields[13] as String?,
      linkedBurnId: fields[14] as String?,
      deleted: (fields[15] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseSession obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.externalId)
      ..writeByte(1)
      ..write(obj.dayKey)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.start)
      ..writeByte(5)
      ..write(obj.end)
      ..writeByte(6)
      ..write(obj.durationMin)
      ..writeByte(7)
      ..write(obj.activeKcal)
      ..writeByte(8)
      ..write(obj.totalKcal)
      ..writeByte(9)
      ..write(obj.avgHr)
      ..writeByte(10)
      ..write(obj.maxHr)
      ..writeByte(11)
      ..write(obj.distanceM)
      ..writeByte(12)
      ..write(obj.vo2Max)
      ..writeByte(13)
      ..write(obj.sourceDevice)
      ..writeByte(14)
      ..write(obj.linkedBurnId)
      ..writeByte(15)
      ..write(obj.deleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
