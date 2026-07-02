import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/features/finance/finance_page.dart'; 
import 'package:habit_tracker/features/speech_vault/speech_vault_page.dart';
import 'widgets/task_card.dart';
import 'widgets/add_task_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:habit_tracker/data/services/notification_service.dart';
import 'task_analytics_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with SingleTickerProviderStateMixin {
  final Box<Goal> missionBox = Hive.box<Goal>('mission_box_v4');
  late TabController _tabController;
  String _currentView = 'missions'; // 'missions', 'finance', 'vault'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleTab("MISSIONS", 'missions'),
              _buildToggleTab("FINANCE", 'finance'),
              _buildToggleTab("VAULT", 'vault'),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentView == 'missions') 
            IconButton(
              icon: const Icon(Icons.analytics, color: AppColors.primary),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskAnalyticsPage()));
              },
            ),
        ],
        
        bottom: _currentView == 'missions' 
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: "TODAY"), 
                  Tab(text: "DAILY"), 
                  Tab(text: "WEEKLY"), 
                  Tab(text: "MONTHLY")
                ],
              )
            : const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink()),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentView == 'missions' 
              ? _buildTaskEngine() 
              : _currentView == 'finance'
                  ? const FinanceDashboard()
                  : const SpeechVaultPage(),
        ),
      ),
    );
  }

  Widget _buildToggleTab(String text, String viewKey) {
    final isSelected = _currentView == viewKey;
    return GestureDetector(
      onTap: () => setState(() {
        _currentView = viewKey;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) : Border.all(color: Colors.transparent),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textTertiary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskEngine() {
    return ValueListenableBuilder(
      valueListenable: missionBox.listenable(),
      builder: (context, Box<Goal> box, _) {
        final allGoals = box.values.toList();
        return TabBarView(
          controller: _tabController,
          children: [
            _buildGoalList(allGoals, GoalType.today),
            _buildGoalList(allGoals, GoalType.daily),
            _buildGoalList(allGoals, GoalType.weekly),
            _buildGoalList(allGoals, GoalType.monthly),
          ],
        );
      },
    );
  }

  Widget _buildGoalList(List<Goal> allGoals, GoalType type) {
    final allTypeGoals = allGoals.where((g) => g.type == type && !g.isArchived).toList();
    final activeGoals = allTypeGoals.where((g) => !g.isCompleted).toList();
    final completedGoals = allTypeGoals.where((g) => g.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...activeGoals.asMap().entries.map((entry) => TaskCard(
          goal: entry.value, 
          onTap: () => _showGoalDetails(entry.value)
        ).animate().slideY(begin: 0.1, duration: 400.ms, delay: (50 * entry.key).ms, curve: Curves.easeOutBack).fade(duration: 400.ms)),
        const SizedBox(height: 20),
        _buildAddGoalButton(type).animate().slideY(begin: 0.1, duration: 400.ms, delay: (50 * activeGoals.length).ms).fade(),
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 30),
          _buildCompletedSection(completedGoals),
        ],
        const SizedBox(height: 80), // Padding for bottom nav
      ],
    );
  }

  Widget _buildAddGoalButton(GoalType type) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context, 
        builder: (_) => AddTaskDialog(defaultType: type)
      ),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              "ADD NEW MISSION",
              style: TextStyle(
                color: AppColors.primary,
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
      collapsedIconColor: AppColors.textTertiary,
      iconColor: AppColors.primary,
      title: Text(
        "COMPLETED (${completedGoals.length})",
        style: const TextStyle(
          color: AppColors.textTertiary,
          letterSpacing: 2,
          fontSize: 12,
        ),
      ),
      children: completedGoals
          .map((goal) => Opacity(
            opacity: 0.6, 
            child: TaskCard(goal: goal, onTap: () => _showGoalDetails(goal))
          ))
          .toList(),
    );
  }

  void _showGoalDetails(Goal goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Progress', '${goal.currentValue.toInt()}/${goal.targetValue.toInt()} ${goal.unit}'),
              _buildDetailRow('Completion', '${goal.completionPercentage.toInt()}%'),
              _buildDetailRow('Streak', '${goal.streakCount} days'),
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
                      child: const Text('Add Progress'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        NotificationService().cancelReminder(goal.key.hashCode);
                        missionBox.delete(goal.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${goal.title} deleted'),
                            backgroundColor: AppColors.surface,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Delete', style: TextStyle(color: AppColors.error)),
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
          Text(label, style: const TextStyle(color: AppColors.textTertiary)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
