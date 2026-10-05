import 'package:hive/hive.dart';

@HiveType(typeId: 61)
class SleepSession extends HiveObject {
  @HiveField(0)
  final String externalId;

  @HiveField(1)
  String dayKey; // wake day: yyyy-MM-dd

  @HiveField(2)
  DateTime start;

  @HiveField(3)
  DateTime end;

  @HiveField(4)
  int durationMin;

  @HiveField(5)
  int? awakeMin;

  @HiveField(6)
  int? lightMin;

  @HiveField(7)
  int? deepMin;

  @HiveField(8)
  int? remMin;

  @HiveField(9)
  int? score;

  @HiveField(10)
  double? efficiency;

  @HiveField(11)
  bool isNap;

  @HiveField(12)
  String? sourceDevice;

  @HiveField(13)
  bool deleted;

  SleepSession({
    required this.externalId,
    required this.dayKey,
    required this.start,
    required this.end,
    required this.durationMin,
    this.awakeMin,
    this.lightMin,
    this.deepMin,
    this.remMin,
    this.score,
    this.efficiency,
    this.isNap = false,
    this.sourceDevice,
    this.deleted = false,
  });
}

class SleepSessionAdapter extends TypeAdapter<SleepSession> {
  @override
  final int typeId = 61;

  @override
  SleepSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepSession(
      externalId: fields[0] as String,
      dayKey: fields[1] as String,
      start: fields[2] as DateTime,
      end: fields[3] as DateTime,
      durationMin: (fields[4] as int?) ?? 0,
      awakeMin: fields[5] as int?,
      lightMin: fields[6] as int?,
      deepMin: fields[7] as int?,
      remMin: fields[8] as int?,
      score: fields[9] as int?,
      efficiency: fields[10] as double?,
      isNap: (fields[11] as bool?) ?? false,
      sourceDevice: fields[12] as String?,
      deleted: (fields[13] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, SleepSession obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.externalId)
      ..writeByte(1)
      ..write(obj.dayKey)
      ..writeByte(2)
      ..write(obj.start)
      ..writeByte(3)
      ..write(obj.end)
      ..writeByte(4)
      ..write(obj.durationMin)
      ..writeByte(5)
      ..write(obj.awakeMin)
      ..writeByte(6)
      ..write(obj.lightMin)
      ..writeByte(7)
      ..write(obj.deepMin)
      ..writeByte(8)
      ..write(obj.remMin)
      ..writeByte(9)
      ..write(obj.score)
      ..writeByte(10)
      ..write(obj.efficiency)
      ..writeByte(11)
      ..write(obj.isNap)
      ..writeByte(12)
      ..write(obj.sourceDevice)
      ..writeByte(13)
      ..write(obj.deleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
