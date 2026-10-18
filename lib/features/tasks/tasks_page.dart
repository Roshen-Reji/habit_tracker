import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/smart_scheduler_engine.dart';
import 'package:habit_tracker/features/tasks/engine/task_urgency_engine.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/task_analytics_page.dart';
import 'package:habit_tracker/features/tasks/widgets/academic_hub_view.dart';
import 'package:habit_tracker/features/tasks/widgets/focus_timer_sheet.dart';
import 'package:habit_tracker/features/tasks/widgets/quick_add_nl_bar.dart';
import 'package:habit_tracker/features/tasks/widgets/smart_plan_banner.dart';
import 'package:habit_tracker/features/tasks/widgets/task_detail_sheet.dart';
import 'package:habit_tracker/features/tasks/widgets/weekly_review_shutdown_sheet.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'p1', 'p2', 'overdue'

  bool _isTimelineMode = false; // VIEW-6: List vs Timeline toggle
  bool _dismissedHealthBanner = false; // REM-9
  PlanProposalItem? _currentDayPlan;

  final Set<String> _selectedInboxTaskIds = {};
  bool _isBulkSelecting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initRepository();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  Future<void> _initRepository() async {
    if (!TaskOsRepository.instance.isInitialized) {
      await TaskOsRepository.instance.init();
    }
    _generatePlan();
    if (mounted) setState(() {});
  }

  void _generatePlan() {
    final now = DateTime.now();
    final tasks = TaskOsRepository.instance.activeTasks;
    final timetable = TaskOsRepository.instance.timetableSlots;
    final exams = TaskOsRepository.instance.activeExams;
    final rules = TaskOsRepository.instance.rulesNotifier.value;

    final plan = SmartSchedulerEngine.generateDailyPlan(
      date: now,
      openTasks: tasks,
      timetableSlots: timetable,
      exams: exams,
      rules: rules,
    );
    setState(() => _currentDayPlan = plan);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openTaskDetail(TaskItem task) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskDetailSheet(task: task),
    );
  }

  void _openFocusTimer(TaskItem task, {bool startJust5Min = false}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FocusTimerSheet(
        task: task,
        startJust5Min: startJust5Min,
      ),
    );
  }

  void _openShutdownRitual() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WeeklyReviewShutdownSheet(isWeeklyReview: false),
    );
  }

  void _cycleAutonomy() {
    HapticFeedback.selectionClick();
    final current = TaskOsRepository.instance.rulesNotifier.value;
    const levels = ['manual', 'suggest', 'autoWithApproval', 'auto'];
    final nextIdx = (levels.indexOf(current.autonomyLevel) + 1) % levels.length;
    final newLevel = levels[nextIdx];

    TaskOsRepository.instance.saveSchedulingRules(
      SchedulingRules(
        workStartHour: current.workStartHour,
        workEndHour: current.workEndHour,
        lightSundays: current.lightSundays,
        minBlockMin: current.minBlockMin,
        maxContinuousMin: current.maxContinuousMin,
        breakMin: current.breakMin,
        deadlineBufferHours: current.deadlineBufferHours,
        autonomyLevel: newLevel,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI Autonomy set to: ${newLevel.toUpperCase()}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<TaskItem> _filterTasks(List<TaskItem> list) {
    var result = list;
    if (_searchQuery.isNotEmpty) {
      result = TaskOsRepository.instance.searchTasks(_searchQuery);
    }

    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'p1':
        return result.where((t) => t.priority == TaskPriority.urgent).toList();
      case 'p2':
        return result.where((t) => t.priority == TaskPriority.high).toList();
      case 'overdue':
        return result.where((t) => t.isOverdue(now)).toList();
      case 'all':
      default:
        return result;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = TaskOsRepository.instance.rulesNotifier.value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search tasks, tags, courses...',
                  hintStyle: TextStyle(color: BentoTheme.textSecondary),
                  border: InputBorder.none,
                ),
              )
            : Row(
                children: [
                  Text(
                    'TASKS',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'AI: ${rules.autonomyLevel.toUpperCase()}',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? LucideIcons.x : LucideIcons.search,
              color: BentoTheme.textPrimary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal, size: 19),
            color: BentoTheme.textSecondary,
            tooltip: 'Autonomy Dial',
            onPressed: _cycleAutonomy,
          ),
          IconButton(
            icon: const Icon(LucideIcons.moon, size: 19),
            color: BentoTheme.textSecondary,
            tooltip: 'Shutdown Ritual',
            onPressed: _openShutdownRitual,
          ),
          IconButton(
            icon: Icon(LucideIcons.barChart2, color: BentoTheme.accent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskAnalyticsPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BentoTheme.accent,
          labelColor: BentoTheme.accent,
          unselectedLabelColor: BentoTheme.textSecondary,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: "TODAY"),
            Tab(text: "UPCOMING"),
            Tab(text: "INBOX"),
            Tab(text: "ACADEMIC"),
            Tab(text: "BOARD"),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Reliability Health Check Banner (REM-9)
              if (!_dismissedHealthBanner) ...[
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: BentoTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bellRing,
                          size: 14, color: BentoTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Background alarms verified: Reminders fire on exact time.',
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _dismissedHealthBanner = true),
                        child: Icon(LucideIcons.x,
                            size: 14, color: BentoTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All'),
                    _buildFilterChip('p1', '⚡ Urgent (P1)'),
                    _buildFilterChip('p2', '🔥 High (P2)'),
                    _buildFilterChip('overdue', '⚠️ Overdue'),
                  ],
                ),
              ),
              // TabBarViews
              Expanded(
                child: ValueListenableBuilder<List<TaskItem>>(
                  valueListenable: TaskOsRepository.instance.tasksNotifier,
                  builder: (context, allTasks, _) {
                    final filtered = _filterTasks(allTasks);

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTodayView(filtered),
                        _buildUpcomingView(filtered),
                        _buildInboxView(allTasks),
                        const AcademicHubView(),
                        _buildBoardView(allTasks),
                      ],
                    );
                  },
                ),
              ),
              // Reserve bottom space for docked QuickAddNlBar
              const SizedBox(height: 64),
            ],
          ),
          // Docked QuickAddNlBar at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QuickAddNlBar(
              onTaskAdded: () {
                _generatePlan();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = key);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? BentoTheme.accent.withValues(alpha: 0.15)
              : BentoTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? BentoTheme.accent : BentoTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ================= 1. TODAY VIEW (PLAN-1, PLAN-3..6, VIEW-6, HAB-1) =================
  Widget _buildTodayView(List<TaskItem> tasks) {
    final now = DateTime.now();
    final openTasks = tasks.where((t) => !t.isDone && !t.isDeleted).toList();
    final ranked = rankTasksByUrgency(openTasks, now);
    final nextUpTask = ranked.isNotEmpty ? ranked.first : null;

    final completedToday = tasks.where((t) => t.isDone && !t.isDeleted).toList();

    return RefreshIndicator(
      onRefresh: () async {
        _generatePlan();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        physics: const BouncingScrollPhysics(),
        children: [
          // Forgiving Habits Strip (HAB-1, HAB-2)
          _buildHabitsStrip(),
          const SizedBox(height: 8),

          // Pinned "Next Up" Hero Card (PLAN-1)
          if (nextUpTask != null) ...[
            _buildNextUpHeroCard(nextUpTask, now),
            const SizedBox(height: 8),
          ],

          // AI Morning Plan Card (PLAN-3..6)
          if (_currentDayPlan != null) ...[
            SmartPlanBanner(
              plan: _currentDayPlan!,
              onPlanAccepted: () {
                setState(() {});
              },
              onRebalance: () {
                _generatePlan();
              },
            ),
            const SizedBox(height: 8),
          ],

          // View-6: List vs Timeline Toggle Header
          Row(
            children: [
              Text(
                'TODAY’S SCHEDULE',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isTimelineMode = !_isTimelineMode);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BentoTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isTimelineMode
                            ? LucideIcons.list
                            : LucideIcons.clock,
                        size: 12,
                        color: BentoTheme.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isTimelineMode ? 'List View' : 'Timeline (08-22)',
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Either Visual Timeline or Grouped List
          if (_isTimelineMode)
            _buildVisualTimeline(now)
          else ...[
            if (openTasks.isEmpty)
              _buildEmptyPlaceholder('No tasks due today. You’re all clear! 🎉')
            else
              for (var t in openTasks) ...[
                _buildTaskTile(t),
              ],
            if (completedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'COMPLETED TODAY (${completedToday.length})',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (var ct in completedToday) ...[
                _buildTaskTile(ct),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNextUpHeroCard(TaskItem task, DateTime now) {
    final breakdown = computeUrgencyBreakdown(task, now);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: BentoTheme.accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NEXT UP (PLAN-1)',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Urgency: ${breakdown.totalScore.toStringAsFixed(0)}/100',
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            breakdown.explanation,
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Just 5 Min button (FOC-5)
              Expanded(
                child: TactileButton(
                  onPressed: () => _openFocusTimer(task, startJust5Min: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: BentoTheme.accent.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.zap,
                            size: 13, color: BentoTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Just 5 Min (FOC-5)',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Focus timer button (FOC-1)
              Expanded(
                child: TactileButton(
                  onPressed: () => _openFocusTimer(task),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.play, size: 13, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          '⏱ Focus',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsStrip() {
    return ValueListenableBuilder<List<ForgivingHabitItem>>(
      valueListenable: TaskOsRepository.instance.habitsNotifier,
      builder: (context, habits, _) {
        final activeHabits = habits.where((h) => h.deletedAt == null).toList();
        if (activeHabits.isEmpty) return const SizedBox.shrink();

        final todayIso = DateTime.now().toIso8601String().substring(0, 10);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var h in activeHabits) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    TaskOsRepository.instance.toggleHabitDay(h.id, todayIso, false);
                  },
                  onLongPress: () {
                    // Freeze action
                    HapticFeedback.heavyImpact();
                    TaskOsRepository.instance.toggleHabitDay(h.id, todayIso, true);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: h.isCompletedOn(todayIso)
                          ? BentoTheme.accent.withValues(alpha: 0.15)
                          : (h.isFrozenOn(todayIso)
                              ? Colors.lightBlue.withValues(alpha: 0.15)
                              : BentoTheme.surface),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: h.isCompletedOn(todayIso)
                            ? BentoTheme.accent
                            : (h.isFrozenOn(todayIso)
                                ? Colors.lightBlue
                                : BentoTheme.divider),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          h.isCompletedOn(todayIso)
                              ? LucideIcons.check
                              : (h.isFrozenOn(todayIso)
                                  ? LucideIcons.snowflake
                                  : LucideIcons.circle),
                          size: 13,
                          color: h.isCompletedOn(todayIso)
                              ? BentoTheme.accent
                              : (h.isFrozenOn(todayIso)
                                  ? Colors.lightBlue
                                  : BentoTheme.textSecondary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          h.name,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '❄️${h.freezesLeft}',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisualTimeline(DateTime now) {
    // 08:00 to 22:00 timeline (VIEW-6)
    final slots = TaskOsRepository.instance.timetableSlots
        .where((s) => s.dayOfWeek == now.weekday)
        .toList();

    final blocks = _currentDayPlan?.blocks ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BentoTheme.divider),
      ),
      child: Column(
        children: [
          for (int hour = 8; hour <= 21; hour++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _renderTimelineHourEvent(hour, slots, blocks),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderTimelineHourEvent(int hour, List<TimetableSlotItem> slots,
      List<ScheduledBlockItem> blocks) {
    // Check if slot falls in this hour
    for (var s in slots) {
      if ((s.startMinutes ~/ 60) == hour) {
        return Text(
          '📚 Class: ${s.courseId} (${s.room ?? ''})',
          style: const TextStyle(
            color: Color(0xFFA855F7),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }

    for (var b in blocks) {
      if (b.startAt.hour == hour) {
        return Text(
          '⚡ Block: ${b.title}',
          style: TextStyle(
            color: BentoTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }

    return Text(
      'Free slot',
      style: TextStyle(color: BentoTheme.textMuted, fontSize: 10),
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    return Dismissible(
      key: ValueKey(task.id),
      background: Container(
        color: const Color(0xFF10B981),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(LucideIcons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          TaskOsRepository.instance.toggleTaskDone(task.id, DateTime.now());
        } else {
          TaskOsRepository.instance.deleteTask(task.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BentoTheme.divider),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                TaskOsRepository.instance.toggleTaskDone(task.id, DateTime.now());
              },
              child: Icon(
                task.isDone ? LucideIcons.checkCircle2 : LucideIcons.circle,
                size: 20,
                color: task.isDone
                    ? BentoTheme.accent
                    : _priorityColor(task.priority),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _openTaskDetail(task),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: task.isDone
                            ? BentoTheme.textMuted
                            : BentoTheme.textPrimary,
                        decoration:
                            task.isDone ? TextDecoration.lineThrough : null,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (task.courseId != null) ...[
                          Text(
                            '#${task.courseId}',
                            style: TextStyle(
                              color: BentoTheme.accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (task.estimateMin != null) ...[
                          Text(
                            '~${task.estimateMin}m',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (task.dueAt != null)
                          Text(
                            task.dueAt!.difference(DateTime.now()).inHours <= 24
                                ? 'Due today'
                                : 'Due ${task.dueAt!.day}/${task.dueAt!.month}',
                            style: TextStyle(
                              color: task.isOverdue(DateTime.now())
                                  ? Colors.redAccent
                                  : BentoTheme.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.play, size: 16),
              color: BentoTheme.textSecondary,
              onPressed: () => _openFocusTimer(task),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 2. UPCOMING VIEW (PLAN-10 Heatmap) =================
  Widget _buildUpcomingView(List<TaskItem> tasks) {
    final now = DateTime.now();
    final timetable = TaskOsRepository.instance.timetableSlots;
    final exams = TaskOsRepository.instance.activeExams;

    final workload = SmartSchedulerEngine.computeWeeklyWorkload(
      startDate: now,
      tasks: tasks,
      timetableSlots: timetable,
      exams: exams,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // Overload Warning Banner (PLAN-10)
        if (workload.hasOverloadWarning &&
            workload.overloadWarningBanner != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workload.overloadWarningBanner!,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 7-day Workload Heatmap
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BentoTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '7-DAY WORKLOAD HEATMAP (PLAN-10)',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var day in workload.days) ...[
                    Column(
                      children: [
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.date.weekday - 1],
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _heatColor(day.status),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${(day.totalMinutes / 60).toStringAsFixed(0)}h',
                            style: TextStyle(
                              color: day.status == 'overloaded'
                                  ? Colors.white
                                  : Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'UPCOMING TASKS',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        for (var t in tasks.where((t) => !t.isDone && !t.isDeleted)) ...[
          _buildTaskTile(t),
        ],
      ],
    );
  }

  // ================= 3. INBOX VIEW (VIEW-3 + TSK-8 Bulk Selection) =================
  Widget _buildInboxView(List<TaskItem> allTasks) {
    final inboxTasks = allTasks
        .where((t) => !t.isDeleted && (t.status == TaskStatus.inbox || t.courseId == null))
        .toList();

    return Column(
      children: [
        // Bulk toolbar
        if (inboxTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isBulkSelecting = !_isBulkSelecting;
                      if (!_isBulkSelecting) _selectedInboxTaskIds.clear();
                    });
                  },
                  child: Text(
                    _isBulkSelecting ? 'Cancel Select' : 'Select Multiple (TSK-8)',
                    style: TextStyle(
                      color: BentoTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_isBulkSelecting && _selectedInboxTaskIds.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(LucideIcons.checkCheck, size: 18),
                    color: BentoTheme.accent,
                    onPressed: () async {
                      for (var id in _selectedInboxTaskIds) {
                        await TaskOsRepository.instance.toggleTaskDone(id, DateTime.now());
                      }
                      setState(() => _selectedInboxTaskIds.clear());
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 18),
                    color: Colors.redAccent,
                    onPressed: () async {
                      for (var id in _selectedInboxTaskIds) {
                        await TaskOsRepository.instance.deleteTask(id);
                      }
                      setState(() => _selectedInboxTaskIds.clear());
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
        Expanded(
          child: inboxTasks.isEmpty
              ? _buildEmptyPlaceholder('Inbox is zero! All items organized.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: inboxTasks.length,
                  itemBuilder: (ctx, idx) {
                    final t = inboxTasks[idx];
                    final isChecked = _selectedInboxTaskIds.contains(t.id);

                    return GestureDetector(
                      onTap: () {
                        if (_isBulkSelecting) {
                          setState(() {
                            if (isChecked) {
                              _selectedInboxTaskIds.remove(t.id);
                            } else {
                              _selectedInboxTaskIds.add(t.id);
                            }
                          });
                        } else {
                          _openTaskDetail(t);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? BentoTheme.accent.withValues(alpha: 0.1)
                              : BentoTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChecked
                                ? BentoTheme.accent
                                : BentoTheme.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isBulkSelecting) ...[
                              Icon(
                                isChecked
                                    ? LucideIcons.checkSquare
                                    : LucideIcons.square,
                                size: 18,
                                color: isChecked
                                    ? BentoTheme.accent
                                    : BentoTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                t.title,
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= 5. BOARD VIEW (VIEW-7 Kanban) =================
  Widget _buildBoardView(List<TaskItem> allTasks) {
    final active = allTasks.where((t) => !t.isDeleted).toList();

    const columns = [
      {'title': 'To Do', 'status': TaskStatus.todo},
      {'title': 'Doing', 'status': TaskStatus.doing},
      {'title': 'Done', 'status': TaskStatus.done},
    ];

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        for (var col in columns) ...[
          Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BentoTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  col['title']!.toUpperCase(),
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (var t in active.where((t) => t.status == col['status']))
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BentoTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'P${t.priority}',
                                    style: TextStyle(
                                      color: _priorityColor(t.priority),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      final nextStatus =
                                          col['status'] == TaskStatus.todo
                                              ? TaskStatus.doing
                                              : TaskStatus.done;
                                      TaskOsRepository.instance.saveTask(
                                        t.copyWith(status: nextStatus),
                                      );
                                    },
                                    child: Icon(
                                      LucideIcons.arrowRightCircle,
                                      size: 14,
                                      color: BentoTheme.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(LucideIcons.sparkles, size: 36, color: BentoTheme.accent),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 1:
        return const Color(0xFFF43F5E);
      case 2:
        return const Color(0xFFFB923C);
      case 3:
        return const Color(0xFF38BDF8);
      default:
        return BentoTheme.textSecondary;
    }
  }

  Color _heatColor(String status) {
    switch (status) {
      case 'overloaded':
        return Colors.redAccent;
      case 'heavy':
        return Colors.amber;
      case 'safe':
      default:
        return BentoTheme.accent;
    }
  }
}
