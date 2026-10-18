import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/money/core/snapshot.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/core/motion/animated_metric_ticker.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class NetWorthHomeCard extends StatelessWidget {
  final HomeCardSize size;

  const NetWorthHomeCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MoneySnapshot>(
      valueListenable: MoneyState(),
      builder: (context, snapshot, _) {
        final now = snapshot.asOf;
        final netWorth = snapshot.netWorthRupees;
        final change = snapshot.monthReceivedRupees - snapshot.monthSpentRupees;
        final isPositive = change >= 0;
        final prevEst = netWorth - change;
        final pct = prevEst > 0 ? (change / prevEst) * 100 : 0.0;

        return HomeCardFrame(
          domain: HomeCardDomain.ledger,
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
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          child: _buildBody(
            context: context,
            snapshot: snapshot,
            now: now,
            netWorth: netWorth,
            change: change,
            isPositive: isPositive,
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required MoneySnapshot snapshot,
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
            AnimatedMetricTicker.currency(
              value: netWorth,
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
        );
      case HomeCardSize.large:
        final history = _getHistory(snapshot, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedMetricTicker.rupees(
                      value: netWorth,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
        final history = _getHistory(snapshot, now);
        final totalAssets = snapshot.balancesByAccountMinor.values
                .where((b) => b > 0)
                .fold(0, (s, b) => s + b) /
            100.0;
        final totalLiabilities = snapshot.balancesByAccountMinor.values
                .where((b) => b < 0)
                .fold(0, (s, b) => s + b.abs()) /
            100.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedMetricTicker.rupees(
              value: netWorth,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
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

  List<double> _getHistory(MoneySnapshot snapshot, DateTime now) {
    final val = snapshot.netWorthRupees;
    final change = snapshot.monthReceivedRupees - snapshot.monthSpentRupees;
    final prev = val - change;
    return [
      prev * 0.96,
      prev * 0.98,
      prev,
      val,
    ];
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
