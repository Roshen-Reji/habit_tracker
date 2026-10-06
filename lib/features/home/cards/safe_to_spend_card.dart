import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class SafeToSpendCard extends StatelessWidget {
  const SafeToSpendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FinanceController();
    final safeToSpend = controller.getSafeToSpend();

    final isShortfall = safeToSpend.hasShortfall;
    final displayAmount = isShortfall
        ? 'Deficit ${FormatUtils.formatMoney(safeToSpend.shortfall, decimals: 0)}'
        : FormatUtils.formatMoney(safeToSpend.safeToSpend, decimals: 0);

    return HomeCardFrame(
      icon: isShortfall ? LucideIcons.alertTriangle : LucideIcons.shieldCheck,
      title: 'Safe to Spend',
      onTap: () {
        AppNav.openMoney(context, deepLink: 'overview');
      },
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isShortfall ? AppColors.error : BentoTheme.accent)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isShortfall
              ? 'DEFICIT'
              : '${FormatUtils.formatMoney(safeToSpend.perDay, decimals: 0)}/day',
          style: TextStyle(
            color: isShortfall ? AppColors.error : BentoTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayAmount,
            style: TextStyle(
              color: isShortfall ? AppColors.error : BentoTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isShortfall
                ? 'Committed obligations exceed liquid reserves'
                : 'Available for discretionary spend for the next ${safeToSpend.daysLeft} days',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
