import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/data/services/ai_service.dart';

/// Interactive Fast Food Logging & AI Draft Sheet.
/// Provides 3 clean modes:
/// 1. Search & Indian Regional DB with Household portion units and allergen alerts
/// 2. ✨ AI Multimodal Text / Meal Photo / Packaged Label Draft Logger
/// 3. Fast Custom Entry with a 500ms duplicate tap guard
class ManualFoodInputWidget extends StatefulWidget {
  final MealSlot defaultSlot;
  final String? dateIso;
  final VoidCallback? onFoodAdded;

  const ManualFoodInputWidget({
    super.key,
    this.defaultSlot = MealSlot.lunch,
    this.dateIso,
    this.onFoodAdded,
  });

  static Future<void> show(
    BuildContext context, {
    MealSlot defaultSlot = MealSlot.lunch,
    String? dateIso,
    VoidCallback? onFoodAdded,
  }) {
    return SpringSheet.show(
      context: context,
      title: 'Log Meal (${defaultSlot.title})',
      child: ManualFoodInputWidget(
        defaultSlot: defaultSlot,
        dateIso: dateIso,
        onFoodAdded: onFoodAdded,
      ),
    );
  }

  @override
  State<ManualFoodInputWidget> createState() => _ManualFoodInputWidgetState();
}

class _ManualFoodInputWidgetState extends State<ManualFoodInputWidget> {
  int _activeMode = 0; // 0: Database Search, 1: AI Prompt/Snap, 2: Custom Entry
  late MealSlot _selectedSlot;

  // Mode 0: Search & Portion
  final _searchCtrl = TextEditingController();
  FoodItemData? _selectedFood;
  double _portionQty = 1.0;
  HouseholdUnit _selectedUnit = HouseholdUnit.serving;

  // Mode 1: AI Draft
  final _aiPromptCtrl = TextEditingController();
  Uint8List? _selectedImageBytes;
  bool _isAnalyzingAi = false;
  List<DietLogEntry> _aiDrafts = [];

  // Mode 2: Custom
  final _customNameCtrl = TextEditingController();
  final _customKcalCtrl = TextEditingController();
  final _customProteinCtrl = TextEditingController();
  final _customCarbsCtrl = TextEditingController();
  final _customFatCtrl = TextEditingController();
  final _customFibreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.defaultSlot;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _aiPromptCtrl.dispose();
    _customNameCtrl.dispose();
    _customKcalCtrl.dispose();
    _customProteinCtrl.dispose();
    _customCarbsCtrl.dispose();
    _customFatCtrl.dispose();
    _customFibreCtrl.dispose();
    super.dispose();
  }

  String get _effectiveDate =>
      widget.dateIso ?? DateTime.now().toIso8601String().split('T').first;

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  void _logSelectedFood() async {
    if (_selectedFood == null) return;

    final portion = _selectedFood!.computePortionNutrition(_portionQty, _selectedUnit);
    final warnings = <String>[];
    for (final alg in _selectedFood!.allergens) {
      if (DietRepository.instance.profile.allergies
          .any((u) => u.toLowerCase() == alg.toLowerCase())) {
        warnings.add('Contains $alg');
      }
    }

    final entry = DietLogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      dateIso: _effectiveDate,
      mealSlot: _selectedSlot,
      foodId: _selectedFood!.id,
      title: _selectedFood!.name,
      quantity: _portionQty,
      unit: _selectedUnit,
      gramsTotal: portion['grams'] ?? 100.0,
      kcal: portion['kcal'] ?? 100.0,
      proteinG: portion['proteinG'] ?? 0.0,
      carbsG: portion['carbsG'] ?? 0.0,
      fatG: portion['fatG'] ?? 0.0,
      fibreG: portion['fibreG'] ?? 0.0,
      confidence: _selectedFood!.confidence,
      allergenWarnings: warnings,
    );

    final success = await DietRepository.instance.logFood(entry);
    if (success && mounted) {
      widget.onFoodAdded?.call();
      Navigator.pop(context);
    }
  }

  void _runAiAnalysis() async {
    final text = _aiPromptCtrl.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;

    setState(() => _isAnalyzingAi = true);

    try {
      final drafts = await AiService.instance.parseMealDescriptionWithAi(
        text.isNotEmpty ? text : 'Parsed meal photo',
        imageBytes: _selectedImageBytes,
        defaultSlot: _selectedSlot,
        dateIso: _effectiveDate,
      );
      if (mounted) {
        setState(() {
          _aiDrafts = drafts;
          _isAnalyzingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI analysis note: $e')),
        );
      }
    }
  }

  void _logAiDrafts() async {
    for (final d in _aiDrafts) {
      await DietRepository.instance.logFood(d);
    }
    if (mounted) {
      widget.onFoodAdded?.call();
      Navigator.pop(context);
    }
  }

  void _logCustomFood() async {
    final name = _customNameCtrl.text.trim();
    final kcal = double.tryParse(_customKcalCtrl.text) ?? 0.0;
    if (name.isEmpty || kcal <= 0) return;

    final entry = DietLogEntry(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      dateIso: _effectiveDate,
      mealSlot: _selectedSlot,
      title: name,
      quantity: 1.0,
      unit: HouseholdUnit.serving,
      gramsTotal: 120.0,
      kcal: kcal,
      proteinG: double.tryParse(_customProteinCtrl.text) ?? 0.0,
      carbsG: double.tryParse(_customCarbsCtrl.text) ?? 0.0,
      fatG: double.tryParse(_customFatCtrl.text) ?? 0.0,
      fibreG: double.tryParse(_customFibreCtrl.text) ?? 0.0,
      confidence: FoodConfidence.userSubmitted,
    );

    final success = await DietRepository.instance.logFood(entry);
    if (success && mounted) {
      widget.onFoodAdded?.call();
      Navigator.pop(context);
    }
  }

  void _pickMealImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1024);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal slot selector chips
          Row(
            children: MealSlot.values.map((s) {
              final isSel = _selectedSlot == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: PressScale(
                    onTap: () => setState(() => _selectedSlot = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? accent : BentoTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel
                              ? accent
                              : (BentoTheme.isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${s.emoji} ${s.name[0].toUpperCase() + s.name.substring(1)}',
                        style: TextStyle(
                          color: isSel ? Colors.black : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 3-Mode switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _modeTab('Search & Regional', 0, LucideIcons.search),
                _modeTab('✨ AI Prompt/Snap', 1, LucideIcons.sparkles),
                _modeTab('Quick Custom', 2, LucideIcons.plusCircle),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_activeMode == 0) _buildSearchMode(accent),
          if (_activeMode == 1) _buildAiMode(accent),
          if (_activeMode == 2) _buildCustomMode(accent),
        ],
      ),
    );
  }

  Widget _modeTab(String label, int index, IconData icon) {
    final isSel = _activeMode == index;
    final accent = BentoTheme.accent;
    return Expanded(
      child: PressScale(
        onTap: () => setState(() => _activeMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? (BentoTheme.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: isSel ? accent : Colors.grey),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSel
                      ? (BentoTheme.isDark ? Colors.white : Colors.black)
                      : Colors.grey,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODE 0: SEARCH & REGIONAL DB
  // ---------------------------------------------------------------------------

  Widget _buildSearchMode(Color accent) {
    final query = _searchCtrl.text.toLowerCase().trim();
    final allFoods = DietRepository.instance.foods;
    final filtered = query.isEmpty
        ? allFoods.take(12).toList()
        : allFoods
            .where((f) =>
                f.name.toLowerCase().contains(query) ||
                f.aliases.any((a) => a.toLowerCase().contains(query)) ||
                f.cuisine.toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BentoTheme.isDark ? Colors.white12 : Colors.black12),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search Appam, Puttu, Roti, Chicken, Eggs...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _searchCtrl.clear()),
                  child: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_selectedFood != null) ...[
          // Selected Food portion customization card
          _buildPortionConfigCard(accent),
          const SizedBox(height: 16),
        ],

        // Food results list
        Text(
          _selectedFood != null ? 'Or select another item:' : 'Popular & Regional Dishes:',
          style: TextStyle(color: BentoTheme.isDark ? Colors.white60 : Colors.black45, fontSize: 11),
        ),
        const SizedBox(height: 8),
        ...filtered.map((food) {
          final isSelected = _selectedFood?.id == food.id;
          final hasAllergyConflict = food.allergens.any((alg) =>
              DietRepository.instance.profile.allergies
                  .any((u) => u.toLowerCase() == alg.toLowerCase()));

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PressScale(
              onTap: () {
                setState(() {
                  _selectedFood = food;
                  _selectedUnit = food.defaultUnit;
                  _portionQty = 1.0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? accent.withValues(alpha: 0.15) : BentoTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : (hasAllergyConflict
                            ? AppColors.error.withValues(alpha: 0.5)
                            : (BentoTheme.isDark ? Colors.white10 : Colors.black12)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                food.name,
                                style: TextStyle(
                                  color: BentoTheme.isDark ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasAllergyConflict) ...[
                                const SizedBox(width: 6),
                                Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.error),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${food.cuisine} · ${food.defaultUnit.description}',
                            style: TextStyle(
                              color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${food.kcalPer100g.round()} kcal',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'P: ${food.proteinPer100g}g / 100g',
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white60 : Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPortionConfigCard(Color accent) {
    final food = _selectedFood!;
    final portion = food.computePortionNutrition(_portionQty, _selectedUnit);
    final hasAllergyConflict = food.allergens.any((alg) =>
        DietRepository.instance.profile.allergies
            .any((u) => u.toLowerCase() == alg.toLowerCase()));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: TextStyle(
                    color: BentoTheme.isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedFood = null),
                child: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
              ),
            ],
          ),
          if (hasAllergyConflict) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'Allergen Warning: Contains ${food.allergens.join(", ")}',
                    style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Unit Picker & Gram Equivalent
          Row(
            children: [
              Text(
                'Unit:',
                style: TextStyle(
                  color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<HouseholdUnit>(
                value: _selectedUnit,
                dropdownColor: BentoTheme.surface,
                isDense: true,
                underline: const SizedBox(),
                items: HouseholdUnit.values.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text(
                      '${u.description} (~${u.defaultGrams.round()}g)',
                      style: TextStyle(
                        color: BentoTheme.isDark ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedUnit = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Portion multiplier pills
          Row(
            children: [0.5, 1.0, 1.5, 2.0, 3.0].map((m) {
              final isSel = _portionQty == m;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PressScale(
                  onTap: () => setState(() => _portionQty = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel ? accent : BentoTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? accent : (BentoTheme.isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    child: Text(
                      '${m}x',
                      style: TextStyle(
                        color: isSel ? Colors.black : (BentoTheme.isDark ? Colors.white70 : Colors.black87),
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Live Macro breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroPortionChip('Energy', '${portion['kcal']?.round()} kcal', accent),
              _macroPortionChip('Protein', '${portion['proteinG']?.toStringAsFixed(1)}g', AppColors.primary),
              _macroPortionChip('Carbs', '${portion['carbsG']?.toStringAsFixed(1)}g', AppColors.warning),
              _macroPortionChip('Fat', '${portion['fatG']?.toStringAsFixed(1)}g', const Color(0xFFE57373)),
              _macroPortionChip('Fibre', '${portion['fibreG']?.toStringAsFixed(1)}g', AppColors.success),
            ],
          ),
          const SizedBox(height: 14),

          // Confirm Log Button
          PressScale(
            onTap: _logSelectedFood,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'Log ${_portionQty}x ${food.name} (${portion['grams']?.round()}g)',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroPortionChip(String title, String val, Color c) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MODE 1: AI MULTIMODAL DRAFT LOGGER
  // ---------------------------------------------------------------------------

  Widget _buildAiMode(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speak, type, or snap your meal or packaged nutrition label:',
          style: TextStyle(color: BentoTheme.isDark ? Colors.white70 : Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),

        // Text prompt box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BentoTheme.isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            children: [
              TextField(
                controller: _aiPromptCtrl,
                maxLines: 3,
                style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g., "2 appam with 1 cup egg roast and a glass of tea"',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              if (_selectedImageBytes != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedImageBytes!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Image attached', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _selectedImageBytes = null),
                      child: const Icon(LucideIcons.trash2, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
              const Divider(height: 16),
              Row(
                children: [
                  PressScale(
                    onTap: () => _pickMealImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.camera, size: 13, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Camera', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressScale(
                    onTap: () => _pickMealImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.image, size: 13, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Gallery', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  PressScale(
                    onTap: _isAnalyzingAi ? null : _runAiAnalysis,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isAnalyzingAi
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Row(
                              children: [
                                Icon(LucideIcons.sparkles, size: 13, color: Colors.black),
                                SizedBox(width: 4),
                                Text(
                                  'Analyze & Draft',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Generated Draft Items (Requiring user confirmation before saving)
        if (_aiDrafts.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'AI Drafted Items (${_aiDrafts.length})',
                style: TextStyle(
                  color: BentoTheme.isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Review before logging',
                style: TextStyle(color: accent, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._aiDrafts.map((d) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BentoTheme.isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.checkCircle2, size: 16, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d.quantity}x ${d.title}',
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${d.unit.symbol} · ${d.gramsTotal.round()}g · ${d.confidence.label}',
                          style: TextStyle(
                            color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${d.kcal.round()} kcal\nP: ${d.proteinG.round()}g',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          PressScale(
            onTap: _logAiDrafts,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'Confirm & Log ${_aiDrafts.length} Items',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MODE 2: CUSTOM MANUAL ENTRY
  // ---------------------------------------------------------------------------

  Widget _buildCustomMode(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _customInput('Food Name / Description', _customNameCtrl, TextInputType.text),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _customInput('Calories (kcal)', _customKcalCtrl, TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _customInput('Protein (g)', _customProteinCtrl, TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _customInput('Carbs (g)', _customCarbsCtrl, TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _customInput('Fat (g)', _customFatCtrl, TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _customInput('Fibre (g)', _customFibreCtrl, TextInputType.number)),
          ],
        ),
        const SizedBox(height: 20),
        PressScale(
          onTap: _logCustomFood,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Add Custom Food Entry',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _customInput(String label, TextEditingController ctrl, TextInputType kb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BentoTheme.isDark ? Colors.white12 : Colors.black12),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: kb,
            style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
