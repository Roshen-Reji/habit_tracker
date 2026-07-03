import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:habit_tracker/features/finance/finance_page.dart'; 
import 'package:habit_tracker/features/speech_vault/speech_vault_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      backgroundColor: NeuTheme.background,
      appBar: AppBar(
        centerTitle: true,
        title: NeuContainer(
          height: 50,
          padding: EdgeInsets.zero,
          borderRadius: 25,
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
              icon: Icon(LucideIcons.barChart2, color: NeuTheme.accent),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskAnalyticsPage()));
              },
            ),
        ],
        
        bottom: _currentView == 'missions' 
            ? TabBar(
                controller: _tabController,
                indicatorColor: NeuTheme.accent,
                labelColor: NeuTheme.accent,
                unselectedLabelColor: NeuTheme.textSecondary,
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
        decoration: BoxDecoration(
          color: NeuTheme.background,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: _currentView == 'missions' 
              ? SizedBox(key: const ValueKey('missions'), child: _buildTaskEngine())
              : _currentView == 'finance'
                  ? const FinanceDashboard(key: ValueKey('finance'))
                  : const SpeechVaultPage(key: ValueKey('vault')),
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
      child: NeuContainer(
        borderRadius: 25,
        isPressed: false,
        padding: EdgeInsets.zero,
        customColor: isSelected ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? NeuTheme.accent : NeuTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
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
      padding: EdgeInsets.all(16),
      children: [
        ...activeGoals.asMap().entries.map((entry) => TaskCard(
          goal: entry.value, 
          onTap: () => _showGoalDetails(entry.value)
        ).animate().slideY(begin: 0.1, duration: 400.ms, delay: (50 * entry.key).ms, curve: Curves.easeOutBack).fade(duration: 400.ms)),
        SizedBox(height: 20),
        _buildAddGoalButton(type).animate().slideY(begin: 0.1, duration: 400.ms, delay: (50 * activeGoals.length).ms).fade(),
        if (completedGoals.isNotEmpty) ...[
          SizedBox(height: 30),
          _buildCompletedSection(completedGoals),
        ],
        SizedBox(height: 80), // Padding for bottom nav
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
          border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, color: NeuTheme.accent),
            SizedBox(width: 8),
            Text(
              "ADD NEW MISSION",
              style: TextStyle(
                color: NeuTheme.accent,
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
      collapsedIconColor: NeuTheme.textSecondary,
      iconColor: NeuTheme.accent,
      title: Text(
        "COMPLETED (${completedGoals.length})",
        style: TextStyle(
          color: NeuTheme.textSecondary,
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
      backgroundColor: NeuTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        color: NeuTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: NeuTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildDetailRow('Progress', '${goal.currentValue.toInt()}/${goal.targetValue.toInt()} ${goal.unit}'),
              _buildDetailRow('Completion', '${goal.completionPercentage.toInt()}%'),
              _buildDetailRow('Streak', '${goal.streakCount} days'),
              SizedBox(height: 24),
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
                      child: Text('Add Progress'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        NotificationService().cancelReminder(goal.key.hashCode);
                        missionBox.delete(goal.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${goal.title} deleted'),
                            backgroundColor: NeuTheme.background,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: NeuTheme.textSecondary)),
          Text(value, style: TextStyle(color: NeuTheme.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
