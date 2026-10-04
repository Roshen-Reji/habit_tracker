import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';

class CashFlowChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const CashFlowChart({super.key, required this.data});

  double _asDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '0') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No cash flow data available',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    final maxIncome = data.fold<double>(
        0, (max, item) => _asDouble(item['income']) > max ? _asDouble(item['income']) : max);
    final maxExpense = data.fold<double>(
        0, (max, item) => _asDouble(item['expense']) > max ? _asDouble(item['expense']) : max);
    final maxY = ((maxIncome > maxExpense ? maxIncome : maxExpense) * 1.25)
        .clamp(100.0, 10000000.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => BentoTheme.background,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isIncome = rodIndex == 0;
              final label = isIncome ? 'Income' : 'Expense';
              final value = FormatUtils.formatCurrency(rod.toY);
              return BarTooltipItem(
                '$label\n$value',
                TextStyle(
                  color: isIncome ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: BentoTheme.textSecondary.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
        barGroups: data.asMap().entries.map((entry) {
          final item = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: _asDouble(item['income']),
                width: 8,
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF22C55E),
              ),
              BarChartRodData(
                toY: _asDouble(item['expense']),
                width: 8,
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFFEF4444),
              ),
            ],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}
