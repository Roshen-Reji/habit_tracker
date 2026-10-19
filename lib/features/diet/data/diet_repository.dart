import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/engine/nutrition_science_engine.dart';
import 'package:habit_tracker/features/diet/engine/native_diet_ai_engine.dart';
import 'package:habit_tracker/data/models/diet_models.dart';

/// Single source of truth for the Diet Planner OS.
/// Encapsulates all Hive persistence, debounces rapid duplicate taps,
/// and synchronizes with legacy [DietDayLog] so all existing home cards remain 100% reactive.
class DietRepository extends ChangeNotifier {
  static final DietRepository instance = DietRepository._internal();
  factory DietRepository() => instance;
  DietRepository._internal();

  Box? _box;
  bool _initialized = false;

  // In-memory reactive state
  NutritionProfile _profile = const NutritionProfile();
  final List<FoodItemData> _foods = [];
  final List<CustomFoodItem> _customFoods = [];
  final List<DietLogEntry> _logs = [];
  final List<PlannedMealItem> _plannedMeals = [];
  final List<GroceryItem> _groceryList = [];
  final List<WeightProgressEntry> _weightEntries = [];
  final Map<String, double> _waterLogs = {};

  // Duplicate-tap guard
  String? _lastLogSignature;
  DateTime? _lastLogTime;

  // Getters
  bool get isInitialized => _initialized;
  NutritionProfile get profile => _profile;
  List<FoodItemData> get foods => List.unmodifiable(_foods);
  List<CustomFoodItem> get customFoods => List.unmodifiable(_customFoods);
  List<DietLogEntry> get logs => List.unmodifiable(_logs);
  List<DietLogEntry> get todayLogs => getLogsForDate(_todayKey());
  List<PlannedMealItem> get plannedMeals => List.unmodifiable(_plannedMeals);
  List<GroceryItem> get groceryList => List.unmodifiable(_groceryList);
  List<WeightProgressEntry> get weightEntries => List.unmodifiable(_weightEntries);

  /// Dynamically calculated targets according to Mifflin-St Jeor + Gym training rules.
  DailyTargets get dailyTargets => NutritionScienceEngine.computeDailyTargets(_profile);

  /// 7-day EWMA smoothed weight trend.
  EWMAWeightTrend get weightTrend =>
      NutritionScienceEngine.computeWeightTrend(
        _weightEntries,
        defaultWeightKg: _profile.currentWeightKg,
      );

  /// Water intake in ml for a given date.
  double waterDrankMl(String dateIso) => _waterLogs[dateIso] ?? 0.0;

  /// Logs for a specific date (YYYY-MM-DD).
  List<DietLogEntry> getLogsForDate(String dateIso) {
    return _logs.where((l) => l.dateIso == dateIso).toList();
  }

  /// Planned meals for a specific date (YYYY-MM-DD).
  List<PlannedMealItem> getPlannedMealsForDate(String dateIso) {
    return _plannedMeals.where((m) => m.dateIso == dateIso).toList();
  }

  /// Doctor & Trainer insights for today.
  List<DoctorTrainerInsight> get todayInsights {
    final today = _todayKey();
    return NutritionScienceEngine.analyzeDayBalance(
      logs: getLogsForDate(today),
      targets: dailyTargets,
      profile: _profile,
      loggedWaterMl: waterDrankMl(today),
    );
  }

  /// Initialize repository and load persisted data.
  Future<void> init() async {
    if (_initialized) return;

    // Clean slate: Zero preloaded food clutter.
    _foods.clear();

    try {
      if (Hive.isBoxOpen('diet_os_box')) {
        _box = Hive.box('diet_os_box');
      } else {
        _box = await Hive.openBox('diet_os_box');
      }
    } catch (e) {
      debugPrint('DietRepository Hive open warning: $e');
    }

    _loadFromStorage();
    _initialized = true;
    notifyListeners();
  }

  void _loadFromStorage() {
    if (_box == null) {
      _loadDefaultsInMemory();
      return;
    }

    // 1. Profile
    final rawProfile = _box!.get('profile');
    if (rawProfile is Map) {
      _profile = NutritionProfile.fromJson(Map<String, dynamic>.from(rawProfile));
    } else {
      _profile = const NutritionProfile();
    }

    // 2. Custom Foods
    _customFoods.clear();
    final rawCustom = _box!.get('custom_foods');
    if (rawCustom is List) {
      for (final item in rawCustom) {
        if (item is Map) {
          _customFoods.add(CustomFoodItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 3. Food Logs
    _logs.clear();
    final rawLogs = _box!.get('logs');
    if (rawLogs is List) {
      for (final item in rawLogs) {
        if (item is Map) {
          _logs.add(DietLogEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 4. Planned Meals (purge any legacy placeholder entries)
    _plannedMeals.clear();
    final rawPlanned = _box!.get('planned_meals');
    if (rawPlanned is List) {
      for (final item in rawPlanned) {
        if (item is Map) {
          final meal = PlannedMealItem.fromJson(Map<String, dynamic>.from(item));
          if (!meal.id.startsWith('seed_') && !meal.id.startsWith('plan_default_')) {
            _plannedMeals.add(meal);
          }
        }
      }
    }

    // 5. Recipes (remove box key permanently)
    _box!.delete('recipes');

    // 6. Grocery List (purge any legacy placeholder entries)
    _groceryList.clear();
    final rawGrocery = _box!.get('grocery_items');
    if (rawGrocery is List) {
      for (final item in rawGrocery) {
        if (item is Map) {
          final g = GroceryItem.fromJson(Map<String, dynamic>.from(item));
          if (!g.id.startsWith('seed_')) {
            _groceryList.add(g);
          }
        }
      }
    }

    // 7. Weight Progress (purge any legacy placeholder fake weigh-ins)
    _weightEntries.clear();
    final rawWeights = _box!.get('weight_entries');
    if (rawWeights is List) {
      for (final item in rawWeights) {
        if (item is Map) {
          final w = WeightProgressEntry.fromJson(Map<String, dynamic>.from(item));
          if (!w.id.startsWith('seed_wt_')) {
            _weightEntries.add(w);
          }
        }
      }
    }

    // 8. Water Logs
    _waterLogs.clear();
    final rawWater = _box!.get('water_logs');
    if (rawWater is Map) {
      rawWater.forEach((k, v) {
        if (v is num) _waterLogs[k.toString()] = v.toDouble();
      });
    }

    // Write back cleaned lists to purge any previous placeholders from storage
    _box!.put('planned_meals', _plannedMeals.map((e) => e.toJson()).toList());
    _box!.put('grocery_items', _groceryList.map((e) => e.toJson()).toList());
    _box!.put('weight_entries', _weightEntries.map((e) => e.toJson()).toList());
    _box!.put('custom_foods', _customFoods.map((e) => e.toJson()).toList());
  }

  void _loadDefaultsInMemory() {
    _profile = const NutritionProfile();
    _customFoods.clear();
    _plannedMeals.clear();
    _groceryList.clear();
    _weightEntries.clear();
  }

  Future<void> regenerateGroceryList() async {
    _groceryList.clear();
    _groceryList.addAll(
      NativeDietAiEngine.buildConsolidatedGroceryList(
        plan: _plannedMeals,
        foods: _foods,
        existingPantry: _groceryList.where((g) => g.inPantry).toList(),
      ),
    );
    await _box?.put('grocery_items', _groceryList.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // MUTATION METHODS
  // ---------------------------------------------------------------------------

  /// Updates profile and syncs targets across legacy boxes.
  Future<void> updateProfile(NutritionProfile newProfile) async {
    _profile = newProfile;
    await _box?.put('profile', _profile.toJson());
    _syncLegacyTargets();
    notifyListeners();
  }

  /// Alias conforming to domain specification.
  Future<void> saveNutritionProfile(NutritionProfile newProfile) => updateProfile(newProfile);

  /// Upserts user custom food item into local reactive storage.
  Future<void> upsertCustomFood(CustomFoodItem item) async {
    final idx = _customFoods.indexWhere((f) => f.id == item.id);
    if (idx != -1) {
      _customFoods[idx] = item;
    } else {
      _customFoods.add(item);
    }
    await _box?.put('custom_foods', _customFoods.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Deletes user custom food item.
  Future<void> deleteCustomFood(String id) async {
    _customFoods.removeWhere((f) => f.id == id);
    await _box?.put('custom_foods', _customFoods.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Logs a food entry with a 500ms duplicate-tap debouncer.
  Future<bool> logFood(DietLogEntry entry) async {
    final signature = '${entry.dateIso}_${entry.title}_${entry.gramsTotal.round()}';
    final now = DateTime.now();

    // 500ms debounce guard
    if (_lastLogSignature == signature && _lastLogTime != null) {
      final diffMs = now.difference(_lastLogTime!).inMilliseconds;
      if (diffMs < 500) {
        debugPrint('DietRepository: Duplicate tap ignored for $signature (${diffMs}ms)');
        return false;
      }
    }

    _lastLogSignature = signature;
    _lastLogTime = now;

    _logs.add(entry);
    await _box?.put('logs', _logs.map((e) => e.toJson()).toList());

    // Synchronize to legacy DietDayLog for Home cards & Wearable reconciler
    _syncFoodEntryToLegacy(entry);

    notifyListeners();
    return true;
  }

  /// Conforming alias for logFood.
  Future<bool> logMeal(DietLogEntry entry) => logFood(entry);

  /// Updates an existing logged food item.
  Future<void> updateMealLog(DietLogEntry entry) async {
    final idx = _logs.indexWhere((l) => l.id == entry.id);
    if (idx != -1) {
      _logs[idx] = entry;
      await _box?.put('logs', _logs.map((e) => e.toJson()).toList());
      _syncFoodEntryToLegacy(entry);
      notifyListeners();
    }
  }

  /// Deletes a logged food item.
  Future<void> deleteFoodLog(String logId) async {
    final idx = _logs.indexWhere((l) => l.id == logId);
    if (idx != -1) {
      final entry = _logs.removeAt(idx);
      await _box?.put('logs', _logs.map((e) => e.toJson()).toList());
      _deleteFoodFromLegacy(entry.dateIso, logId);
      notifyListeners();
    }
  }

  /// Conforming alias for deleteFoodLog.
  Future<void> deleteMealLog(String id) => deleteFoodLog(id);

  /// Adds water in ml for a given date (defaults to today).
  Future<void> addWater(double ml, {String? dateIso}) async {
    final date = dateIso ?? _todayKey();
    final current = _waterLogs[date] ?? 0.0;
    _waterLogs[date] = (current + ml).clamp(0.0, 8000.0);
    await _box?.put('water_logs', _waterLogs);
    notifyListeners();
  }

  /// Sets absolute water intake for a date.
  Future<void> setWater(double ml, {String? dateIso}) async {
    final date = dateIso ?? _todayKey();
    _waterLogs[date] = ml.clamp(0.0, 8000.0);
    await _box?.put('water_logs', _waterLogs);
    notifyListeners();
  }

  /// Logs a weight weigh-in and updates the 7-day EWMA trend.
  Future<void> logWeight(
    double weightKg, {
    double? waistCm,
    String notes = '',
    String? dateIso,
  }) async {
    final date = dateIso ?? _todayKey();
    _weightEntries.removeWhere((w) => w.dateIso == date);
    _weightEntries.add(
      WeightProgressEntry(
        id: 'wt_${DateTime.now().millisecondsSinceEpoch}',
        dateIso: date,
        weightKg: weightKg,
        waistCm: waistCm,
        notes: notes,
      ),
    );
    _weightEntries.sort((a, b) => a.dateIso.compareTo(b.dateIso));
    await _box?.put('weight_entries', _weightEntries.map((e) => e.toJson()).toList());

    // Update current profile weight
    if (date == _todayKey()) {
      _profile = _profile.copyWith(currentWeightKg: weightKg);
      await _box?.put('profile', _profile.toJson());
    }

    notifyListeners();
  }

  /// Deletes a weigh-in entry.
  Future<void> deleteWeightEntry(String id) async {
    _weightEntries.removeWhere((w) => w.id == id);
    await _box?.put('weight_entries', _weightEntries.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Updates status of a planned meal (e.g. eaten, skipped, ateOut).
  Future<void> updateMealStatus(String mealId, PlannedMealStatus newStatus) async {
    final idx = _plannedMeals.indexWhere((m) => m.id == mealId);
    if (idx != -1) {
      final current = _plannedMeals[idx];
      _plannedMeals[idx] = current.copyWith(status: newStatus);

      // If marked eaten, log as a draft food entry if not already logged
      if (newStatus == PlannedMealStatus.eaten) {
        final existing = _logs.any((l) =>
            l.dateIso == current.dateIso &&
            l.mealSlot == current.mealSlot &&
            l.title == current.title);
        if (!existing) {
          await logFood(
            DietLogEntry(
              id: 'logged_plan_${current.id}',
              dateIso: current.dateIso,
              mealSlot: current.mealSlot,
              foodId: current.foodId,
              title: current.title,
              quantity: current.servings,
              gramsTotal: 150.0 * current.servings,
              kcal: current.kcal,
              proteinG: current.proteinG,
              carbsG: current.carbsG,
              fatG: current.fatG,
              fibreG: current.fibreG,
              notes: 'Logged from planned meal',
            ),
          );
        }
      }

      await _box?.put('planned_meals', _plannedMeals.map((e) => e.toJson()).toList());
      notifyListeners();
    }
  }

  /// Swaps or updates a single planned meal.
  Future<void> savePlannedMeal(PlannedMealItem item) async {
    final idx = _plannedMeals.indexWhere((m) => m.id == item.id);
    if (idx != -1) {
      _plannedMeals[idx] = item;
    } else {
      _plannedMeals.add(item);
    }
    await _box?.put('planned_meals', _plannedMeals.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Overwrites planned meals for a given date.
  Future<void> setPlannedMealsForDate(String dateIso, List<PlannedMealItem> meals) async {
    _plannedMeals.removeWhere((m) => m.dateIso == dateIso);
    _plannedMeals.addAll(meals);
    await _box?.put('planned_meals', _plannedMeals.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Toggles grocery checked item.
  Future<void> toggleGroceryItem(String id) async {
    final idx = _groceryList.indexWhere((g) => g.id == id);
    if (idx != -1) {
      final current = _groceryList[idx];
      _groceryList[idx] = current.copyWith(isChecked: !current.isChecked);
      await _box?.put('grocery_items', _groceryList.map((e) => e.toJson()).toList());
      notifyListeners();
    }
  }

  /// Toggles whether an item is on-hand in pantry.
  Future<void> togglePantryItem(String id) async {
    final idx = _groceryList.indexWhere((g) => g.id == id);
    if (idx != -1) {
      final current = _groceryList[idx];
      _groceryList[idx] = current.copyWith(inPantry: !current.inPantry);
      await _box?.put('grocery_items', _groceryList.map((e) => e.toJson()).toList());
      notifyListeners();
    }
  }

  /// Adds a custom grocery item.
  Future<void> addCustomGroceryItem(GroceryItem item) async {
    _groceryList.add(item);
    await _box?.put('grocery_items', _groceryList.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Deletes a grocery item.
  Future<void> deleteGroceryItem(String id) async {
    _groceryList.removeWhere((g) => g.id == id);
    await _box?.put('grocery_items', _groceryList.map((e) => e.toJson()).toList());
    notifyListeners();
  }



  // ---------------------------------------------------------------------------
  // SYNCHRONIZATION WITH LEGACY DIET BOXES
  // ---------------------------------------------------------------------------

  void _syncLegacyTargets() {
    try {
      if (Hive.isBoxOpen('diet_logs')) {
        final box = Hive.box<DietDayLog>('diet_logs');
        final today = _todayKey();
        final dayLog = box.get(today);
        if (dayLog != null) {
          dayLog.targetCalories = dailyTargets.targetKcal;
          dayLog.save();
        }
      }
    } catch (_) {}
  }

  void _syncFoodEntryToLegacy(DietLogEntry entry) {
    try {
      if (Hive.isBoxOpen('diet_logs')) {
        final box = Hive.box<DietDayLog>('diet_logs');
        final dayLog = box.get(entry.dateIso) ??
            DietDayLog(
              dateKey: entry.dateIso,
              targetCalories: dailyTargets.targetKcal,
            );

        MealType mealType;
        switch (entry.mealSlot) {
          case MealSlot.breakfast:
            mealType = MealType.breakfast;
            break;
          case MealSlot.lunch:
            mealType = MealType.lunch;
            break;
          case MealSlot.snack:
            mealType = MealType.snack;
            break;
          case MealSlot.dinner:
            mealType = MealType.dinner;
            break;
        }

        final foodEntry = FoodEntry(
          id: entry.id,
          name: entry.title,
          calories: entry.kcal,
          protein: entry.proteinG,
          carbs: entry.carbsG,
          fat: entry.fatG,
          timestamp: entry.loggedAt,
          mealType: mealType,
        );

        dayLog.addFood(foodEntry);
        if (!box.containsKey(entry.dateIso)) {
          box.put(entry.dateIso, dayLog);
        }
      }
    } catch (_) {}
  }

  void _deleteFoodFromLegacy(String dateIso, String foodId) {
    try {
      if (Hive.isBoxOpen('diet_logs')) {
        final box = Hive.box<DietDayLog>('diet_logs');
        final dayLog = box.get(dateIso);
        if (dayLog != null) {
          dayLog.removeFood(foodId);
        }
      }
    } catch (_) {}
  }

  String _todayKey() => DateTime.now().toIso8601String().split('T').first;
}
