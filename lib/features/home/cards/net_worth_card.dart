import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class NetWorthHomeCard extends StatelessWidget {
  const NetWorthHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FinanceController();
    final now = DateTime.now();
    final netWorth = controller.getNetWorth();
    final prevMonthEnd = DateTime(now.year, now.month, 0);
    final prevNetWorth = controller.getNetWorth(asOf: prevMonthEnd);
    final change = netWorth - prevNetWorth;
    final isPositive = change >= 0;
    final pct = prevNetWorth > 0 ? (change / prevNetWorth) * 100 : 0.0;

    return HomeCardFrame(
      icon: LucideIcons.lineChart,
      title: 'Net Worth',
      onTap: () {
        AppNav.openNetWorth(context);
      },
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isPositive ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${isPositive ? '+' : ''}${pct.toStringAsFixed(1)}%',
          style: TextStyle(
            color: isPositive ? AppColors.success : AppColors.error,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FormatUtils.formatMoney(netWorth),
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${isPositive ? 'Grew by' : 'Dipped by'} ${FormatUtils.formatMoney(change.abs(), decimals: 0)} vs last month',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
