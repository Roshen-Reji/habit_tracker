import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';

class MysteriousMomentumGraph extends StatelessWidget {
  const MysteriousMomentumGraph({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
      builder: (context, Box<Goal> box, _) {
        final List<Goal> allGoals = box.values.toList();
        final spots = _calculateCalendarMomentum(allGoals);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: NeuContainer(
            borderRadius: 20,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "M O M E N T U M   S I G N A L",
                  style: TextStyle(
                    color: NeuTheme.accent,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                AspectRatio(
                  aspectRatio: 1.70,
                  child: LineChart(mainData(spots)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<FlSpot> _calculateCalendarMomentum(List<Goal> goals) {
    List<int> xpHistory = GlobalXPService.getPast7DaysXP();
    
    // Reverse it so the oldest is at index 0 and today is at index 6
    xpHistory = xpHistory.reversed.toList();
    
    List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), xpHistory[i].toDouble()));
    }
    return spots;
  }

  LineChartData mainData(List<FlSpot> spots) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.white.withValues(alpha: 0.05),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (double value, TitleMeta meta) {
              final int index = value.toInt();
              // Fix: Reference 'index' instead of undefined 'i'
              DateTime date = DateTime.now().subtract(Duration(days: 6 - index));
              String label = index == 6 ? "NOW" : DateFormat('MMM d').format(date).toUpperCase();
              
              // Only show labels for start, middle, and end to keep UI clean
              if (index % 3 != 0 && index != 6) return const SizedBox.shrink();

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 50,
            reservedSize: 42,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}%',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(colors: [NeuTheme.textSecondary, NeuTheme.accent]),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: index == 6 ? 4 : 0, // Only show dot for current day
              color: NeuTheme.accent,
              strokeWidth: 2,
              strokeColor: NeuTheme.background,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [NeuTheme.accent.withValues(alpha: 0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
