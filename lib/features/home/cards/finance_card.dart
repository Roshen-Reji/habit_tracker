import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/finance_calculator.dart';
import 'package:habit_tracker/data/services/sip_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/models/finance_model.dart';

class FinanceCard extends StatelessWidget {
  const FinanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable:
          Hive.box<Transaction>('finance_transactions').listenable(),
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: Hive.box('finance_settings').listenable(),
          builder: (context, Box settingsBox, ___) {
            final snapshot = FinanceCalculator.calculate(
              settings: settingsBox,
            );

            final currencyFormat = NumberFormat.currency(
              symbol: '\$',
              decimalDigits: 0,
            );

            final isPositiveNet = snapshot.monthNet >= 0;
            final netFormatted =
                '${isPositiveNet ? '+' : ''}${currencyFormat.format(snapshot.monthNet)}';

            // Next SIP debit lookup
            final planner = Map<String, dynamic>.from(settingsBox.get(
              'planner',
              defaultValue: {'fixedExpenses': [], 'sips': []},
            ));
            final sips = List.from(planner['sips'] ?? []);
            String? nextSipInfo;

            if (sips.isNotEmpty) {
              DateTime? earliestDate;
              String? earliestName;
              double? earliestAmount;

              for (final raw in sips) {
                if (raw is Map) {
                  final sipDate = SipService.getNextDebitDate(raw);
                  if (earliestDate == null || sipDate.isBefore(earliestDate)) {
                    earliestDate = sipDate;
                    earliestName = raw['name']?.toString() ?? 'SIP';
                    earliestAmount = (raw['amount'] is num)
                        ? (raw['amount'] as num).toDouble()
                        : double.tryParse(raw['amount']?.toString() ?? '0');
                  }
                }
              }

              if (earliestDate != null) {
                final dateStr = DateFormat('MMM d').format(earliestDate);
                final amtStr = earliestAmount != null
                    ? ' (${currencyFormat.format(earliestAmount)})'
                    : '';
                nextSipInfo = '$earliestName · $dateStr$amtStr';
              }
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
                            currencyFormat.format(snapshot.totalBalance),
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
                            '${currencyFormat.format(snapshot.monthIncome)} in / ${currencyFormat.format(snapshot.monthExpense)} out',
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
