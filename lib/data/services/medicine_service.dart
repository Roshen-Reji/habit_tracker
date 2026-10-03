import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MedicineDailyStats {
  final int totalDosesToday;
  final int takenDosesToday;
  final Medicine? nextDoseMedicine;
  final DateTime? nextDoseTime;

  const MedicineDailyStats({
    required this.totalDosesToday,
    required this.takenDosesToday,
    this.nextDoseMedicine,
    this.nextDoseTime,
  });

  bool get hasDosesToday => totalDosesToday > 0;
  double get complianceRate => totalDosesToday > 0
      ? (takenDosesToday / totalDosesToday).clamp(0.0, 1.0)
      : 1.0;
}

class MedicineService {
  static int getNotificationId(String medicineId, int slotIndex) {
    return (Object.hash(medicineId, slotIndex) & 0x7FFFFFFF);
  }

  /// Calculates the next occurrence for a specific medicine time slot.
  static DateTime? getNextOccurrence(
    Medicine medicine,
    int timeMinutes, {
    DateTime? now,
  }) {
    if (!medicine.active) return null;
    final current = now ?? DateTime.now();
    final hour = timeMinutes ~/ 60;
    final minute = timeMinutes % 60;

    // Check up to 14 days ahead
    for (int dayOffset = 0; dayOffset <= 14; dayOffset++) {
      final candidateDate = current.add(Duration(days: dayOffset));
      final candidateDateTime = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        hour,
        minute,
      );

      // If scheduled time has already passed today, check the next day
      if (candidateDateTime.isBefore(current)) {
        continue;
      }

      if (medicine.appliesToDay(candidateDateTime)) {
        return candidateDateTime;
      }
    }
    return null;
  }

  /// Finds the next upcoming dose across all active medicines.
  static ({Medicine medicine, DateTime time, int slotMinutes})?
      getOverallNextDose(
    List<Medicine> medicines, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    ({Medicine medicine, DateTime time, int slotMinutes})? earliest;

    for (final med in medicines) {
      if (!med.active) continue;
      for (final slot in med.timesMinutes) {
        final nextTime = getNextOccurrence(med, slot, now: current);
        if (nextTime != null) {
          if (earliest == null || nextTime.isBefore(earliest.time)) {
            earliest = (medicine: med, time: nextTime, slotMinutes: slot);
          }
        }
      }
    }
    return earliest;
  }

  /// Pure computation for daily medicine progress
  static MedicineDailyStats getDailyStats({
    DateTime? now,
    List<Medicine>? medicines,
    List<MedicineLog>? logs,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    final medList = medicines ??
        (Hive.isBoxOpen('medicines')
            ? Hive.box<Medicine>('medicines').values.toList()
            : <Medicine>[]);
    final logList = logs ??
        (Hive.isBoxOpen('medicine_logs')
            ? Hive.box<MedicineLog>('medicine_logs').values.toList()
            : <MedicineLog>[]);

    int totalDosesToday = 0;
    for (final med in medList) {
      if (med.appliesToDay(today)) {
        totalDosesToday += med.timesMinutes.length;
      }
    }

    // Taken doses today
    final takenToday = logList.where((log) {
      final logDate = DateTime(
        log.scheduledAt.year,
        log.scheduledAt.month,
        log.scheduledAt.day,
      );
      return logDate == today && log.status == 'taken';
    }).length;

    final nextDose = getOverallNextDose(medList, now: current);

    return MedicineDailyStats(
      totalDosesToday: totalDosesToday,
      takenDosesToday: takenToday,
      nextDoseMedicine: nextDose?.medicine,
      nextDoseTime: nextDose?.time,
    );
  }

  /// Schedules local notifications for all slots of a medicine.
  static Future<void> scheduleMedicine(Medicine medicine) async {
    if (!medicine.active) {
      await cancelMedicine(medicine);
      return;
    }

    bool isExact = true;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        isExact = await Permission.scheduleExactAlarm.isGranted;
      } catch (_) {
        isExact = false;
      }
    }

    for (int i = 0; i < medicine.timesMinutes.length; i++) {
      final slotMinutes = medicine.timesMinutes[i];
      final nextTime = getNextOccurrence(medicine, slotMinutes);
      final id = getNotificationId(medicine.id, i);

      if (nextTime != null) {
        await NotificationService().scheduleMedicineReminder(
          id: id,
          medicineId: medicine.id,
          title: "Medicine Reminder: ${medicine.name}",
          body:
              "Time for ${medicine.doseLabel}${medicine.notes.isNotEmpty ? ' (${medicine.notes})' : ''}",
          scheduledDate: nextTime,
          isExact: isExact,
        );
      } else {
        await NotificationService().cancelReminder(id);
      }
    }
  }

  /// Cancels notifications for a medicine.
  static Future<void> cancelMedicine(Medicine medicine) async {
    for (int i = 0; i < medicine.timesMinutes.length; i++) {
      final id = getNotificationId(medicine.id, i);
      await NotificationService().cancelReminder(id);
    }
  }

  /// Reschedules all medicines at app start or edit.
  static Future<void> rescheduleAll() async {
    if (!Hive.isBoxOpen('medicines')) return;
    final box = Hive.box<Medicine>('medicines');
    for (final med in box.values) {
      await scheduleMedicine(med);
    }
  }

  /// Logs a medicine dose as taken.
  static Future<void> markTaken(
    String medicineId,
    DateTime scheduledAt,
  ) async {
    if (!Hive.isBoxOpen('medicine_logs')) return;
    final box = Hive.box<MedicineLog>('medicine_logs');
    final log = MedicineLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      medicineId: medicineId,
      scheduledAt: scheduledAt,
      status: 'taken',
      loggedAt: DateTime.now(),
    );
    await box.put(log.id, log);
  }

  /// Logs a medicine dose as skipped.
  static Future<void> markSkipped(
    String medicineId,
    DateTime scheduledAt,
  ) async {
    if (!Hive.isBoxOpen('medicine_logs')) return;
    final box = Hive.box<MedicineLog>('medicine_logs');
    final log = MedicineLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      medicineId: medicineId,
      scheduledAt: scheduledAt,
      status: 'skipped',
      loggedAt: DateTime.now(),
    );
    await box.put(log.id, log);
  }
}
