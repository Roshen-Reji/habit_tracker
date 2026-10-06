import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class SinkingFundTemplate {
  final String name;
  final String categoryName;
  final int colorValue;
  final double defaultTarget;

  const SinkingFundTemplate({
    required this.name,
    required this.categoryName,
    required this.colorValue,
    required this.defaultTarget,
  });
}

class GoalEditSheet extends StatefulWidget {
  final FinanceController controller;
  final SavingsGoal? existingGoal;
  final String initialKind;

  const GoalEditSheet({
    super.key,
    required this.controller,
    this.existingGoal,
    this.initialKind = 'goal',
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    SavingsGoal? existingGoal,
    String initialKind = 'goal',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalEditSheet(
        controller: controller,
        existingGoal: existingGoal,
        initialKind: initialKind,
      ),
    );
  }

  @override
  State<GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<GoalEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _kind;
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _monthlyController;

  DateTime? _deadline;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  late int _colorValue;
  late bool _autoContribute;

  static const List<SinkingFundTemplate> _templates = [
    SinkingFundTemplate(
      name: 'Insurance Premium',
      categoryName: 'Insurance',
      colorValue: 0xFF38BDF8,
      defaultTarget: 25000,
    ),
    SinkingFundTemplate(
      name: 'College Fees',
      categoryName: 'Education',
      colorValue: 0xFFA78BFA,
      defaultTarget: 100000,
    ),
    SinkingFundTemplate(
      name: 'Laptop Replacement',
      categoryName: 'Shopping',
      colorValue: 0xFFF472B6,
      defaultTarget: 80000,
    ),
    SinkingFundTemplate(
      name: 'Festival Shopping',
      categoryName: 'Shopping',
      colorValue: 0xFFFBBF24,
      defaultTarget: 30000,
    ),
    SinkingFundTemplate(
      name: 'Travel & Vacation',
      categoryName: 'Travel',
      colorValue: 0xFF34D399,
      defaultTarget: 50000,
    ),
    SinkingFundTemplate(
      name: 'Medical Reserve',
      categoryName: 'Health',
      colorValue: 0xFFF87171,
      defaultTarget: 40000,
    ),
    SinkingFundTemplate(
      name: 'Vehicle Maintenance',
      categoryName: 'Transport',
      colorValue: 0xFFFB923C,
      defaultTarget: 15000,
    ),
    SinkingFundTemplate(
      name: 'Gifts & Celebrations',
      categoryName: 'Gifts',
      colorValue: 0xFFE879F9,
      defaultTarget: 20000,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;

    _kind = g?.kind ?? widget.initialKind;
    _nameController = TextEditingController(text: g?.name ?? '');
    _targetController = TextEditingController(
      text: g != null
          ? (g.targetAmount.truncateToDouble() == g.targetAmount
              ? g.targetAmount.toInt().toString()
              : g.targetAmount.toStringAsFixed(2))
          : '',
    );
    _monthlyController = TextEditingController(
      text: g?.plannedMonthly != null && g!.plannedMonthly! > 0
          ? (g.plannedMonthly!.truncateToDouble() == g.plannedMonthly
              ? g.plannedMonthly!.toInt().toString()
              : g.plannedMonthly!.toStringAsFixed(2))
          : '',
    );

    _deadline = g?.deadline ?? g?.dueDate;
    _selectedAccountId = g?.accountId;
    _selectedCategoryId = g?.linkedCategoryId;
    _colorValue = g?.colorValue ?? 0xFF00E5FF;
    _autoContribute = g?.autoContribute ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  void _applyTemplate(SinkingFundTemplate t) {
    setState(() {
      _nameController.text = t.name;
      _targetController.text = t.defaultTarget.toInt().toString();
      _colorValue = t.colorValue;

      // Try matching category
      final matchedCat = widget.controller.storage.categoryBox.values
          .where((c) =>
              c.name.toLowerCase() == t.categoryName.toLowerCase() &&
              c.kind == 'expense')
          .firstOrNull;
      if (matchedCat != null) {
        _selectedCategoryId = matchedCat.id;
      }
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: BentoTheme.accent,
              surface: BentoTheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final targetVal = double.parse(_targetController.text.trim());
    final monthlyVal = _monthlyController.text.trim().isNotEmpty
        ? double.tryParse(_monthlyController.text.trim())
        : null;

    final isNew = widget.existingGoal == null;
    final id = widget.existingGoal?.id ??
        'goal_${DateTime.now().millisecondsSinceEpoch}';

    final goal = SavingsGoal(
      id: id,
      name: _nameController.text.trim(),
      kind: _kind,
      targetAmount: targetVal,
      deadline: _kind == 'goal' ? _deadline : null,
      dueDate: _kind == 'sinking_fund' ? _deadline : null,
      accountId: _selectedAccountId,
      colorValue: _colorValue,
      autoContribute: _autoContribute,
      plannedMonthly: monthlyVal,
      linkedCategoryId: _selectedCategoryId,
      archived: widget.existingGoal?.archived ?? false,
    );

    if (isNew) {
      await widget.controller.addGoal(goal);
    } else {
      await widget.controller.updateGoal(goal);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNew
                ? '${goal.name} created successfully'
                : '${goal.name} updated',
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
          'Delete ${widget.existingGoal!.name}?',
          style: TextStyle(color: BentoTheme.textPrimary),
        ),
        content: Text(
          'This will delete this goal and its contribution logs.',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: BentoTheme.negative),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingGoal != null) {
      await widget.controller.deleteGoal(widget.existingGoal!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.activeAccounts;
    final categories = widget.controller.storage.categoryBox.values
        .where((c) => !c.archived && c.kind == 'expense')
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Icon(
                    _kind == 'sinking_fund'
                        ? LucideIcons.calendarClock
                        : LucideIcons.target,
                    color: BentoTheme.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.existingGoal == null
                        ? (_kind == 'sinking_fund'
                            ? 'New Sinking Fund'
                            : 'New Savings Goal')
                        : 'Edit Goal',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.existingGoal != null)
                    IconButton(
                      icon: Icon(LucideIcons.trash2,
                          color: BentoTheme.negative, size: 20),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white60, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kind Selector (Goal vs Sinking Fund)
              if (widget.existingGoal == null) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: BentoTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _kind = 'goal'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _kind == 'goal'
                                  ? BentoTheme.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Savings Goal',
                              style: TextStyle(
                                color: _kind == 'goal'
                                    ? Colors.black
                                    : BentoTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _kind = 'sinking_fund'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _kind == 'sinking_fund'
                                  ? BentoTheme.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sinking Fund',
                              style: TextStyle(
                                color: _kind == 'sinking_fund'
                                    ? Colors.black
                                    : BentoTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sinking Fund Templates Carousel
              if (_kind == 'sinking_fund' && widget.existingGoal == null) ...[
                Text(
                  'QUICK TEMPLATES',
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
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final t = _templates[idx];
                      return ActionChip(
                        avatar: CircleAvatar(
                          radius: 6,
                          backgroundColor: Color(t.colorValue),
                        ),
                        label: Text(t.name),
                        backgroundColor: BentoTheme.background,
                        labelStyle: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        onPressed: () => _applyTemplate(t),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Name Field
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  labelText: _kind == 'sinking_fund'
                      ? 'Fund Name (e.g. Annual Insurance)'
                      : 'Goal Name (e.g. Emergency Fund)',
                  labelStyle:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Target Amount
              TextFormField(
                controller: _targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '${FormatUtils.getCurrencySymbol()} ',
                  prefixStyle: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  labelText: 'Target Amount',
                  labelStyle:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                validator: (val) {
                  final num = double.tryParse(val ?? '');
                  if (num == null || num <= 0) {
                    return 'Please enter a target > 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Target Date / Due Date
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: BentoTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 18,
                        color: BentoTheme.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _kind == 'sinking_fund'
                                  ? 'Due Date'
                                  : 'Target Deadline',
                              style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deadline != null
                                  ? DateFormat('dd MMMM yyyy')
                                      .format(_deadline!)
                                  : 'Select target date (optional)',
                              style: TextStyle(
                                color: _deadline != null
                                    ? BentoTheme.textPrimary
                                    : Colors.white38,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 16, color: Colors.white38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Earmark Account Dropdown
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                dropdownColor: BentoTheme.surface,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Earmark Account (Optional)',
                  labelStyle:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None (General savings pool)'),
                  ),
                  ...accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text('${acc.name} (${acc.kind})'),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedAccountId = val),
              ),
              const SizedBox(height: 16),

              // Linked Category (for sinking funds or auto-prompts)
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                dropdownColor: BentoTheme.surface,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Linked Expense Category (Optional)',
                  labelStyle:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None'),
                  ),
                  ...categories.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 16),

              // Auto-contribute toggle & planned monthly
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Contribute Monthly',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Automatically logs monthly reserve contribution on 1st of each month.',
                                style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _autoContribute,
                          activeColor: BentoTheme.accent,
                          onChanged: (val) {
                            setState(() => _autoContribute = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _monthlyController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                          color: BentoTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '${FormatUtils.getCurrencySymbol()} ',
                        prefixStyle: TextStyle(
                            color: BentoTheme.accent,
                            fontWeight: FontWeight.bold),
                        labelText: 'Planned Monthly Reserve',
                        labelStyle: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: BentoTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
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
                    widget.existingGoal == null
                        ? (_kind == 'sinking_fund'
                            ? 'Create Sinking Fund'
                            : 'Create Goal')
                        : 'Save Changes',
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
