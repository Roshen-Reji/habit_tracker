import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/engine/nutrition_science_engine.dart';
import 'package:habit_tracker/features/diet/engine/native_diet_ai_engine.dart';
import 'package:habit_tracker/features/diet/data/indian_regional_food_db.dart';
import 'package:habit_tracker/features/tasks/engine/native_task_ai_engine.dart';

void main() {
  group('NutritionScienceEngine Tests', () {
    test('Calculates Mifflin-St Jeor TDEE and gym trainer macros correctly', () {
      const profile = NutritionProfile(
        age: 25,
        heightCm: 175.0,
        currentWeightKg: 70.0,
        targetWeightKg: 68.0,
        sex: BiologicalSex.male,
        goal: DietGoal.gradualLoss,
        activityLevel: PhysicalActivityLevel.moderate,
        paceKgPerWeek: 0.5,
      );

      final targets = NutritionScienceEngine.computeDailyTargets(profile);

      // Male BMR: 10*70 + 6.25*175 - 5*25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
      // TDEE: 1673.75 * 1.55 = 2594.3
      // Goal deficit: -450 -> ~2144 kcal
      expect(targets.targetKcal, greaterThanOrEqualTo(1500.0));
      expect(targets.clinicalFloorApplied, isFalse);

      // Gym Trainer Protein: 70kg * 1.7 = ~119g
      expect(targets.proteinG, closeTo(119.0, 5.0));

      // Dietary Fibre: >= 28g
      expect(targets.fibreG, greaterThanOrEqualTo(28.0));
      expect(targets.carbsG, greaterThan(100.0));
      expect(targets.fatG, greaterThan(40.0));
    });

    test('Enforces strict clinical safety floor (>=1300 kcal F / >=1500 kcal M)', () {
      // Very small female user with extreme deficit settings
      const extremeProfile = NutritionProfile(
        age: 45,
        heightCm: 150.0,
        currentWeightKg: 44.0,
        targetWeightKg: 40.0,
        sex: BiologicalSex.female,
        goal: DietGoal.gradualLoss,
        activityLevel: PhysicalActivityLevel.sedentary,
        paceKgPerWeek: 0.5,
      );

      final targets = NutritionScienceEngine.computeDailyTargets(extremeProfile);

      // Female clinical safety floor must strictly be clamped to 1300 kcal
      expect(targets.targetKcal, equals(1300.0));
      expect(targets.clinicalFloorApplied, isTrue);
      expect(targets.explanation, contains('clinical safety floor'));
    });

    test('Computes 7-Day Exponentially Weighted Moving Average (EWMA) trend math', () {
      final entries = [
        const WeightProgressEntry(id: '1', dateIso: '2026-10-01', weightKg: 72.0),
        const WeightProgressEntry(id: '2', dateIso: '2026-10-02', weightKg: 72.8), // temporary water spike
        const WeightProgressEntry(id: '3', dateIso: '2026-10-03', weightKg: 71.5),
        const WeightProgressEntry(id: '4', dateIso: '2026-10-04', weightKg: 71.2),
        const WeightProgressEntry(id: '5', dateIso: '2026-10-05', weightKg: 71.0),
      ];

      final trend = NutritionScienceEngine.computeWeightTrend(entries);

      expect(trend.latestRawKg, equals(71.0));
      // EWMA should be smoothed between 71 and 72
      expect(trend.currentEwmaKg, greaterThan(71.0));
      expect(trend.currentEwmaKg, lessThan(72.5));
      expect(trend.trendDirection, equals('losing'));
    });

    test('Generates non-shaming doctor and gym trainer balance insights', () {
      const profile = NutritionProfile(
        currentWeightKg: 70.0,
        allergies: ['Gluten'],
      );
      final targets = NutritionScienceEngine.computeDailyTargets(profile);

      // Only low protein logged today
      final logs = [
        DietLogEntry(
          id: '1',
          dateIso: '2026-10-18',
          mealSlot: MealSlot.breakfast,
          title: 'Fruit bowl',
          quantity: 1,
          gramsTotal: 150,
          kcal: 200,
          proteinG: 2.0,
          carbsG: 45,
          fatG: 1,
        ),
      ];

      final insights = NutritionScienceEngine.analyzeDayBalance(
        logs: logs,
        targets: targets,
        profile: profile,
      );

      expect(insights.any((i) => i.category == 'protein'), isTrue);
      final proteinInsight = insights.firstWhere((i) => i.category == 'protein');
      expect(proteinInsight.message, contains('protein target'));
    });
  });

  group('NativeDietAiEngine Tests', () {
    final testDb = IndianRegionalFoodDb.defaultFoods;

    test('Parses multi-item natural meal descriptions into structured draft entries', () {
      final drafts = NativeDietAiEngine.parseMealTextToDraftLogs(
        text: '2 appam with 1 cup egg roast and 1 glass chai',
        db: testDb,
        userAllergies: ['Egg'],
      );

      expect(drafts.length, equals(3));

      // Appam
      expect(drafts[0].title.toLowerCase(), contains('appam'));
      expect(drafts[0].quantity, equals(2.0));
      expect(drafts[0].kcal, greaterThan(100.0));

      // Egg Roast (should trigger user's Egg allergy warning)
      expect(drafts[1].title.toLowerCase(), contains('egg'));
      expect(drafts[1].allergenWarnings.isNotEmpty, isTrue);
      expect(drafts[1].allergenWarnings.first.toLowerCase(), contains('egg'));

      // Chai
      expect(drafts[2].title.toLowerCase(), contains('chai'));
    });

    test('Suggests smart recipe swaps respecting dietary pattern and allergies', () {
      const current = PlannedMealItem(
        id: 'p1',
        dateIso: '2026-10-18',
        mealSlot: MealSlot.dinner,
        title: 'Appam and Egg Roast',
        kcal: 385.0,
        proteinG: 16.5,
        carbsG: 48.0,
        fatG: 14.0,
      );

      // Vegetarian user who avoids eggs and seafood
      const profile = NutritionProfile(
        dietaryPattern: DietaryPattern.vegetarian,
        allergies: ['Egg', 'Fish'],
      );

      final swaps = NativeDietAiEngine.suggestMealSwaps(
        current: current,
        profile: profile,
        foods: IndianRegionalFoodDb.defaultFoods,
      );

      expect(swaps.isNotEmpty, isTrue);
      for (final s in swaps) {
        expect(s.kcal, closeTo(current.kcal, 180.0));
        // Must not contain egg or fish for vegetarian user
        expect(s.title.toLowerCase().contains('egg'), isFalse);
        expect(s.title.toLowerCase().contains('fish'), isFalse);
      }
    });

    test('Consolidates grocery list across planned meals and normalizes quantities', () {
      final foods = IndianRegionalFoodDb.defaultFoods;
      final plan = [
        const PlannedMealItem(
          id: 'm1',
          dateIso: '2026-10-18',
          mealSlot: MealSlot.breakfast,
          foodId: 'idli_steamed',
          title: 'Steamed Idli',
          kcal: 270,
          proteinG: 8.2,
          carbsG: 57,
          fatG: 1.2,
        ),
        const PlannedMealItem(
          id: 'm2',
          dateIso: '2026-10-19',
          mealSlot: MealSlot.breakfast,
          foodId: 'idli_steamed',
          title: 'Steamed Idli',
          kcal: 270,
          proteinG: 8.2,
          carbsG: 57,
          fatG: 1.2,
        ),
      ];

      final grocery = NativeDietAiEngine.buildConsolidatedGroceryList(
        plan: plan,
        foods: foods,
      );

      expect(grocery.isNotEmpty, isTrue);
      // Steamed Idli should be consolidated across m1 and m2
      final idliItem = grocery.firstWhere((g) => g.name.toLowerCase().contains('idli'));
      expect(idliItem.sourceMealIds.length, equals(2));
      expect(idliItem.estimatedCostInr, greaterThan(0));
    });
  });

  group('NativeTaskAiEngine Tests', () {
    test('Splits voice/text brain-dump into discrete tasks with confidence scores', () {
      final now = DateTime(2026, 10, 18, 10, 0);
      const text =
          'Submit OS lab record tomorrow at 5pm #OS !high, call IEEE team at 7pm ~30m, and finish B+ trees revision';

      final tasks = NativeTaskAiEngine.extractTasksFromBrainDump(text, now);

      expect(tasks.length, greaterThanOrEqualTo(2));

      // Task 1: OS lab
      final t1 = tasks[0];
      expect(t1.title.toLowerCase(), contains('os lab'));
      expect(t1.courseCode, equals('OS'));
      expect(t1.priority, equals(2)); // High
      expect(t1.confidence, greaterThanOrEqualTo(0.7));

      // Task 2: IEEE call
      final t2 = tasks[1];
      expect(t2.title.toLowerCase(), contains('ieee'));
      expect(t2.estimateMin, equals(30));
    });

    test('Extracts academic syllabus assignments, exams, and course codes', () {
      final now = DateTime(2026, 10, 18);
      const syllabus = '''
Course: CS301 Database Management Systems
Module 1 Quiz on 24/10 ~45m
Assignment 2 Relational Algebra due Oct 28 !urgent
Midterm Exam on 05/11 #CS301
''';

      final tasks = NativeTaskAiEngine.extractTasksFromDocumentText(syllabus, now);

      expect(tasks.length, greaterThanOrEqualTo(3));
      expect(tasks.any((t) => t.title.contains('Assignment 2')), isTrue);
      expect(tasks.any((t) => t.title.contains('Midterm Exam')), isTrue);
      expect(tasks.any((t) => t.courseCode == 'CS301'), isTrue);
    });
  });
}
