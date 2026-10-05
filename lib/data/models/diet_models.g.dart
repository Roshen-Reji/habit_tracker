// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diet_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodEntryAdapter extends TypeAdapter<FoodEntry> {
  @override
  final int typeId = 21;

  @override
  FoodEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodEntry(
      id: fields[0] as String,
      name: fields[1] as String,
      calories: fields[2] as double,
      protein: fields[3] as double,
      carbs: fields[4] as double,
      fat: fields[5] as double,
      timestamp: fields[6] as DateTime,
      mealType: fields[7] as MealType,
    );
  }

  @override
  void write(BinaryWriter writer, FoodEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.calories)
      ..writeByte(3)
      ..write(obj.protein)
      ..writeByte(4)
      ..write(obj.carbs)
      ..writeByte(5)
      ..write(obj.fat)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.mealType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CalorieBurnEntryAdapter extends TypeAdapter<CalorieBurnEntry> {
  @override
  final int typeId = 22;

  @override
  CalorieBurnEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalorieBurnEntry(
      id: fields[0] as String,
      activity: fields[1] as String,
      caloriesBurned: fields[2] as double,
      durationMinutes: fields[3] as int,
      timestamp: fields[4] as DateTime,
      source: fields[5] as String?,
      externalId: fields[6] as String?,
      supersededBy: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CalorieBurnEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activity)
      ..writeByte(2)
      ..write(obj.caloriesBurned)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.source)
      ..writeByte(6)
      ..write(obj.externalId)
      ..writeByte(7)
      ..write(obj.supersededBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalorieBurnEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DietDayLogAdapter extends TypeAdapter<DietDayLog> {
  @override
  final int typeId = 23;

  @override
  DietDayLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DietDayLog(
      dateKey: fields[0] as String,
      entries: (fields[1] as List?)?.cast<FoodEntry>(),
      burnEntries: (fields[2] as List?)?.cast<CalorieBurnEntry>(),
      targetCalories: fields[3] as double,
      notes: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DietDayLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.entries)
      ..writeByte(2)
      ..write(obj.burnEntries)
      ..writeByte(3)
      ..write(obj.targetCalories)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DietDayLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealTypeAdapter extends TypeAdapter<MealType> {
  @override
  final int typeId = 20;

  @override
  MealType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MealType.breakfast;
      case 1:
        return MealType.lunch;
      case 2:
        return MealType.dinner;
      case 3:
        return MealType.snack;
      default:
        return MealType.breakfast;
    }
  }

  @override
  void write(BinaryWriter writer, MealType obj) {
    switch (obj) {
      case MealType.breakfast:
        writer.writeByte(0);
        break;
      case MealType.lunch:
        writer.writeByte(1);
        break;
      case MealType.dinner:
        writer.writeByte(2);
        break;
      case MealType.snack:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
