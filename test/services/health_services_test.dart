import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:habit_tracker/data/services/health_calculator.dart';

void main() {
  group('Medicine Model & AppliesToDay', () {
    test('Daily medicine applies to any day within date range', () {
      final med = Medicine(
        id: 'med_1',
        name: 'Multivitamin',
        doseLabel: '1 tablet',
        timesMinutes: [480], // 08:00
        weekdays: [], // daily
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      expect(med.appliesToDay(DateTime(2026, 10, 5)), isTrue);
      expect(med.appliesToDay(DateTime(2026, 10, 31)), isTrue);
      // Before start date
      expect(med.appliesToDay(DateTime(2026, 9, 30)), isFalse);
      // After end date
      expect(med.appliesToDay(DateTime(2026, 11, 1)), isFalse);
    });

    test('Specific weekdays medicine only applies on scheduled weekdays', () {
      // 2026-10-05 is Monday (weekday = 1)
      // 2026-10-06 is Tuesday (weekday = 2)
      // 2026-10-07 is Wednesday (weekday = 3)
      final med = Medicine(
        id: 'med_2',
        name: 'Omega 3',
        doseLabel: '1 capsule',
        timesMinutes: [720], // 12:00
        weekdays: [1, 3, 5], // Mon, Wed, Fri
        startDate: DateTime(2026, 10, 1),
      );

      expect(med.appliesToDay(DateTime(2026, 10, 5)), isTrue); // Monday
      expect(med.appliesToDay(DateTime(2026, 10, 6)), isFalse); // Tuesday
      expect(med.appliesToDay(DateTime(2026, 10, 7)), isTrue); // Wednesday
    });

    test('Inactive medicine does not schedule occurrences', () {
      final med = Medicine(
        id: 'med_inactive',
        name: 'Inactive Med',
        doseLabel: '10mg',
        timesMinutes: [600],
        weekdays: [],
        startDate: DateTime(2026, 10, 1),
        active: false,
      );

      final next = MedicineService.getNextOccurrence(
        med,
        600,
        now: DateTime(2026, 10, 5, 8, 0),
      );
      expect(next, isNull);
    });
  });

  group('MedicineService Next Occurrence & Daily Stats', () {
    test('Calculates next occurrence today if time has not passed', () {
      final med = Medicine(
        id: 'med_test',
        name: 'Vitamin D',
        doseLabel: '1 drop',
        timesMinutes: [840], // 14:00 (2:00 PM)
        weekdays: [],
        startDate: DateTime(2026, 10, 1),
      );

      final now = DateTime(2026, 10, 5, 10, 30);
      final next = MedicineService.getNextOccurrence(med, 840, now: now);

      expect(next, isNotNull);
      expect(next!.year, 2026);
      expect(next.month, 10);
      expect(next.day, 5);
      expect(next.hour, 14);
      expect(next.minute, 0);
    });

    test('Rolls over to tomorrow if slot has already passed today', () {
      final med = Medicine(
        id: 'med_test_2',
        name: 'Iron',
        doseLabel: '1 tablet',
        timesMinutes: [480], // 08:00 AM
        weekdays: [],
        startDate: DateTime(2026, 10, 1),
      );

      final now = DateTime(2026, 10, 5, 10, 30); // 10:30 AM (after 8:00 AM)
      final next = MedicineService.getNextOccurrence(med, 480, now: now);

      expect(next, isNotNull);
      expect(next!.year, 2026);
      expect(next.month, 10);
      expect(next.day, 6); // Tomorrow
      expect(next.hour, 8);
      expect(next.minute, 0);
    });

    test('Computes daily stats accurately with total and taken doses', () {
      final med1 = Medicine(
        id: 'med_a',
        name: 'Med A',
        doseLabel: '1 pill',
        timesMinutes: [480, 1200], // 2 doses per day
        weekdays: [],
        startDate: DateTime(2026, 10, 1),
      );
      final med2 = Medicine(
        id: 'med_b',
        name: 'Med B',
        doseLabel: '1 pill',
        timesMinutes: [720], // 1 dose per day
        weekdays: [],
        startDate: DateTime(2026, 10, 1),
      );

      final today = DateTime(2026, 10, 5, 9, 0);

      // Log: Med A 8:00 AM taken
      final log = MedicineLog(
        id: 'log_1',
        medicineId: 'med_a',
        scheduledAt: DateTime(2026, 10, 5, 8, 0),
        status: 'taken',
        loggedAt: DateTime(2026, 10, 5, 8, 5),
      );

      final stats = MedicineService.getDailyStats(
        now: today,
        medicines: [med1, med2],
        logs: [log],
      );

      expect(stats.totalDosesToday, 3);
      expect(stats.takenDosesToday, 1);
      expect(stats.complianceRate, closeTo(1 / 3, 0.001));
    });
  });

  group('HealthCalculator Composite Summary', () {
    test('Calculates score based on calorie, medicine, and health missions',
        () {
      final dietLog = DietDayLog(
        dateKey: '2026-10-05',
        entries: [
          FoodEntry(
            id: 'f1',
            mealType: MealType.breakfast,
            name: 'Oatmeal',
            calories: 400,
            protein: 15,
            carbs: 60,
            fat: 8,
            timestamp: DateTime(2026, 10, 5, 8, 30),
          ),
          FoodEntry(
            id: 'f2',
            mealType: MealType.lunch,
            name: 'Chicken Rice',
            calories: 600,
            protein: 45,
            carbs: 70,
            fat: 15,
            timestamp: DateTime(2026, 10, 5, 13, 0),
          ),
        ],
        burnEntries: [
          CalorieBurnEntry(
            id: 'b1',
            activity: 'Running',
            caloriesBurned: 200,
            durationMinutes: 30,
            timestamp: DateTime(2026, 10, 5, 7, 0),
          ),
        ],
      );

      final medStats = MedicineDailyStats(
        totalDosesToday: 2,
        takenDosesToday: 2,
      );

      final goals = [
        Goal(
          id: 'g1',
          title: 'Morning Yoga',
          description: 'Stretch for 20m',
          type: GoalType.daily,
          category: GoalCategory.health,
          targetValue: 1.0,
          currentValue: 1.0,
          unit: 'session',
          isCompleted: true,
        ),
        Goal(
          id: 'g2',
          title: 'Coding Task',
          description: 'Finish PR',
          type: GoalType.daily,
          category: GoalCategory.productivity,
          targetValue: 1.0,
          currentValue: 1.0,
          unit: 'task',
          isCompleted: true,
        ),
      ];

      final weights = [
        WeightEntry(date: '2026-10-01', kg: 75.0),
        WeightEntry(date: '2026-10-05', kg: 74.2),
      ];

      final summary = HealthCalculator.computeSummary(
        now: DateTime(2026, 10, 5),
        weights: weights,
        dietLog: dietLog,
        calorieTarget:
            900, // Net is 800 (1000 - 200), ratio is ~0.89 -> full 35 pts
        medStats: medStats, // 2/2 -> full 35 pts
        goals: goals, // 1/1 health goal -> full 30 pts
        settingsMap: {
          'weight_start': 75.0,
          'weight_goal': 70.0,
          'weight_unit': 'kg',
        },
      );

      expect(summary.latestWeightKg, 74.2);
      expect(summary.consumedCalories, 1000);
      expect(summary.burnedCalories, 200);
      expect(summary.netCalories, 800);
      expect(summary.medicineTakenToday, 2);
      expect(summary.medicineTotalToday, 2);
      expect(summary.healthMissionsCompletedToday, 1);
      expect(summary.healthMissionsTotalToday, 1);
      expect(summary.compositeScore, 100.0);
    });

    test('Composite score falls back gracefully when no goals/meds/target', () {
      final summary = HealthCalculator.computeSummary(
        now: DateTime(2026, 10, 5),
        weights: [],
        dietLog: null,
        calorieTarget: 0,
        medStats:
            const MedicineDailyStats(totalDosesToday: 0, takenDosesToday: 0),
        goals: [],
        settingsMap: {},
      );

      expect(summary.latestWeightKg, isNull);
      expect(summary.netCalories, 0);
      expect(summary.compositeScore,
          100.0); // Defaults to full points when no targets are active
    });
  });

  group('Health Models Round-trip & CopyWith', () {
    test('Medicine copyWith works properly', () {
      final med = Medicine(
        id: 'med_orig',
        name: 'Aspirin',
        doseLabel: '100mg',
        timesMinutes: [540],
        weekdays: [1, 2, 3],
        startDate: DateTime(2026, 10, 1),
        notes: 'Take after food',
      );

      final updated = med.copyWith(
        name: 'Aspirin Cardio',
        active: false,
      );

      expect(updated.id, 'med_orig');
      expect(updated.name, 'Aspirin Cardio');
      expect(updated.doseLabel, '100mg');
      expect(updated.active, isFalse);
      expect(updated.notes, 'Take after food');
    });

    test('WeightEntry retains accurate fields', () {
      final entry =
          WeightEntry(date: '2026-10-05', kg: 71.8, note: 'Morning weigh-in');
      expect(entry.date, '2026-10-05');
      expect(entry.kg, 71.8);
      expect(entry.note, 'Morning weigh-in');
    });
  });
}
