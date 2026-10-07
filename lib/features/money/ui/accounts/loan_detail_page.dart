import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../../core/account_group.dart';
import '../../core/ledger.dart';
import '../../core/minor.dart';
import '../../core/snapshot.dart';
import '../../state/money_state.dart';
import '../widgets/money_category_icon.dart';
import '../widgets/quick_add_sheet.dart';

/// Detailed view for a Loan account fulfilling Law L5:
/// Displays Principal Paid, Interest Paid, Outstanding balance, and repayment history.
class LoanDetailPage extends StatelessWidget {
  final String accountId;

  const LoanDetailPage({
    super.key,
    required this.accountId,
  });

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
        title: Text('Loan Overview',
            style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<MoneySnapshot>(
        valueListenable: MoneyState(),
        builder: (context, snapshot, _) {
          final account = MoneyState().accounts.firstWhere(
                (a) => a.id == accountId,
                orElse: () => CoreAccount(
                  id: accountId,
                  name: 'Loan Account',
                  group: AccountGroup.loans,
                  rawKind: 'loan',
                  openingBalanceMinor: 0,
                  openingDate: DateTime(2020),
                ),
              );

          final loan = snapshot.loans.firstWhere(
            (l) => l.accountId == accountId,
            orElse: () => LoanSummary(
              accountId: accountId,
              outstandingMinor: 0,
              totalPrincipalPaidMinor: 0,
              totalInterestPaidMinor: 0,
              annualRatePct: 0.0,
            ),
          );

          final repayments = snapshot.recentEntries
              .where((e) =>
                  e.toAccountId == accountId || e.fromAccountId == accountId)
              .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Main Loan Card (Law L5)
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
                            'Principal Paid',
                            Minor.format(loan.totalPrincipalPaidMinor),
                            BentoTheme.positive),
                        _buildMetricColumn(
                            'Interest Paid',
                            Minor.format(loan.totalInterestPaidMinor),
                            BentoTheme.negative),
                        _buildMetricColumn(
                            'Outstanding',
                            Minor.format(loan.outstandingMinor),
                            BentoTheme.textPrimary,
                            isLarge: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Repayment History',
                style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (repayments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Text('No repayments recorded for this loan yet',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 13)),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(18)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: repayments.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 50,
                        color: BentoTheme.divider.withValues(alpha: 0.3)),
                    itemBuilder: (ctx, idx) {
                      final e = repayments[idx];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BentoTheme.positive.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            MoneyCategoryIcon.getIcon(e.icon ?? e.category),
                            color: BentoTheme.positive,
                            size: 16,
                          ),
                        ),
                        title: Text(e.title,
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(e.date),
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 11)),
                        trailing: Text(
                          Minor.format(e.amountMinor),
                          style: TextStyle(
                              color: BentoTheme.positive,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        onTap: () => QuickAddSheet.show(context, editEntry: e),
                      );
                    },
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
