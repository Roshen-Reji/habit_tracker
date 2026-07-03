import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/features/diet/widgets/diet_dashboard_widgets.dart';
import 'package:habit_tracker/features/diet/widgets/manual_food_input.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _aiOpinion = '';
  bool _isLoadingOpinion = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAiOpinion() async {
    if (!AiService.instance.isConfigured) return;
    setState(() => _isLoadingOpinion = true);

    final response = await AiService.instance.processMessage(
      'Give me a brief nutritional analysis and advice based on my diet data. Keep it to 2-3 sentences.',
      contextHint: 'diet',
    );

    if (mounted) {
      setState(() {
        _aiOpinion = response.message;
        _isLoadingOpinion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "D I E T   P L A N N E R",
          style: TextStyle(
            color: accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: BentoTheme.textSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "TODAY"),
            Tab(text: "DASHBOARD"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayView(),
          _buildDashboardView(),
        ],
      ),
    );
  }

  // ==================== TODAY VIEW ====================
  Widget _buildTodayView() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DietDayLog>('diet_logs').listenable(),
      builder: (context, Box<DietDayLog> box, _) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final log = box.get(today) ?? DietDayLog(
          dateKey: today,
          targetCalories: AiService.instance.getTodayLog().targetCalories,
        );
        final accent = BentoTheme.accent;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              BentoContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  children: [
                    CalorieRingChart(
                      intake: log.totalCalories,
                      target: log.targetCalories,
                      burned: log.totalBurned,
                    ),
                    const SizedBox(height: 20),
                    MacroBreakdownBar(
                      protein: log.totalProtein,
                      carbs: log.totalCarbs,
                      fat: log.totalFat,
                    ),
                    const SizedBox(height: 16),
                    DeficitBadge(deficit: log.deficit),
                  ],
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Burn Section
              _buildSectionHeader("CALORIES BURNED", LucideIcons.flame, Colors.redAccent),
              const SizedBox(height: 8),
              BurnInputWidget(onBurnAdded: () => setState(() {})),
              const SizedBox(height: 8),
              if (log.burnEntries.isNotEmpty)
                ...log.burnEntries.map((b) => BurnEntryTile(
                  burn: b,
                  onDelete: () {
                    log.removeBurn(b.id);
                    setState(() {});
                  },
                )),
              if (log.burnEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "Total: -${log.totalBurned.toStringAsFixed(0)} kcal",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Food Log Section
              _buildSectionHeader("FOOD LOG", LucideIcons.utensils, accent),
              const SizedBox(height: 8),
              
              // Quick Add (Task 11)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAddChip("💧 Water", 0, "water", () { log.addFood(FoodEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), name: "Water", calories: 0, protein: 0, carbs: 0, fat: 0, timestamp: DateTime.now(), mealType: MealType.snack)); setState((){}); }),
                    _buildQuickAddChip("☕ Coffee", 50, "coffee", () { log.addFood(FoodEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), name: "Black Coffee", calories: 50, protein: 0, carbs: 0, fat: 0, timestamp: DateTime.now(), mealType: MealType.breakfast)); setState((){}); }),
                    _buildQuickAddChip("🍎 Apple", 95, "apple", () { log.addFood(FoodEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), name: "Apple", calories: 95, protein: 0, carbs: 25, fat: 0, timestamp: DateTime.now(), mealType: MealType.snack)); setState((){}); }),
                    _buildQuickAddChip("🥚 Egg", 78, "egg", () { log.addFood(FoodEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), name: "Boiled Egg", calories: 78, protein: 6, carbs: 0, fat: 5, timestamp: DateTime.now(), mealType: MealType.breakfast)); setState((){}); }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ManualFoodInputWidget(onFoodAdded: () => setState(() {})),
              const SizedBox(height: 8),

              if (log.entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.frown, color: BentoTheme.textSecondary.withValues(alpha: 0.3), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          "No food logged yet",
                          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            _tabController.animateTo(2); // Switch to chat tab
                          },
                          child: Text(
                            "Use the chat to log food →",
                            style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Group by meal type
                ..._buildMealGroups(log, accent),

              const SizedBox(height: 24),

              // Daily Report Card
              if (log.entries.isNotEmpty) ...[
                _buildSectionHeader("DAILY REPORT", LucideIcons.barChart2, accent),
                const SizedBox(height: 8),
                DailyReportCard(log: log)
                    .animate()
                    .fade(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.1),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMealGroups(DietDayLog log, Color accent) {
    final widgets = <Widget>[];

    for (var meal in MealType.values) {
      final entries = log.entriesForMeal(meal);
      if (entries.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            meal.name.toUpperCase(),
            style: TextStyle(
              color: accent.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );

      for (var entry in entries) {
        widgets.add(
          FoodEntryTile(
            entry: entry,
            onDelete: () {
              log.removeFood(entry.id);
              setState(() {});
            },
          ),
        );
      }
    }

    return widgets;
  }

  // ==================== DASHBOARD VIEW ====================
  Widget _buildDashboardView() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DietDayLog>('diet_logs').listenable(),
      builder: (context, Box<DietDayLog> box, _) {
        final accent = BentoTheme.accent;
        final weekLogs = AiService.instance.getLogsForRange(7);
        final monthLogs = AiService.instance.getLogsForRange(30);

        // Weekly averages
        final weekCalories = weekLogs.map((l) => l.totalCalories).toList();
        final weekAvg = weekCalories.isEmpty ? 0.0 : weekCalories.reduce((a, b) => a + b) / weekCalories.length;
        final weekTarget = weekLogs.isNotEmpty ? weekLogs.first.targetCalories : 2000;

        // Monthly averages
        final monthCalories = monthLogs.where((l) => l.entries.isNotEmpty).map((l) => l.totalCalories).toList();
        final monthAvg = monthCalories.isEmpty ? 0.0 : monthCalories.reduce((a, b) => a + b) / monthCalories.length;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekly Overview
              _buildSectionHeader("WEEKLY OVERVIEW", LucideIcons.calendarDays, accent),
              const SizedBox(height: 8),
              BentoContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Avg. Daily", style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
                            Text(
                              "${weekAvg.toStringAsFixed(0)} kcal",
                              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        DeficitBadge(deficit: weekTarget - weekAvg),
                      ],
                    ),
                    const SizedBox(height: 16),
                    WeeklyCalorieChart(logs: weekLogs),
                  ],
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Monthly Trend
              _buildSectionHeader("MONTHLY TREND", LucideIcons.lineChart, accent),
              const SizedBox(height: 8),
              BentoContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Avg. Daily (logged days)", style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
                            Text(
                              "${monthAvg.toStringAsFixed(0)} kcal",
                              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          "${monthCalories.length} days logged",
                          style: TextStyle(color: accent, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MonthlyTrendChart(logs: monthLogs),
                  ],
                ),
              ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // AI Opinion
              _buildSectionHeader("AI ANALYSIS", LucideIcons.sparkles, accent),
              const SizedBox(height: 8),
              if (_aiOpinion.isEmpty && !_isLoadingOpinion)
                GestureDetector(
                  onTap: _fetchAiOpinion,
                  child: BentoContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.sparkles, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Tap to get AI nutritional analysis",
                          style: TextStyle(color: accent, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                AiOpinionCard(
                  opinion: _aiOpinion,
                  isLoading: _isLoadingOpinion,
                ).animate().fade(duration: 400.ms, delay: 200.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddChip(String label, int calories, String type, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: BentoContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            if (calories > 0) ...[
              const SizedBox(height: 4),
              Text("$calories kcal", style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
            ]
          ],
        ),
      ),
    );
  }
}
