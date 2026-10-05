import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';

class MarkPaidDialog extends StatefulWidget {
  final FinanceController controller;
  final DueItem item;

  const MarkPaidDialog({
    super.key,
    required this.controller,
    required this.item,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required DueItem item,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MarkPaidDialog(controller: controller, item: item),
    );
  }

  @override
  State<MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<MarkPaidDialog> {
  late TextEditingController _amountController;
  late DateTime _paidDate;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.item.estimatedAmount.truncateToDouble() == widget.item.estimatedAmount
          ? widget.item.estimatedAmount.toInt().toString()
          : widget.item.estimatedAmount.toStringAsFixed(2),
    );
    _paidDate = widget.item.dueDate;
    _selectedAccountId = widget.item.rule.accountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) return;

    await widget.controller.markRecurringPaid(
      widget.item,
      paidDate: _paidDate,
      accountId: _selectedAccountId,
      amount: amt,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.item.rule.name} marked as paid!'),
          backgroundColor: BentoTheme.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.activeAccounts;

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
              Icon(LucideIcons.checkCircle, color: const Color(0xFF10B981), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirm Payment: ${widget.item.rule.name}',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Input
          Text(
            'AMOUNT PAID',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: BentoTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Text(
                  FormatUtils.getCurrencySymbol(),
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Dropdown
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            dropdownColor: BentoTheme.surface,
            style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Paid From Account',
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
                return DropdownMenuItem(
                  value: acc.id,
                  child: Text('${acc.name} (${acc.kind})'),
                );
              }),
            ],
            onChanged: (val) => setState(() => _selectedAccountId = val),
          ),
          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: ExpressiveTokens.borderM,
                ),
              ),
              child: const Text(
                'Mark as Paid',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
