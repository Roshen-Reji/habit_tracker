import 'package:hive/hive.dart';

@HiveType(typeId: 60)
class DailyActivity extends HiveObject {
  @HiveField(0)
  final String dayKey; // yyyy-MM-dd

  @HiveField(1)
  int steps;

  @HiveField(2)
  double? distanceM;

  @HiveField(3)
  double? activeKcal;

  @HiveField(4)
  double? totalKcal;

  @HiveField(5)
  int? activeMinutes;

  @HiveField(6)
  int? floors;

  @HiveField(7)
  int? restingHr;

  @HiveField(8)
  int? avgHr;

  @HiveField(9)
  double? spo2Avg;

  @HiveField(10)
  int? stepGoal;

  @HiveField(11)
  double? activeKcalGoal;

  @HiveField(12)
  int? activeTimeGoal;

  @HiveField(13)
  String? sourceNote;

  @HiveField(14)
  DateTime syncedAt;

  DailyActivity({
    required this.dayKey,
    this.steps = 0,
    this.distanceM,
    this.activeKcal,
    this.totalKcal,
    this.activeMinutes,
    this.floors,
    this.restingHr,
    this.avgHr,
    this.spo2Avg,
    this.stepGoal,
    this.activeKcalGoal,
    this.activeTimeGoal,
    this.sourceNote,
    DateTime? syncedAt,
  }) : syncedAt = syncedAt ?? DateTime.now();
}

class DailyActivityAdapter extends TypeAdapter<DailyActivity> {
  @override
  final int typeId = 60;

  @override
  DailyActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyActivity(
      dayKey: fields[0] as String,
      steps: (fields[1] as int?) ?? 0,
      distanceM: fields[2] as double?,
      activeKcal: fields[3] as double?,
      totalKcal: fields[4] as double?,
      activeMinutes: fields[5] as int?,
      floors: fields[6] as int?,
      restingHr: fields[7] as int?,
      avgHr: fields[8] as int?,
      spo2Avg: fields[9] as double?,
      stepGoal: fields[10] as int?,
      activeKcalGoal: fields[11] as double?,
      activeTimeGoal: fields[12] as int?,
      sourceNote: fields[13] as String?,
      syncedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyActivity obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.dayKey)
      ..writeByte(1)
      ..write(obj.steps)
      ..writeByte(2)
      ..write(obj.distanceM)
      ..writeByte(3)
      ..write(obj.activeKcal)
      ..writeByte(4)
      ..write(obj.totalKcal)
      ..writeByte(5)
      ..write(obj.activeMinutes)
      ..writeByte(6)
      ..write(obj.floors)
      ..writeByte(7)
      ..write(obj.restingHr)
      ..writeByte(8)
      ..write(obj.avgHr)
      ..writeByte(9)
      ..write(obj.spo2Avg)
      ..writeByte(10)
      ..write(obj.stepGoal)
      ..writeByte(11)
      ..write(obj.activeKcalGoal)
      ..writeByte(12)
      ..write(obj.activeTimeGoal)
      ..writeByte(13)
      ..write(obj.sourceNote)
      ..writeByte(14)
      ..write(obj.syncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
