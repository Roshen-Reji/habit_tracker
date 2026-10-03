import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// --- Calorie Ring Chart ---
class CalorieRingChart extends StatelessWidget {
  final double intake;
  final double target;
  final double burned;
  final double size;

  const CalorieRingChart({
    super.key,
    required this.intake,
    required this.target,
    this.burned = 0,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final net = intake - burned;
    final progress = target > 0 ? (net / target).clamp(0.0, 1.5) : 0.0;
    final isOver = net > target;
    final accent = BentoTheme.accent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isOver ? Colors.redAccent : accent)
                      .withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          // Background ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                BentoTheme.background.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Progress ring
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOver ? Colors.redAccent : accent,
                  ),
                );
              },
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                net.toStringAsFixed(0),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "of ${target.toStringAsFixed(0)} kcal",
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: size * 0.065,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOver ? Colors.redAccent : Colors.greenAccent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOver
                      ? "+${(net - target).toStringAsFixed(0)} over"
                      : "${(target - net).toStringAsFixed(0)} left",
                  style: TextStyle(
                    color: isOver ? Colors.redAccent : Colors.greenAccent,
                    fontSize: size * 0.055,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Macro Breakdown Bar ---
class MacroBreakdownBar extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const MacroBreakdownBar({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const Color proteinColor = Color(0xFF448AFF);
  static const Color carbsColor = Color(0xFFFFD740);
  static const Color fatColor = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;
    if (total == 0) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMacroRing("Protein", protein, total, proteinColor),
        _buildMacroRing("Carbs", carbs, total, carbsColor),
        _buildMacroRing("Fat", fat, total, fatColor),
      ],
    );
  }

  Widget _buildMacroRing(
      String label, double amount, double total, Color color) {
    double progress = (amount / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 6,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white10),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
        Text(
          "${amount.toStringAsFixed(0)}g",
          style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

// --- Weekly Calorie Chart ---
class WeeklyCalorieChart extends StatelessWidget {
  final List<DietDayLog> logs; // 7 days

  const WeeklyCalorieChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    final target = logs.isNotEmpty ? logs.first.targetCalories : 2000;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (logs.map((l) => l.totalCalories).fold(0.0, math.max) * 1.3)
              .clamp(target * 1.2, double.infinity),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (touchedGroup) => BentoTheme.background,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toStringAsFixed(0)} kcal',
                  TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: target / 2,
            getDrawingHorizontalLine: (value) {
              if (value == target) {
                return FlLine(
                    color: accent.withValues(alpha: 0.5),
                    strokeWidth: 1.5,
                    dashArray: [8, 4]);
              }
              return FlLine(
                  color: BentoTheme.background.withValues(alpha: 0.3),
                  strokeWidth: 0.5);
            },
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < logs.length) {
                    final date = DateTime.tryParse(logs[index].dateKey);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        date != null
                            ? DateFormat('E').format(date).substring(0, 2)
                            : '',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: logs.asMap().entries.map((entry) {
            final index = entry.key;
            final log = entry.value;
            final cal = log.totalCalories;
            final isOver = cal > target;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: cal,
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isOver
                        ? [
                            Colors.redAccent.withValues(alpha: 0.6),
                            Colors.redAccent
                          ]
                        : [accent.withValues(alpha: 0.4), accent],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// --- Monthly Trend Chart ---
class MonthlyTrendChart extends StatelessWidget {
  final List<DietDayLog> logs; // 30 days

  const MonthlyTrendChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    final target = logs.isNotEmpty ? logs.first.targetCalories : 2000;

    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalCalories);
    }).toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: target / 2,
            getDrawingHorizontalLine: (value) {
              if (value == target) {
                return FlLine(
                    color: accent.withValues(alpha: 0.5),
                    strokeWidth: 1.5,
                    dashArray: [8, 4]);
              }
              return FlLine(
                  color: BentoTheme.background.withValues(alpha: 0.2),
                  strokeWidth: 0.5);
            },
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < logs.length) {
                    final date = DateTime.tryParse(logs[index].dateKey);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        date != null ? DateFormat('d/M').format(date) : '',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: accent,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.3),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => BentoTheme.background,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (spots) {
                return spots.map((s) {
                  return LineTooltipItem(
                    '${s.y.toStringAsFixed(0)} kcal',
                    TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// --- Deficit/Surplus Badge ---
class DeficitBadge extends StatelessWidget {
  final double deficit; // positive = deficit, negative = surplus

  const DeficitBadge({super.key, required this.deficit});

  @override
  Widget build(BuildContext context) {
    final isDeficit = deficit > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDeficit ? Colors.greenAccent : Colors.redAccent)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDeficit ? Colors.greenAccent : Colors.redAccent)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDeficit ? LucideIcons.trendingDown : LucideIcons.trendingUp,
            color: isDeficit ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            "${isDeficit ? 'DEFICIT' : 'SURPLUS'} ${deficit.abs().toStringAsFixed(0)} kcal",
            style: TextStyle(
              color: isDeficit ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// --- AI Opinion Card ---
class AiOpinionCard extends StatelessWidget {
  final String opinion;
  final bool isLoading;

  const AiOpinionCard({
    super.key,
    required this.opinion,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.sparkles, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "AI NUTRITIONIST",
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Text(
                  opinion,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Burn Entry Tile ---
class BurnEntryTile extends StatelessWidget {
  final CalorieBurnEntry burn;
  final VoidCallback? onDelete;

  const BurnEntryTile({super.key, required this.burn, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.flame, color: Colors.redAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  burn.activity,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (burn.durationMinutes > 0)
                  Text(
                    "${burn.durationMinutes} min",
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            "-${burn.caloriesBurned.toStringAsFixed(0)} kcal",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(LucideIcons.x,
                  color: BentoTheme.textSecondary, size: 16),
              onPressed: onDelete,
              padding: const EdgeInsets.only(left: 8),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// --- Food Entry Tile ---
class FoodEntryTile extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback? onDelete;

  const FoodEntryTile({super.key, required this.entry, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _mealColor(entry.mealType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_mealIcon(entry.mealType),
                color: _mealColor(entry.mealType), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "P: ${entry.protein.toStringAsFixed(1)}g  C: ${entry.carbs.toStringAsFixed(1)}g  F: ${entry.fat.toStringAsFixed(1)}g",
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${entry.calories.toStringAsFixed(0)} kcal",
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(LucideIcons.x,
                  color: BentoTheme.textSecondary, size: 16),
              onPressed: onDelete,
              padding: const EdgeInsets.only(left: 8),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Color _mealColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return const Color(0xFFFFD740);
      case MealType.lunch:
        return const Color(0xFF69F0AE);
      case MealType.dinner:
        return const Color(0xFF448AFF);
      case MealType.snack:
        return const Color(0xFFE040FB);
    }
  }

  IconData _mealIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return LucideIcons.sun;
      case MealType.lunch:
        return LucideIcons.cloud;
      case MealType.dinner:
        return LucideIcons.moon;
      case MealType.snack:
        return LucideIcons.cookie;
    }
  }
}

// --- Glass Card (reusable) ---
// --- Daily Report Card (Aesthetic) ---
class DailyReportCard extends StatelessWidget {
  final DietDayLog log;

  const DailyReportCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    final date = DateTime.tryParse(log.dateKey) ?? DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(date);

    return BentoContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(LucideIcons.barChart2, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Daily Report — $dateStr",
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Food Items Table
          if (log.entries.isNotEmpty) ...[
            _buildTableHeader(accent),
            const Divider(color: Colors.transparent, height: 1),
            ...log.entries.map((e) => _buildFoodRow(e)),
            const Divider(color: Colors.transparent, height: 1),
            const SizedBox(height: 20),
          ],

          // Summary Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _buildSummaryRow("Total Calories",
                    "${log.totalCalories.toStringAsFixed(0)} kcal", accent),
                _buildSummaryRow(
                    "Total Protein",
                    "${log.totalProtein.toStringAsFixed(1)} g",
                    MacroBreakdownBar.proteinColor),
                _buildSummaryRow(
                    "Total Carbs",
                    "${log.totalCarbs.toStringAsFixed(1)} g",
                    MacroBreakdownBar.carbsColor),
                _buildSummaryRow(
                    "Total Fat",
                    "${log.totalFat.toStringAsFixed(1)} g",
                    MacroBreakdownBar.fatColor),
                const Divider(color: Colors.transparent),
                _buildSummaryRow(
                    "Calories Burned",
                    "${log.totalBurned.toStringAsFixed(0)} kcal",
                    Colors.redAccent),
                _buildSummaryRow(
                  log.isDeficit ? "Caloric Deficit" : "Caloric Surplus",
                  "${log.deficit.abs().toStringAsFixed(0)} kcal",
                  log.isDeficit ? Colors.greenAccent : Colors.redAccent,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text("Food",
                  style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1))),
          Expanded(
              flex: 2,
              child: Text("kcal",
                  style: TextStyle(
                      color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text("P (g)",
                  style: TextStyle(
                      color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text("C (g)",
                  style: TextStyle(
                      color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text("F (g)",
                  style: TextStyle(
                      color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildFoodRow(FoodEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(e.name,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 2,
              child: Text(e.calories.toStringAsFixed(0),
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text(e.protein.toStringAsFixed(1),
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text(e.carbs.toStringAsFixed(1),
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.right)),
          Expanded(
              flex: 2,
              child: Text(e.fat.toStringAsFixed(1),
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- Burn Input Widget ---
class BurnInputWidget extends StatefulWidget {
  final VoidCallback? onBurnAdded;

  const BurnInputWidget({super.key, this.onBurnAdded});

  @override
  State<BurnInputWidget> createState() => _BurnInputWidgetState();
}

class _BurnInputWidgetState extends State<BurnInputWidget> {
  final _activityController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void dispose() {
    _activityController.dispose();
    _caloriesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _addBurn() {
    final activity = _activityController.text.trim();
    final calories = double.tryParse(_caloriesController.text) ?? 0;
    final duration = int.tryParse(_durationController.text) ?? 0;

    if (activity.isNotEmpty && calories > 0) {
      AiService.instance.addManualBurn(activity, calories, duration);
      _activityController.clear();
      _caloriesController.clear();
      _durationController.clear();
      widget.onBurnAdded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "LOG CALORIES BURNED",
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _activityController,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Activity (e.g., Running)",
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: BentoTheme.background)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: BentoTheme.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "kcal",
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: BentoTheme.background)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: BentoTheme.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "min",
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: BentoTheme.background)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: BentoTheme.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addBurn,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.flame,
                      color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
