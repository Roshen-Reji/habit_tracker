import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/account.dart';

/// Modal dialog allowing the user to reconcile an account with their actual bank balance.
/// Generates an 'adjustment' transaction for the difference.
class AccountReconcileDialog extends StatefulWidget {
  final Account account;
  final FinanceRepository? repository;
  final FinanceController? controller;

  const AccountReconcileDialog({
    super.key,
    required this.account,
    this.repository,
    this.controller,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Account account,
    FinanceRepository? repository,
    FinanceController? controller,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AccountReconcileDialog(
        account: account,
        repository: repository,
        controller: controller,
      ),
    );
  }

  @override
  State<AccountReconcileDialog> createState() => _AccountReconcileDialogState();
}

class _AccountReconcileDialogState extends State<AccountReconcileDialog> {
  late final TextEditingController _realBalanceController;
  late final TextEditingController _notesController;
  late double _currentBalance;

  bool _isSaving = false;
  double? _enteredBalance;

  @override
  void initState() {
    super.initState();
    final ctrl = widget.controller ?? FinanceController();
    _currentBalance = ctrl.getAccountBalance(widget.account);

    _realBalanceController = TextEditingController();
    _notesController = TextEditingController();

    _realBalanceController.addListener(() {
      final val = double.tryParse(_realBalanceController.text.trim());
      setState(() {
        _enteredBalance = val;
      });
    });
  }

  @override
  void dispose() {
    _realBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? get _difference {
    if (_enteredBalance == null) return null;
    return Money.r2(_enteredBalance! - _currentBalance);
  }

  Future<void> _handleReconcile() async {
    if (_enteredBalance == null) return;
    setState(() => _isSaving = true);

    try {
      final repo = widget.repository ?? FinanceRepository();
      await repo.reconcileAccount(
        accountId: widget.account.id,
        realBalance: _enteredBalance!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account reconciled successfully.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reconciliation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = _difference;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: BentoTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Color(widget.account.colorValue).withValues(alpha: 0.2),
                    radius: 20,
                    child: Icon(
                      Icons.tune_rounded,
                      color: Color(widget.account.colorValue),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reconcile Account',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.account.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: BentoTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current ledger balance
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'App Ledger Balance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BentoTheme.textMuted,
                      ),
                    ),
                    Text(
                      FormatUtils.formatMoney(_currentBalance),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Real actual balance input
              TextField(
                controller: _realBalanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Actual Bank/Statement Balance',
                  hintText: 'e.g. 15420.50',
                  prefixText: '${FormatUtils.getCurrencySymbol()} ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Difference feedback
              if (diff != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: (diff == 0)
                        ? Colors.blue.withValues(alpha: 0.1)
                        : (diff > 0)
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (diff == 0)
                            ? Icons.check_circle_outline
                            : (diff > 0)
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                        size: 18,
                        color: (diff == 0)
                            ? Colors.blue
                            : (diff > 0)
                                ? Colors.green
                                : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (diff == 0)
                              ? 'Balances match. No adjustment needed.'
                              : 'Adjustment: ${diff > 0 ? '+' : ''}${FormatUtils.formatMoney(diff)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: (diff == 0)
                                ? Colors.blue
                                : (diff > 0)
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Notes field
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Bank interest credit, monthly fees',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_enteredBalance == null || _isSaving)
                        ? null
                        : _handleReconcile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reconcile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
