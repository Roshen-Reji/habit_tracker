import 'package:hive/hive.dart';

part 'health_models.g.dart';

@HiveType(typeId: 30)
class Medicine extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String doseLabel;

  @HiveField(3)
  final List<int> timesMinutes; // Minutes from midnight (e.g. 480 = 08:00)

  @HiveField(4)
  final List<int> weekdays; // 1 (Mon) - 7 (Sun), empty means every day

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  final DateTime? endDate;

  @HiveField(7)
  final String notes;

  @HiveField(8)
  final bool active;

  Medicine({
    required this.id,
    required this.name,
    required this.doseLabel,
    required this.timesMinutes,
    this.weekdays = const [],
    required this.startDate,
    this.endDate,
    this.notes = '',
    this.active = true,
  });

  bool appliesToDay(DateTime day) {
    if (!active) return false;
    final dateOnly = DateTime(day.year, day.month, day.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    if (dateOnly.isBefore(startOnly)) return false;
    if (endDate != null) {
      final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dateOnly.isAfter(endOnly)) return false;
    }
    if (weekdays.isNotEmpty && !weekdays.contains(day.weekday)) {
      return false;
    }
    return true;
  }

  Medicine copyWith({
    String? id,
    String? name,
    String? doseLabel,
    List<int>? timesMinutes,
    List<int>? weekdays,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool? active,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      doseLabel: doseLabel ?? this.doseLabel,
      timesMinutes: timesMinutes ?? this.timesMinutes,
      weekdays: weekdays ?? this.weekdays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      active: active ?? this.active,
    );
  }
}

@HiveType(typeId: 31)
class MedicineLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String medicineId;

  @HiveField(2)
  final DateTime scheduledAt;

  @HiveField(3)
  final String status; // 'taken', 'skipped', 'snoozed'

  @HiveField(4)
  final DateTime loggedAt;

  MedicineLog({
    required this.id,
    required this.medicineId,
    required this.scheduledAt,
    required this.status,
    required this.loggedAt,
  });
}

@HiveType(typeId: 32)
class WeightEntry extends HiveObject {
  @HiveField(0)
  final String date; // 'yyyy-MM-dd'

  @HiveField(1)
  final double kg;

  @HiveField(2)
  final String note;

  @HiveField(3)
  String? source;

  @HiveField(4)
  String? externalId;

  WeightEntry({
    required this.date,
    required this.kg,
    this.note = '',
    this.source,
    this.externalId,
  });
}
