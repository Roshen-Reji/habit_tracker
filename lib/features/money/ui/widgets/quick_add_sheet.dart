import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../../core/entry.dart';
import '../../core/minor.dart';
import '../../data/money_service.dart';
import '../../state/money_state.dart';
import '../motion/press_scale.dart';
import 'money_category_icon.dart';

/// 3-tap Quick Add and Entry Edit Sheet complying with Section 5 of AGENTS.md.
class QuickAddSheet extends StatefulWidget {
  final EntryKind initialKind;
  final Entry? editEntry;

  const QuickAddSheet({
    super.key,
    this.initialKind = EntryKind.spent,
    this.editEntry,
  });

  static Future<void> show(
    BuildContext context, {
    EntryKind initialKind = EntryKind.spent,
    Entry? editEntry,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddSheet(
        initialKind: editEntry != null ? editEntry.kind : initialKind,
        editEntry: editEntry,
      ),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  late EntryKind _selectedKind;
  String _amountInput = '';
  late String _selectedCategory;
  late String _selectedAccountId;
  String? _selectedToAccountId;
  late DateTime _selectedDate;
  late TextEditingController _noteController;
  bool _showMoreOptions = false;

  final List<String> _spendCategories = const [
    'Food',
    'Groceries',
    'Shopping',
    'Transport',
    'Bills',
    'Health',
    'Entertainment',
    'Other',
  ];

  final List<String> _receiveCategories = const [
    'Salary',
    'Freelance',
    'Investment',
    'Gift',
    'Refund',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.editEntry;
    _selectedKind = edit != null ? edit.kind : widget.initialKind;

    if (edit != null) {
      _amountInput = (edit.amountMinor / 100.0).toStringAsFixed(
        edit.amountMinor % 100 == 0 ? 0 : 2,
      );
      _selectedCategory = edit.category;
      _selectedAccountId = edit.fromAccountId ?? MoneyState().mainAccountId;
      _selectedToAccountId = edit.toAccountId;
      _selectedDate = edit.date;
      _noteController = TextEditingController(text: edit.notes ?? edit.title);
      _showMoreOptions = true;
    } else {
      _selectedCategory = _selectedKind == EntryKind.received
          ? _receiveCategories.first
          : _spendCategories.first;
      _selectedAccountId = MoneyState().mainAccountId;
      _selectedDate = DateTime.now();
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == 'backspace') {
        if (_amountInput.isNotEmpty) {
          _amountInput = _amountInput.substring(0, _amountInput.length - 1);
        }
      } else if (key == '.') {
        if (!_amountInput.contains('.')) {
          _amountInput = _amountInput.isEmpty ? '0.' : '$_amountInput.';
        }
      } else {
        // Limit decimals to 2 places
        if (_amountInput.contains('.')) {
          final parts = _amountInput.split('.');
          if (parts.length > 1 && parts[1].length >= 2) return;
        }
        if (_amountInput == '0') {
          _amountInput = key;
        } else {
          _amountInput += key;
        }
      }
    });
  }

  int get _parsedMinor {
    if (_amountInput.isEmpty) return 0;
    final parsed = double.tryParse(_amountInput) ?? 0.0;
    return Minor.toMinor(parsed);
  }

  Future<void> _handleSave() async {
    final minor = _parsedMinor;
    if (minor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final service = MoneyService();
    final note = _noteController.text.trim();
    final title = note.isNotEmpty ? note : _selectedCategory;

    Navigator.of(context).pop();
    HapticFeedback.lightImpact();

    try {
      if (widget.editEntry != null) {
        final updated = widget.editEntry!.copyWith(
          kind: _selectedKind,
          amountMinor: minor,
          title: title,
          category: _selectedCategory,
          fromAccountId:
              _selectedKind == EntryKind.received ? null : _selectedAccountId,
          toAccountId: _selectedKind == EntryKind.received
              ? _selectedAccountId
              : (_selectedKind == EntryKind.moved
                  ? _selectedToAccountId
                  : null),
          date: _selectedDate,
          notes: note.isNotEmpty ? note : null,
        );
        await service.editEntry(updated);
      } else {
        switch (_selectedKind) {
          case EntryKind.spent:
            await service.spend(
              amountMinor: minor,
              title: title,
              category: _selectedCategory,
              accountId: _selectedAccountId,
              date: _selectedDate,
              notes: note.isNotEmpty ? note : null,
            );
            break;
          case EntryKind.received:
            await service.receive(
              amountMinor: minor,
              title: title,
              category: _selectedCategory,
              accountId: _selectedAccountId,
              date: _selectedDate,
              notes: note.isNotEmpty ? note : null,
            );
            break;
          case EntryKind.moved:
            final toAcc = _selectedToAccountId ??
                MoneyState()
                    .accounts
                    .firstWhere((a) => a.id != _selectedAccountId,
                        orElse: () => MoneyState().accounts.first)
                    .id;
            await service.move(
              amountMinor: minor,
              fromAccountId: _selectedAccountId,
              toAccountId: toAcc,
              title: title,
              category: _selectedCategory,
              date: _selectedDate,
              notes: note.isNotEmpty ? note : null,
            );
            break;
          case EntryKind.adjustment:
            break;
        }
      }

      if (mounted) {
        final undo = service.lastUndoAction;
        if (undo != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${undo.description} saved'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await service.undo();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final state = MoneyState();
    final categories = _selectedKind == EntryKind.received
        ? _receiveCategories
        : _spendCategories;

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: BentoTheme.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Kind Toggle (Spent, Received, Moved)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildKindTab(EntryKind.spent, 'Spent'),
                _buildKindTab(EntryKind.received, 'Received'),
                _buildKindTab(EntryKind.moved, 'Moved'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Large Amount Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _amountInput.isEmpty ? '0' : _amountInput,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category Chips Row
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = categories[idx];
                final isSelected = _selectedCategory == cat;
                return PressScale(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? BentoTheme.accent : BentoTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MoneyCategoryIcon.getIcon(cat),
                          size: 15,
                          color: isSelected
                              ? Colors.white
                              : BentoTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : BentoTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // "More options" toggle
          GestureDetector(
            onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showMoreOptions ? 'Less options' : 'More options',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _showMoreOptions
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: BentoTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // More Options Accordion
          if (_showMoreOptions) ...[
            const SizedBox(height: 8),
            // Note Field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Note / Description (optional)',
                hintStyle: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: BentoTheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Account & Date row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: state.accounts.any((a) => a.id == _selectedAccountId)
                        ? _selectedAccountId
                        : (state.accounts.isNotEmpty
                            ? state.accounts.first.id
                            : null),
                    decoration: InputDecoration(
                      labelText:
                          _selectedKind == EntryKind.moved ? 'From' : 'Account',
                      labelStyle: TextStyle(
                          color: BentoTheme.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: BentoTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                    dropdownColor: BentoTheme.surfaceElevated,
                    items: state.accounts.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name,
                            style: TextStyle(
                                color: BentoTheme.textPrimary, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAccountId = val);
                    },
                  ),
                ),
                if (_selectedKind == EntryKind.moved) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedToAccountId ??
                          state.accounts
                              .firstWhere((a) => a.id != _selectedAccountId,
                                  orElse: () => state.accounts.first)
                              .id,
                      decoration: InputDecoration(
                        labelText: 'To',
                        labelStyle: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: BentoTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                      ),
                      dropdownColor: BentoTheme.surfaceElevated,
                      items: state.accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name,
                              style: TextStyle(
                                  color: BentoTheme.textPrimary, fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedToAccountId = val);
                      },
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                PressScale(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 16, color: BentoTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM').format(_selectedDate),
                          style: TextStyle(
                              color: BentoTheme.textPrimary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Numeric Keypad
          _buildKeypad(),
          const SizedBox(height: 14),

          // Save Button
          PressScale(
            onTap: _handleSave,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BentoTheme.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  widget.editEntry != null ? 'Update Entry' : 'Save Entry',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKindTab(EntryKind kind, String label) {
    final isSelected = _selectedKind == kind;
    return Expanded(
      child: PressScale(
        onTap: () {
          setState(() {
            _selectedKind = kind;
            if (kind == EntryKind.received) {
              _selectedCategory = _receiveCategories.first;
            } else {
              _selectedCategory = _spendCategories.first;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? BentoTheme.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? BentoTheme.textPrimary
                    : BentoTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 8),
        _buildKeypadRow(['.', '0', 'backspace']),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PressScale(
              onTap: () => _onKeypadTap(key),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: key == 'backspace'
                      ? Icon(LucideIcons.delete,
                          color: BentoTheme.textPrimary, size: 20)
                      : Text(
                          key,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
