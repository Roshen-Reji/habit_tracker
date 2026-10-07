import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/safe_to_spend_engine.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class SafeToSpendCard extends StatelessWidget {
  final HomeCardSize size;

  const SafeToSpendCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    final controller = FinanceController();
    final safeToSpend = controller.getSafeToSpend();
    final explanation = controller.getSafeToSpendExplanation();

    final isShortfall = safeToSpend.hasShortfall;
    final displayAmount = isShortfall
        ? 'Deficit ${FormatUtils.formatMoney(safeToSpend.shortfall, decimals: 0)}'
        : FormatUtils.formatMoney(safeToSpend.safeToSpend, decimals: 0);
    final perDayAmount = isShortfall
        ? 'DEFICIT'
        : '${FormatUtils.formatMoney(safeToSpend.perDay, decimals: 0)}/day';

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
          perDayAmount,
          style: TextStyle(
            color: isShortfall ? AppColors.error : BentoTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: _buildBody(
        context: context,
        safeToSpend: safeToSpend,
        explanation: explanation,
        displayAmount: displayAmount,
        perDayAmount: perDayAmount,
        isShortfall: isShortfall,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required SafeToSpendResult safeToSpend,
    required SafeToSpendExplanation explanation,
    required String displayAmount,
    required String perDayAmount,
    required bool isShortfall,
  }) {
    switch (size) {
      case HomeCardSize.compact:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isShortfall
                  ? displayAmount
                  : FormatUtils.formatMoney(safeToSpend.perDay, decimals: 0),
              style: TextStyle(
                color: isShortfall ? AppColors.error : BentoTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isShortfall
                  ? 'Committed obligations exceed liquid reserves'
                  : 'per day available for the next ${safeToSpend.daysLeft} days',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        );
      case HomeCardSize.large:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayAmount,
                      style: TextStyle(
                        color: isShortfall
                            ? AppColors.error
                            : BentoTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${safeToSpend.daysLeft} days remaining in month',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  perDayAmount,
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDeductionsList(explanation),
          ],
        );
      case HomeCardSize.hero:
        final double liquid = explanation.liquid;
        final double ratio = liquid > 0
            ? (safeToSpend.safeToSpend / liquid).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isShortfall
                  ? displayAmount
                  : FormatUtils.formatMoney(safeToSpend.perDay, decimals: 0),
              style: TextStyle(
                color: isShortfall ? AppColors.error : BentoTheme.textPrimary,
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              isShortfall
                  ? 'Deficit for committed month-end obligations'
                  : 'Daily spend pace · ${FormatUtils.formatMoney(safeToSpend.safeToSpend, decimals: 0)} total',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ProgressBarX(
              value: ratio,
              height: 8,
              semantic: isShortfall
                  ? ProgressSemantic.over
                  : ProgressSemantic.neutral,
            ),
            const SizedBox(height: 12),
            _buildDeductionsList(explanation),
          ],
        );
    }
  }

  Widget _buildDeductionsList(SafeToSpendExplanation exp) {
    final items = <Map<String, dynamic>>[];
    if (exp.obligations > 0) {
      items.add({
        'label': 'Bills & Subscriptions',
        'amount': exp.obligations,
        'icon': LucideIcons.calendarClock,
      });
    }
    if (exp.goalsEarmark > 0) {
      items.add({
        'label': 'Earmarked Goals',
        'amount': exp.goalsEarmark,
        'icon': LucideIcons.target,
      });
    }
    if (exp.plannedEssential > 0) {
      items.add({
        'label': 'Essential Budget',
        'amount': exp.plannedEssential,
        'icon': LucideIcons.pieChart,
      });
    }
    if (exp.cardDues > 0) {
      items.add({
        'label': 'Card Dues',
        'amount': exp.cardDues,
        'icon': LucideIcons.creditCard,
      });
    }

    if (items.isEmpty) {
      return Text(
        'No major deductions committed for this period.',
        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
      );
    }

    return Column(
      children: items.take(4).map((i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: [
              Icon(i['icon'] as IconData,
                  size: 13, color: BentoTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  i['label'] as String,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                FormatUtils.formatMoney(i['amount'] as double, decimals: 0),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
