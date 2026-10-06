import 'package:habit_tracker/core/utils/format_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/capture_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/transactions/split_editor_sheet.dart';

class TransactionSheet extends StatefulWidget {
  final Transaction? existingTransaction;
  final String? initialKind;
  final String? initialAccountId;

  const TransactionSheet({
    super.key,
    this.existingTransaction,
    this.initialKind,
    this.initialAccountId,
  });

  /// Static helper to open the sheet
  static Future<bool?> show(
    BuildContext context, {
    Transaction? existingTransaction,
    String? initialKind,
    String? initialAccountId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionSheet(
        existingTransaction: existingTransaction,
        initialKind: initialKind,
        initialAccountId: initialAccountId,
      ),
    );
  }

  @override
  State<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final FinanceController _controller = FinanceController();
  late final FinanceRepository _repository = _controller.repository;

  late String _kind;
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  late TextEditingController _interestController;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedCategoryId;
  String _selectedPaymentMethod = 'UPI';
  String? _splitsJson;
  String? _refundOfId;
  List<String> _receiptPaths = [];

  bool _isSaving = false;

  static const List<String> _allKinds = [
    'expense',
    'income',
    'transfer',
    'refund',
    'investment',
    'debt_payment',
    'adjustment',
    'reimbursement',
  ];

  static const List<String> _paymentMethods = [
    'UPI',
    'Card',
    'Cash',
    'NetBanking',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;

    _kind = tx?.effectiveKind ?? widget.initialKind ?? 'expense';
    _amountController = TextEditingController(
      text: tx != null
          ? tx.amount.abs().toStringAsFixed(
              tx.amount.abs().truncateToDouble() == tx.amount.abs() ? 0 : 2)
          : '',
    );
    _titleController = TextEditingController(text: tx?.title ?? '');
    _merchantController = TextEditingController(text: tx?.merchant ?? '');
    _notesController = TextEditingController(text: tx?.notes ?? '');
    _tagsController = TextEditingController(
      text: tx?.tags != null && tx!.tags!.isNotEmpty ? tx.tags!.join(', ') : '',
    );
    _interestController = TextEditingController(
      text: tx?.interestAmount != null && tx!.interestAmount! > 0
          ? tx.interestAmount!.toStringAsFixed(2)
          : '',
    );

    if (tx != null) {
      _selectedDate = tx.date;
      _selectedTime = TimeOfDay.fromDateTime(tx.date);
      _selectedAccountId = tx.accountId;
      _selectedToAccountId = tx.toAccountId;
      _selectedCategoryId = tx.categoryId;
      _selectedPaymentMethod = tx.paymentMethod ?? 'UPI';
      _splitsJson = tx.splits;
      _refundOfId = tx.refundOfId;
      _receiptPaths = List<String>.from(tx.receiptPaths ?? []);
    } else {
      _selectedAccountId = widget.initialAccountId;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    _ensureValidAccounts();
    _ensureValidCategory();
  }

  void _ensureValidAccounts() {
    final accounts = _controller.activeAccounts;
    if (accounts.isEmpty) return;

    if (_selectedAccountId == null ||
        !accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = accounts.first.id;
    }

    if (_needsDestinationAccount) {
      final others = accounts.where((a) => a.id != _selectedAccountId).toList();
      if (others.isNotEmpty &&
          (_selectedToAccountId == null ||
              _selectedToAccountId == _selectedAccountId ||
              !others.any((a) => a.id == _selectedToAccountId))) {
        _selectedToAccountId = others.first.id;
      }
    }
  }

  void _ensureValidCategory() {
    final categories = _filteredCategories;
    if (categories.isEmpty) return;

    if (_selectedCategoryId == null ||
        !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.first.id;
    }
  }

  bool get _needsDestinationAccount =>
      _kind == 'transfer' || _kind == 'investment' || _kind == 'debt_payment';

  bool get _needsCategory =>
      _kind == 'expense' ||
      _kind == 'income' ||
      _kind == 'refund' ||
      _kind == 'investment';

  List<Category> get _filteredCategories {
    final all = _controller.activeCategories;
    if (_kind == 'income') {
      return all.where((c) => c.kind == 'income').toList();
    }
    return all.where((c) => c.kind == 'expense').toList();
  }

  void _repeatLast() {
    final last = _controller.lastTransaction;
    if (last == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous transaction to repeat')),
      );
      return;
    }

    setState(() {
      _kind = last.effectiveKind;
      _amountController.text = last.amount.abs().toString();
      _titleController.text = last.title;
      _merchantController.text = last.merchant ?? '';
      _selectedAccountId = last.accountId;
      _selectedToAccountId = last.toAccountId;
      _selectedCategoryId = last.categoryId;
      _selectedPaymentMethod = last.paymentMethod ?? 'UPI';
      if (last.tags != null) {
        _tagsController.text = last.tags!.join(', ');
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
  }

  Future<void> _openSplitEditor() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter an amount before splitting')),
      );
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SplitEditorSheet(
        totalAmount: amount,
        initialSplitsJson: _splitsJson,
        categories: _controller.activeCategories,
      ),
    );

    if (result != null) {
      setState(() {
        _splitsJson = result;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amountRaw = double.tryParse(_amountController.text) ?? 0.0;
    if (amountRaw <= 0 && _kind != 'adjustment') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    // Invariant I6 checks
    if (_needsDestinationAccount) {
      if (_selectedAccountId == _selectedToAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Source and destination accounts must be different')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final category = _controller.getCategory(_selectedCategoryId);
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : (_merchantController.text.trim().isNotEmpty
              ? _merchantController.text.trim()
              : (category?.name ?? _kind.toUpperCase()));

      final interestAmount = double.tryParse(_interestController.text);

      final draft = TxDraft(
        title: title,
        amount: amountRaw,
        kind: _kind,
        accountId: _selectedAccountId,
        toAccountId: _selectedToAccountId,
        categoryId: _selectedCategoryId,
        category: category?.name ?? 'Other',
        date: combinedDateTime,
        merchant: _merchantController.text.trim().isNotEmpty
            ? _merchantController.text.trim()
            : null,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        tags: tags.isNotEmpty ? tags : null,
        splits: _splitsJson,
        interestAmount: interestAmount,
        refundOfId: _refundOfId,
        receiptPaths: _receiptPaths.isNotEmpty ? _receiptPaths : null,
      );

      if (widget.existingTransaction != null) {
        await _repository.updateTransaction(
          widget.existingTransaction!.id ??
              widget.existingTransaction!.key.toString(),
          draft,
        );
      } else {
        await _repository.addTransaction(draft);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final tx = widget.existingTransaction;
    if (tx == null) return;

    final id = tx.id ?? tx.key.toString();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);

    await _repository.deleteTransaction(id);

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: BentoTheme.accent,
          onPressed: () async {
            await _repository.undo();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeStr = DateFormat('EEE, MMM d, yyyy · hh:mm a').format(
      DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Top handle & header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    widget.existingTransaction != null
                        ? 'Edit Transaction'
                        : 'New Transaction',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.existingTransaction == null)
                    TextButton.icon(
                      onPressed: _repeatLast,
                      icon: const Icon(LucideIcons.repeat, size: 14),
                      label: const Text('Repeat Last',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: BentoTheme.accent,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (widget.existingTransaction != null)
                    IconButton(
                      icon: const Icon(LucideIcons.trash2,
                          size: 18, color: Colors.redAccent),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Scrollable fields
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Kind Chips (all 8 kinds)
                    _buildKindChips(),
                    const SizedBox(height: 16),

                    // 2. Amount Input
                    _buildAmountField(),
                    const SizedBox(height: 16),

                    // 3. Accounts (Source & Destination if needed)
                    _buildAccountSelectors(),
                    const SizedBox(height: 16),

                    // 4. Category Grid (if needed)
                    if (_needsCategory) ...[
                      _buildCategorySection(),
                      const SizedBox(height: 16),
                    ],

                    // 5. Debt principal / interest split (if debt_payment)
                    if (_kind == 'debt_payment') ...[
                      _buildInterestField(),
                      const SizedBox(height: 16),
                    ],

                    // 6. Date & Time Picker Chip
                    _buildDateTimePicker(dateTimeStr),
                    const SizedBox(height: 16),

                    // 7. Payment Method Chips (persisted!)
                    _buildPaymentMethodSection(),
                    const SizedBox(height: 16),

                    // 8. Merchant / Counterparty
                    _buildMerchantField(),
                    const SizedBox(height: 12),

                    // 9. Notes & Tags
                    _buildNotesAndTags(),
                    const SizedBox(height: 16),

                    // 10. Split & Recurring Buttons
                    _buildSpecialActions(),
                  ],
                ),
              ),
            ),

            // Bottom Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          widget.existingTransaction != null
                              ? 'Update'
                              : 'Save Transaction',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _allKinds.map((k) {
          final isSelected = _kind == k;
          final label = _kindLabel(k);
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _kind = k;
                    _ensureValidAccounts();
                    _ensureValidCategory();
                  });
                }
              },
              selectedColor: BentoTheme.accent,
              backgroundColor: BentoTheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : BentoTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? BentoTheme.accent : Colors.transparent,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _kindLabel(String k) {
    switch (k) {
      case 'expense':
        return 'Expense';
      case 'income':
        return 'Income';
      case 'transfer':
        return 'Transfer';
      case 'refund':
        return 'Refund';
      case 'investment':
        return 'Investment';
      case 'debt_payment':
        return 'Debt Payment';
      case 'adjustment':
        return 'Adjustment';
      case 'reimbursement':
        return 'Reimbursement';
      default:
        return k;
    }
  }

  Widget _buildAmountField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Row(
        children: [
          Text(
            FormatUtils.getCurrencySymbol(),
            style: TextStyle(
              color: BentoTheme.accent,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              autofocus: widget.existingTransaction == null,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                isDense: true,
              ),
              validator: (v) {
                final num = double.tryParse(v ?? '');
                if (num == null) return 'Enter a valid amount';
                if (num <= 0 && _kind != 'adjustment')
                  return 'Amount must be > 0';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSelectors() {
    final accounts = _controller.activeAccounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedAccountId,
                dropdownColor: BentoTheme.surface,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText:
                      _needsDestinationAccount ? 'From Account' : 'Account',
                  labelStyle:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: BentoTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: accounts.map((a) {
                  return DropdownMenuItem<String>(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedAccountId = val;
                    _ensureValidAccounts();
                  });
                },
              ),
            ),
            if (_needsDestinationAccount) ...[
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedToAccountId,
                  dropdownColor: BentoTheme.surface,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'To Account',
                    labelStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: BentoTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: accounts
                      .where((a) => a.id != _selectedAccountId)
                      .map((a) {
                    return DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedToAccountId = val;
                      if (val != null && _kind == 'transfer') {
                        try {
                          final toAcc = accounts.firstWhere((a) => a.id == val);
                          if (toAcc.isValuedAsset) {
                            _kind = 'investment';
                          } else if (toAcc.isLoan) {
                            _kind = 'debt_payment';
                          }
                          _ensureValidCategory();
                        } catch (_) {}
                      }
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final categories = _filteredCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategoryId == cat.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryId = cat.id;
                  });
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 75,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BentoTheme.accent.withValues(alpha: 0.2)
                        : BentoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconForCategory(cat.iconKey),
                        size: 20,
                        color: isSelected
                            ? BentoTheme.accent
                            : BentoTheme.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? BentoTheme.textPrimary
                              : BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _iconForCategory(String? key) {
    switch (key) {
      case 'utensils':
        return LucideIcons.utensils;
      case 'shopping_cart':
        return LucideIcons.shoppingCart;
      case 'car':
        return LucideIcons.car;
      case 'bolt':
        return LucideIcons.zap;
      case 'heart_pulse':
        return LucideIcons.heartPulse;
      case 'film':
        return LucideIcons.film;
      case 'tv':
        return LucideIcons.tv;
      case 'apple':
        return LucideIcons.apple;
      case 'credit_card':
        return LucideIcons.creditCard;
      case 'home':
        return LucideIcons.home;
      case 'graduation_cap':
        return LucideIcons.graduationCap;
      case 'plane':
        return LucideIcons.plane;
      case 'repeat':
        return LucideIcons.repeat;
      case 'shield':
        return LucideIcons.shield;
      case 'gift':
        return LucideIcons.gift;
      case 'sparkles':
        return LucideIcons.sparkles;
      case 'banknote':
        return LucideIcons.banknote;
      default:
        return LucideIcons.tag;
    }
  }

  Widget _buildInterestField() {
    return TextFormField(
      controller: _interestController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Interest portion (optional)',
        labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
        prefixText: '${FormatUtils.getCurrencySymbol()} ',
        prefixStyle: TextStyle(color: BentoTheme.accent),
        filled: true,
        fillColor: BentoTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  bool get _isDatedBeforeAccountOpening {
    if (_selectedAccountId == null) return false;
    final acc = _controller.getAccount(_selectedAccountId);
    if (acc == null) return false;
    return _selectedDate.isBefore(acc.openingDate);
  }

  Widget _buildDateTimePicker(String formatted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 16, color: BentoTheme.accent),
                const SizedBox(width: 10),
                Text(
                  formatted,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(LucideIcons.chevronRight,
                    size: 16, color: BentoTheme.textSecondary),
              ],
            ),
          ),
        ),
        if (_isDatedBeforeAccountOpening) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.alertTriangle,
                    size: 14, color: Colors.orangeAccent),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Before this account\'s opening date, it will not count',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAYMENT METHOD',
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _paymentMethods.map((m) {
              final isSelected = _selectedPaymentMethod == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPaymentMethod = m);
                    }
                  },
                  selectedColor: BentoTheme.accent,
                  backgroundColor: BentoTheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : BentoTheme.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          isSelected ? BentoTheme.accent : Colors.transparent,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantField() {
    final merchants = _controller.allMerchants.toList();

    return Column(
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _merchantController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return merchants.where((m) =>
                m.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (String selection) {
            _merchantController.text = selection;
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // keep controllers in sync
            controller.addListener(() {
              _merchantController.text = controller.text;
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Merchant / Payee (optional)',
                hintText: 'e.g. Swiggy, Amazon, Metro',
                hintStyle: TextStyle(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                labelStyle:
                    TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: BentoTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotesAndTags() {
    return Column(
      children: [
        TextFormField(
          controller: _notesController,
          maxLines: 2,
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            labelStyle:
                TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
            filled: true,
            fillColor: BentoTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _tagsController,
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Tags (comma separated)',
            hintText: 'e.g. trip, office, dinner',
            hintStyle: TextStyle(
              color: BentoTheme.textSecondary.withValues(alpha: 0.4),
              fontSize: 12,
            ),
            labelStyle:
                TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
            filled: true,
            fillColor: BentoTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.camera, color: BentoTheme.accent),
                title: Text('Take Photo',
                    style: TextStyle(color: BentoTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(LucideIcons.image, color: BentoTheme.accent),
                title: Text('Choose from Gallery',
                    style: TextStyle(color: BentoTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        final txId = widget.existingTransaction?.id ??
            'temp_${DateTime.now().millisecondsSinceEpoch}';
        final savedPath = await ReceiptManager.saveReceipt(
            txId: txId, sourceFile: File(picked.path));
        setState(() {
          _receiptPaths.add(savedPath);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach receipt: $e')),
        );
      }
    }
  }

  Widget _buildSpecialActions() {
    final hasSplits = _splitsJson != null && _splitsJson!.isNotEmpty;
    final hasReceipts = _receiptPaths.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Split Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openSplitEditor,
                icon: Icon(
                  hasSplits ? LucideIcons.checkCheck : LucideIcons.split,
                  size: 16,
                  color:
                      hasSplits ? const Color(0xFF22C55E) : BentoTheme.accent,
                ),
                label: Text(
                  hasSplits ? 'Splits Added' : 'Split Expense',
                  style: TextStyle(
                    color:
                        hasSplits ? const Color(0xFF22C55E) : BentoTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: (hasSplits
                            ? const Color(0xFF22C55E)
                            : BentoTheme.accent)
                        .withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Receipt Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickReceipt,
                icon: Icon(
                  hasReceipts ? LucideIcons.paperclip : LucideIcons.camera,
                  size: 16,
                  color: hasReceipts
                      ? const Color(0xFF38BDF8)
                      : BentoTheme.textSecondary,
                ),
                label: Text(
                  hasReceipts
                      ? 'Receipts (${_receiptPaths.length})'
                      : 'Add Receipt',
                  style: TextStyle(
                    color: hasReceipts
                        ? const Color(0xFF38BDF8)
                        : BentoTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color:
                        (hasReceipts ? const Color(0xFF38BDF8) : Colors.white12)
                            .withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasReceipts) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _receiptPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final path = _receiptPaths[idx];
                final file = File(path);
                return Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: BentoTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: file.existsSync()
                          ? Image.file(file, fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                LucideIcons.fileText,
                                size: 24,
                                color: BentoTheme.textSecondary,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _receiptPaths.removeAt(idx);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
