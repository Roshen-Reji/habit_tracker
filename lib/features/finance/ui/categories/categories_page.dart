import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/models/category.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final FinanceController _controller = FinanceController();
  late final FinanceRepository _repository = _controller.repository;

  String _selectedKind = 'expense'; // 'expense' or 'income'
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<Category> get _categories {
    final all = _controller.storage.categoryBox.values.toList();
    return all.where((c) {
      if (c.kind != _selectedKind) return false;
      if (!_showArchived && c.archived) return false;
      return true;
    }).toList();
  }

  void _showAddEditDialog({Category? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    String group = category?.group ?? 'needs';
    bool essential = category?.essential ?? false;
    String iconKey = category?.iconKey ?? 'tag';
    int colorValue = category?.colorValue ?? 0xFF22C55E;

    final availableColors = [
      0xFF22C55E, 0xFF3B82F6, 0xFFF59E0B, 0xFFEC4899,
      0xFF8B5CF6, 0xFF14B8A6, 0xFFEF4444, 0xFF6366F1,
      0xFF84CC16, 0xFF06B6D4, 0xFFE11D48, 0xFFD97706,
    ];

    final availableIcons = [
      'tag', 'utensils', 'shopping_cart', 'car', 'bolt',
      'heart_pulse', 'film', 'tv', 'apple', 'home',
      'graduation_cap', 'plane', 'repeat', 'shield', 'gift', 'sparkles',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BentoTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Category' : 'New Category',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Group dropdown (Needs, Wants, Savings, None)
                    DropdownButtonFormField<String>(
                      value: group,
                      dropdownColor: BentoTheme.surface,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Group',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'needs', child: Text('Needs (Essential)')),
                        DropdownMenuItem(value: 'wants', child: Text('Wants (Discretionary)')),
                        DropdownMenuItem(value: 'savings', child: Text('Savings')),
                        DropdownMenuItem(value: 'none', child: Text('None')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            group = val;
                            if (val == 'needs') essential = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Essential switch
                    SwitchListTile(
                      title: Text(
                        'Essential Expense',
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Counted towards basic emergency buffer and essential needs',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                      value: essential,
                      activeColor: BentoTheme.accent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setModalState(() => essential = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'ICON',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableIcons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final key = availableIcons[i];
                          final isSelected = iconKey == key;
                          return InkWell(
                            onTap: () => setModalState(() => iconKey = key),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? BentoTheme.accent.withValues(alpha: 0.2)
                                    : BentoTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? BentoTheme.accent : Colors.transparent,
                                ),
                              ),
                              child: Icon(
                                _iconForKey(key),
                                size: 18,
                                color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'COLOR',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableColors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final c = availableColors[i];
                          final isSelected = colorValue == c;
                          return InkWell(
                            onTap: () => setModalState(() => colorValue = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2.5)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          if (isEditing) {
                            final updated = Category(
                              id: category.id,
                              name: name,
                              kind: category.kind,
                              group: group,
                              iconKey: iconKey,
                              colorValue: colorValue,
                              essential: essential,
                              archived: category.archived,
                              sortOrder: category.sortOrder,
                            );
                            await _repository.saveCategory(updated);
                          } else {
                            final newCat = Category(
                              id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              kind: _selectedKind,
                              group: group,
                              iconKey: iconKey,
                              colorValue: colorValue,
                              essential: essential,
                            );
                            await _repository.saveCategory(newCat);
                          }
                          if (mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BentoTheme.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isEditing ? 'Save Changes' : 'Create Category',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMergeDialog(Category sourceCategory) {
    final targets = _controller.activeCategories
        .where((c) => c.id != sourceCategory.id && c.kind == sourceCategory.kind)
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other categories to merge into')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? targetId = targets.first.id;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: BentoTheme.background,
              title: Text('Merge "${sourceCategory.name}"',
                  style: TextStyle(color: BentoTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All transactions using "${sourceCategory.name}" will be updated to the chosen category, and "${sourceCategory.name}" will be archived.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: targetId,
                    dropdownColor: BentoTheme.surface,
                    style: TextStyle(color: BentoTheme.textPrimary),
                    items: targets
                        .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => targetId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: TextStyle(color: BentoTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (targetId == null) return;
                    Navigator.of(ctx).pop();
                    await _repository.mergeCategory(sourceCategory.id, targetId!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Merged into ${_controller.getCategory(targetId)?.name}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Merge'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Manage Categories',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showArchived ? LucideIcons.archive : LucideIcons.archiveRestore,
              color: _showArchived ? BentoTheme.accent : BentoTheme.textSecondary,
              size: 20,
            ),
            tooltip: _showArchived ? 'Hide Archived' : 'Show Archived',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Switch: Expense vs Income
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Expense Categories')),
                    selected: _selectedKind == 'expense',
                    selectedColor: BentoTheme.accent,
                    backgroundColor: BentoTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedKind == 'expense' ? Colors.black : BentoTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedKind = 'expense');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Income Categories')),
                    selected: _selectedKind == 'income',
                    selectedColor: BentoTheme.accent,
                    backgroundColor: BentoTheme.surface,
                    labelStyle: TextStyle(
                      color: _selectedKind == 'income' ? Colors.black : BentoTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedKind = 'income');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Categories List
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories found',
                      style: TextStyle(color: BentoTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return _buildCategoryTile(cat);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: BentoTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryTile(Category cat) {
    final color = cat.colorValue != 0 ? Color(cat.colorValue) : BentoTheme.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(
          color: cat.archived
              ? Colors.white10
              : BentoTheme.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForKey(cat.iconKey),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: cat.archived ? BentoTheme.textSecondary : BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: cat.archived ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (cat.essential) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ESSENTIAL',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  cat.group.toUpperCase(),
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Actions Popup Menu
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.moreVertical, size: 16, color: BentoTheme.textSecondary),
            color: BentoTheme.surface,
            onSelected: (action) async {
              if (action == 'edit') {
                _showAddEditDialog(category: cat);
              } else if (action == 'merge') {
                _showMergeDialog(cat);
              } else if (action == 'archive') {
                final updated = Category(
                  id: cat.id,
                  name: cat.name,
                  kind: cat.kind,
                  group: cat.group,
                  iconKey: cat.iconKey,
                  colorValue: cat.colorValue,
                  essential: cat.essential,
                  archived: !cat.archived,
                  sortOrder: cat.sortOrder,
                );
                await _repository.saveCategory(updated);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'merge',
                child: Text('Merge Into...', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  cat.archived ? 'Unarchive' : 'Archive',
                  style: TextStyle(color: cat.archived ? BentoTheme.accent : Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForKey(String? key) {
    switch (key) {
      case 'utensils': return LucideIcons.utensils;
      case 'shopping_cart': return LucideIcons.shoppingCart;
      case 'car': return LucideIcons.car;
      case 'bolt': return LucideIcons.zap;
      case 'heart_pulse': return LucideIcons.heartPulse;
      case 'film': return LucideIcons.film;
      case 'tv': return LucideIcons.tv;
      case 'apple': return LucideIcons.apple;
      case 'home': return LucideIcons.home;
      case 'graduation_cap': return LucideIcons.graduationCap;
      case 'plane': return LucideIcons.plane;
      case 'repeat': return LucideIcons.repeat;
      case 'shield': return LucideIcons.shield;
      case 'gift': return LucideIcons.gift;
      case 'sparkles': return LucideIcons.sparkles;
      default: return LucideIcons.tag;
    }
  }
}
