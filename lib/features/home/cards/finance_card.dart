import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/ui/overview/safe_to_spend_breakdown_sheet.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class FinanceCard extends StatelessWidget {
  final HomeCardSize size;

  const FinanceCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('fin_accounts') ||
        !Hive.isBoxOpen('finance_transactions')) {
      return HomeCardFrame(
        icon: LucideIcons.wallet,
        title: 'Finance Summary',
        child: Text(
          'Finance data unavailable',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
      );
    }
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

        // Safe to Spend
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
              color: (isPositiveNet ? BentoTheme.positive : BentoTheme.negative)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              netFormatted,
              style: TextStyle(
                color:
                    isPositiveNet ? BentoTheme.positive : BentoTheme.negative,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child: _buildContent(
            context: context,
            controller: controller,
            now: now,
            moneyLeft: moneyLeft,
            report: report,
            safeToSpend: safeToSpend,
            safeToSpendDisplay: safeToSpendDisplay,
            isShortfall: isShortfall,
            nextSipInfo: nextSipInfo,
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required FinanceController controller,
    required DateTime now,
    required double moneyLeft,
    required dynamic report,
    required dynamic safeToSpend,
    required String safeToSpendDisplay,
    required bool isShortfall,
    required String? nextSipInfo,
  }) {
    switch (size) {
      case HomeCardSize.compact:
        return _buildCompact(
          context: context,
          controller: controller,
          moneyLeft: moneyLeft,
          safeToSpend: safeToSpend,
          safeToSpendDisplay: safeToSpendDisplay,
          isShortfall: isShortfall,
        );
      case HomeCardSize.large:
        return _buildLarge(
          context: context,
          controller: controller,
          moneyLeft: moneyLeft,
          report: report,
          safeToSpend: safeToSpend,
          safeToSpendDisplay: safeToSpendDisplay,
          isShortfall: isShortfall,
          nextSipInfo: nextSipInfo,
        );
      case HomeCardSize.hero:
        return _buildHero(
          context: context,
          controller: controller,
          now: now,
          moneyLeft: moneyLeft,
          report: report,
          nextSipInfo: nextSipInfo,
        );
    }
  }

  Widget _buildCompact({
    required BuildContext context,
    required FinanceController controller,
    required double moneyLeft,
    required dynamic safeToSpend,
    required String safeToSpendDisplay,
    required bool isShortfall,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Column(
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
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                final exp = controller.getSafeToSpendExplanation();
                SafeToSpendBreakdownSheet.show(context, exp);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SAFE TO SPEND',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isShortfall
                        ? safeToSpendDisplay
                        : '${FormatUtils.formatMoney(safeToSpend.perDay, decimals: 0)}/day',
                    style: TextStyle(
                      color: isShortfall
                          ? BentoTheme.negative
                          : BentoTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLarge({
    required BuildContext context,
    required FinanceController controller,
    required double moneyLeft,
    required dynamic report,
    required dynamic safeToSpend,
    required String safeToSpendDisplay,
    required bool isShortfall,
    required String? nextSipInfo,
  }) {
    final double totalFlow = (report.income + report.spending).toDouble();
    final double incomeRatio =
        totalFlow > 0 ? (report.income / totalFlow).clamp(0.0, 1.0) : 0.5;

    return Column(
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
        const SizedBox(height: 12),
        // Income vs Spend progress bar
        ProgressBarX(
          value: incomeRatio,
          height: 6,
          semantic: ProgressSemantic.neutral,
        ),
        const SizedBox(height: 10),
        // Safe to spend line
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    ? BentoTheme.negative
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
                    color: isShortfall
                        ? BentoTheme.negative
                        : BentoTheme.textPrimary,
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
        // Next due line
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                'Next Due: ',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  nextSipInfo ?? 'No upcoming bills or SIPs',
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
    );
  }

  Widget _buildHero({
    required BuildContext context,
    required FinanceController controller,
    required DateTime now,
    required double moneyLeft,
    required dynamic report,
    required String? nextSipInfo,
  }) {
    // 6-month historical trend
    final trendList = <Map<String, dynamic>>[];
    double maxAmount = 1.0;
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final inc = controller.getMonthIncome(m);
      final exp = controller.getMonthSpending(m);
      if (inc > maxAmount) maxAmount = inc;
      if (exp > maxAmount) maxAmount = exp;
      trendList.add({
        'month': DateFormat('MMM').format(m),
        'income': inc,
        'spending': exp,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MONEY LEFT',
          style: AppTokens.label(color: BentoTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          FormatUtils.formatMoney(moneyLeft, decimals: 0),
          style: TextStyle(
            color: moneyLeft < 0
                ? const Color(0xFFE07A7A)
                : BentoTheme.textPrimary,
            fontSize: 44,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '6-MONTH CASHFLOW TREND',
          style: AppTokens.label(color: BentoTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trendList.map((entry) {
              final inc = (entry['income'] as double);
              final exp = (entry['spending'] as double);
              final incHeight = (inc / maxAmount * 56).clamp(4.0, 56.0);
              final expHeight = (exp / maxAmount * 56).clamp(4.0, 56.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 10,
                        height: incHeight,
                        decoration: BoxDecoration(
                          color: BentoTheme.positive.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 10,
                        height: expHeight,
                        decoration: BoxDecoration(
                          color: BentoTheme.negative.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry['month'] as String,
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (nextSipInfo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendarClock,
                  size: 14,
                  color: BentoTheme.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextSipInfo,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
