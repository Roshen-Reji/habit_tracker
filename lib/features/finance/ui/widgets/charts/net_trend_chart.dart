import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';

class NetTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const NetTrendChart({super.key, required this.data});

  double _asDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '0') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No net trend data available',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    final spots = data.asMap().entries.map((entry) {
      final income = _asDouble(entry.value['income']);
      final expense = _asDouble(entry.value['expense']);
      return FlSpot(entry.key.toDouble(), income - expense);
    }).toList();

    final minValue =
        spots.fold<double>(0, (min, spot) => spot.y < min ? spot.y : min);
    final maxValue =
        spots.fold<double>(0, (max, spot) => spot.y > max ? spot.y : max);
    final padding = ((maxValue - minValue).abs() * 0.18).clamp(100.0, 100000.0);

    return LineChart(
      LineChartData(
        minY: minValue - padding,
        maxY: maxValue + padding,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => BentoTheme.background,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  FormatUtils.formatCurrency(spot.y),
                  TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: value == 0
                ? BentoTheme.accent.withValues(alpha: 0.26)
                : BentoTheme.textSecondary.withValues(alpha: 0.08),
            strokeWidth: value == 0 ? 1.4 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[index]['month'].toString(),
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            color: BentoTheme.accent,
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final color = spot.y >= 0
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444);
                return FlDotCirclePainter(
                  radius: 3.2,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: BentoTheme.background,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BentoTheme.accent.withValues(alpha: 0.20),
                  BentoTheme.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}
