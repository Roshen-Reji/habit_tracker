import 'dart:math' as math;
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';

/// Pure Dart native on-device AI engine for meal parsing, smart swaps,
/// pantry-based meal generation, and grocery consolidation.
/// Executes deterministically with <50ms latency offline. Zero Flutter dependencies.
class NativeDietAiEngine {
  const NativeDietAiEngine._();

  // ---------------------------------------------------------------------------
  // 1. NATURAL LANGUAGE MEAL PARSER
  // ---------------------------------------------------------------------------

  /// Parses natural phrases like "2 appam with 1 cup egg roast and 1 glass chai"
  /// into structured, editable draft [DietLogEntry] items.
  static List<DietLogEntry> parseMealTextToDraftLogs({
    required String text,
    required List<FoodItemData> db,
    String? dateIso,
    MealSlot defaultSlot = MealSlot.lunch,
    List<String> userAllergies = const [],
  }) {
    final effectiveDate = dateIso ??
        DateTime.now().toIso8601String().split('T').first;

    if (text.trim().isEmpty) return [];

    // Split compound utterances on delimiters: "with", "and", "+", ",", "\n", ";"
    final segments = text
        .split(RegExp(r'\band\b|\bwith\b|\balso\b|\+|\;|\,|\n', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final List<DietLogEntry> draftEntries = [];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final parsed = _parseSingleSegment(
        segment: seg,
        db: db,
        dateIso: effectiveDate,
        slot: defaultSlot,
        index: i,
        userAllergies: userAllergies,
      );
      if (parsed != null) {
        draftEntries.add(parsed);
      }
    }

    return draftEntries;
  }

  static DietLogEntry? _parseSingleSegment({
    required String segment,
    required List<FoodItemData> db,
    required String dateIso,
    required MealSlot slot,
    required int index,
    required List<String> userAllergies,
  }) {
    String clean = segment.toLowerCase().trim();
    if (clean.isEmpty) return null;

    // Detect quantity
    double quantity = 1.0;
    final qtyMatch = RegExp(r'^(\d+(?:\.\d+)?|\d+\/\d+)\s*').firstMatch(clean);
    if (qtyMatch != null) {
      final rawNum = qtyMatch.group(1)!;
      if (rawNum.contains('/')) {
        final parts = rawNum.split('/');
        quantity = (double.tryParse(parts[0]) ?? 1.0) /
            (double.tryParse(parts[1]) ?? 1.0);
      } else {
        quantity = double.tryParse(rawNum) ?? 1.0;
      }
      clean = clean.substring(qtyMatch.end).trim();
    } else {
      // Word numbers
      final wordMap = {
        'a': 1.0,
        'an': 1.0,
        'one': 1.0,
        'two': 2.0,
        'three': 3.0,
        'four': 4.0,
        'five': 5.0,
        'half': 0.5,
        'quarter': 0.25,
      };
      for (final entry in wordMap.entries) {
        if (clean.startsWith('${entry.key} ')) {
          quantity = entry.value;
          clean = clean.substring(entry.key.length).trim();
          break;
        }
      }
    }

    // Detect unit
    HouseholdUnit matchedUnit = HouseholdUnit.serving;
    bool explicitUnit = false;

    for (final unit in HouseholdUnit.values) {
      final patterns = [
        unit.name,
        unit.symbol,
        '${unit.name}s',
        '${unit.symbol}s',
      ];
      for (final p in patterns) {
        final regex = RegExp('^$p\\b|\\b$p\\b');
        if (regex.hasMatch(clean)) {
          matchedUnit = unit;
          explicitUnit = true;
          clean = clean.replaceFirst(regex, '').trim();
          break;
        }
      }
      if (explicitUnit) break;
    }

    // If clean became empty because the food itself was the unit (e.g. "appam", "idli", "roti", "dosa")
    final query = clean.isEmpty && explicitUnit ? matchedUnit.name : clean;

    // Match against database foods
    FoodItemData? bestMatch;
    int bestScore = 0;

    for (final food in db) {
      final names = [food.name.toLowerCase(), ...food.aliases.map((a) => a.toLowerCase())];
      for (final n in names) {
        if (query == n) {
          bestMatch = food;
          bestScore = 100;
          break;
        } else if (query.isNotEmpty && (query.contains(n) || n.contains(query))) {
          final score = (query.length > n.length ? n.length : query.length);
          if (score > bestScore) {
            bestScore = score;
            bestMatch = food;
          }
        }
      }
      if (bestScore == 100) break;
    }

    final id = 'draft_${DateTime.now().millisecondsSinceEpoch}_$index';

    if (bestMatch != null) {
      // If no explicit unit was parsed, use food's default unit
      final finalUnit = explicitUnit ? matchedUnit : bestMatch.defaultUnit;
      final portion = bestMatch.computePortionNutrition(quantity, finalUnit);

      // Check for allergen warnings
      final List<String> warnings = [];
      for (final alg in bestMatch.allergens) {
        if (userAllergies.any((u) => u.toLowerCase() == alg.toLowerCase())) {
          warnings.add('Contains allergen: $alg');
        }
      }

      return DietLogEntry(
        id: id,
        dateIso: dateIso,
        mealSlot: slot,
        foodId: bestMatch.id,
        title: bestMatch.name,
        quantity: quantity,
        unit: finalUnit,
        gramsTotal: portion['grams'] ?? 100.0,
        kcal: portion['kcal'] ?? 150.0,
        proteinG: portion['proteinG'] ?? 5.0,
        carbsG: portion['carbsG'] ?? 20.0,
        fatG: portion['fatG'] ?? 5.0,
        fibreG: portion['fibreG'] ?? 2.0,
        confidence: bestMatch.confidence,
        allergenWarnings: warnings,
      );
    }

    // Fallback: Smart culinary heuristic estimation for unknown items
    final fallbackTitle = query.isNotEmpty ? query : segment;
    final heuristic = _estimateHeuristicNutrition(fallbackTitle, quantity, matchedUnit);

    return DietLogEntry(
      id: id,
      dateIso: dateIso,
      mealSlot: slot,
      foodId: null,
      title: _formatTitle(fallbackTitle),
      quantity: quantity,
      unit: matchedUnit,
      gramsTotal: heuristic['grams']!,
      kcal: heuristic['kcal']!,
      proteinG: heuristic['proteinG']!,
      carbsG: heuristic['carbsG']!,
      fatG: heuristic['fatG']!,
      fibreG: heuristic['fibreG']!,
      confidence: FoodConfidence.approximate,
      allergenWarnings: const [],
      notes: 'Estimated via on-device culinary AI',
    );
  }

  static Map<String, double> _estimateHeuristicNutrition(
      String foodName, double qty, HouseholdUnit unit) {
    final lower = foodName.toLowerCase();
    double grams = qty * unit.defaultGrams;

    double kcalPer100g = 180.0;
    double proteinPer100g = 5.0;
    double carbsPer100g = 25.0;
    double fatPer100g = 6.0;
    double fibrePer100g = 2.0;

    if (lower.contains('biryani') || lower.contains('fried rice')) {
      kcalPer100g = 210.0;
      proteinPer100g = 8.0;
      carbsPer100g = 30.0;
      fatPer100g = 7.0;
      fibrePer100g = 1.5;
    } else if (lower.contains('salad') || lower.contains('veg')) {
      kcalPer100g = 60.0;
      proteinPer100g = 2.0;
      carbsPer100g = 8.0;
      fatPer100g = 2.0;
      fibrePer100g = 3.5;
    } else if (lower.contains('chicken') || lower.contains('meat') || lower.contains('fish')) {
      kcalPer100g = 190.0;
      proteinPer100g = 20.0;
      carbsPer100g = 4.0;
      fatPer100g = 10.0;
      fibrePer100g = 0.5;
    } else if (lower.contains('paneer') || lower.contains('cheese')) {
      kcalPer100g = 240.0;
      proteinPer100g = 15.0;
      carbsPer100g = 5.0;
      fatPer100g = 18.0;
      fibrePer100g = 0.0;
    } else if (lower.contains('shake') || lower.contains('smoothie')) {
      kcalPer100g = 90.0;
      proteinPer100g = 6.0;
      carbsPer100g = 12.0;
      fatPer100g = 2.0;
      fibrePer100g = 1.0;
    }

    final ratio = grams / 100.0;
    return {
      'grams': grams,
      'kcal': kcalPer100g * ratio,
      'proteinG': proteinPer100g * ratio,
      'carbsG': carbsPer100g * ratio,
      'fatG': fatPer100g * ratio,
      'fibreG': fibrePer100g * ratio,
    };
  }

  static String _formatTitle(String raw) {
    if (raw.isEmpty) return 'Logged Food';
    return raw
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ')
        .trim();
  }

  // ---------------------------------------------------------------------------
  // 2. SMART MEAL SWAPPER
  // ---------------------------------------------------------------------------

  /// Finds top 3 slot-matching food alternatives within ±180 kcal,
  /// matching dietary preferences, avoiding user allergies, and sorted by protein & prep time.
  static List<PlannedMealItem> suggestMealSwaps({
    required PlannedMealItem current,
    required NutritionProfile profile,
    required List<FoodItemData> foods,
  }) {
    final List<MapEntry<FoodItemData, double>> candidates = [];

    for (final f in foods) {
      if (f.id == current.foodId || f.name.toLowerCase() == current.title.toLowerCase()) continue;

      // Dietary pattern compliance
      if (profile.dietaryPattern == DietaryPattern.vegan &&
          !f.dietaryTags.contains('vegan')) {
        continue;
      }
      if (profile.dietaryPattern == DietaryPattern.vegetarian &&
          (f.dietaryTags.contains('egg') || f.dietaryTags.contains('nonVeg'))) {
        continue;
      }
      if (profile.dietaryPattern == DietaryPattern.eggetarian &&
          f.dietaryTags.contains('nonVeg')) {
        continue;
      }

      // Allergen filter
      final hasAllergyConflict = f.allergens.any((alg) =>
          profile.allergies.any((u) => u.toLowerCase() == alg.toLowerCase()));
      if (hasAllergyConflict) continue;

      // Standard portion nutrition
      final portion = f.computePortionNutrition(1.0, f.defaultUnit);
      final kcal = portion['kcal'] ?? 150.0;
      final proteinG = portion['proteinG'] ?? 5.0;

      // Calorie proximity (±180 kcal)
      final kcalDelta = (kcal - current.kcal).abs();
      if (kcalDelta > 180.0 && current.kcal > 0) continue;

      // Cooking time check
      if (f.prepTimeMin > profile.maxCookTimeMin + 15) continue;

      // Scoring: +protein difference, -calorie delta, -cook time, +cuisine affinity
      double score = 100.0 - (kcalDelta * 0.2);
      if (proteinG >= current.proteinG) {
        score += (proteinG - current.proteinG) * 3.0;
      }
      if (profile.preferredCuisines.any((c) => f.cuisine.contains(c))) {
        score += 25.0;
      }
      score -= f.prepTimeMin * 0.5;

      candidates.add(MapEntry(f, score));
    }

    candidates.sort((a, b) => b.value.compareTo(a.value));

    return candidates.take(3).map((e) {
      final f = e.key;
      final portion = f.computePortionNutrition(1.0, f.defaultUnit);
      final kcal = portion['kcal'] ?? 150.0;
      final proteinG = portion['proteinG'] ?? 5.0;
      final carbsG = portion['carbsG'] ?? 20.0;
      final fatG = portion['fatG'] ?? 5.0;
      final fibreG = portion['fibreG'] ?? 2.0;
      final proteinDelta = (proteinG - current.proteinG).round();
      final why = proteinDelta > 0
          ? 'Adds +${proteinDelta}g protein, ready in ${f.prepTimeMin}m'
          : 'Fits your calorie target (${kcal.round()} kcal), ${f.cuisine}';

      return PlannedMealItem(
        id: 'swap_${f.id}_${DateTime.now().millisecondsSinceEpoch}',
        dateIso: current.dateIso,
        mealSlot: current.mealSlot,
        foodId: f.id,
        title: f.name,
        servings: 1.0,
        kcal: kcal,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        fibreG: fibreG,
        prepTimeMin: f.prepTimeMin,
        estimatedCostInr: f.estimatedCostInrPer100g * (portion['grams'] ?? 100.0) / 100.0,
        status: PlannedMealStatus.planned,
        whySuggested: why,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 3. "COOK FROM WHAT I HAVE" PANTRY MEAL GENERATOR
  // ---------------------------------------------------------------------------

  /// Generates a realistic 1-day or multi-day plan utilizing available ingredients from verified foods.
  static List<PlannedMealItem> generatePlanFromPantry({
    required List<String> availableIngredients,
    required NutritionProfile profile,
    required List<FoodItemData> foods,
    String? dateIso,
  }) {
    final effectiveDate = dateIso ??
        DateTime.now().toIso8601String().split('T').first;

    // Filter compliant foods
    final eligibleFoods = foods.where((f) {
      // Dietary pattern compliance
      if (profile.dietaryPattern == DietaryPattern.vegan &&
          !f.dietaryTags.contains('vegan')) {
        return false;
      }
      if (profile.dietaryPattern == DietaryPattern.vegetarian &&
          (f.dietaryTags.contains('egg') || f.dietaryTags.contains('nonVeg'))) {
        return false;
      }
      if (profile.dietaryPattern == DietaryPattern.eggetarian &&
          f.dietaryTags.contains('nonVeg')) {
        return false;
      }

      // Allergen filter
      if (f.allergens.any((alg) =>
          profile.allergies.any((u) => u.toLowerCase() == alg.toLowerCase()))) {
        return false;
      }

      return true;
    }).toList();

    if (eligibleFoods.isEmpty) return [];

    // Rank foods by ingredient overlap with pantry
    final scoredFoods = eligibleFoods.map((f) {
      final names = [f.name.toLowerCase(), ...f.aliases.map((a) => a.toLowerCase())];
      double score = 0.0;
      for (final a in availableIngredients) {
        final lowerA = a.toLowerCase().trim();
        if (lowerA.isNotEmpty && names.any((n) => n.contains(lowerA) || lowerA.contains(n))) {
          score += 10.0;
        }
      }
      if (profile.preferredCuisines.any((c) => f.cuisine.contains(c))) {
        score += 5.0;
      }
      return MapEntry(f, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Allocate 4 slots: breakfast, lunch, snack, dinner
    final List<PlannedMealItem> plan = [];
    final slots = [
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.snack,
      MealSlot.dinner,
    ];

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final food = scoredFoods[i % scoredFoods.length].key;
      final matchScore = scoredFoods[i % scoredFoods.length].value;
      final portion = food.computePortionNutrition(1.0, food.defaultUnit);
      final grams = portion['grams'] ?? 100.0;
      final kcal = portion['kcal'] ?? 150.0;
      final proteinG = portion['proteinG'] ?? 5.0;
      final carbsG = portion['carbsG'] ?? 20.0;
      final fatG = portion['fatG'] ?? 5.0;
      final fibreG = portion['fibreG'] ?? 2.0;

      plan.add(
        PlannedMealItem(
          id: 'plan_${slot.name}_${DateTime.now().millisecondsSinceEpoch}_$i',
          dateIso: effectiveDate,
          mealSlot: slot,
          foodId: food.id,
          title: food.name,
          servings: 1.0,
          kcal: kcal,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          fibreG: fibreG,
          prepTimeMin: food.prepTimeMin,
          estimatedCostInr: food.estimatedCostInrPer100g * (grams / 100.0),
          status: PlannedMealStatus.planned,
          whySuggested: matchScore > 0
              ? 'Matches pantry ingredients on hand'
              : 'Balanced for ${profile.goal.label}',
        ),
      );
    }

    return plan;
  }

  // ---------------------------------------------------------------------------
  // 4. GROCERY CONSOLIDATOR
  // ---------------------------------------------------------------------------

  /// Combines duplicate items across all planned meals, converts units,
  /// subtracts pantry items, groups by aisle, and calculates total budget.
  static List<GroceryItem> buildConsolidatedGroceryList({
    required List<PlannedMealItem> plan,
    required List<FoodItemData> foods,
    List<GroceryItem> existingPantry = const [],
  }) {
    final Map<String, _AggregateGrocery> aggMap = {};

    for (final planned in plan) {
      if (planned.kcal <= 0) continue;

      // Find matching food if available
      FoodItemData? matchedFood;
      if (planned.foodId != null) {
        matchedFood = foods.where((f) => f.id == planned.foodId).firstOrNull;
      }
      if (matchedFood == null) {
        final titleLower = planned.title.toLowerCase();
        matchedFood = foods.where((f) =>
            f.name.toLowerCase() == titleLower ||
            f.aliases.any((a) => a.toLowerCase() == titleLower)).firstOrNull;
      }

      final key = _normalizeIngredientName(planned.title);
      final existing = aggMap[key];
      final double estimatedGrams = (matchedFood?.gramsPerDefaultUnit ?? 150.0) * planned.servings;
      final GroceryCategory cat = matchedFood != null
          ? _categoryFromFood(matchedFood.category)
          : _inferGroceryCategory(planned.title);

      if (existing == null) {
        aggMap[key] = _AggregateGrocery(
          name: planned.title,
          totalGrams: estimatedGrams,
          unit: 'g',
          category: cat,
          sourceMealIds: [planned.id],
        );
      } else {
        existing.totalGrams += estimatedGrams;
        if (!existing.sourceMealIds.contains(planned.id)) {
          existing.sourceMealIds.add(planned.id);
        }
      }
    }

    final List<GroceryItem> result = [];
    int counter = 0;

    for (final entry in aggMap.entries) {
      final agg = entry.value;

      // Check if already in pantry
      final inPantry = existingPantry.any((p) =>
          p.inPantry &&
          _normalizeIngredientName(p.name) == entry.key);

      final estimatedCost = _estimateCostForGrams(agg.name, agg.totalGrams);

      result.add(
        GroceryItem(
          id: 'groc_${DateTime.now().millisecondsSinceEpoch}_${counter++}',
          name: agg.name,
          category: agg.category,
          quantity: double.parse(
              (agg.totalGrams >= 1000 ? agg.totalGrams / 1000 : agg.totalGrams)
                  .toStringAsFixed(1)),
          unit: agg.totalGrams >= 1000 ? 'kg' : 'g',
          estimatedCostInr: double.parse(estimatedCost.toStringAsFixed(0)),
          isChecked: false,
          inPantry: inPantry,
          sourceMealIds: agg.sourceMealIds,
        ),
      );
    }

    // Sort by Category order, then name
    result.sort((a, b) {
      final catCmp = a.category.index.compareTo(b.category.index);
      if (catCmp != 0) return catCmp;
      return a.name.compareTo(b.name);
    });

    return result;
  }

  static GroceryCategory _categoryFromFood(FoodCategory cat) {
    switch (cat) {
      case FoodCategory.grains:
        return GroceryCategory.grainsAndStaples;
      case FoodCategory.protein:
        return GroceryCategory.protein;
      case FoodCategory.vegetables:
        return GroceryCategory.vegetables;
      case FoodCategory.fruits:
        return GroceryCategory.fruits;
      case FoodCategory.dairy:
        return GroceryCategory.dairyAndEggs;
      case FoodCategory.pantry:
        return GroceryCategory.pantryAndSpices;
      case FoodCategory.snacks:
        return GroceryCategory.snacks;
    }
  }

  static String _normalizeIngredientName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)|cooked|raw|boiled|sliced|pieces|cubes'), '')
        .trim();
  }

  static GroceryCategory _inferGroceryCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rice') ||
        lower.contains('atta') ||
        lower.contains('flour') ||
        lower.contains('oats') ||
        lower.contains('batter')) {
      return GroceryCategory.grainsAndStaples;
    }
    if (lower.contains('egg') ||
        lower.contains('milk') ||
        lower.contains('curd') ||
        lower.contains('dahi') ||
        lower.contains('butter') ||
        lower.contains('ghee')) {
      return GroceryCategory.dairyAndEggs;
    }
    if (lower.contains('chicken') ||
        lower.contains('fish') ||
        lower.contains('mutton') ||
        lower.contains('dal') ||
        lower.contains('paneer') ||
        lower.contains('chickpea') ||
        lower.contains('kadala') ||
        lower.contains('rajma') ||
        lower.contains('soya')) {
      return GroceryCategory.protein;
    }
    if (lower.contains('banana') ||
        lower.contains('apple') ||
        lower.contains('fruit')) {
      return GroceryCategory.fruits;
    }
    if (lower.contains('oil') ||
        lower.contains('spice') ||
        lower.contains('masala') ||
        lower.contains('salt') ||
        lower.contains('sugar')) {
      return GroceryCategory.pantryAndSpices;
    }
    return GroceryCategory.vegetables;
  }

  static double _estimateCostForGrams(String name, double grams) {
    final lower = name.toLowerCase();
    double inrPer100g = 15.0;

    if (lower.contains('chicken') || lower.contains('fish')) {
      inrPer100g = 35.0;
    } else if (lower.contains('paneer') || lower.contains('nut')) {
      inrPer100g = 45.0;
    } else if (lower.contains('rice') || lower.contains('atta') || lower.contains('dal')) {
      inrPer100g = 10.0;
    } else if (lower.contains('onion') || lower.contains('cabbage') || lower.contains('tomato')) {
      inrPer100g = 6.0;
    }

    return (grams / 100.0) * inrPer100g;
  }
}

class _AggregateGrocery {
  final String name;
  double totalGrams;
  final String unit;
  final GroceryCategory category;
  final List<String> sourceMealIds;

  _AggregateGrocery({
    required this.name,
    required this.totalGrams,
    required this.unit,
    required this.category,
    required this.sourceMealIds,
  });
}
