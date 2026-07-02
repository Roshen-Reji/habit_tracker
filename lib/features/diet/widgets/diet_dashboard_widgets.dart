import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/services/music_manager.dart';

// --- Dynamic Theme Helper ---
class DietTheme {
  static Color get accent {
    // If music is playing, try to use the song's dominant color
    final manager = MusicManager();
    if (manager.currentPlaylist != null &&
        manager.currentIndex != null &&
        manager.audioPlayer.playing) {
      final song = manager.currentPlaylist![manager.currentIndex!];
      return song.dominantColor;
    }
    return AppColors.primary;
  }

  static Color get accentDim => accent.withValues(alpha: 0.3);
  static Color get accentGlow => accent.withValues(alpha: 0.15);
}

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
    final accent = DietTheme.accent;

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
                  color: (isOver ? AppColors.error : accent).withValues(alpha: 0.2),
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
                AppColors.surfaceLight.withValues(alpha: 0.3),
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
                    isOver ? AppColors.error : accent,
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
                  color: AppColors.textPrimary,
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "of ${target.toStringAsFixed(0)} kcal",
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: size * 0.065,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOver ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOver
                      ? "+${(net - target).toStringAsFixed(0)} over"
                      : "${(target - net).toStringAsFixed(0)} left",
                  style: TextStyle(
                    color: isOver ? AppColors.error : AppColors.success,
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
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                _buildSegment(protein / total, proteinColor),
                _buildSegment(carbs / total, carbsColor),
                _buildSegment(fat / total, fatColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMacroLabel("Protein", protein, proteinColor),
            _buildMacroLabel("Carbs", carbs, carbsColor),
            _buildMacroLabel("Fat", fat, fatColor),
          ],
        ),
      ],
    );
  }

  Widget _buildSegment(double fraction, Color color) {
    return Expanded(
      flex: (fraction * 100).toInt().clamp(1, 100),
      child: Container(color: color),
    );
  }

  Widget _buildMacroLabel(String label, double grams, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Text(
          "${grams.toStringAsFixed(1)}g",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
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
    final accent = DietTheme.accent;
    final target = logs.isNotEmpty ? logs.first.targetCalories : 2000;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (logs.map((l) => l.totalCalories).fold(0.0, math.max) * 1.3).clamp(target * 1.2, double.infinity),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: AppColors.surface,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toStringAsFixed(0)} kcal',
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
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
                return FlLine(color: accent.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [8, 4]);
              }
              return FlLine(color: AppColors.surfaceLight.withValues(alpha: 0.3), strokeWidth: 0.5);
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
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
                        date != null ? DateFormat('E').format(date).substring(0, 2) : '',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isOver
                        ? [AppColors.error.withValues(alpha: 0.6), AppColors.error]
                        : [accent.withValues(alpha: 0.4), accent],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        swapAnimationDuration: const Duration(milliseconds: 400),
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
    final accent = DietTheme.accent;
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
                return FlLine(color: accent.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [8, 4]);
              }
              return FlLine(color: AppColors.surfaceLight.withValues(alpha: 0.2), strokeWidth: 0.5);
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
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
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
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
              tooltipBgColor: AppColors.surface,
              tooltipRoundedRadius: 8,
              getTooltipItems: (spots) {
                return spots.map((s) {
                  return LineTooltipItem(
                    '${s.y.toStringAsFixed(0)} kcal',
                    const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
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
        color: (isDeficit ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDeficit ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDeficit ? Icons.trending_down : Icons.trending_up,
            color: isDeficit ? AppColors.success : AppColors.error,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            "${isDeficit ? 'DEFICIT' : 'SURPLUS'} ${deficit.abs().toStringAsFixed(0)} kcal",
            style: TextStyle(
              color: isDeficit ? AppColors.success : AppColors.error,
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
    final accent = DietTheme.accent;
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
                  Icon(Icons.auto_awesome, color: accent, size: 18),
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_fire_department, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  burn.activity,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (burn.durationMinutes > 0)
                  Text(
                    "${burn.durationMinutes} min",
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            "-${burn.caloriesBurned.toStringAsFixed(0)} kcal",
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textTertiary, size: 16),
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
    final accent = DietTheme.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _mealColor(entry.mealType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_mealIcon(entry.mealType), color: _mealColor(entry.mealType), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "P: ${entry.protein.toStringAsFixed(1)}g  C: ${entry.carbs.toStringAsFixed(1)}g  F: ${entry.fat.toStringAsFixed(1)}g",
                  style: const TextStyle(
                    color: AppColors.textTertiary,
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
              icon: const Icon(Icons.close, color: AppColors.textTertiary, size: 16),
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
        return Icons.wb_sunny_rounded;
      case MealType.lunch:
        return Icons.wb_cloudy_rounded;
      case MealType.dinner:
        return Icons.nightlight_round;
      case MealType.snack:
        return Icons.cookie_rounded;
    }
  }
}

// --- Glass Card (reusable) ---
class DietGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  const DietGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = DietTheme.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// --- Daily Report Card (Aesthetic) ---
class DailyReportCard extends StatelessWidget {
  final DietDayLog log;

  const DailyReportCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final accent = DietTheme.accent;
    final date = DateTime.tryParse(log.dateKey) ?? DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(date);

    return DietGlassCard(
      glow: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.assessment_rounded, color: accent, size: 20),
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
            const Divider(color: AppColors.glassBorder, height: 1),
            ...log.entries.map((e) => _buildFoodRow(e)),
            const Divider(color: AppColors.glassBorder, height: 1),
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
                _buildSummaryRow("Total Calories", "${log.totalCalories.toStringAsFixed(0)} kcal", accent),
                _buildSummaryRow("Total Protein", "${log.totalProtein.toStringAsFixed(1)} g", MacroBreakdownBar.proteinColor),
                _buildSummaryRow("Total Carbs", "${log.totalCarbs.toStringAsFixed(1)} g", MacroBreakdownBar.carbsColor),
                _buildSummaryRow("Total Fat", "${log.totalFat.toStringAsFixed(1)} g", MacroBreakdownBar.fatColor),
                const Divider(color: AppColors.glassBorder),
                _buildSummaryRow("Calories Burned", "${log.totalBurned.toStringAsFixed(0)} kcal", AppColors.error),
                _buildSummaryRow(
                  log.isDeficit ? "Caloric Deficit" : "Caloric Surplus",
                  "${log.deficit.abs().toStringAsFixed(0)} kcal",
                  log.isDeficit ? AppColors.success : AppColors.error,
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
          Expanded(flex: 3, child: Text("Food", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))),
          Expanded(flex: 2, child: Text("kcal", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text("P (g)", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text("C (g)", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text("F (g)", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildFoodRow(FoodEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(e.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(e.calories.toStringAsFixed(0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(e.protein.toStringAsFixed(1), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(e.carbs.toStringAsFixed(1), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(e.fat.toStringAsFixed(1), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
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
    final accent = DietTheme.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
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
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "Activity (e.g., Running)",
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceLight)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "kcal",
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceLight)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "min",
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceLight)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addBurn,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_fire_department, color: AppColors.error, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


