import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        title: Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.02),
                blurRadius: 1,
                offset: const Offset(0, -1),
              )
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: _currentView == 'missions' 
                      ? Alignment.centerLeft 
                      : _currentView == 'finance' 
                          ? Alignment.center 
                          : Alignment.centerRight,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 70,
                    height: 40,
                  decoration: BoxDecoration(
                    color: Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light' ? Colors.white : const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleTab(LucideIcons.target, 'missions'),
                  _buildToggleTab(LucideIcons.wallet, 'finance'),
                  _buildToggleTab(LucideIcons.shield, 'vault'),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentView == 'missions') 
            IconButton(
              icon: Icon(LucideIcons.barChart2, color: BentoTheme.accent),
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const TaskAnalyticsPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      final fadeAnim = CurvedAnimation(parent: animation, curve: Curves.easeOut);
                      final slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)
                      );
                      return FadeTransition(
                        opacity: fadeAnim,
                        child: SlideTransition(position: slideAnim, child: child),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
            ),
        ],
        
        bottom: _currentView == 'missions' 
            ? TabBar(
                controller: _tabController,
                indicatorColor: BentoTheme.accent,
                labelColor: BentoTheme.accent,
                unselectedLabelColor: BentoTheme.textSecondary,
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
          color: Colors.transparent,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
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

  Widget _buildToggleTab(IconData icon, String viewKey) {
    final isSelected = _currentView == viewKey;
    return GestureDetector(
      onTap: () => setState(() {
        _currentView = viewKey;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: 70,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? (Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light' ? Colors.black : Colors.white) : BentoTheme.textSecondary,
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
    final activeGoals = allTypeGoals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => (b.createdDate ?? DateTime.now()).compareTo(a.createdDate ?? DateTime.now()));
    final completedGoals = allTypeGoals.where((g) => g.isCompleted).toList()
      ..sort((a, b) => (b.createdDate ?? DateTime.now()).compareTo(a.createdDate ?? DateTime.now()));

    return CustomScrollView(
      slivers: [
        if (activeGoals.isEmpty && completedGoals.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Column(
                  children: [
                    Icon(LucideIcons.wind, size: 60, color: BentoTheme.textSecondary.withValues(alpha: 0.5))
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .slideY(begin: -0.1, end: 0.1, duration: 2.seconds, curve: Curves.easeInOut),
                    const SizedBox(height: 16),
                    Text("No missions here yet.", style: TextStyle(color: BentoTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Time to assign yourself a new objective.", style: TextStyle(color: BentoTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ).animate().fade().scale(curve: Curves.easeOutBack),
              ),
            ),
          ),
        
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final goal = activeGoals[index];
                return TaskCard(
                  goal: goal, 
                  onTap: () => _showGoalDetails(goal)
                ).animate().slideY(begin: 0.1, duration: 200.ms, delay: (20 * index).ms, curve: Curves.easeOutCubic).fade(duration: 200.ms);
              },
              childCount: activeGoals.length,
            ),
          ),
        ),
        
        SliverPadding(
          padding: const EdgeInsets.all(16).copyWith(bottom: 80),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildAddGoalButton(type).animate().slideY(begin: 0.1, duration: 200.ms, delay: (20 * activeGoals.length).ms).fade(),
                if (completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  _buildCompletedSection(completedGoals),
                ],
              ],
            ),
          ),
        ),
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
          border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, color: BentoTheme.accent),
            SizedBox(width: 8),
            Text(
              "ADD NEW MISSION",
              style: TextStyle(
                color: BentoTheme.accent,
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
      collapsedIconColor: BentoTheme.textSecondary,
      iconColor: BentoTheme.accent,
      title: Text(
        "COMPLETED (${completedGoals.length})",
        style: TextStyle(
          color: BentoTheme.textSecondary,
          letterSpacing: 2,
          fontSize: 12,
        ),
      ),
      children: completedGoals
          .map((goal) => TaskCard(goal: goal, onTap: () => _showGoalDetails(goal)))
          .toList(),
    );
  }

  void _showGoalDetails(Goal goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.background,
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
                        color: BentoTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: BentoTheme.textSecondary),
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
                            backgroundColor: BentoTheme.background,
                            duration: const Duration(milliseconds: 800),
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
          Text(label, style: TextStyle(color: BentoTheme.textSecondary)),
          Text(value, style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
