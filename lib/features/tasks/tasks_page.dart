import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/features/tasks/widgets/task_action_pill.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/smart_scheduler_engine.dart';
import 'package:habit_tracker/features/tasks/engine/task_urgency_engine.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/task_analytics_page.dart';
import 'package:habit_tracker/features/tasks/widgets/academic_hub_view.dart';
import 'package:habit_tracker/features/tasks/widgets/animated_task_os_tile.dart';
import 'package:habit_tracker/features/tasks/widgets/focus_timer_sheet.dart';
import 'package:habit_tracker/features/tasks/widgets/quick_add_nl_bar.dart';
import 'package:habit_tracker/features/tasks/widgets/sliding_workspace_pill_bar.dart';
import 'package:habit_tracker/features/tasks/widgets/smart_plan_banner.dart';
import 'package:habit_tracker/features/tasks/widgets/task_detail_sheet.dart';
import 'package:habit_tracker/features/tasks/widgets/wakeup_detail_sheet.dart';
import 'package:habit_tracker/features/tasks/widgets/weekly_review_shutdown_sheet.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int _selectedWorkspace = 0; // 0: Today, 1: Upcoming, 2: Inbox, 3: Academic, 4: Board
  late final PageController _pageController;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isFiltering = false;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'p1', 'p2', 'overdue'

  bool _isTimelineMode = false;
  PlanProposalItem? _currentDayPlan;

  final Set<String> _selectedInboxTaskIds = {};
  bool _isBulkSelecting = false;
  int _selectedUpcomingDayOffset = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedWorkspace);
    _initRepository();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  Future<void> _initRepository() async {
    if (!TaskOsRepository.instance.isInitialized) {
      await TaskOsRepository.instance.init();
    }
    await TaskOsRepository.instance.purgePreseededPlaceholders();
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
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onWorkspaceChanged(int index) {
    setState(() => _selectedWorkspace = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
    );
  }

  void _openTaskDetail(TaskItem task) {
    HapticFeedback.selectionClick();
    SpringSheet.show(
      context: context,
      builder: (ctx) => TaskDetailSheet(task: task),
    );
  }

  void _openFocusTimer(TaskItem task, {bool startJust5Min = false}) {
    HapticFeedback.lightImpact();
    SpringSheet.show(
      context: context,
      builder: (ctx) => FocusTimerSheet(
        task: task,
        startJust5Min: startJust5Min,
      ),
    );
  }

  void _openWakeupLog() {
    HapticFeedback.selectionClick();
    SpringSheet.show(
      context: context,
      builder: (ctx) => const WakeupDetailSheet(),
    );
  }

  void _openShutdownRitual() {
    HapticFeedback.lightImpact();
    SpringSheet.show(
      context: context,
      builder: (ctx) => const WeeklyReviewShutdownSheet(isWeeklyReview: false),
    );
  }

  void _openWeeklyReview() {
    HapticFeedback.lightImpact();
    SpringSheet.show(
      context: context,
      builder: (ctx) => const WeeklyReviewShutdownSheet(isWeeklyReview: true),
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

  void _confirmClearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text('Clear All Tasks & Data?',
            style: TextStyle(color: BentoTheme.textPrimary)),
        content: Text(
          'This will remove all tasks, courses, habits, and reset the schedule to a clean state.',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: BentoTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TaskOsRepository.instance.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All tasks and data cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddHabitSheet() {
    final nameController = TextEditingController();
    int targetDays = 5;

    SpringSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: BentoTheme.divider),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BentoTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Forgiving Habit',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Habit name (e.g. Read 20m, DSA Problem)',
                    hintStyle: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: BentoTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Target: $targetDays days / week',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.minusCircle, size: 20),
                          color: BentoTheme.accent,
                          onPressed: targetDays > 1
                              ? () => setSheetState(() => targetDays--)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.plusCircle, size: 20),
                          color: BentoTheme.accent,
                          onPressed: targetDays < 7
                              ? () => setSheetState(() => targetDays++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final habit = ForgivingHabitItem(
                      id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      targetPerWeek: targetDays,
                      freezesLeft: 2,
                    );
                    await TaskOsRepository.instance.saveHabit(habit);
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Add Habit',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
    return ListenableBuilder(
      listenable: TaskOsRepository.instance,
      builder: (context, _) {
        final allTasks = TaskOsRepository.instance.tasksNotifier.value;
        final filteredTasks = _filterTasks(allTasks);
        final rules = TaskOsRepository.instance.rulesNotifier.value;

        final inboxCount = allTasks
            .where((t) => !t.isDeleted && t.status == TaskStatus.inbox)
            .length;

        final completedCount =
            allTasks.where((t) => !t.isDeleted && t.status == TaskStatus.done).length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            toolbarHeight: 48,
            centerTitle: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                Text(
                  'Tasks',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF262626)),
                  ),
                  child: Text(
                    '✓ $completedCount',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // 1. Search Toggle (36x36 circular)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PressScale(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _searchController.clear();
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isSearching
                          ? BentoTheme.accent.withValues(alpha: 0.15)
                          : const Color(0xFF141414),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSearching
                            ? BentoTheme.accent
                            : const Color(0xFF262626),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _isSearching ? LucideIcons.x : Icons.search_rounded,
                      color: _isSearching
                          ? BentoTheme.accent
                          : BentoTheme.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              // 2. Analytics Button (36x36 circular)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PressScale(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransitions.springSlideFade(
                          const TaskAnalyticsPage()),
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF262626)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: BentoTheme.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              // 3. More / Overflow Button (36x36 circular)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF262626)),
                  ),
                  color: const Color(0xFF1A1A1A),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF262626)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: BentoTheme.textPrimary,
                      size: 18,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    switch (val) {
                      case 'filter':
                        setState(() => _isFiltering = !_isFiltering);
                        break;
                      case 'wake':
                        _openWakeupLog();
                        break;
                      case 'autonomy':
                        _cycleAutonomy();
                        break;
                      case 'shutdown':
                        _openShutdownRitual();
                        break;
                      case 'weekly':
                        _openWeeklyReview();
                        break;
                      case 'clear_data':
                        _confirmClearAllData();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'filter',
                      child: Row(
                        children: [
                          Icon(LucideIcons.filter,
                              size: 16,
                              color: _isFiltering
                                  ? BentoTheme.accent
                                  : BentoTheme.textPrimary),
                          const SizedBox(width: 10),
                          Text(_isFiltering ? 'Hide Filter Bar' : 'Filter Tasks'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'wake',
                      child: Row(
                        children: [
                          Icon(Icons.wb_sunny_outlined,
                              size: 16, color: Colors.amber),
                          SizedBox(width: 10),
                          Text('Wake-Up Log'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'autonomy',
                      child: Row(
                        children: [
                          Icon(LucideIcons.slidersHorizontal,
                              size: 16, color: BentoTheme.accent),
                          const SizedBox(width: 10),
                          Text('AI Autonomy: ${rules.autonomyLevel.toUpperCase()}'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'shutdown',
                      child: Row(
                        children: [
                          Icon(LucideIcons.moon,
                              size: 16, color: Colors.white),
                          SizedBox(width: 10),
                          Text('End-of-Day Shutdown Ritual'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'weekly',
                      child: Row(
                        children: [
                          Icon(LucideIcons.calendarCheck,
                              size: 16, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Weekly Review'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'clear_data',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2,
                              size: 16, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          const Text('Clear All Tasks & Data',
                              style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Collapsible Search & Filter Area (AnimatedSize)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSearching) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(
                                  color: BentoTheme.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText:
                                    'Search tasks, notes, #course, @tags...',
                                hintStyle: TextStyle(
                                  color: BentoTheme.textSecondary
                                      .withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: BentoTheme.surface,
                                isDense: true,
                                prefixIcon: Icon(LucideIcons.search,
                                    size: 16, color: BentoTheme.textSecondary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: BentoTheme.divider),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_isFiltering) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                _buildFilterChip('all', 'All Tasks'),
                                _buildFilterChip('p1', '⚡ Urgent (P1)'),
                                _buildFilterChip('p2', '🔥 High (P2)'),
                                _buildFilterChip('overdue', '⚠️ Overdue'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),



                  // Sliding Segmented Workspace Pill Bar
                  SlidingWorkspacePillBar(
                    selectedIndex: _selectedWorkspace,
                    inboxBadgeCount: inboxCount,
                    onWorkspaceSelected: _onWorkspaceChanged,
                  ),

                  // Synchronized Workspace PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() => _selectedWorkspace = page);
                      },
                      children: [
                        _buildTodayView(filteredTasks),
                        _buildUpcomingView(filteredTasks),
                        _buildInboxView(allTasks),
                        const AcademicHubView(),
                        _buildBoardView(allTasks),
                      ],
                    ),
                  ),

                  // Space reserved for docked QuickAddNlBar
                  const SizedBox(height: 16),
                ],
              ),

              // Docked QuickAddNlBar at bottom with bottom clearance
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                    ? (MediaQuery.viewInsetsOf(context).bottom + 4)
                    : (kBottomNavigationBarHeight + 28),
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
      },
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
              ? BentoTheme.accent.withValues(alpha: 0.18)
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

  // ================= 1. TODAY VIEW =================
  Widget _buildTodayView(List<TaskItem> tasks) {
    final now = DateTime.now();
    final openTasks = tasks
        .where((t) => !t.isDone && !t.isDeleted && t.status != TaskStatus.inbox)
        .toList();

    final ranked = rankTasksByUrgency(openTasks, now);
    final nextUpTask = ranked.isNotEmpty ? ranked.first : null;
    final otherTasks = ranked.length > 1 ? ranked.sublist(1) : <TaskItem>[];

    final completedToday =
        tasks.where((t) => t.isDone && !t.isDeleted).toList();

    return RefreshIndicator(
      onRefresh: () async {
        _generatePlan();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
        physics: const BouncingScrollPhysics(),
        children: [
          // Forgiving Habits Horizontal Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildHabitsStrip(),
          ),
          const SizedBox(height: 12),

          // Pinned "Next Up" Hero Card
          if (nextUpTask != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildNextUpHeroCard(nextUpTask, now),
            ),
            const SizedBox(height: 12),
          ],

          // AI Morning Plan Card
          if (_currentDayPlan != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SmartPlanBanner(
                plan: _currentDayPlan!,
                onPlanAccepted: () => setState(() {}),
                onRebalance: () => _generatePlan(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // List vs Visual Timeline Toggle Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'AGENDA',
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
                          _isTimelineMode ? 'List View' : 'Timeline (08–22)',
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
          ),
          const SizedBox(height: 8),

          // Either Visual Timeline or Grouped List
          if (_isTimelineMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildVisualTimeline(now),
            )
          else ...[
            if (openTasks.isEmpty)
              _buildEmptyPlaceholder(
                  'No open tasks scheduled for today. You’re clear! 🎉')
            else ...[
              for (var t in otherTasks) ...[
                AnimatedTaskOsTile(
                  task: t,
                  course: TaskOsRepository.instance.getCourseById(t.courseId ?? ''),
                  onTap: () => _openTaskDetail(t),
                  onToggleDone: () =>
                      TaskOsRepository.instance.toggleTaskDone(t.id, now),
                  onDelete: () => TaskOsRepository.instance.deleteTask(t.id),
                  onStartFocus: () => _openFocusTimer(t),
                ),
              ],
            ],

            // Completed Section
            if (completedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'COMPLETED TODAY (${completedToday.length})',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (var ct in completedToday) ...[
                AnimatedTaskOsTile(
                  task: ct,
                  course: TaskOsRepository.instance.getCourseById(ct.courseId ?? ''),
                  onTap: () => _openTaskDetail(ct),
                  onToggleDone: () =>
                      TaskOsRepository.instance.toggleTaskDone(ct.id, now),
                  onDelete: () => TaskOsRepository.instance.deleteTask(ct.id),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNextUpHeroCard(TaskItem task, DateTime now) {
    final breakdown = computeUrgencyBreakdown(task, now);

    String dueStr = '';
    if (task.dueAt != null) {
      final diff = task.dueAt!.difference(now);
      if (diff.isNegative) {
        dueStr = 'Overdue';
      } else if (diff.inHours < 1) {
        dueStr = 'Due in ${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        dueStr = 'Due in ${diff.inHours}h';
      } else {
        dueStr = 'Due in ${diff.inDays}d';
      }
    }

    final metaParts = <String>[
      if (dueStr.isNotEmpty) dueStr,
      if (task.courseId != null && task.courseId!.isNotEmpty) '#${task.courseId}',
      if (task.estimateMin != null) '~${task.estimateMin}m',
    ];
    final metaText = metaParts.isNotEmpty
        ? metaParts.join(' · ')
        : (breakdown.explanation.isNotEmpty ? breakdown.explanation : 'High priority');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: BentoTheme.accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  '🔥 NEXT UP',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Urgency ${breakdown.totalScore.round()}/100',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metaText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TaskActionPill(
                  label: '5m Start',
                  icon: const Icon(LucideIcons.zap, size: 14),
                  isPrimary: false,
                  height: 36,
                  horizontalPadding: 10,
                  onTap: () => _openFocusTimer(task, startJust5Min: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TaskActionPill(
                  label: 'Focus',
                  icon: const Icon(LucideIcons.timer, size: 14),
                  isPrimary: true,
                  height: 36,
                  horizontalPadding: 10,
                  onTap: () => _openFocusTimer(task),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsStrip() {
    final habits = TaskOsRepository.instance.activeHabits;
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (var h in habits) ...[
            PressScale(
              onTap: () {
                HapticFeedback.lightImpact();
                TaskOsRepository.instance.toggleHabitDay(h.id, todayIso, false);
              },
              onLongPress: () {
                HapticFeedback.heavyImpact();
                TaskOsRepository.instance.toggleHabitDay(h.id, todayIso, true);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: h.isCompletedOn(todayIso)
                      ? BentoTheme.accent.withValues(alpha: 0.16)
                      : (h.isFrozenOn(todayIso)
                          ? Colors.lightBlue.withValues(alpha: 0.16)
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
                      size: 12,
                      color: h.isCompletedOn(todayIso)
                          ? BentoTheme.accent
                          : (h.isFrozenOn(todayIso)
                              ? Colors.lightBlue
                              : BentoTheme.textSecondary),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      h.name,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '🔥${h.completedDatesIso.length}d',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Add Habit Button
          PressScale(
            onTap: _showAddHabitSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 12, color: BentoTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    '+ Habit',
                    style: TextStyle(
                      color: BentoTheme.accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualTimeline(DateTime now) {
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
                        color: BentoTheme.textSecondary,
                        fontSize: 10.5,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10),
    );
  }

  // ================= 2. UPCOMING VIEW =================
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

    final selectedTargetDate =
        now.add(Duration(days: _selectedUpcomingDayOffset));

    final upcomingTasks = tasks.where((t) {
      if (t.isDone || t.isDeleted) return false;
      if (t.dueAt == null) return true;
      return t.dueAt!.year == selectedTargetDate.year &&
          t.dueAt!.month == selectedTargetDate.month &&
          t.dueAt!.day == selectedTargetDate.day;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        // Overload Warning Banner
        if (workload.hasOverloadWarning &&
            workload.overloadWarningBanner != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
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
          ),
          const SizedBox(height: 12),
        ],

        // 7-day Workload Capacity Heatmap Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
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
                  '7-DAY WORKLOAD HEATMAP',
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
                    for (int i = 0; i < workload.days.length; i++) ...[
                      Builder(builder: (context) {
                        final day = workload.days[i];
                        final isSelected = _selectedUpcomingDayOffset == i;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedUpcomingDayOffset = i);
                          },
                          child: Column(
                            children: [
                              Text(
                                [
                                  'M',
                                  'T',
                                  'W',
                                  'T',
                                  'F',
                                  'S',
                                  'S'
                                ][day.date.weekday - 1],
                                style: TextStyle(
                                  color: isSelected
                                      ? BentoTheme.accent
                                      : BentoTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _heatColor(day.status),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.white, width: 2)
                                      : null,
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
                        );
                      }),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'TASKS FOR ${DateFormat('EEEE, d MMM').format(selectedTargetDate).toUpperCase()}',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (upcomingTasks.isEmpty)
          _buildEmptyPlaceholder('No scheduled tasks for this day.')
        else
          for (var t in upcomingTasks) ...[
            AnimatedTaskOsTile(
              task: t,
              course: TaskOsRepository.instance.getCourseById(t.courseId ?? ''),
              onTap: () => _openTaskDetail(t),
              onToggleDone: () =>
                  TaskOsRepository.instance.toggleTaskDone(t.id, now),
              onDelete: () => TaskOsRepository.instance.deleteTask(t.id),
              onStartFocus: () => _openFocusTimer(t),
            ),
          ],
      ],
    );
  }

  // ================= 3. INBOX VIEW =================
  Widget _buildInboxView(List<TaskItem> allTasks) {
    final now = DateTime.now();
    final inboxTasks = allTasks
        .where((t) =>
            !t.isDeleted &&
            (t.status == TaskStatus.inbox ||
                (t.dueAt == null && t.courseId == null && !t.isDone)))
        .toList();

    return Column(
      children: [
        // Multi-select bulk action toolbar
        if (inboxTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isBulkSelecting = !_isBulkSelecting;
                      if (!_isBulkSelecting) _selectedInboxTaskIds.clear();
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BentoTheme.divider),
                    ),
                    child: Text(
                      _isBulkSelecting
                          ? 'Cancel Select'
                          : 'Select Multiple (${_selectedInboxTaskIds.length})',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (_isBulkSelecting && _selectedInboxTaskIds.isNotEmpty) ...[
                  // 1-tap schedule all for today
                  TactileButton(
                    onPressed: () async {
                      for (var id in _selectedInboxTaskIds) {
                        final t = allTasks.firstWhere((item) => item.id == id);
                        await TaskOsRepository.instance.saveTask(
                          t.copyWith(
                            status: TaskStatus.todo,
                            dueAt: now,
                          ),
                        );
                      }
                      setState(() => _selectedInboxTaskIds.clear());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: BentoTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Schedule Today',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(LucideIcons.checkCheck, size: 18),
                    color: BentoTheme.accent,
                    onPressed: () async {
                      for (var id in _selectedInboxTaskIds) {
                        await TaskOsRepository.instance.toggleTaskDone(id, now);
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
              ? _buildEmptyPlaceholder(
                  'Inbox Zero! All items organized and scheduled. 🚀')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
                  physics: const BouncingScrollPhysics(),
                  itemCount: inboxTasks.length,
                  itemBuilder: (ctx, idx) {
                    final t = inboxTasks[idx];
                    final isChecked = _selectedInboxTaskIds.contains(t.id);

                    if (_isBulkSelecting) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              _selectedInboxTaskIds.remove(t.id);
                            } else {
                              _selectedInboxTaskIds.add(t.id);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? BentoTheme.accent.withValues(alpha: 0.12)
                                : BentoTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isChecked
                                  ? BentoTheme.accent
                                  : BentoTheme.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isChecked
                                    ? LucideIcons.checkSquare
                                    : LucideIcons.square,
                                size: 18,
                                color: isChecked
                                    ? BentoTheme.accent
                                    : BentoTheme.textSecondary,
                              ),
                              const SizedBox(width: 10),
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
                    }

                    return AnimatedTaskOsTile(
                      task: t,
                      isInbox: true,
                      course: TaskOsRepository.instance.getCourseById(t.courseId ?? ''),
                      onTap: () => _openTaskDetail(t),
                      onScheduleToday: () async {
                        await TaskOsRepository.instance.saveTask(
                          t.copyWith(status: TaskStatus.todo, dueAt: now),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Scheduled "${t.title}" for Today'),
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onToggleDone: () =>
                          TaskOsRepository.instance.toggleTaskDone(t.id, now),
                      onDelete: () => TaskOsRepository.instance.deleteTask(t.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= 5. BOARD VIEW (KANBAN) =================
  Widget _buildBoardView(List<TaskItem> allTasks) {
    final active = allTasks.where((t) => !t.isDeleted).toList();

    const columns = [
      {'title': 'Inbox', 'status': TaskStatus.inbox},
      {'title': 'To Do', 'status': TaskStatus.todo},
      {'title': 'Doing', 'status': TaskStatus.doing},
      {'title': 'Done', 'status': TaskStatus.done},
      {'title': 'Archived', 'status': TaskStatus.archived},
    ];

    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        for (var col in columns) ...[
          _buildKanbanColumn(
            title: col['title']!,
            status: col['status']!,
            tasks: active.where((t) => t.status == col['status']).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required String status,
    required List<TaskItem> tasks,
  }) {
    return DragTarget<TaskItem>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        final now = DateTime.now();
        final updated = details.data.copyWith(
          status: status,
          completedAt: status == TaskStatus.done ? now : null,
          updatedAt: now,
        );
        TaskOsRepository.instance.saveTask(updated);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          width: 250,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHovered
                ? BentoTheme.accent.withValues(alpha: 0.1)
                : BentoTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHovered ? BentoTheme.accent : BentoTheme.divider,
              width: isHovered ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No items',
                          style: TextStyle(
                            color: BentoTheme.textSecondary
                                .withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: tasks.length,
                        itemBuilder: (ctx, idx) {
                          final t = tasks[idx];
                          return LongPressDraggable<TaskItem>(
                            data: t,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Transform.rotate(
                                angle: 0.04,
                                child: Container(
                                  width: 240,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: BentoTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: BentoTheme.accent),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    t.title,
                                    style: TextStyle(
                                      color: BentoTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildKanbanCard(t, status),
                            ),
                            child: _buildKanbanCard(t, status),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(TaskItem task, String currentStatus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BentoTheme.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openTaskDetail(task),
            child: Text(
              task.title,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'P${task.priority}',
                style: TextStyle(
                  color: _priorityColor(task.priority),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (task.courseId != null) ...[
                const SizedBox(width: 6),
                Text(
                  '#${task.courseId}',
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              // 1-tap forward status pill
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final nextStatus = _nextStatus(currentStatus);
                  TaskOsRepository.instance.saveTask(
                    task.copyWith(status: nextStatus),
                  );
                },
                child: Icon(
                  LucideIcons.arrowRightCircle,
                  size: 15,
                  color: BentoTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nextStatus(String status) {
    switch (status) {
      case TaskStatus.inbox:
        return TaskStatus.todo;
      case TaskStatus.todo:
        return TaskStatus.doing;
      case TaskStatus.doing:
        return TaskStatus.done;
      case TaskStatus.done:
        return TaskStatus.archived;
      case TaskStatus.archived:
      default:
        return TaskStatus.todo;
    }
  }

  Widget _buildEmptyPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(LucideIcons.sparkles, size: 36, color: BentoTheme.accent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
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
