import 'package:hive/hive.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';

part 'diet_models.g.dart';

@HiveType(typeId: 20)
enum MealType {
  @HiveField(0)
  breakfast,
  @HiveField(1)
  lunch,
  @HiveField(2)
  dinner,
  @HiveField(3)
  snack,
}

@HiveType(typeId: 21)
class FoodEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double calories;

  @HiveField(3)
  double protein;

  @HiveField(4)
  double carbs;

  @HiveField(5)
  double fat;

  @HiveField(6)
  DateTime timestamp;

  @HiveField(7)
  MealType mealType;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.timestamp,
    required this.mealType,
  });
}

@HiveType(typeId: 22)
class CalorieBurnEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String activity;

  @HiveField(2)
  double caloriesBurned;

  @HiveField(3)
  int durationMinutes;

  @HiveField(4)
  DateTime timestamp;

  CalorieBurnEntry({
    required this.id,
    required this.activity,
    required this.caloriesBurned,
    required this.durationMinutes,
    required this.timestamp,
  });
}

@HiveType(typeId: 23)
class DietDayLog extends HiveObject {
  @HiveField(0)
  final String dateKey; // e.g. "2026-07-02"

  @HiveField(1)
  List<FoodEntry> entries;

  @HiveField(2)
  List<CalorieBurnEntry> burnEntries;

  @HiveField(3)
  double targetCalories;

  @HiveField(4)
  String notes;

  DietDayLog({
    required this.dateKey,
    List<FoodEntry>? entries,
    List<CalorieBurnEntry>? burnEntries,
    this.targetCalories = 2000.0,
    this.notes = '',
  })  : entries = entries ?? [],
        burnEntries = burnEntries ?? [];

  // Computed totals
  double get totalCalories => entries.fold(0.0, (sum, e) => sum + e.calories);
  double get totalProtein => entries.fold(0.0, (sum, e) => sum + e.protein);
  double get totalCarbs => entries.fold(0.0, (sum, e) => sum + e.carbs);
  double get totalFat => entries.fold(0.0, (sum, e) => sum + e.fat);
  double get totalBurned => burnEntries.fold(0.0, (sum, e) => sum + e.caloriesBurned);
  double get netCalories => totalCalories - totalBurned;
  double get deficit => targetCalories - netCalories;
  bool get isDeficit => deficit > 0;

  // Helpers for meal grouping
  List<FoodEntry> entriesForMeal(MealType meal) =>
      entries.where((e) => e.mealType == meal).toList();

  void addFood(FoodEntry entry) {
    bool wasDeficit = isDeficit;
    entries.add(entry);
    save();
    
    // If they were in deficit but adding food pushed them over, subtract XP
    if (wasDeficit && !isDeficit) {
      GlobalXPService.subtractXP(20);
    }
  }

  void addBurn(CalorieBurnEntry burn) {
    bool wasDeficit = isDeficit;
    burnEntries.add(burn);
    save();
    
    // If they weren't in deficit but burning pushed them under, add XP
    if (!wasDeficit && isDeficit) {
      GlobalXPService.addXP(20);
    }
  }

  void removeFood(String entryId) {
    bool wasDeficit = isDeficit;
    entries.removeWhere((e) => e.id == entryId);
    save();
    
    if (!wasDeficit && isDeficit) {
      GlobalXPService.addXP(20);
    }
  }

  void removeBurn(String burnId) {
    burnEntries.removeWhere((e) => e.id == burnId);
    save();
  }
}
