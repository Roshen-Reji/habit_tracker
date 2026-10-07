import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class NetWorthHomeCard extends StatelessWidget {
  final HomeCardSize size;

  const NetWorthHomeCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

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
      child: _buildBody(
        context: context,
        controller: controller,
        now: now,
        netWorth: netWorth,
        change: change,
        isPositive: isPositive,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required FinanceController controller,
    required DateTime now,
    required double netWorth,
    required double change,
    required bool isPositive,
  }) {
    switch (size) {
      case HomeCardSize.compact:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FormatUtils.formatMoney(netWorth),
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
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
        );
      case HomeCardSize.large:
        final history = _getHistory(controller, now);
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
                      FormatUtils.formatMoney(netWorth),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${FormatUtils.formatMoney(change, decimals: 0)} this month',
                      style: TextStyle(
                        color: isPositive
                            ? BentoTheme.positive
                            : BentoTheme.negative,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                _buildSparkline(history),
              ],
            ),
          ],
        );
      case HomeCardSize.hero:
        final history = _getHistory(controller, now);
        final totalAssets = controller.totalAssets;
        final totalLiabilities = controller.totalLiabilities;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FormatUtils.formatMoney(netWorth),
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '${isPositive ? 'Accumulated' : 'Decline of'} ${FormatUtils.formatMoney(change.abs(), decimals: 0)} vs previous month',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: BentoTheme.positive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ASSETS',
                            style: TextStyle(
                                color: BentoTheme.positive,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(FormatUtils.formatMoney(totalAssets, decimals: 0),
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: BentoTheme.negative.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LIABILITIES',
                            style: TextStyle(
                                color: BentoTheme.negative,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                            FormatUtils.formatMoney(totalLiabilities,
                                decimals: 0),
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 70,
              child: _buildSparkline(history, height: 60, width: 220),
            ),
          ],
        );
    }
  }

  List<double> _getHistory(FinanceController controller, DateTime now) {
    final list = <double>[];
    for (var i = 5; i >= 0; i--) {
      final endOfMonth = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);
      list.add(controller.getNetWorth(asOf: endOfMonth));
    }
    return list;
  }

  Widget _buildSparkline(List<double> history,
      {double height = 40, double width = 110}) {
    if (history.isEmpty) return const SizedBox.shrink();
    final minVal = history.reduce((a, b) => a < b ? a : b);
    final maxVal = history.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();

    return SizedBox(
      height: height,
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: history.map((val) {
          final ratio =
              range > 0 ? ((val - minVal) / range).clamp(0.15, 1.0) : 0.5;
          final barHeight = (ratio * (height - 8)).clamp(4.0, height - 8);

          return Container(
            width: width / (history.length * 2),
            height: barHeight,
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList(),
      ),
    );
  }
}
