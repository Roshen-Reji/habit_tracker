// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicineAdapter extends TypeAdapter<Medicine> {
  @override
  final int typeId = 30;

  @override
  Medicine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medicine(
      id: fields[0] as String,
      name: fields[1] as String,
      doseLabel: fields[2] as String,
      timesMinutes: (fields[3] as List).cast<int>(),
      weekdays: (fields[4] as List).cast<int>(),
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime?,
      notes: fields[7] as String,
      active: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Medicine obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.doseLabel)
      ..writeByte(3)
      ..write(obj.timesMinutes)
      ..writeByte(4)
      ..write(obj.weekdays)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.active);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineLogAdapter extends TypeAdapter<MedicineLog> {
  @override
  final int typeId = 31;

  @override
  MedicineLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicineLog(
      id: fields[0] as String,
      medicineId: fields[1] as String,
      scheduledAt: fields[2] as DateTime,
      status: fields[3] as String,
      loggedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MedicineLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicineId)
      ..writeByte(2)
      ..write(obj.scheduledAt)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.loggedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeightEntryAdapter extends TypeAdapter<WeightEntry> {
  @override
  final int typeId = 32;

  @override
  WeightEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeightEntry(
      date: fields[0] as String,
      kg: fields[1] as double,
      note: fields[2] as String,
      source: fields[3] as String?,
      externalId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WeightEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.kg)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.externalId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
