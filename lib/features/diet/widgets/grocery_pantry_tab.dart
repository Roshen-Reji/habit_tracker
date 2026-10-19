import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';

/// Smart Categorized Grocery List & Pantry Tracker Tab.
/// Groups ingredients by aisle category, tracks pantry staples vs purchases,
/// and balances estimated costs against the weekly budget.
class GroceryPantryTab extends StatefulWidget {
  const GroceryPantryTab({super.key});

  @override
  State<GroceryPantryTab> createState() => _GroceryPantryTabState();
}

class _GroceryPantryTabState extends State<GroceryPantryTab> {
  int _subView = 0; // 0: Shopping List, 1: Pantry & On-Hand

  void _openAddCustomItemSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'g');
    final costCtrl = TextEditingController(text: '40');
    GroceryCategory selectedCat = GroceryCategory.vegetables;

    SpringSheet.show(
      context: context,
      title: 'Add Custom Grocery Item',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final accent = BentoTheme.accent;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Unit (g/kg/pc)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: BentoTheme.isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Est. Cost (₹)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GroceryCategory>(
                value: selectedCat,
                dropdownColor: BentoTheme.surface,
                decoration: const InputDecoration(
                  labelText: 'Aisle Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: GroceryCategory.values.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c.label, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setSheetState(() => selectedCat = val);
                },
              ),
              const SizedBox(height: 20),
              PressScale(
                onTap: () {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    final item = GroceryItem(
                      id: 'custom_groc_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      category: selectedCat,
                      quantity: double.tryParse(qtyCtrl.text) ?? 1.0,
                      unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'g',
                      estimatedCostInr: double.tryParse(costCtrl.text) ?? 40.0,
                    );
                    DietRepository.instance.addCustomGroceryItem(item);
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Add Item',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = DietRepository.instance;
    final accent = BentoTheme.accent;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final allItems = repo.groceryList;
        final shoppingList = allItems.where((i) => !i.inPantry).toList();
        final pantryList = allItems.where((i) => i.inPantry).toList();

        final totalEstCost = shoppingList.fold(0.0, (sum, i) => sum + i.estimatedCostInr);
        final budget = repo.profile.weeklyBudgetInr;
        final budgetRatio = budget > 0 ? (totalEstCost / budget).clamp(0.0, 1.0) : 0.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // Budget vs. Estimated Cost Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.wallet, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Grocery Budget',
                        style: TextStyle(
                          color: BentoTheme.isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${totalEstCost.round()} / ₹${budget.round()}',
                        style: TextStyle(
                          color: totalEstCost > budget ? AppColors.error : accent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budgetRatio,
                      backgroundColor: BentoTheme.isDark ? Colors.white10 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation(
                        totalEstCost > budget ? AppColors.error : accent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Approximate local market pricing. Items already in your pantry are excluded from the total spend.',
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sub-view segmented pill
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _subViewTab('Shopping List (${shoppingList.length})', 0),
                  _subViewTab('Pantry & Home (${pantryList.length})', 1),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Add Custom Item / Refresh row
            Row(
              children: [
                Expanded(
                  child: PressScale(
                    onTap: _openAddCustomItemSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plus, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            '+ Custom Item',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PressScale(
                  onTap: () async {
                    await repo.regenerateGroceryList();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Re-synced list with active meal plan!')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: BentoTheme.isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.refreshCw, size: 13, color: Colors.grey),
                        SizedBox(width: 6),
                        Text('Sync Plan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_subView == 0) ...[
              if (shoppingList.isEmpty)
                _buildEmptyState('Your shopping list is empty. Add custom items or sync from your meal planner.')
              else
                ..._buildCategorizedList(shoppingList, repo, accent),
            ] else ...[
              if (pantryList.isEmpty)
                _buildEmptyState('No items in pantry yet. Tap "+ Custom Item" to track staples on hand.')
              else
                ..._buildPantryList(pantryList, repo, accent),
            ],
          ],
        );
      },
    );
  }

  Widget _subViewTab(String label, int index) {
    final isSel = _subView == index;
    return Expanded(
      child: PressScale(
        onTap: () => setState(() => _subView = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? (BentoTheme.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? (BentoTheme.isDark ? Colors.white : Colors.black) : Colors.grey,
              fontSize: 12,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategorizedList(
    List<GroceryItem> items,
    DietRepository repo,
    Color accent,
  ) {
    final widgets = <Widget>[];

    for (final cat in GroceryCategory.values) {
      final catItems = items.where((i) => i.category == cat).toList();
      if (catItems.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            cat.label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      );

      for (final item in catItems) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.isChecked
                    ? AppColors.success.withValues(alpha: 0.3)
                    : (BentoTheme.isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                PressScale(
                  onTap: () => repo.toggleGroceryItem(item.id),
                  child: Icon(
                    item.isChecked ? LucideIcons.checkSquare : LucideIcons.square,
                    size: 18,
                    color: item.isChecked ? AppColors.success : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: item.isChecked
                              ? Colors.grey
                              : (BentoTheme.isDark ? Colors.white : Colors.black87),
                          fontSize: 13,
                          decoration: item.isChecked ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item.quantity} ${item.unit} · ~₹${item.estimatedCostInr.round()}',
                        style: TextStyle(
                          color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                PressScale(
                  onTap: () => repo.togglePantryItem(item.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'At Home',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => repo.deleteGroceryItem(item.id),
                  child: const Icon(LucideIcons.trash2, size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildPantryList(
    List<GroceryItem> items,
    DietRepository repo,
    Color accent,
  ) {
    return items.map((item) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: BentoTheme.isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.packageCheck, size: 16, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${item.quantity} ${item.unit} in pantry · ${item.category.label}',
                    style: TextStyle(
                      color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PressScale(
              onTap: () => repo.togglePantryItem(item.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Move to List',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => repo.deleteGroceryItem(item.id),
              child: const Icon(LucideIcons.trash2, size: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: BentoTheme.isDark ? Colors.white54 : Colors.black45,
          fontSize: 12,
        ),
      ),
    );
  }
}
