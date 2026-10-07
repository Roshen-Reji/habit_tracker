import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class UpcomingBillsCard extends StatelessWidget {
  final HomeCardSize size;

  const UpcomingBillsCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('fin_recurring')) {
      return HomeCardFrame(
        icon: LucideIcons.calendarClock,
        title: 'Upcoming Bills',
        child: Text(
          'No bills data available',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
        ),
      );
    }

    final controller = FinanceController();
    final dueItems = controller.getUnpostedDueItems();
    final totalDue = dueItems.fold(0.0, (sum, i) => sum + i.rule.amount);
    final count = size == HomeCardSize.large ? 5 : 2;

    return HomeCardFrame(
      icon: LucideIcons.calendarClock,
      title: 'Upcoming Bills',
      onTap: () {
        AppNav.openBills(context);
      },
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BentoTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${dueItems.length} due',
          style: TextStyle(
            color: BentoTheme.accent,
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
              Text(
                'Total Due',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
              ),
              Text(
                FormatUtils.formatMoney(totalDue, decimals: 0),
                style: TextStyle(
                  color:
                      totalDue > 0 ? BentoTheme.negative : BentoTheme.positive,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dueItems.isEmpty)
            Text(
              'No upcoming bills due right now. You are all caught up!',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
            )
          else
            ...dueItems.take(count).map((item) {
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.rule.name} (${DateFormat('d MMM').format(item.dueDate)})',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      FormatUtils.formatMoney(item.rule.amount, decimals: 0),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
