import 'package:hive/hive.dart';

@HiveType(typeId: 65)
class AgesSample extends HiveObject {
  @HiveField(0)
  final String id; // externalId or yyyy-MM-dd

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  double score; // Samsung Health AGEs index score

  @HiveField(3)
  String? sourceDevice;

  @HiveField(4)
  String? extraJson;

  AgesSample({
    required this.id,
    required this.timestamp,
    required this.score,
    this.sourceDevice,
    this.extraJson,
  });
}

class AgesSampleAdapter extends TypeAdapter<AgesSample> {
  @override
  final int typeId = 65;

  @override
  AgesSample read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AgesSample(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      score: (fields[2] as num?)?.toDouble() ?? 0.0,
      sourceDevice: fields[3] as String?,
      extraJson: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AgesSample obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.score)
      ..writeByte(3)
      ..write(obj.sourceDevice)
      ..writeByte(4)
      ..write(obj.extraJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgesSampleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
