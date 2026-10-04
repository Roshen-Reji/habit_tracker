import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class BudgetLineSheet extends StatefulWidget {
  final FinanceController controller;
  final BudgetLine? existingLine;
  final String? initialCategoryId;
  final DateTime currentMonth;

  const BudgetLineSheet({
    super.key,
    required this.controller,
    this.existingLine,
    this.initialCategoryId,
    required this.currentMonth,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    BudgetLine? existingLine,
    String? initialCategoryId,
    required DateTime currentMonth,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetLineSheet(
        controller: controller,
        existingLine: existingLine,
        initialCategoryId: initialCategoryId,
        currentMonth: currentMonth,
      ),
    );
  }

  @override
  State<BudgetLineSheet> createState() => _BudgetLineSheetState();
}

class _BudgetLineSheetState extends State<BudgetLineSheet> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCategoryId;
  late TextEditingController _baseAmountController;
  late TextEditingController _overrideAmountController;

  late bool _rollover;
  late bool _essential;
  bool _hasOverride = false;
  late String _monthKey;

  @override
  void initState() {
    super.initState();
    _monthKey = DateFormat('yyyy-MM').format(widget.currentMonth);

    final line = widget.existingLine;
    if (line != null) {
      _selectedCategoryId = line.categoryId;
      _baseAmountController = TextEditingController(
        text: line.amount.truncateToDouble() == line.amount
            ? line.amount.toInt().toString()
            : line.amount.toStringAsFixed(2),
      );
      _rollover = line.rollover;
      _essential = line.essential;

      final override =
          widget.controller.repository.getAllBudgetOverrides()['${line.id}_$_monthKey'];
      if (override != null) {
        _hasOverride = true;
        _overrideAmountController = TextEditingController(
          text: override.truncateToDouble() == override
              ? override.toInt().toString()
              : override.toStringAsFixed(2),
        );
      } else {
        _overrideAmountController = TextEditingController();
      }
    } else {
      _selectedCategoryId = widget.initialCategoryId;
      _baseAmountController = TextEditingController();
      _overrideAmountController = TextEditingController();
      _rollover = false;

      // Default essential from category if available
      final cat = _selectedCategoryId != null
          ? widget.controller.storage.categoryBox.get(_selectedCategoryId!)
          : null;
      _essential = cat?.essential ?? false;
    }
  }

  @override
  void dispose() {
    _baseAmountController.dispose();
    _overrideAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final baseAmount = double.parse(_baseAmountController.text.trim());
    final isNew = widget.existingLine == null;
    final lineId = widget.existingLine?.id ??
        'bl_${DateTime.now().millisecondsSinceEpoch}';

    final budgetLine = BudgetLine(
      id: lineId,
      categoryId: _selectedCategoryId,
      amount: baseAmount,
      rollover: _rollover,
      essential: _essential,
      startMonth: widget.existingLine?.startMonth ?? _monthKey,
    );

    await widget.controller.setBudgetLine(budgetLine);

    // Handle month override
    if (_hasOverride && _overrideAmountController.text.trim().isNotEmpty) {
      final overrideAmt = double.tryParse(_overrideAmountController.text.trim());
      if (overrideAmt != null && overrideAmt > 0) {
        await widget.controller.setBudgetOverride(lineId, _monthKey, overrideAmt);
      }
    } else if (widget.existingLine != null) {
      await widget.controller.removeBudgetOverride(lineId, _monthKey);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNew ? 'Budget created successfully' : 'Budget updated',
          ),
          backgroundColor: BentoTheme.surface,
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text(
          'Delete Budget?',
          style: TextStyle(color: BentoTheme.textPrimary),
        ),
        content: Text(
          'This will remove the monthly budget limit for this category. Past transactions will not be deleted.',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingLine != null) {
      await widget.controller.deleteBudgetLine(widget.existingLine!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.storage.categoryBox.values
        .where((c) => !c.archived && c.kind == 'expense')
        .toList();
    final monthLabel = DateFormat('MMMM yyyy').format(widget.currentMonth);

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(LucideIcons.target, color: BentoTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.existingLine == null ? 'Set Budget' : 'Edit Budget',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.existingLine != null)
                    IconButton(
                      icon: const Icon(LucideIcons.trash2,
                          color: Colors.redAccent, size: 20),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Picker (if not editing an existing locked category)
              Text(
                'CATEGORY',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.existingLine != null) ...[
                // Display locked category chip
                Builder(builder: (context) {
                  final cat = widget.controller.storage.categoryBox
                      .get(widget.existingLine!.categoryId);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: BentoTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              Color(cat?.colorValue ?? 0xFF00E5FF),
                          child: const Icon(LucideIcons.tag,
                              size: 14, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cat?.name ?? 'Category',
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                // Horizontal category selector
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final cat = categories[idx];
                      final isSelected = _selectedCategoryId == cat.id;

                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(cat.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(cat.name),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: BentoTheme.accent.withValues(alpha: 0.2),
                        backgroundColor: BentoTheme.background,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? BentoTheme.accent
                              : BentoTheme.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? BentoTheme.accent
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategoryId = cat.id;
                              _essential = cat.essential;
                            });
                            HapticFeedback.selectionClick();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Base monthly budget amount
              Text(
                'MONTHLY BASE BUDGET',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Text(
                      '₹',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _baseAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '5000',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                        ),
                        validator: (val) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num <= 0) {
                            return 'Enter a valid amount > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Month override toggle & input
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Override for $monthLabel',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set a specific limit for this month only.',
                                style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _hasOverride,
                          activeColor: BentoTheme.accent,
                          onChanged: (val) {
                            setState(() {
                              _hasOverride = val;
                              if (!val) _overrideAmountController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    if (_hasOverride) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: BentoTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: BentoTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Text('₹',
                                style: TextStyle(
                                    color: BentoTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _overrideAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText:
                                      'Override limit for ${_monthKey}',
                                  hintStyle:
                                      const TextStyle(color: Colors.white24),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Rollover toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.repeat,
                                  size: 15, color: BentoTheme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Rollover unspent amount',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unused budget carries forward to increase next month\'s limit.',
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _rollover,
                      activeColor: BentoTheme.accent,
                      onChanged: (val) {
                        setState(() => _rollover = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Essential toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.shieldAlert,
                                  size: 15, color: Colors.amberAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Essential Expense (Needs)',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Classified as Needs in 50/30/20 and protected during safe-to-spend cuts.',
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _essential,
                      activeColor: Colors.amberAccent,
                      onChanged: (val) {
                        setState(() => _essential = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: ExpressiveTokens.borderM,
                    ),
                  ),
                  child: Text(
                    widget.existingLine == null ? 'Create Budget' : 'Save Changes',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
