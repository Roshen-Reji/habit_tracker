/// Supported biological sexes for Mifflin-St Jeor BMR calculation.
enum BiologicalSex { male, female, other }

/// Core diet and body composition goals.
enum DietGoal {
  maintain,
  gradualLoss,
  gradualGain,
  improveHabits;

  String get label {
    switch (this) {
      case DietGoal.maintain:
        return 'Maintain Weight & Vitality';
      case DietGoal.gradualLoss:
        return 'Gradual Fat Loss (Sustainable)';
      case DietGoal.gradualGain:
        return 'Clean Muscle Gain';
      case DietGoal.improveHabits:
        return 'Improve Dietary Habits';
    }
  }
}

/// Physical activity multipliers based on daily movement & training.
enum PhysicalActivityLevel {
  sedentary(1.2, 'Sedentary (Desk job, minimal exercise)'),
  light(1.375, 'Lightly Active (1-3 days light exercise/week)'),
  moderate(1.55, 'Moderately Active (3-5 days gym/sports)'),
  active(1.725, 'Very Active (6-7 days hard training)'),
  athlete(1.9, 'Athlete / Physical Labor (2x training/day)');

  final double multiplier;
  final String label;
  const PhysicalActivityLevel(this.multiplier, this.label);
}

/// Common dietary patterns and lifestyles.
enum DietaryPattern {
  omnivore('Omnivore'),
  eggetarian('Eggetarian'),
  vegetarian('Vegetarian'),
  vegan('Vegan'),
  custom('Custom');

  final String label;
  const DietaryPattern(this.label);
}

/// Common household & Indian culinary portion units.
enum HouseholdUnit {
  gram('g', 1.0, 'Grams'),
  ml('ml', 1.0, 'Milliliters'),
  katori('katori', 150.0, 'Katori (~150g standard bowl)'),
  cup('cup', 240.0, 'Cup (~240ml standard cup)'),
  tbsp('tbsp', 15.0, 'Tablespoon (~15g)'),
  tsp('tsp', 5.0, 'Teaspoon (~5g)'),
  piece('pc', 50.0, 'Piece / Item'),
  roti('roti', 40.0, 'Roti / Chapati (~40g cooked)'),
  idli('idli', 60.0, 'Idli (~60g standard steamed)'),
  dosa('dosa', 90.0, 'Dosa (~90g medium)'),
  appam('appam', 55.0, 'Appam (~55g standard)'),
  serving('serving', 120.0, 'Standard Serving (~120g)'),
  glass('glass', 250.0, 'Glass (~250ml)');

  final String symbol;
  final double defaultGrams;
  final String description;
  const HouseholdUnit(this.symbol, this.defaultGrams, this.description);

  static HouseholdUnit fromString(String val) {
    for (final u in HouseholdUnit.values) {
      if (u.name.toLowerCase() == val.toLowerCase() ||
          u.symbol.toLowerCase() == val.toLowerCase()) {
        return u;
      }
    }
    return HouseholdUnit.gram;
  }
}

/// 4 primary meal slots for structured daily tracking.
enum MealSlot {
  breakfast('Breakfast', '🌅'),
  lunch('Lunch', '☀️'),
  snack('Snacks / Tea', '☕'),
  dinner('Dinner', '🌙');

  final String title;
  final String emoji;
  const MealSlot(this.title, this.emoji);

  static MealSlot fromString(String val) {
    for (final s in MealSlot.values) {
      if (s.name.toLowerCase() == val.toLowerCase()) return s;
    }
    return MealSlot.lunch;
  }
}

/// Data verification confidence for food database entries.
enum FoodConfidence {
  verified('Verified Scientific DB'),
  approximate('Culinary Estimate'),
  userSubmitted('User Added');

  final String label;
  const FoodConfidence(this.label);
}

/// Status of a planned meal item.
enum PlannedMealStatus {
  planned,
  prepared,
  eaten,
  skipped,
  ateOut;

  String get label {
    switch (this) {
      case PlannedMealStatus.planned:
        return 'Planned';
      case PlannedMealStatus.prepared:
        return 'Prepped';
      case PlannedMealStatus.eaten:
        return 'Eaten';
      case PlannedMealStatus.skipped:
        return 'Skipped';
      case PlannedMealStatus.ateOut:
        return 'Ate Out';
    }
  }
}

/// Categorization for food database.
enum FoodCategory {
  grains('Grains & Cereals'),
  protein('Protein & Meats/Fish'),
  vegetables('Vegetables'),
  fruits('Fruits'),
  dairy('Dairy & Eggs'),
  pantry('Pantry & Oils'),
  snacks('Snacks & Beverages');

  final String label;
  const FoodCategory(this.label);
}

/// Smart grocery aisle grouping.
enum GroceryCategory {
  vegetables('Vegetables & Greens'),
  fruits('Fresh Fruits'),
  grainsAndStaples('Grains, Rice & Atta'),
  dairyAndEggs('Dairy & Eggs'),
  protein('Lentils, Meat & Seafood'),
  pantryAndSpices('Pantry, Oils & Spices'),
  snacks('Snacks & Quick Bites'),
  other('Other Supplies');

  final String label;
  const GroceryCategory(this.label);
}

/// Comprehensive user nutrition & physiological profile.
class NutritionProfile {
  final int age;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final BiologicalSex sex;
  final DietGoal goal;
  final PhysicalActivityLevel activityLevel;
  final double paceKgPerWeek; // 0.25 or 0.5 kg/week
  final DietaryPattern dietaryPattern;
  final List<String> allergies;
  final List<String> intolerances;
  final List<String> foodsToAvoid;
  final List<String> preferredCuisines;
  final double weeklyBudgetInr;
  final int maxCookTimeMin;
  final bool hideCaloriesMode; // Habit Focus Mode
  final bool enableWaterReminders;
  final int wakeHour;
  final int sleepHour;
  final double? customProteinTargetG;
  final double? customFibreTargetG;

  const NutritionProfile({
    this.age = 24,
    this.heightCm = 175.0,
    this.currentWeightKg = 72.0,
    this.targetWeightKg = 70.0,
    this.sex = BiologicalSex.male,
    this.goal = DietGoal.gradualLoss,
    this.activityLevel = PhysicalActivityLevel.moderate,
    this.paceKgPerWeek = 0.5,
    this.dietaryPattern = DietaryPattern.omnivore,
    this.allergies = const [],
    this.intolerances = const [],
    this.foodsToAvoid = const [],
    this.preferredCuisines = const [
      'Kerala / South Indian',
      'North Indian',
      'High-Protein Quick',
    ],
    this.weeklyBudgetInr = 1800.0,
    this.maxCookTimeMin = 30,
    this.hideCaloriesMode = false,
    this.enableWaterReminders = true,
    this.wakeHour = 7,
    this.sleepHour = 23,
    this.customProteinTargetG,
    this.customFibreTargetG,
  });

  NutritionProfile copyWith({
    int? age,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    BiologicalSex? sex,
    DietGoal? goal,
    PhysicalActivityLevel? activityLevel,
    double? paceKgPerWeek,
    DietaryPattern? dietaryPattern,
    List<String>? allergies,
    List<String>? intolerances,
    List<String>? foodsToAvoid,
    List<String>? preferredCuisines,
    double? weeklyBudgetInr,
    int? maxCookTimeMin,
    bool? hideCaloriesMode,
    bool? enableWaterReminders,
    int? wakeHour,
    int? sleepHour,
    double? customProteinTargetG,
    double? customFibreTargetG,
  }) {
    return NutritionProfile(
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      sex: sex ?? this.sex,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      paceKgPerWeek: paceKgPerWeek ?? this.paceKgPerWeek,
      dietaryPattern: dietaryPattern ?? this.dietaryPattern,
      allergies: allergies ?? this.allergies,
      intolerances: intolerances ?? this.intolerances,
      foodsToAvoid: foodsToAvoid ?? this.foodsToAvoid,
      preferredCuisines: preferredCuisines ?? this.preferredCuisines,
      weeklyBudgetInr: weeklyBudgetInr ?? this.weeklyBudgetInr,
      maxCookTimeMin: maxCookTimeMin ?? this.maxCookTimeMin,
      hideCaloriesMode: hideCaloriesMode ?? this.hideCaloriesMode,
      enableWaterReminders: enableWaterReminders ?? this.enableWaterReminders,
      wakeHour: wakeHour ?? this.wakeHour,
      sleepHour: sleepHour ?? this.sleepHour,
      customProteinTargetG: customProteinTargetG ?? this.customProteinTargetG,
      customFibreTargetG: customFibreTargetG ?? this.customFibreTargetG,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'targetWeightKg': targetWeightKg,
        'sex': sex.name,
        'goal': goal.name,
        'activityLevel': activityLevel.name,
        'paceKgPerWeek': paceKgPerWeek,
        'dietaryPattern': dietaryPattern.name,
        'allergies': allergies,
        'intolerances': intolerances,
        'foodsToAvoid': foodsToAvoid,
        'preferredCuisines': preferredCuisines,
        'weeklyBudgetInr': weeklyBudgetInr,
        'maxCookTimeMin': maxCookTimeMin,
        'hideCaloriesMode': hideCaloriesMode,
        'enableWaterReminders': enableWaterReminders,
        'wakeHour': wakeHour,
        'sleepHour': sleepHour,
        'customProteinTargetG': customProteinTargetG,
        'customFibreTargetG': customFibreTargetG,
      };

  factory NutritionProfile.fromJson(Map<String, dynamic> json) {
    return NutritionProfile(
      age: (json['age'] as num?)?.toInt() ?? 24,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 175.0,
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble() ?? 72.0,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble() ?? 70.0,
      sex: BiologicalSex.values.firstWhere(
        (e) => e.name == json['sex'],
        orElse: () => BiologicalSex.male,
      ),
      goal: DietGoal.values.firstWhere(
        (e) => e.name == json['goal'],
        orElse: () => DietGoal.gradualLoss,
      ),
      activityLevel: PhysicalActivityLevel.values.firstWhere(
        (e) => e.name == json['activityLevel'],
        orElse: () => PhysicalActivityLevel.moderate,
      ),
      paceKgPerWeek: (json['paceKgPerWeek'] as num?)?.toDouble() ?? 0.5,
      dietaryPattern: DietaryPattern.values.firstWhere(
        (e) => e.name == json['dietaryPattern'],
        orElse: () => DietaryPattern.omnivore,
      ),
      allergies: List<String>.from(json['allergies'] ?? const []),
      intolerances: List<String>.from(json['intolerances'] ?? const []),
      foodsToAvoid: List<String>.from(json['foodsToAvoid'] ?? const []),
      preferredCuisines: List<String>.from(json['preferredCuisines'] ??
          const ['Kerala / South Indian', 'North Indian', 'High-Protein Quick']),
      weeklyBudgetInr: (json['weeklyBudgetInr'] as num?)?.toDouble() ?? 1800.0,
      maxCookTimeMin: (json['maxCookTimeMin'] as num?)?.toInt() ?? 30,
      hideCaloriesMode: json['hideCaloriesMode'] as bool? ?? false,
      enableWaterReminders: json['enableWaterReminders'] as bool? ?? true,
      wakeHour: (json['wakeHour'] as num?)?.toInt() ?? 7,
      sleepHour: (json['sleepHour'] as num?)?.toInt() ?? 23,
      customProteinTargetG: (json['customProteinTargetG'] as num?)?.toDouble(),
      customFibreTargetG: (json['customFibreTargetG'] as num?)?.toDouble(),
    );
  }
}

/// Food database master record.
class FoodItemData {
  final String id;
  final String name;
  final List<String> aliases;
  final String cuisine; // Kerala, North Indian, Pan-Indian, Global
  final FoodCategory category;
  final List<String> dietaryTags; // veg, egg, nonVeg, vegan
  final List<String> allergens; // gluten, dairy, nuts, shellfish, soy
  final HouseholdUnit defaultUnit;
  final double gramsPerDefaultUnit;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fibrePer100g;
  final double ironMgPer100g;
  final double calciumMgPer100g;
  final double estimatedCostInrPer100g;
  final FoodConfidence confidence;
  final int prepTimeMin;
  final bool isQuickMeal;
  final bool isNoCook;
  final bool isBatchCookable;

  const FoodItemData({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.cuisine = 'Indian',
    required this.category,
    this.dietaryTags = const ['veg'],
    this.allergens = const [],
    this.defaultUnit = HouseholdUnit.gram,
    this.gramsPerDefaultUnit = 100.0,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fibrePer100g = 0.0,
    this.ironMgPer100g = 0.0,
    this.calciumMgPer100g = 0.0,
    this.estimatedCostInrPer100g = 15.0,
    this.confidence = FoodConfidence.verified,
    this.prepTimeMin = 15,
    this.isQuickMeal = false,
    this.isNoCook = false,
    this.isBatchCookable = false,
  });

  /// Calculate actual grams for a given portion & unit
  double computeGrams(double quantity, HouseholdUnit unit) {
    if (unit == HouseholdUnit.gram || unit == HouseholdUnit.ml) {
      return quantity;
    }
    if (unit == defaultUnit) {
      return quantity * gramsPerDefaultUnit;
    }
    return quantity * unit.defaultGrams;
  }

  /// Scale nutrition metrics for a specific quantity & unit
  Map<String, double> computePortionNutrition(double quantity, HouseholdUnit unit) {
    final grams = computeGrams(quantity, unit);
    final ratio = grams / 100.0;
    return {
      'grams': grams,
      'kcal': (kcalPer100g * ratio),
      'proteinG': (proteinPer100g * ratio),
      'carbsG': (carbsPer100g * ratio),
      'fatG': (fatPer100g * ratio),
      'fibreG': (fibrePer100g * ratio),
      'ironMg': (ironMgPer100g * ratio),
      'calciumMg': (calciumMgPer100g * ratio),
      'costInr': (estimatedCostInrPer100g * ratio),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'cuisine': cuisine,
        'category': category.name,
        'dietaryTags': dietaryTags,
        'allergens': allergens,
        'defaultUnit': defaultUnit.name,
        'gramsPerDefaultUnit': gramsPerDefaultUnit,
        'kcalPer100g': kcalPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'fibrePer100g': fibrePer100g,
        'ironMgPer100g': ironMgPer100g,
        'calciumMgPer100g': calciumMgPer100g,
        'estimatedCostInrPer100g': estimatedCostInrPer100g,
        'confidence': confidence.name,
        'prepTimeMin': prepTimeMin,
        'isQuickMeal': isQuickMeal,
        'isNoCook': isNoCook,
        'isBatchCookable': isBatchCookable,
      };

  factory FoodItemData.fromJson(Map<String, dynamic> json) {
    return FoodItemData(
      id: json['id'] as String,
      name: json['name'] as String,
      aliases: List<String>.from(json['aliases'] ?? const []),
      cuisine: json['cuisine'] as String? ?? 'Indian',
      category: FoodCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => FoodCategory.grains,
      ),
      dietaryTags: List<String>.from(json['dietaryTags'] ?? const ['veg']),
      allergens: List<String>.from(json['allergens'] ?? const []),
      defaultUnit: HouseholdUnit.fromString(json['defaultUnit'] as String? ?? 'gram'),
      gramsPerDefaultUnit: (json['gramsPerDefaultUnit'] as num?)?.toDouble() ?? 100.0,
      kcalPer100g: (json['kcalPer100g'] as num?)?.toDouble() ?? 100.0,
      proteinPer100g: (json['proteinPer100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble() ?? 0.0,
      fibrePer100g: (json['fibrePer100g'] as num?)?.toDouble() ?? 0.0,
      ironMgPer100g: (json['ironMgPer100g'] as num?)?.toDouble() ?? 0.0,
      calciumMgPer100g: (json['calciumMgPer100g'] as num?)?.toDouble() ?? 0.0,
      estimatedCostInrPer100g: (json['estimatedCostInrPer100g'] as num?)?.toDouble() ?? 15.0,
      confidence: FoodConfidence.values.firstWhere(
        (e) => e.name == json['confidence'],
        orElse: () => FoodConfidence.verified,
      ),
      prepTimeMin: (json['prepTimeMin'] as num?)?.toInt() ?? 15,
      isQuickMeal: json['isQuickMeal'] as bool? ?? false,
      isNoCook: json['isNoCook'] as bool? ?? false,
      isBatchCookable: json['isBatchCookable'] as bool? ?? false,
    );
  }
}

/// A logged intake item for a specific day and meal slot.
class DietLogEntry {
  final String id;
  final String dateIso; // YYYY-MM-DD
  final MealSlot mealSlot;
  final String? foodId;
  final String title;
  final double quantity;
  final HouseholdUnit unit;
  final double gramsTotal;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fibreG;
  final FoodConfidence confidence;
  final List<String> allergenWarnings;
  final DateTime loggedAt;
  final String notes;
  final bool isCookedQuantity;

  DietLogEntry({
    required this.id,
    required this.dateIso,
    required this.mealSlot,
    this.foodId,
    required this.title,
    required this.quantity,
    this.unit = HouseholdUnit.serving,
    required this.gramsTotal,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fibreG = 0.0,
    this.confidence = FoodConfidence.verified,
    this.allergenWarnings = const [],
    DateTime? loggedAt,
    this.notes = '',
    this.isCookedQuantity = true,
  }) : loggedAt = loggedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateIso': dateIso,
        'mealSlot': mealSlot.name,
        'foodId': foodId,
        'title': title,
        'quantity': quantity,
        'unit': unit.name,
        'gramsTotal': gramsTotal,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'fibreG': fibreG,
        'confidence': confidence.name,
        'allergenWarnings': allergenWarnings,
        'loggedAt': loggedAt.toIso8601String(),
        'notes': notes,
        'isCookedQuantity': isCookedQuantity,
      };

  factory DietLogEntry.fromJson(Map<String, dynamic> json) {
    return DietLogEntry(
      id: json['id'] as String,
      dateIso: json['dateIso'] as String,
      mealSlot: MealSlot.fromString(json['mealSlot'] as String? ?? 'lunch'),
      foodId: json['foodId'] as String?,
      title: json['title'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: HouseholdUnit.fromString(json['unit'] as String? ?? 'serving'),
      gramsTotal: (json['gramsTotal'] as num?)?.toDouble() ?? 100.0,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0.0,
      fibreG: (json['fibreG'] as num?)?.toDouble() ?? 0.0,
      confidence: FoodConfidence.values.firstWhere(
        (e) => e.name == json['confidence'],
        orElse: () => FoodConfidence.verified,
      ),
      allergenWarnings: List<String>.from(json['allergenWarnings'] ?? const []),
      loggedAt: DateTime.tryParse(json['loggedAt'] as String? ?? '') ?? DateTime.now(),
      notes: json['notes'] as String? ?? '',
      isCookedQuantity: json['isCookedQuantity'] as bool? ?? true,
    );
  }
}

/// An entry on the day/weekly meal planner.
class PlannedMealItem {
  final String id;
  final String dateIso;
  final MealSlot mealSlot;
  final String? recipeId;
  final String? foodId;
  final String title;
  final double servings;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fibreG;
  final int prepTimeMin;
  final double estimatedCostInr;
  final PlannedMealStatus status;
  final String whySuggested;

  const PlannedMealItem({
    required this.id,
    required this.dateIso,
    required this.mealSlot,
    this.recipeId,
    this.foodId,
    required this.title,
    this.servings = 1.0,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fibreG = 0.0,
    this.prepTimeMin = 15,
    this.estimatedCostInr = 60.0,
    this.status = PlannedMealStatus.planned,
    this.whySuggested = 'Balanced for your protein & energy targets',
  });

  PlannedMealItem copyWith({
    String? id,
    String? dateIso,
    MealSlot? mealSlot,
    String? recipeId,
    String? foodId,
    String? title,
    double? servings,
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fibreG,
    int? prepTimeMin,
    double? estimatedCostInr,
    PlannedMealStatus? status,
    String? whySuggested,
  }) {
    return PlannedMealItem(
      id: id ?? this.id,
      dateIso: dateIso ?? this.dateIso,
      mealSlot: mealSlot ?? this.mealSlot,
      recipeId: recipeId ?? this.recipeId,
      foodId: foodId ?? this.foodId,
      title: title ?? this.title,
      servings: servings ?? this.servings,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fibreG: fibreG ?? this.fibreG,
      prepTimeMin: prepTimeMin ?? this.prepTimeMin,
      estimatedCostInr: estimatedCostInr ?? this.estimatedCostInr,
      status: status ?? this.status,
      whySuggested: whySuggested ?? this.whySuggested,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateIso': dateIso,
        'mealSlot': mealSlot.name,
        'recipeId': recipeId,
        'foodId': foodId,
        'title': title,
        'servings': servings,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'fibreG': fibreG,
        'prepTimeMin': prepTimeMin,
        'estimatedCostInr': estimatedCostInr,
        'status': status.name,
        'whySuggested': whySuggested,
      };

  factory PlannedMealItem.fromJson(Map<String, dynamic> json) {
    return PlannedMealItem(
      id: json['id'] as String,
      dateIso: json['dateIso'] as String,
      mealSlot: MealSlot.fromString(json['mealSlot'] as String? ?? 'lunch'),
      recipeId: json['recipeId'] as String?,
      foodId: json['foodId'] as String?,
      title: json['title'] as String,
      servings: (json['servings'] as num?)?.toDouble() ?? 1.0,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0.0,
      fibreG: (json['fibreG'] as num?)?.toDouble() ?? 0.0,
      prepTimeMin: (json['prepTimeMin'] as num?)?.toInt() ?? 15,
      estimatedCostInr: (json['estimatedCostInr'] as num?)?.toDouble() ?? 60.0,
      status: PlannedMealStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PlannedMealStatus.planned,
      ),
      whySuggested: json['whySuggested'] as String? ?? 'Balanced choice',
    );
  }
}

/// Item in the consolidated grocery list or pantry inventory.
class GroceryItem {
  final String id;
  final String name;
  final GroceryCategory category;
  final double quantity;
  final String unit;
  final double estimatedCostInr;
  final bool isChecked;
  final bool inPantry;
  final String? expiryDateIso;
  final List<String> sourceMealIds;

  const GroceryItem({
    required this.id,
    required this.name,
    this.category = GroceryCategory.vegetables,
    required this.quantity,
    this.unit = 'g',
    this.estimatedCostInr = 40.0,
    this.isChecked = false,
    this.inPantry = false,
    this.expiryDateIso,
    this.sourceMealIds = const [],
  });

  GroceryItem copyWith({
    String? id,
    String? name,
    GroceryCategory? category,
    double? quantity,
    String? unit,
    double? estimatedCostInr,
    bool? isChecked,
    bool? inPantry,
    String? expiryDateIso,
    List<String>? sourceMealIds,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedCostInr: estimatedCostInr ?? this.estimatedCostInr,
      isChecked: isChecked ?? this.isChecked,
      inPantry: inPantry ?? this.inPantry,
      expiryDateIso: expiryDateIso ?? this.expiryDateIso,
      sourceMealIds: sourceMealIds ?? this.sourceMealIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'estimatedCostInr': estimatedCostInr,
        'isChecked': isChecked,
        'inPantry': inPantry,
        'expiryDateIso': expiryDateIso,
        'sourceMealIds': sourceMealIds,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: GroceryCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => GroceryCategory.vegetables,
      ),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'g',
      estimatedCostInr: (json['estimatedCostInr'] as num?)?.toDouble() ?? 40.0,
      isChecked: json['isChecked'] as bool? ?? false,
      inPantry: json['inPantry'] as bool? ?? false,
      expiryDateIso: json['expiryDateIso'] as String?,
      sourceMealIds: List<String>.from(json['sourceMealIds'] ?? const []),
    );
  }
}

/// Body weight & waist tracker log.
class WeightProgressEntry {
  final String id;
  final String dateIso;
  final double weightKg;
  final double? waistCm;
  final String notes;

  const WeightProgressEntry({
    required this.id,
    required this.dateIso,
    required this.weightKg,
    this.waistCm,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateIso': dateIso,
        'weightKg': weightKg,
        'waistCm': waistCm,
        'notes': notes,
      };

  factory WeightProgressEntry.fromJson(Map<String, dynamic> json) {
    return WeightProgressEntry(
      id: json['id'] as String,
      dateIso: json['dateIso'] as String,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Clinically computed daily targets based on Mifflin-St Jeor + Gym science.
class DailyTargets {
  final double targetKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fibreG;
  final double ironMg;
  final double calciumMg;
  final double waterMl;
  final bool clinicalFloorApplied;
  final String explanation;

  const DailyTargets({
    required this.targetKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fibreG,
    this.ironMg = 18.0,
    this.calciumMg = 1000.0,
    this.waterMl = 2500.0,
    this.clinicalFloorApplied = false,
    required this.explanation,
  });
}

/// Smooth 7-day Exponentially Weighted Moving Average trend result.
class EWMAWeightTrend {
  final double latestRawKg;
  final double currentEwmaKg;
  final double weeklyRateOfChangeKg;
  final String trendDirection; // 'losing', 'gaining', 'stable'
  final Map<String, double> smoothedSeries;

  const EWMAWeightTrend({
    required this.latestRawKg,
    required this.currentEwmaKg,
    required this.weeklyRateOfChangeKg,
    required this.trendDirection,
    required this.smoothedSeries,
  });
}

/// Actionable Doctor & Trainer insight.
class DoctorTrainerInsight {
  final String id;
  final String title;
  final String message;
  final String category; // 'protein', 'fibre', 'hydration', 'balance'
  final String? suggestedFoodOrSwap;
  final String? actionPillText;

  const DoctorTrainerInsight({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.suggestedFoodOrSwap,
    this.actionPillText,
  });
}
