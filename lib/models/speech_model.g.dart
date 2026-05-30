// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpeechModelAdapter extends TypeAdapter<SpeechModel> {
  @override
  final int typeId = 4;

  @override
  SpeechModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpeechModel(
      id: fields[0] as String,
      title: fields[1] as String,
      speaker: fields[2] as String,
      youtubeVideoId: fields[3] as String,
      thumbnailUrl: fields[4] as String,
      durationLabel: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SpeechModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.speaker)
      ..writeByte(3)
      ..write(obj.youtubeVideoId)
      ..writeByte(4)
      ..write(obj.thumbnailUrl)
      ..writeByte(5)
      ..write(obj.durationLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
