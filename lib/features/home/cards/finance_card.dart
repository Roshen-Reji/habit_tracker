import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/finance_calculator.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/models/finance_model.dart';

class FinanceCard extends StatelessWidget {
  const FinanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('finance_transactions').listenable(),
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: Hive.box('finance_settings').listenable(),
          builder: (context, Box settingsBox, ___) {
            final controller = FinanceController();
            final now = DateTime.now();
            final report = controller.getMonthlySummaryReport(now);
            final totalBalance = controller.getNetWorth();

            final isPositiveNet = report.net >= 0;
            final netFormatted = FormatUtils.signed(report.net, decimals: 0);

            // Next SIP/Bill debit lookup
            final dueItems = controller.getUnpostedDueItems();
            String? nextSipInfo;
            
            if (dueItems.isNotEmpty) {
              // Sort to find the earliest due item
              final sortedItems = List.of(dueItems)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              final earliest = sortedItems.first;
              
              final dateStr = DateFormat('MMM d').format(earliest.dueDate);
              final amtStr = ' (${FormatUtils.formatMoney(earliest.rule.amount, decimals: 0)})';
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
                    color:
                        isPositiveNet ? Colors.greenAccent : Colors.redAccent,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BALANCE',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            FormatUtils.formatMoney(totalBalance, decimals: 0),
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
                  const SizedBox(height: 12),
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
      },
    );
  }
}
