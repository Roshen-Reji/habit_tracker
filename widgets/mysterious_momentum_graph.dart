import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/goals.dart';
import 'package:intl/intl.dart';

class MysteriousMomentumGraph extends StatelessWidget {
  const MysteriousMomentumGraph({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Goal>('mission_box_v3').listenable(),
      builder: (context, Box<Goal> box, _) {
        final List<Goal> allGoals = box.values.toList();
        final spots = _calculateCalendarMomentum(allGoals);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF120024).withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "M O M E N T U M   S I G N A L",
                style: TextStyle(
                  color: Colors.tealAccent,
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
        );
      },
    );
  }

  List<FlSpot> _calculateCalendarMomentum(List<Goal> goals) {
    if (goals.isEmpty) return List.generate(7, (index) => FlSpot(index.toDouble(), 0));

    List<FlSpot> spots = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      double dayScore = 0;
      double totalWeight = 0;

      for (var goal in goals) {
        // Engineering Note: Applying priority weights
        // Monthly = 5.0, Weekly = 3.0, Daily = 1.0
        double weight = goal.type == GoalType.monthly 
            ? 5.0 
            : (goal.type == GoalType.weekly ? 3.0 : 1.0);
        
        totalWeight += weight;

        if (i == 6) {
          // Current real-time progress
          dayScore += (goal.progress * weight);
        } else {
          // Historical estimation based on streakCount
          if (goal.streakCount > (6 - i)) {
            dayScore += weight;
          }
        }
      }

      double percentage = totalWeight > 0 ? (dayScore / totalWeight) * 100 : 0;
      spots.add(FlSpot(i.toDouble(), percentage.clamp(0, 100)));
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
          color: Colors.white.withOpacity(0.05),
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
                axisSide: meta.axisSide,
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
          gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.tealAccent]),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: index == 6 ? 4 : 0, // Only show dot for current day
              color: Colors.tealAccent,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [Colors.tealAccent.withOpacity(0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}