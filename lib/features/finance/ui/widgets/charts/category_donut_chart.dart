import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';

class CategoryDonutChart extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const CategoryDonutChart({super.key, required this.items});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;

  static const List<Color> _chartColors = [
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
    Color(0xFF06B6D4),
  ];

  double _asDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '0') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'No category data available',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    final total = widget.items
        .fold<double>(0, (sum, item) => sum + _asDouble(item['value']));
    final selected = _touchedIndex >= 0 && _touchedIndex < widget.items.length
        ? widget.items[_touchedIndex]
        : (widget.items.isNotEmpty ? widget.items.first : null);

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 52,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final section = response?.touchedSection;
                  if (!event.isInterestedForInteractions || section == null) {
                    setState(() => _touchedIndex = -1);
                    return;
                  }
                  setState(() => _touchedIndex = section.touchedSectionIndex);
                },
              ),
              sections: widget.items.asMap().entries.map((entry) {
                final amount = _asDouble(entry.value['value']);
                final isSelected = entry.key == _touchedIndex;
                final percent = total <= 0 ? 0 : amount / total * 100;
                final color = entry.value['color'] is Color
                    ? entry.value['color'] as Color
                    : _chartColors[entry.key % _chartColors.length];

                return PieChartSectionData(
                  value: amount <= 0 ? 0.01 : amount,
                  color: color,
                  radius: isSelected ? 58 : 48,
                  title: percent < 7 ? '' : '${percent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 350),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: selected == null
              ? const SizedBox.shrink()
              : Row(
                  key: ValueKey(selected['name']),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      selected['name'].toString(),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      FormatUtils.formatCurrency(_asDouble(selected['value'])),
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
