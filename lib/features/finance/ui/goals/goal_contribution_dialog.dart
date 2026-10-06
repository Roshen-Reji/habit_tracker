import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class GoalContributionDialog extends StatefulWidget {
  final FinanceController controller;
  final SavingsGoal goal;

  const GoalContributionDialog({
    super.key,
    required this.controller,
    required this.goal,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required SavingsGoal goal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalContributionDialog(
        controller: controller,
        goal: goal,
      ),
    );
  }

  @override
  State<GoalContributionDialog> createState() => _GoalContributionDialogState();
}

class _GoalContributionDialogState extends State<GoalContributionDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isWithdrawal = false;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    final amountVal = double.tryParse(_amountController.text.trim());
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount > 0')),
      );
      return;
    }

    final signedAmount = _isWithdrawal ? -amountVal : amountVal;

    await widget.controller.addGoalContribution(
      goalId: widget.goal.id,
      amount: signedAmount,
      date: _date,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isWithdrawal
                ? 'Withdrew ${FormatUtils.formatMoney(amountVal)} from ${widget.goal.name}'
                : 'Contributed ${FormatUtils.formatMoney(amountVal)} to ${widget.goal.name} (+20 XP!)',
          ),
          backgroundColor: BentoTheme.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              CircleAvatar(
                radius: 12,
                backgroundColor: Color(widget.goal.colorValue),
                child: const Icon(LucideIcons.target,
                    size: 14, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.goal.name,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 18,
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

          // Direction Segmented Button (Deposit vs Withdraw)
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
                    onTap: () => setState(() => _isWithdrawal = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isWithdrawal
                            ? const Color(0xFF10B981).withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.arrowDownLeft,
                            size: 16,
                            color: !_isWithdrawal
                                ? const Color(0xFF10B981)
                                : BentoTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Deposit / Save',
                            style: TextStyle(
                              color: !_isWithdrawal
                                  ? const Color(0xFF10B981)
                                  : BentoTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isWithdrawal = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isWithdrawal
                            ? BentoTheme.negative.withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.arrowUpRight,
                            size: 16,
                            color: _isWithdrawal
                                ? BentoTheme.negative
                                : BentoTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Withdrawal',
                            style: TextStyle(
                              color: _isWithdrawal
                                  ? BentoTheme.negative
                                  : BentoTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Amount field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: BentoTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all( // allowed: input focus
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Text(
                  FormatUtils.getCurrencySymbol(),
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 24,
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
          const SizedBox(height: 12),

          // Date chip & note
          Row(
            children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: BentoTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy').format(_date),
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: BentoTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all( // allowed: input focus
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: TextField(
                    controller: _noteController,
                    style:
                        TextStyle(color: BentoTheme.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Note (optional)',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isWithdrawal ? BentoTheme.negative : BentoTheme.positive,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: ExpressiveTokens.borderM,
                ),
              ),
              child: Text(
                _isWithdrawal
                    ? 'Record Withdrawal'
                    : 'Add Contribution (+20 XP)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
