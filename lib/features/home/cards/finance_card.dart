import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/ui/overview/safe_to_spend_breakdown_sheet.dart';

class FinanceCard extends StatelessWidget {
  const FinanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FinanceController();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final now = DateTime.now();
        final report = controller.getMonthlySummaryReport(now);

        // P1-2: Primary figure is Money left (sum of spendable accounts as of now)
        final moneyLeft = controller.getLiquidBalance();

        final isPositiveNet = report.net >= 0;
        final netFormatted = FormatUtils.signed(report.net, decimals: 0);

        // Safe to Spend as secondary info
        final safeToSpend = controller.getSafeToSpend();
        final isShortfall = safeToSpend.hasShortfall;
        final safeToSpendDisplay = isShortfall
            ? 'Short by ${FormatUtils.formatMoney(safeToSpend.shortfall, decimals: 0)}'
            : FormatUtils.formatMoney(safeToSpend.safeToSpend, decimals: 0);

        // Next SIP/Bill debit lookup
        final dueItems = controller.getUnpostedDueItems();
        String? nextSipInfo;

        if (dueItems.isNotEmpty) {
          final sortedItems = List.of(dueItems)
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          final earliest = sortedItems.first;

          final dateStr = DateFormat('MMM d').format(earliest.dueDate);
          final amtStr =
              ' (${FormatUtils.formatMoney(earliest.rule.amount, decimals: 0)})';
          nextSipInfo = '${earliest.rule.name} · $dateStr$amtStr';
        }

        return HomeCardFrame(
          icon: LucideIcons.wallet,
          title: 'Finance Summary',
          onTap: () {
            AppNav.openMoney(context);
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isPositiveNet ? Colors.green : Colors.redAccent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              netFormatted,
              style: TextStyle(
                color: isPositiveNet ? Colors.greenAccent : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      final exp = controller.getSafeToSpendExplanation();
                      SafeToSpendBreakdownSheet.show(context, exp);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONEY LEFT',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatMoney(moneyLeft, decimals: 0),
                          style: TextStyle(
                            color: moneyLeft < 0
                                ? const Color(0xFFE07A7A)
                                : BentoTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'THIS MONTH',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${FormatUtils.formatMoney(report.income, decimals: 0)} in / ${FormatUtils.formatMoney(report.spending, decimals: 0)} out',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // P1-3: Safe to Spend secondary line
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isShortfall
                          ? LucideIcons.alertTriangle
                          : LucideIcons.shieldCheck,
                      size: 13,
                      color: isShortfall
                          ? Colors.red.withValues(alpha: 0.8)
                          : BentoTheme.accent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Safe to Spend: ',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        safeToSpendDisplay,
                        style: TextStyle(
                          color:
                              isShortfall ? Colors.red : BentoTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isShortfall)
                      Text(
                        '${FormatUtils.formatMoney(safeToSpend.perDay, decimals: 0)}/day',
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Next SIP line
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.calendarClock,
                      size: 13,
                      color: BentoTheme.accent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Next SIP: ',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        nextSipInfo ?? 'No active SIPs scheduled',
                        style: TextStyle(
                          color: nextSipInfo != null
                              ? BentoTheme.textPrimary
                              : BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      LucideIcons.arrowRight,
                      size: 13,
                      color: BentoTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
