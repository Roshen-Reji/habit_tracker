import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class RecurringEditSheet extends StatefulWidget {
  final FinanceController controller;
  final RecurringRule? existingRule;
  final String? initialKind;
  final String? initialName;
  final double? initialAmount;
  final String? initialCategoryId;

  const RecurringEditSheet({
    super.key,
    required this.controller,
    this.existingRule,
    this.initialKind,
    this.initialName,
    this.initialAmount,
    this.initialCategoryId,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    RecurringRule? existingRule,
    String? initialKind,
    String? initialName,
    double? initialAmount,
    String? initialCategoryId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecurringEditSheet(
        controller: controller,
        existingRule: existingRule,
        initialKind: initialKind,
        initialName: initialName,
        initialAmount: initialAmount,
        initialCategoryId: initialCategoryId,
      ),
    );
  }

  @override
  State<RecurringEditSheet> createState() => _RecurringEditSheetState();
}

class _RecurringEditSheetState extends State<RecurringEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _kind;
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late bool _amountIsVariable;
  late String _frequency;
  late int _dayOfMonth;
  late DateTime _startDate;
  late bool _autoPost;
  late int _reminderDays;
  late String _status;

  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;

  static const List<String> _kinds = [
    'bill',
    'subscription',
    'sip',
    'emi',
    'income',
    'transfer',
  ];

  static const List<String> _frequencies = [
    'monthly',
    'weekly',
    'quarterly',
    'yearly',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.existingRule;

    _kind = r?.kind ?? widget.initialKind ?? 'bill';
    _nameController = TextEditingController(text: r?.name ?? widget.initialName ?? '');
    _amountController = TextEditingController(
      text: r != null
          ? (r.amount.truncateToDouble() == r.amount
              ? r.amount.toInt().toString()
              : r.amount.toStringAsFixed(2))
          : (widget.initialAmount != null
              ? (widget.initialAmount!.truncateToDouble() == widget.initialAmount
                  ? widget.initialAmount!.toInt().toString()
                  : widget.initialAmount!.toStringAsFixed(2))
              : ''),
    );
    _notesController = TextEditingController(text: r?.notes ?? '');

    _amountIsVariable = r?.amountIsVariable ?? false;
    _frequency = r?.frequency ?? 'monthly';
    _dayOfMonth = r?.dayOfMonth ?? DateTime.now().day;
    _startDate = r?.startDate ?? DateTime.now();
    _autoPost = r?.autoPost ?? false;
    _reminderDays = r?.reminderDaysBefore ?? 2;
    _status = r?.status ?? 'active';

    _selectedCategoryId = r?.categoryId ?? widget.initialCategoryId;
    _selectedAccountId = r?.accountId;
    _selectedToAccountId = r?.toAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amtVal = double.parse(_amountController.text.trim());
    final isNew = widget.existingRule == null;
    final id = widget.existingRule?.id ?? 'rec_${DateTime.now().millisecondsSinceEpoch}';

    final rule = RecurringRule(
      id: id,
      name: _nameController.text.trim(),
      kind: _kind,
      amount: amtVal,
      amountIsVariable: _amountIsVariable,
      categoryId: _selectedCategoryId,
      accountId: _selectedAccountId,
      toAccountId: _selectedToAccountId,
      frequency: _frequency,
      dayOfMonth: _dayOfMonth,
      startDate: _startDate,
      autoPost: _autoPost,
      reminderDaysBefore: _reminderDays,
      status: _status,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
    );

    if (isNew) {
      await widget.controller.addRecurringRule(rule);
    } else {
      await widget.controller.updateRecurringRule(rule);
    }

    // Reschedule reminders
    await widget.controller.scheduleRecurringReminders();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNew ? '${rule.name} added to recurring' : '${rule.name} updated'),
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
        title: Text('Delete ${widget.existingRule!.name}?', style: TextStyle(color: BentoTheme.textPrimary)),
        content: Text(
          'This will remove this recurring rule. Past posted transactions will remain untouched.',
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

    if (confirmed == true && widget.existingRule != null) {
      await widget.controller.deleteRecurringRule(widget.existingRule!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.activeAccounts;
    final categories = widget.controller.storage.categoryBox.values
        .where((c) => !c.archived && (_kind == 'income' ? c.kind == 'income' : c.kind == 'expense'))
        .toList();

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

              // Title Bar
              Row(
                children: [
                  Icon(LucideIcons.repeat, color: BentoTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.existingRule == null ? 'New Recurring Rule' : 'Edit Recurring Rule',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.existingRule != null)
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kind Selector Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kinds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final k = _kinds[idx];
                    final isSel = _kind == k;
                    return ChoiceChip(
                      label: Text(k.toUpperCase()),
                      selected: isSel,
                      selectedColor: BentoTheme.accent,
                      backgroundColor: BentoTheme.background,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : BentoTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSel ? BentoTheme.accent : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _kind = k);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Rule Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Name (e.g. Netflix, Electricity Bill)',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter a name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  labelText: _amountIsVariable ? 'Estimated Amount' : 'Amount',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                validator: (val) {
                  final num = double.tryParse(val ?? '');
                  if (num == null || num <= 0) return 'Enter a valid amount > 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Variable Amount Toggle
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _amountIsVariable,
                activeColor: BentoTheme.accent,
                checkColor: Colors.black,
                title: Text(
                  'Amount is variable (e.g. utility bills)',
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  'Estimates future charges from the 3-month historical average.',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                ),
                onChanged: (val) => setState(() => _amountIsVariable = val ?? false),
              ),
              const SizedBox(height: 12),

              // Frequency & Due Day Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _frequency,
                      dropdownColor: BentoTheme.surface,
                      style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Frequency',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: BentoTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                      items: _frequencies.map((f) {
                        return DropdownMenuItem(value: f, child: Text(f.toUpperCase()));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _dayOfMonth.clamp(1, 31),
                      dropdownColor: BentoTheme.surface,
                      style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Due Day of Month',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: BentoTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                      items: List.generate(31, (i) => i + 1).map((d) {
                        return DropdownMenuItem(value: d, child: Text('$d${_daySuffix(d)}'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _dayOfMonth = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Picker
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                dropdownColor: BentoTheme.surface,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                items: categories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 5,
                          backgroundColor: Color(c.colorValue),
                        ),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 16),

              // Account Selector
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                dropdownColor: BentoTheme.surface,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Payment Account',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: BentoTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default / Cash')),
                  ...accounts.map((acc) {
                    return DropdownMenuItem(value: acc.id, child: Text('${acc.name} (${acc.kind})'));
                  }),
                ],
                onChanged: (val) => setState(() => _selectedAccountId = val),
              ),
              const SizedBox(height: 16),

              // Auto-Post Switch Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-Post Transaction',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _autoPost
                                ? 'Transactions post automatically on due date (e.g. SIPs).'
                                : 'Creates a due item you confirm when paid (e.g. credit card bills).',
                            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoPost,
                      activeColor: BentoTheme.accent,
                      onChanged: (val) => setState(() => _autoPost = val),
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
                    widget.existingRule == null ? 'Create Recurring Rule' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
