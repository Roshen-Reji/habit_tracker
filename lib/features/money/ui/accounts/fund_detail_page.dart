import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../../core/account_group.dart';
import '../../core/ledger.dart';
import '../../core/minor.dart';
import '../../core/snapshot.dart';
import '../../data/money_service.dart';
import '../../state/money_state.dart';
import '../motion/press_scale.dart';
import '../widgets/money_category_icon.dart';
import '../widgets/quick_add_sheet.dart';

/// Detailed view for a Fund account fulfilling Law L4:
/// Displays Invested, Value, Gain, Update Value action, and transaction history.
class FundDetailPage extends StatefulWidget {
  final String accountId;

  const FundDetailPage({
    super.key,
    required this.accountId,
  });

  @override
  State<FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends State<FundDetailPage> {
  Future<void> _showUpdateValueDialog(
      BuildContext context, int currentValueMinor) async {
    final ctrl = TextEditingController(
      text: currentValueMinor > 0
          ? (currentValueMinor / 100.0).toStringAsFixed(0)
          : '',
    );

    final updated = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.trendingUp, color: BentoTheme.positive, size: 20),
            const SizedBox(width: 8),
            Text('Update Fund Value',
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter current market valuation:',
                style:
                    TextStyle(color: BentoTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                    color: BentoTheme.textPrimary, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: BentoTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BentoTheme.accent,
                foregroundColor: Colors.white),
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim()) ?? 0.0;
              final minor = Minor.toMinor(parsed);
              if (minor > 0) {
                Navigator.of(ctx).pop(minor);
              }
            },
            child: const Text('Save Value'),
          ),
        ],
      ),
    );

    if (updated != null && mounted) {
      HapticFeedback.lightImpact();
      await MoneyService().updateValuation(
        accountId: widget.accountId,
        valueMinor: updated,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Fund value updated to ${Minor.format(updated)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Fund Overview',
            style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<MoneySnapshot>(
        valueListenable: MoneyState(),
        builder: (context, snapshot, _) {
          final account = MoneyState().accounts.firstWhere(
                (a) => a.id == widget.accountId,
                orElse: () => CoreAccount(
                  id: widget.accountId,
                  name: 'Investment Fund',
                  group: AccountGroup.funds,
                  rawKind: 'mutual_fund',
                  openingBalanceMinor: 0,
                  openingDate: DateTime(2020),
                ),
              );

          final fund = snapshot.funds.firstWhere(
            (f) => f.accountId == widget.accountId,
            orElse: () => FundSummary(
              accountId: widget.accountId,
              investedMinor: 0,
              valueMinor: 0,
              gainMinor: 0,
              hasValuationUpdate: false,
            ),
          );

          final deposits = snapshot.recentEntries
              .where((e) =>
                  e.toAccountId == widget.accountId ||
                  e.fromAccountId == widget.accountId)
              .toList();

          final isPositive = fund.gainMinor >= 0;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Main Fund Card (Law L4)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricColumn(
                            'Invested',
                            Minor.format(fund.investedMinor),
                            BentoTheme.textSecondary),
                        _buildMetricColumn(
                            'Current Value',
                            Minor.format(fund.valueMinor),
                            BentoTheme.textPrimary,
                            isLarge: true),
                        _buildMetricColumn(
                          'Gain',
                          '${isPositive ? '+' : ''}${Minor.format(fund.gainMinor)}',
                          isPositive
                              ? BentoTheme.positive
                              : BentoTheme.negative,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Update Value Action Button
                    PressScale(
                      onTap: () =>
                          _showUpdateValueDialog(context, fund.valueMinor),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: BentoTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.edit3,
                                size: 16, color: BentoTheme.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Update Market Value',
                              style: TextStyle(
                                  color: BentoTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Activity History',
                style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (deposits.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Text('No transactions for this fund yet',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 13)),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    children: [
                      for (int idx = 0; idx < deposits.length; idx++) ...[
                        if (idx > 0)
                          Divider(
                              height: 1,
                              indent: 50,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                        Builder(builder: (ctx) {
                          final e = deposits[idx];
                          final isDeposit = e.toAccountId == widget.accountId;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDeposit
                                        ? BentoTheme.positive
                                        : BentoTheme.negative)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                MoneyCategoryIcon.getIcon(e.icon ?? e.category),
                                color: isDeposit
                                    ? BentoTheme.positive
                                    : BentoTheme.negative,
                                size: 16,
                              ),
                            ),
                            title: Text(e.title,
                                style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            subtitle: Text(
                                DateFormat('dd MMM yyyy').format(e.date),
                                style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 11)),
                            trailing: Text(
                              '${isDeposit ? '+' : '-'}${Minor.format(e.amountMinor)}',
                              style: TextStyle(
                                color: isDeposit
                                    ? BentoTheme.positive
                                    : BentoTheme.negative,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () =>
                                QuickAddSheet.show(context, editEntry: e),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color,
      {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
