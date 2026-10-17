import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import '../../data/balance_check.dart';

/// Modal dialog showing one-time balance migration review (Section 6).
class BalanceReviewDialog extends StatefulWidget {
  final List<AccountDiscrepancy> discrepancies;
  final VoidCallback onCompleted;

  const BalanceReviewDialog({
    super.key,
    required this.discrepancies,
    required this.onCompleted,
  });

  static Future<void> showIfNeeded(
    BuildContext context, {
    VoidCallback? onCompleted,
  }) async {
    final service = BalanceCheckService();
    if (service.isMigrationDone) return;

    final discrepancies =
        service.computeDiscrepancies().where((d) => d.hasDiscrepancy).toList();

    if (discrepancies.isEmpty) {
      await service.applyUseNewBalances();
      onCompleted?.call();
      return;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BalanceReviewDialog(
        discrepancies: discrepancies,
        onCompleted: onCompleted ?? () {},
      ),
    );
  }

  @override
  State<BalanceReviewDialog> createState() => _BalanceReviewDialogState();
}

class _BalanceReviewDialogState extends State<BalanceReviewDialog> {
  final BalanceCheckService _service = BalanceCheckService();
  bool _isProcessing = false;

  Future<void> _handleUseNewBalances() async {
    setState(() => _isProcessing = true);
    try {
      await _service.applyUseNewBalances();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating balances: $e')),
        );
      }
    }
  }

  Future<void> _handleKeepTodayBalances() async {
    setState(() => _isProcessing = true);
    try {
      await _service.applyKeepTodayBalances();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adjusting balances: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BentoTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(LucideIcons.scale,
                        color: BentoTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Balance Verification',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const SizedBox(height: 12),
              Text(
                'Money v2 counts all transactions without ignoring earlier or backdated entries. This changes the calculated balances for the following accounts:',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  itemCount: widget.discrepancies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final d = widget.discrepancies[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BentoTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.account.name,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Previous balance:',
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                FormatUtils.formatMoney(d.oldBalance),
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Corrected balance:',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                FormatUtils.formatMoney(d.newBalance),
                                style: TextStyle(
                                  color: BentoTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (d.ignoredTransactions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${d.ignoredTransactions.length} previously ignored transactions (${d.ignoredTransactions.map((t) => DateFormat('dd MMM').format(t.date)).take(3).join(', ')}...)',
                              style: TextStyle(
                                color: BentoTheme.warning,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BentoTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleUseNewBalances,
                    child: const Text('Use new balances',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BentoTheme.textPrimary,
                      side: BorderSide(color: BentoTheme.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleKeepTodayBalances,
                    child: const Text('Keep today\'s balances'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
