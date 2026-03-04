import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:habit_tracker/models/goals.dart';
import 'package:habit_tracker/screens/finance_page.dart'; 


class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> with SingleTickerProviderStateMixin {
  final Box<Goal> missionBox = Hive.box<Goal>('mission_box_v3');
  late TabController _tabController;
  
  bool showAnalytics = false;
  bool _isTaskMode = true; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAndSeedInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkAndSeedInitialData() {
    final prefsBox = Hive.box('settings');
    final hasSeeded = prefsBox.get('goals_seeded_v3', defaultValue: false);
    
    if (!hasSeeded) {
      _seedInitialData();
      prefsBox.put('goals_seeded_v3', true);
    }
  }

  void _seedInitialData() {
    final seedGoals = [
      Goal(id: '1', title: 'Practice Python / Java', type: GoalType.daily, category: GoalCategory.learning, targetValue: 2, currentValue: 1, unit: 'hours', isCompleted: false)
    ];

    for (var goal in seedGoals) {
      goal.progress = (goal.currentValue / goal.targetValue * 100).clamp(0, 100) / 100;
      if (goal.currentValue >= goal.targetValue) goal.isCompleted = true;
      missionBox.put(goal.id, goal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        // THE NEW GORGEOUS GLASS TOGGLE
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleTab("TASKS", true),
              _buildToggleTab("FINANCE", false),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isTaskMode) 
            IconButton(
              icon: Icon(showAnalytics ? Icons.list : Icons.analytics, color: const Color(0xFFFC3C44)),
              onPressed: () => setState(() => showAnalytics = !showAnalytics),
            ),
        ],
        
        bottom: _isTaskMode 
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFC3C44),
                labelColor: const Color(0xFFFC3C44),
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                tabs: const [Tab(text: "DAILY"), Tab(text: "WEEKLY"), Tab(text: "MONTHLY")],
              )
            : const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink()),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF0F0020)],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          
          child: _isTaskMode ? _buildTaskEngine() : const FinanceDashboard(),
        ),
      ),
    );
  }


  Widget _buildToggleTab(String text, bool isTaskButton) {
    final isSelected = _isTaskMode == isTaskButton;
    return GestureDetector(
      onTap: () => setState(() {
        _isTaskMode = isTaskButton;
        showAnalytics = false; 
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: isSelected ? Border.all(color: Colors.tealAccent.withOpacity(0.5)) : Border.all(color: Colors.transparent),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.tealAccent : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // --- EXTRACTED TASK ENGINE ---
  Widget _buildTaskEngine() {
    return ValueListenableBuilder(
      valueListenable: missionBox.listenable(),
      builder: (context, Box<Goal> box, _) {
        final allGoals = box.values.toList();
        if (showAnalytics) return _buildAnalyticsView(allGoals);
        return TabBarView(
          controller: _tabController,
          children: [
            _buildGoalList(allGoals, GoalType.daily),
            _buildGoalList(allGoals, GoalType.weekly),
            _buildGoalList(allGoals, GoalType.monthly),
          ],
        );
      },
    );
  }

  

  Widget _buildAnalyticsView(List<Goal> allGoals) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStreakTracker(allGoals), 
          _buildWeeklyProgressGraph(allGoals),
          const SizedBox(height: 16),
          _buildStatisticsCards(allGoals),
          const SizedBox(height: 16),
          _buildCategoryBreakdown(allGoals),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressGraph(List<Goal> allGoals) {
    final weeklyData = _getWeeklyProgressData(allGoals);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C1E),
            Color.fromRGBO(44, 44, 46, 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WEEKLY PROGRESS',
                    style: TextStyle(
                      color: Color(0xFFFC3C44),
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getCompletionRate(allGoals)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Completion Rate',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(252, 60, 68, 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Color(0xFFFC3C44), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+${_getActiveGoalsCount(allGoals)}',
                      style: const TextStyle(
                        color: Color(0xFFFC3C44),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.8,
            child: LineChart(_buildChartData(weeklyData)),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(List<DailyProgress> weeklyData) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Color.fromRGBO(255, 255, 255, 0.05),
            strokeWidth: 1,
          );
        },
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
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= weeklyData.length) return const SizedBox();
              final day = weeklyData[value.toInt()].day;
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 25,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (weeklyData.length - 1).toDouble(),
      minY: 0,
      maxY: 100,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => const Color(0xFF2C2C2E),
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final data = weeklyData[spot.x.toInt()];
              return LineTooltipItem(
                '${data.day}\n${spot.y.toInt()}%\n${data.completedGoals}/${data.totalGoals} goals',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
            weeklyData.length,
                (i) => FlSpot(i.toDouble(), weeklyData[i].completionRate),
          ),
          isCurved: true,
          gradient: const LinearGradient(
            colors: [Color(0xFFFC3C44), Color(0xFFFF6B6B)],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFFFC3C44),
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: const LinearGradient(
              colors: [
                Color.fromRGBO(252, 60, 68, 0.3),
                Color.fromRGBO(252, 60, 68, 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(List<Goal> allGoals) {
    final completed = allGoals.where((g) => g.isCompleted).length;
    final active = allGoals.where((g) => !g.isCompleted && !g.isArchived).length;
    final avgProgress = allGoals.isEmpty
        ? 0.0
        : allGoals.fold(0.0, (sum, g) => sum + g.progress) / allGoals.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Completed', completed.toString(), Icons.check_circle, Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Active', active.toString(), Icons.radio_button_checked, const Color(0xFFFC3C44))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Avg Progress', '${(avgProgress * 100).toInt()}%', Icons.trending_up, Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<Goal> allGoals) {
    final categoryData = <GoalCategory, int>{};
    for (var goal in allGoals) {
      categoryData[goal.category] = (categoryData[goal.category] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORY BREAKDOWN',
            style: TextStyle(
              color: Color(0xFFFC3C44),
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...categoryData.entries.map((entry) {
            final percentage = allGoals.isEmpty ? 0.0 : entry.value / allGoals.length;
            return _buildCategoryBar(
              _getCategoryName(entry.key),
              percentage,
              _getCategoryColor(entry.key),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String category, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(color: Colors.white)),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color.fromRGBO(255, 255, 255, 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakTracker(List<Goal> allGoals) {
    final maxStreak = allGoals.isEmpty ? 0 :
    allGoals.map((g) => g.streakCount).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(252, 60, 68, 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, color: Color(0xFFFC3C44), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$maxStreak Day Streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Keep it up! You\'re on fire! 🔥',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalList(List<Goal> allGoals, GoalType type) {
    final allTypeGoals = allGoals.where((g) => g.type == type).toList();
    final activeGoals = allTypeGoals.where((g) => !g.isCompleted).toList();
    final completedGoals = allTypeGoals.where((g) => g.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...activeGoals.map((goal) => _buildGoalCard(goal)),
        const SizedBox(height: 20),
        _buildAddGoalButton(type),
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 30),
          _buildCompletedSection(completedGoals),
        ],
      ],
    );
  }

  Widget _buildGoalCard(Goal goal) {
    return GestureDetector(
      onTap: () => _showGoalDetails(goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1C1C1E),
              Color.fromRGBO(44, 44, 46, 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: goal.isCompleted
                ? const Color.fromRGBO(76, 175, 80, 0.5)
                : const Color.fromRGBO(252, 60, 68, 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(goal.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(goal.category),
                    color: _getCategoryColor(goal.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (goal.description.isNotEmpty)
                        Text(
                          goal.description,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                
                if (goal.streakCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(252, 60, 68, 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromRGBO(252, 60, 68, 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, color: Color(0xFFFC3C44), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${goal.streakCount}',
                          style: const TextStyle(
                            color: Color(0xFFFC3C44), 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                IconButton(
                  icon: Icon(
                    goal.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: goal.isCompleted ? Colors.green : Colors.grey,
                  ),
                  onPressed: () {
                    if (!missionBox.containsKey(goal.id)) return;
                    
                    setState(() {
                      if (goal.isCompleted) {
                        goal.reset();
                      } else {
                        goal.complete();
                      }
                      missionBox.put(goal.id, goal);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: goal.progress,
                        backgroundColor: const Color.fromRGBO(255, 255, 255, 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCategoryColor(goal.category),
                        ),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${goal.currentValue.toInt()}/${goal.targetValue.toInt()} ${goal.unit}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${goal.completionPercentage.toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddGoalButton(GoalType type) {
    return GestureDetector(
      onTap: () => _showAddGoalDialog(type),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color.fromRGBO(252, 60, 68, 0.5), width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Color(0xFFFC3C44)),
            SizedBox(width: 8),
            Text(
              "ADD NEW GOAL",
              style: TextStyle(
                color: Color(0xFFFC3C44),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSection(List<Goal> completedGoals) {
    return ExpansionTile(
      collapsedIconColor: Colors.grey,
      iconColor: const Color(0xFFFC3C44),
      title: Text(
        "COMPLETED (${completedGoals.length})",
        style: const TextStyle(
          color: Colors.grey,
          letterSpacing: 2,
          fontSize: 12,
        ),
      ),
      children: completedGoals
          .map((goal) => Opacity(opacity: 0.6, child: _buildGoalCard(goal)))
          .toList(),
    );
  }

  void _showGoalDetails(Goal goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Progress', '${goal.currentValue.toInt()}/${goal.targetValue.toInt()} ${goal.unit}'),
              _buildDetailRow('Completion', '${goal.completionPercentage.toInt()}%'),
              _buildDetailRow('Streak', '${goal.streakCount} days'),
              _buildDetailRow('Category', _getCategoryName(goal.category)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (missionBox.containsKey(goal.id)) {
                          goal.incrementProgress(1);
                          missionBox.put(goal.id, goal);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFC3C44),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Add Progress'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        missionBox.delete(goal.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${goal.title} deleted'),
                            backgroundColor: const Color(0xFF2C2C2E),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddGoalDialog(GoalType type) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    GoalCategory selectedCategory = GoalCategory.productivity; // Default

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "NEW ${type.name.toUpperCase()} GOAL",
                style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Goal title...",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFC3C44))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Target value (e.g., 20)...",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFC3C44))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<GoalCategory>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF1C1C1E),
                      onChanged: (GoalCategory? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedCategory = newValue;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                      items: GoalCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 20),
                              const SizedBox(width: 8),
                              Text(_getCategoryName(category), style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text;
                    final target = double.tryParse(targetController.text);

                    if (title.isNotEmpty && target != null && target > 0) {
                      final newGoal = Goal(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        type: type,
                        category: selectedCategory,
                        targetValue: target,
                        unit: 'units',
                      );
                      missionBox.put(newGoal.id, newGoal);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFC3C44)),
                  child: const Text("ADD GOAL"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getCategoryName(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return 'Health & Wellness';
      case GoalCategory.productivity: return 'Productivity';
      case GoalCategory.learning: return 'Learning & Growth';
      case GoalCategory.fitness: return 'Fitness';
      case GoalCategory.hobby: return 'Hobbies & Fun';
    }
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return Colors.pinkAccent;
      case GoalCategory.productivity: return Colors.orangeAccent;
      case GoalCategory.learning: return Colors.blueAccent;
      case GoalCategory.fitness: return Colors.greenAccent;
      case GoalCategory.hobby: return Colors.purpleAccent;
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.health: return Icons.favorite;
      case GoalCategory.productivity: return Icons.bolt;
      case GoalCategory.learning: return Icons.menu_book;
      case GoalCategory.fitness: return Icons.fitness_center;
      case GoalCategory.hobby: return Icons.extension;
    }
  }

  int _getCompletionRate(List<Goal> goals) {
    if (goals.isEmpty) return 0;
    final completed = goals.where((g) => g.isCompleted).length;
    return ((completed / goals.length) * 100).toInt();
  }

  int _getActiveGoalsCount(List<Goal> goals) {
    return goals.where((g) => !g.isCompleted && !g.isArchived).length;
  }

  List<DailyProgress> _getWeeklyProgressData(List<Goal> allGoals) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final List<DailyProgress> weeklyData = [];

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final goalsForDay = allGoals.where((g) {
        return g.type == GoalType.daily;
      }).toList();

      if (goalsForDay.isEmpty) {
        weeklyData.add(DailyProgress(_dayName(day.weekday), 0, 0, 0));
      } else {
        final completed = goalsForDay.where((g) => g.isCompleted).length;
        final completionRate = (completed / goalsForDay.length) * 100;
        weeklyData.add(DailyProgress(_dayName(day.weekday), completionRate, completed, goalsForDay.length));
      }
    }
    return weeklyData;
  }

  String _dayName(int weekday) {
    switch (weekday) {
      case 1: return 'MON'; case 2: return 'TUE'; case 3: return 'WED'; case 4: return 'THU';
      case 5: return 'FRI'; case 6: return 'SAT'; case 7: return 'SUN'; default: return '';
    }
  }
}

class DailyProgress {
  final String day;
  final double completionRate;
  final int completedGoals;
  final int totalGoals;
  DailyProgress(this.day, this.completionRate, this.completedGoals, this.totalGoals);
}