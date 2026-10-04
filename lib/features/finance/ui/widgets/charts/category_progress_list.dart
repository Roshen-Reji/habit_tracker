import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';

class CategoryProgressList extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const CategoryProgressList({super.key, required this.items});

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
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No categories to display',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    final total =
        items.fold<double>(0, (sum, item) => sum + _asDouble(item['value']));

    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        final amount = _asDouble(item['value']);
        final progress = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
        final color = item['color'] is Color
            ? item['color'] as Color
            : _chartColors[entry.key % _chartColors.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['name'].toString(),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    FormatUtils.formatCurrency(amount),
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress,
                  color: color,
                  backgroundColor: BentoTheme.textSecondary.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
