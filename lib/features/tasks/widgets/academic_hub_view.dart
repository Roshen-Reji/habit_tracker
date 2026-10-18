import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/core/motion/animated_metric_ticker.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/attendance_gpa_engine.dart';
import 'package:habit_tracker/features/tasks/engine/smart_scheduler_engine.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class AcademicHubView extends StatefulWidget {
  const AcademicHubView({super.key});

  @override
  State<AcademicHubView> createState() => _AcademicHubViewState();
}

class _AcademicHubViewState extends State<AcademicHubView> {
  int _subTab = 0; // 0: Attendance, 1: Timetable, 2: Exams, 3: GPA Calculator
  String _activeWeekPattern = 'every'; // 'every', 'weekA', 'weekB'
  int _selectedDayOfWeek = 1; // 1 = Monday

  // GPA Target Calculator Interactive State
  double _targetGradePct = 85.0;
  double _internalScore = 42.0;
  final double _maxInternalScore = 50.0;
  final double _finalExamWeight = 50.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CourseItem>>(
      valueListenable: TaskOsRepository.instance.coursesNotifier,
      builder: (context, courses, _) {
        final activeCourses =
            courses.where((c) => c.deletedAt == null).toList();

        return Column(
          children: [
            // Segmented Sub-tab bar with tactile feedback
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: Row(
                children: [
                  _buildSubTabItem(0, 'Attendance', LucideIcons.userCheck),
                  _buildSubTabItem(1, 'Timetable', LucideIcons.calendar),
                  _buildSubTabItem(2, 'Exams', LucideIcons.graduationCap),
                  _buildSubTabItem(3, 'GPA Target', LucideIcons.target),
                ],
              ),
            ),
            // Body of selected subtab
            Expanded(
              child: _buildSubTabContent(activeCourses),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubTabItem(int index, String label, IconData icon) {
    final isSelected = _subTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _subTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? BentoTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.black : BentoTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabContent(List<CourseItem> courses) {
    switch (_subTab) {
      case 0:
        return _buildAttendanceTracker(courses);
      case 1:
        return _buildTimetableView(courses);
      case 2:
        return _buildExamsAndRevisionView(courses);
      case 3:
      default:
        return _buildGpaTargetView(courses);
    }
  }

  // ================= 1. ATTENDANCE TRACKER =================
  Widget _buildAttendanceTracker(List<CourseItem> courses) {
    final sessionLogs = TaskOsRepository.instance.sessionLogsNotifier.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        // Action Bar (+ Add Course)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'COURSES & ATTENDANCE (${courses.length})',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            GestureDetector(
              onTap: _showAddCourseSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BentoTheme.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 12, color: BentoTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      '+ Add Course',
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
          ],
        ),
        const SizedBox(height: 10),

        if (courses.isEmpty)
          _buildEmptyState(
            title: 'No Courses Added Yet',
            subtitle:
                'Add your academic courses to track 75% attendance and missable classes.',
            actionLabel: '+ Add Course',
            onAction: _showAddCourseSheet,
          )
        else
          for (var course in courses) ...[
            Builder(builder: (ctx) {
              final stats = AttendanceGpaEngine.calculateAttendanceStats(
                course: course,
                sessionLogs: sessionLogs,
              );

              final color = _parseHexColor(course.colorHex);
              final isSafe = stats.status == AttendanceStatus.safe;
              final statusColor = isSafe ? AppColors.success : AppColors.error;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BentoTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${course.code} · ${course.name}',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSafe ? 'SAFE' : 'ATTENTION',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AnimatedMetricTicker.percentage(
                          value: stats.attendancePercentage,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${stats.attendedClasses}/${stats.totalClasses} classes)',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Req: ${course.requiredAttendancePct.round()}%',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBarX(
                      value: (stats.attendancePercentage / 100.0).clamp(0.0, 1.0),
                      color: statusColor,
                      customTrackColor: BentoTheme.surfaceElevated,
                      height: 6,
                    ),
                    const SizedBox(height: 10),
                    // Missable / Must attend banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSafe
                                ? LucideIcons.shieldCheck
                                : LucideIcons.alertTriangle,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              stats.statusMessage,
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tactile 1-tap attendance buttons: Present, Absent, Cancelled
                    Row(
                      children: [
                        Expanded(
                          child: TactileButton(
                            onPressed: () =>
                                _markAttendance(course.id, 'present'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '✓ Present',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TactileButton(
                            onPressed: () =>
                                _markAttendance(course.id, 'absent'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '✕ Absent',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TactileButton(
                            onPressed: () =>
                                _markAttendance(course.id, 'unmarked', status: 'cancelled'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: BentoTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BentoTheme.divider),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Cancelled',
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
      ],
    );
  }

  // ================= 2. TIMETABLE VIEW =================
  Widget _buildTimetableView(List<CourseItem> courses) {
    final slots = TaskOsRepository.instance.timetableSlots;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        // Top control strip: Day selector + Week A/B + Add Slot
        Row(
          children: [
            // Week A/B toggle
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: Row(
                children: [
                  _buildWeekPatternChip('every', 'All'),
                  _buildWeekPatternChip('weekA', 'Week A'),
                  _buildWeekPatternChip('weekB', 'Week B'),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showAddSlotSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BentoTheme.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 12, color: BentoTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      '+ Add Slot',
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
          ],
        ),
        const SizedBox(height: 10),

        // Day of Week Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (int i = 0; i < days.length; i++) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDayOfWeek = i + 1);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDayOfWeek == (i + 1)
                          ? BentoTheme.accent
                          : BentoTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedDayOfWeek == (i + 1)
                            ? BentoTheme.accent
                            : BentoTheme.divider,
                      ),
                    ),
                    child: Text(
                      days[i],
                      style: TextStyle(
                        color: _selectedDayOfWeek == (i + 1)
                            ? Colors.black
                            : BentoTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: _selectedDayOfWeek == (i + 1)
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        Builder(builder: (ctx) {
          final daySlots = slots
              .where((s) => s.dayOfWeek == _selectedDayOfWeek)
              .toList()
            ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

          if (daySlots.isEmpty) {
            return _buildEmptyState(
              title: 'No classes scheduled',
              subtitle: 'Enjoy your free time or add a slot.',
              actionLabel: '+ Add Slot',
              onAction: _showAddSlotSheet,
            );
          }

          return Column(
            children: daySlots.map((slot) {
              final startStr = _formatMinutes(slot.startMinutes);
              final endStr = _formatMinutes(slot.endMinutes);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BentoTheme.divider),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$startStr – $endStr',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (slot.room != null)
                          Text(
                            slot.room!,
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        slot.courseId,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildWeekPatternChip(String key, String label) {
    final isSelected = _activeWeekPattern == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeWeekPattern = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? BentoTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ================= 3. EXAMS & SPACED REVISION =================
  Widget _buildExamsAndRevisionView(List<CourseItem> courses) {
    final exams = TaskOsRepository.instance.activeExams;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UPCOMING EXAMS & REVISION (${exams.length})',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            GestureDetector(
              onTap: _showAddExamSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BentoTheme.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 12, color: BentoTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      '+ Add Exam',
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
          ],
        ),
        const SizedBox(height: 10),

        if (exams.isEmpty)
          _buildEmptyState(
            title: 'No Upcoming Exams',
            subtitle:
                'Add your exam dates and syllabus topics for automated revision planning.',
            actionLabel: '+ Add Exam',
            onAction: _showAddExamSheet,
          )
        else
          for (var exam in exams) ...[
            Builder(builder: (ctx) {
              final daysLeft =
                  exam.examDate.difference(DateTime.now()).inDays;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BentoTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exam.title,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: BentoTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            daysLeft <= 0 ? 'Today' : 'in ${daysLeft}d',
                            style: TextStyle(
                              color: BentoTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${exam.courseId} · Venue: ${exam.venue ?? 'TBA'}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Topic confidence pills
                    Text(
                      'Syllabus Topics (Tap confidence to recalculate revision):',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    for (var topic in exam.topics) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                topic.title,
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // Interactive Confidence Level Selector (0..3)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int lvl = 0; lvl <= 3; lvl++) ...[
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      TaskOsRepository.instance
                                          .updateExamTopicConfidence(
                                        exam.id,
                                        topic.id,
                                        lvl,
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 3),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: topic.confidence == lvl
                                            ? _confidenceColor(lvl)
                                            : BentoTheme.surfaceElevated,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _confidenceLabel(lvl),
                                        style: TextStyle(
                                          color: topic.confidence == lvl
                                              ? Colors.black
                                              : BentoTheme.textSecondary,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Spaced Repetition trigger
                    TactileButton(
                      onPressed: () => _generateRevisionSchedule(exam),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: BentoTheme.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.repeat,
                                size: 14, color: Colors.black),
                            SizedBox(width: 6),
                            Text(
                              'Generate Spaced Revision Blocks',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
      ],
    );
  }

  Color _confidenceColor(int lvl) {
    switch (lvl) {
      case 0:
        return const Color(0xFFEF4444); // New
      case 1:
        return const Color(0xFFF97316); // Weak
      case 2:
        return const Color(0xFFFACC15); // Good
      case 3:
      default:
        return const Color(0xFF10B981); // Mastered
    }
  }

  String _confidenceLabel(int lvl) {
    switch (lvl) {
      case 0:
        return 'New';
      case 1:
        return 'Weak';
      case 2:
        return 'Good';
      case 3:
      default:
        return 'Pro';
    }
  }

  // ================= 4. GPA TARGET CALCULATOR =================
  Widget _buildGpaTargetView(List<CourseItem> courses) {
    // Calculate required final exam score:
    // (Target - InternalScore) / (FinalWeight / 100)
    final requiredScore = ((_targetGradePct - _internalScore) /
            (_finalExamWeight / 100.0))
        .clamp(0.0, 100.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BentoTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.target,
                        size: 20, color: BentoTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Target Final Exam Score',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Adjust your target grade and internal marks to calculate the exact percentage required on the final exam.',
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Interactive Sliders
                Text(
                  'Desired Final Grade: ${_targetGradePct.round()}%',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _targetGradePct,
                  min: 50.0,
                  max: 100.0,
                  activeColor: BentoTheme.accent,
                  inactiveColor: BentoTheme.surfaceElevated,
                  onChanged: (val) => setState(() => _targetGradePct = val),
                ),

                const SizedBox(height: 10),
                Text(
                  'Internal Score: ${_internalScore.round()} / ${_maxInternalScore.round()}',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _internalScore,
                  min: 0.0,
                  max: _maxInternalScore,
                  activeColor: BentoTheme.accent,
                  inactiveColor: BentoTheme.surfaceElevated,
                  onChanged: (val) => setState(() => _internalScore = val),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Required Final Score',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              requiredScore > 100.0
                                  ? 'Unattainable'
                                  : 'Target ${_targetGradePct.round()}% Grade',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedMetricTicker.percentage(
                        value: requiredScore,
                        style: TextStyle(
                          color: requiredScore > 90.0
                              ? Colors.redAccent
                              : BentoTheme.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= MODALS & ACTIONS =================

  void _showAddCourseSheet() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    double requiredPct = 75.0;

    SpringSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                  'Add New Course',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Course Code (e.g. CS301)',
                    hintStyle: TextStyle(color: BentoTheme.textSecondary),
                    filled: true,
                    fillColor: BentoTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Course Name (e.g. Operating Systems)',
                    hintStyle: TextStyle(color: BentoTheme.textSecondary),
                    filled: true,
                    fillColor: BentoTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    if (code.isEmpty || name.isEmpty) return;
                    final course = CourseItem(
                      id: 'course_${code.toLowerCase()}',
                      name: name,
                      code: code,
                      colorHex: '#38BDF8',
                      requiredAttendancePct: requiredPct,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await TaskOsRepository.instance.saveCourse(course);
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
                      'Save Course',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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

  void _showAddSlotSheet() {
    final roomCtrl = TextEditingController();
    String? selectedCourse = TaskOsRepository.instance.activeCourses.isNotEmpty
        ? TaskOsRepository.instance.activeCourses.first.code
        : 'CS301';

    SpringSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final courses = TaskOsRepository.instance.activeCourses;

          return Container(
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                  'Add Timetable Slot',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (courses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedCourse,
                    dropdownColor: BentoTheme.surface,
                    style: TextStyle(color: BentoTheme.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: BentoTheme.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: courses.map((c) {
                      return DropdownMenuItem(
                        value: c.code,
                        child: Text('${c.code} · ${c.name}'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setSheetState(() => selectedCourse = val),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: roomCtrl,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Room / Lab (e.g. C-204)',
                    hintStyle: TextStyle(color: BentoTheme.textSecondary),
                    filled: true,
                    fillColor: BentoTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: () async {
                    if (selectedCourse == null) return;
                    final slot = TimetableSlotItem(
                      id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
                      courseId: selectedCourse!,
                      dayOfWeek: _selectedDayOfWeek,
                      startMinutes: 540, // 09:00
                      endMinutes: 600, // 10:00
                      room: roomCtrl.text.trim().isNotEmpty
                          ? roomCtrl.text.trim()
                          : null,
                    );
                    await TaskOsRepository.instance.saveTimetableSlot(slot);
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
                      'Save Slot',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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

  void _showAddExamSheet() {
    final titleCtrl = TextEditingController();
    String selectedCourse = TaskOsRepository.instance.activeCourses.isNotEmpty
        ? TaskOsRepository.instance.activeCourses.first.code
        : 'CS301';

    SpringSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                  'Add Upcoming Exam',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Exam Title (e.g. Midterm 1)',
                    hintStyle: TextStyle(color: BentoTheme.textSecondary),
                    filled: true,
                    fillColor: BentoTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    final exam = ExamItem(
                      id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
                      courseId: selectedCourse,
                      title: title,
                      examDate: DateTime.now().add(const Duration(days: 14)),
                      topics: const [
                        ExamTopicItem(id: 'tp1', title: 'Chapter 1 & 2', confidence: 1),
                        ExamTopicItem(id: 'tp2', title: 'Chapter 3 & 4', confidence: 0),
                      ],
                    );
                    await TaskOsRepository.instance.saveExam(exam);
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
                      'Save Exam',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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

  void _markAttendance(String courseId, String attendance,
      {String status = 'scheduled'}) async {
    HapticFeedback.lightImpact();
    final todayIso = DateTime.now().toIso8601String().substring(0, 10);
    await TaskOsRepository.instance.markAttendance(
      slotId: 'slot_$courseId',
      courseId: courseId,
      dateIso: todayIso,
      attendance: attendance,
      status: status,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged $attendance for $courseId'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _generateRevisionSchedule(ExamItem exam) {
    HapticFeedback.lightImpact();
    final blocks = SmartSchedulerEngine.generateExamRevisionSchedule(
      exam: exam,
      now: DateTime.now(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Scheduled ${blocks.length} spaced revision blocks for ${exam.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.folderOpen,
                size: 40, color: BentoTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TactileButton(
              onPressed: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return BentoTheme.accent;
    }
  }
}
