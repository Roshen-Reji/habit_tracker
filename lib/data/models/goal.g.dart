// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 1;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      title: fields[1] as String,
      type: fields[2] as GoalType,
      category: fields[5] as GoalCategory,
      targetValue: fields[6] as double,
      currentValue: fields[7] as double,
      unit: fields[8] as String,
      description: fields[9] as String,
      isCompleted: fields[3] as bool,
      progress: fields[4] as double,
      streakCount: fields[10] as int,
      isArchived: fields[11] as bool,
      createdDate: fields[12] as DateTime?,
      lastCompletedDate: fields[13] as DateTime?,
      reminderTime: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.progress)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.targetValue)
      ..writeByte(7)
      ..write(obj.currentValue)
      ..writeByte(8)
      ..write(obj.unit)
      ..writeByte(9)
      ..write(obj.description)
      ..writeByte(10)
      ..write(obj.streakCount)
      ..writeByte(11)
      ..write(obj.isArchived)
      ..writeByte(12)
      ..write(obj.createdDate)
      ..writeByte(13)
      ..write(obj.lastCompletedDate)
      ..writeByte(14)
      ..write(obj.reminderTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalTypeAdapter extends TypeAdapter<GoalType> {
  @override
  final int typeId = 0;

  @override
  GoalType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalType.today;
      case 1:
        return GoalType.daily;
      case 2:
        return GoalType.weekly;
      case 3:
        return GoalType.monthly;
      default:
        return GoalType.today;
    }
  }

  @override
  void write(BinaryWriter writer, GoalType obj) {
    switch (obj) {
      case GoalType.today:
        writer.writeByte(0);
        break;
      case GoalType.daily:
        writer.writeByte(1);
        break;
      case GoalType.weekly:
        writer.writeByte(2);
        break;
      case GoalType.monthly:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalCategoryAdapter extends TypeAdapter<GoalCategory> {
  @override
  final int typeId = 2;

  @override
  GoalCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalCategory.health;
      case 1:
        return GoalCategory.productivity;
      case 2:
        return GoalCategory.learning;
      case 3:
        return GoalCategory.fitness;
      case 4:
        return GoalCategory.hobby;
      default:
        return GoalCategory.health;
    }
  }

  @override
  void write(BinaryWriter writer, GoalCategory obj) {
    switch (obj) {
      case GoalCategory.health:
        writer.writeByte(0);
        break;
      case GoalCategory.productivity:
        writer.writeByte(1);
        break;
      case GoalCategory.learning:
        writer.writeByte(2);
        break;
      case GoalCategory.fitness:
        writer.writeByte(3);
        break;
      case GoalCategory.hobby:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
