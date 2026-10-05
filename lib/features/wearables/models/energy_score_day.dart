import 'package:hive/hive.dart';

@HiveType(typeId: 64)
class EnergyScoreDay extends HiveObject {
  @HiveField(0)
  final String dayKey; // yyyy-MM-dd

  @HiveField(1)
  int score;

  @HiveField(2)
  String? extraJson;

  EnergyScoreDay({
    required this.dayKey,
    required this.score,
    this.extraJson,
  });
}

class EnergyScoreDayAdapter extends TypeAdapter<EnergyScoreDay> {
  @override
  final int typeId = 64;

  @override
  EnergyScoreDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EnergyScoreDay(
      dayKey: fields[0] as String,
      score: (fields[1] as int?) ?? 0,
      extraJson: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EnergyScoreDay obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.dayKey)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.extraJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergyScoreDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
