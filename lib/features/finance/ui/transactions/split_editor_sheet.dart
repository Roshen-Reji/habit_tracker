import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/models/category.dart';

class SplitLineItem {
  String? categoryId;
  double amount;
  String note;
  bool isOwed;
  String counterparty;

  SplitLineItem({
    this.categoryId,
    this.amount = 0.0,
    this.note = '',
    this.isOwed = false,
    this.counterparty = '',
  });

  Map<String, dynamic> toJson() => {
        if (categoryId != null) 'categoryId': categoryId,
        'amount': amount,
        if (note.isNotEmpty) 'note': note,
        'isOwed': isOwed,
        if (isOwed && counterparty.isNotEmpty) 'counterparty': counterparty,
      };

  factory SplitLineItem.fromJson(Map<String, dynamic> json) => SplitLineItem(
        categoryId: json['categoryId']?.toString(),
        amount: (json['amount'] is num)
            ? (json['amount'] as num).toDouble()
            : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
        note: json['note']?.toString() ?? '',
        isOwed: json['isOwed'] == true,
        counterparty: json['counterparty']?.toString() ?? '',
      );
}

class SplitEditorSheet extends StatefulWidget {
  final double totalAmount;
  final String? initialSplitsJson;
  final List<Category> categories;

  const SplitEditorSheet({
    super.key,
    required this.totalAmount,
    this.initialSplitsJson,
    required this.categories,
  });

  @override
  State<SplitEditorSheet> createState() => _SplitEditorSheetState();
}

class _SplitEditorSheetState extends State<SplitEditorSheet> {
  final List<SplitLineItem> _lines = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSplitsJson != null &&
        widget.initialSplitsJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.initialSplitsJson!);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _lines
                  .add(SplitLineItem.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (_) {}
    }

    if (_lines.isEmpty) {
      // Default to 2 lines dividing the amount
      final half = (widget.totalAmount / 2).clamp(0.0, double.infinity);
      _lines.add(SplitLineItem(
        categoryId:
            widget.categories.isNotEmpty ? widget.categories.first.id : null,
        amount: half,
      ));
      _lines.add(SplitLineItem(
        amount: widget.totalAmount - half,
      ));
    }
  }

  double get _allocatedSum =>
      _lines.fold(0.0, (sum, line) => sum + line.amount);

  double get _remaining => widget.totalAmount - _allocatedSum;

  bool get _isValid => (_remaining.abs() < 0.01) && _lines.isNotEmpty;

  void _addLine() {
    setState(() {
      final rem = _remaining > 0 ? _remaining : 0.0;
      _lines.add(SplitLineItem(
        categoryId:
            widget.categories.isNotEmpty ? widget.categories.first.id : null,
        amount: rem,
      ));
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines.removeAt(index);
    });
  }

  void _save() {
    if (!_isValid) return;
    final jsonString = jsonEncode(_lines.map((l) => l.toJson()).toList());
    Navigator.of(context).pop(jsonString);
  }

  @override
  Widget build(BuildContext context) {
    final isBalanced = _remaining.abs() < 0.01;
    final isOver = _remaining < -0.01;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Split Transaction',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Total & Balance Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isBalanced
                  ? BentoTheme.positive.withValues(alpha: 0.12)
                  : isOver
                      ? BentoTheme.negative.withValues(alpha: 0.12)
                      : BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderM,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL AMOUNT',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatCurrency(widget.totalAmount),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isBalanced
                          ? 'BALANCED'
                          : isOver
                              ? 'OVER-ALLOCATED'
                              : 'REMAINING',
                      style: TextStyle(
                        color: isBalanced
                            ? const Color(0xFF22C55E)
                            : isOver
                                ? const Color(0xFFEF4444)
                                : BentoTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBalanced
                          ? 'Ready to save'
                          : FormatUtils.formatCurrency(_remaining.abs()),
                      style: TextStyle(
                        color: isBalanced
                            ? const Color(0xFF22C55E)
                            : isOver
                                ? const Color(0xFFEF4444)
                                : BentoTheme.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Split Lines
          Expanded(
            child: ListView.separated(
              itemCount: _lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final line = _lines[index];
                return _buildSplitCard(line, index);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Actions: Add line & Save
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addLine,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Split'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BentoTheme.accent,
                  side: BorderSide(
                      color: BentoTheme.accent.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isValid ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: BentoTheme.surface,
                    disabledForegroundColor: BentoTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Splits',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCard(SplitLineItem line, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BentoTheme.cardBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Split #${index + 1}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Owed toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        line.isOwed = !line.isOwed;
                        if (line.isOwed) line.categoryId = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: line.isOwed
                            ? BentoTheme.warning.withValues(alpha: 0.2)
                            : BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            line.isOwed
                                ? LucideIcons.userCheck
                                : LucideIcons.user,
                            size: 13,
                            color: line.isOwed
                                ? const Color(0xFFF59E0B)
                                : BentoTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            line.isOwed ? 'Friend Owes' : 'My Expense',
                            style: TextStyle(
                              color: line.isOwed
                                  ? const Color(0xFFF59E0B)
                                  : BentoTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_lines.length > 1)
                IconButton(
                  icon: const Icon(LucideIcons.trash2,
                      size: 16, color: Colors.redAccent),
                  onPressed: () => _removeLine(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Amount & Target Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount field
              Expanded(
                flex: 4,
                child: TextFormField(
                  initialValue:
                      line.amount > 0 ? line.amount.toStringAsFixed(2) : '',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                    prefixText: '${FormatUtils.getCurrencySymbol()} ',
                    prefixStyle: TextStyle(
                      color: BentoTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: BentoTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val) ?? 0.0;
                    setState(() {
                      line.amount = parsed;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Category dropdown or Counterparty textfield
              Expanded(
                flex: 6,
                child: line.isOwed
                    ? TextFormField(
                        initialValue: line.counterparty,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Friend Name',
                          hintText: 'e.g. Rahul',
                          hintStyle: TextStyle(
                            color:
                                BentoTheme.textSecondary.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          labelStyle: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 12,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: BentoTheme.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          line.counterparty = val.trim();
                        },
                      )
                    : DropdownButtonFormField<String>(
                        value: line.categoryId ??
                            (widget.categories.isNotEmpty
                                ? widget.categories.first.id
                                : null),
                        dropdownColor: BentoTheme.surface,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 12,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: BentoTheme.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: widget.categories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            line.categoryId = val;
                          });
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Note
          TextFormField(
            initialValue: line.note,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              hintStyle: TextStyle(
                color: BentoTheme.textSecondary.withValues(alpha: 0.5),
                fontSize: 12,
              ),
              isDense: true,
              filled: true,
              fillColor: BentoTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              line.note = val.trim();
            },
          ),
        ],
      ),
    );
  }
}
