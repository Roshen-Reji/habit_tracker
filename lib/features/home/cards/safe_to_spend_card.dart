import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/money/core/free_to_spend.dart';
import 'package:habit_tracker/features/money/core/snapshot.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
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
    return ValueListenableBuilder<MoneySnapshot>(
      valueListenable: MoneyState(),
      builder: (context, snapshot, _) {
        final fts = snapshot.freeToSpend;
        final isShortfall = fts.isShort;
        final now = snapshot.asOf;
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = (daysInMonth - now.day).clamp(1, 31);
        final freeToSpendRupees = fts.freeToSpendRupees;
        final perDay = isShortfall ? 0.0 : (freeToSpendRupees / daysLeft);

        final displayAmount = isShortfall
            ? 'Short by ${FormatUtils.formatMoney(fts.shortByRupees, decimals: 0)}'
            : FormatUtils.formatMoney(freeToSpendRupees, decimals: 0);

        final perDayAmount = isShortfall
            ? 'DEFICIT'
            : '${FormatUtils.formatMoney(perDay, decimals: 0)}/day';

        return HomeCardFrame(
          icon:
              isShortfall ? LucideIcons.alertTriangle : LucideIcons.shieldCheck,
          title: 'Safe to Spend',
          onTap: () {
            AppNav.openMoney(context, deepLink: 'today');
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
            fts: fts,
            daysLeft: daysLeft,
            perDay: perDay,
            displayAmount: displayAmount,
            perDayAmount: perDayAmount,
            isShortfall: isShortfall,
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required FreeToSpendResult fts,
    required int daysLeft,
    required double perDay,
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
                  : FormatUtils.formatMoney(perDay, decimals: 0),
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
                  : 'per day available for the next $daysLeft days',
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
                      '$daysLeft days remaining in month',
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
            _buildDeductionsList(fts),
          ],
        );
      case HomeCardSize.hero:
        final double liquid = fts.availableRupees;
        final double ratio =
            liquid > 0 ? (fts.freeToSpendRupees / liquid).clamp(0.0, 1.0) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isShortfall
                  ? displayAmount
                  : FormatUtils.formatMoney(perDay, decimals: 0),
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
                  : 'Daily spend pace · ${FormatUtils.formatMoney(fts.freeToSpendRupees, decimals: 0)} total',
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
            _buildDeductionsList(fts),
          ],
        );
    }
  }

  Widget _buildDeductionsList(FreeToSpendResult fts) {
    final items = fts.upcomingPlansThisMonth;

    if (items.isEmpty) {
      return Text(
        'No major deductions committed for this period.',
        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
      );
    }

    return Column(
      children: items.take(4).map((occ) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: [
              Icon(LucideIcons.calendarClock,
                  size: 13, color: BentoTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${occ.plan.title} (${DateFormat('d MMM').format(occ.dueDate)})',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                FormatUtils.formatMoney(occ.amountRupees, decimals: 0),
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
