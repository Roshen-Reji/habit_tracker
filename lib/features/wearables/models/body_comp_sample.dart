import 'package:hive/hive.dart';

@HiveType(typeId: 63)
class BodyCompSample extends HiveObject {
  @HiveField(0)
  final String externalId;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  double? weightKg;

  @HiveField(3)
  double? bodyFatPct;

  @HiveField(4)
  double? bodyFatMassKg;

  @HiveField(5)
  double? skeletalMuscleMassKg;

  @HiveField(6)
  double? bodyWaterPct;

  @HiveField(7)
  double? bmrKcal;

  @HiveField(8)
  double? bmi;

  @HiveField(9)
  String? sourceDevice;

  @HiveField(10)
  bool deleted;

  BodyCompSample({
    required this.externalId,
    required this.timestamp,
    this.weightKg,
    this.bodyFatPct,
    this.bodyFatMassKg,
    this.skeletalMuscleMassKg,
    this.bodyWaterPct,
    this.bmrKcal,
    this.bmi,
    this.sourceDevice,
    this.deleted = false,
  });
}

class BodyCompSampleAdapter extends TypeAdapter<BodyCompSample> {
  @override
  final int typeId = 63;

  @override
  BodyCompSample read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyCompSample(
      externalId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      weightKg: fields[2] as double?,
      bodyFatPct: fields[3] as double?,
      bodyFatMassKg: fields[4] as double?,
      skeletalMuscleMassKg: fields[5] as double?,
      bodyWaterPct: fields[6] as double?,
      bmrKcal: fields[7] as double?,
      bmi: fields[8] as double?,
      sourceDevice: fields[9] as String?,
      deleted: (fields[10] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, BodyCompSample obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.externalId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.weightKg)
      ..writeByte(3)
      ..write(obj.bodyFatPct)
      ..writeByte(4)
      ..write(obj.bodyFatMassKg)
      ..writeByte(5)
      ..write(obj.skeletalMuscleMassKg)
      ..writeByte(6)
      ..write(obj.bodyWaterPct)
      ..writeByte(7)
      ..write(obj.bmrKcal)
      ..writeByte(8)
      ..write(obj.bmi)
      ..writeByte(9)
      ..write(obj.sourceDevice)
      ..writeByte(10)
      ..write(obj.deleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyCompSampleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
