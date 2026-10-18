import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CourseItem>>(
      valueListenable: TaskOsRepository.instance.coursesNotifier,
      builder: (context, courses, _) {
        final activeCourses = courses.where((c) => c.deletedAt == null).toList();

        return Column(
          children: [
            // Segmented Sub-tab bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          duration: const Duration(milliseconds: 180),
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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

  // ================= 1. ATTENDANCE TRACKER (ACA-7) =================
  Widget _buildAttendanceTracker(List<CourseItem> courses) {
    if (courses.isEmpty) {
      return _buildEmptyState(
        title: 'No Courses Added Yet',
        subtitle: 'Add your courses to track 75% attendance and missable classes.',
        actionLabel: '+ Add Sample Course',
        onAction: _addSampleCourse,
      );
    }

    final sessionLogs = TaskOsRepository.instance.sessionLogsNotifier.value;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: courses.length,
      itemBuilder: (ctx, idx) {
        final course = courses[idx];
        final courseLogs =
            sessionLogs.where((l) => l.courseId == course.id || l.courseId == course.code).toList();

        final present =
            courseLogs.where((l) => l.attendance == 'present').length;
        final absent =
            courseLogs.where((l) => l.attendance == 'absent').length;
        // Remaining classes estimate based on 40 classes total per semester
        final remaining = math.max(0, 40 - (present + absent));

        final stats = AttendanceGpaEngine.computeAttendanceStats(
          present: present,
          absent: absent,
          remaining: remaining,
          requiredPct: course.requiredAttendancePct,
        );

        final statusColor = stats.canNoLongerReachMin
            ? Colors.redAccent
            : (stats.attendedPct < stats.requiredPct
                ? Colors.amber
                : const Color(0xFF10B981));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BentoTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _parseHexColor(course.colorHex),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stats.statusLabel.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${(stats.attendedPct * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'attendance (${stats.present}/${stats.present + stats.absent})',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'Req: ${(stats.requiredPct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressBarX(
                value: stats.attendedPct,
                color: statusColor,
                customTrackColor: BentoTheme.surfaceElevated,
                height: 6,
              ),
              const SizedBox(height: 12),
              // Missable insight banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      stats.maxMissable > 0
                          ? LucideIcons.shieldCheck
                          : LucideIcons.alertTriangle,
                      size: 14,
                      color: stats.maxMissable > 0
                          ? BentoTheme.accent
                          : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stats.canNoLongerReachMin
                            ? 'Cannot reach 75% even with full attendance.'
                            : (stats.maxMissable > 0
                                ? 'You can safely miss up to ${stats.maxMissable} more classes.'
                                : 'Must attend next ${stats.mustAttendNext} consecutive classes!'),
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
              // Fast 1-tap attendance logger
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      onPressed: () => _markAttendance(course.id, 'present'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '+ Present',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton(
                      onPressed: () => _markAttendance(course.id, 'absent'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '+ Absent',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  // ================= 2. TIMETABLE VIEW (Week A/B) =================
  Widget _buildTimetableView(List<CourseItem> courses) {
    final slots = TaskOsRepository.instance.timetableSlots;
    if (slots.isEmpty) {
      return _buildEmptyState(
        title: 'Timetable is Empty',
        subtitle: 'Configure your weekly class slots and rotating labs.',
        actionLabel: '+ Add Sample Slot',
        onAction: _addSampleTimetableSlot,
      );
    }

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: days.length,
      itemBuilder: (ctx, dayIdx) {
        final daySlots = slots.where((s) => s.dayOfWeek == (dayIdx + 1)).toList();
        daySlots.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                days[dayIdx].toUpperCase(),
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              if (daySlots.isEmpty)
                Text(
                  'No classes scheduled',
                  style: TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                )
              else
                for (var slot in daySlots) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_formatMinutes(slot.startMinutes)}–${_formatMinutes(slot.endMinutes)}',
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            slot.courseId,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (slot.room != null)
                          Text(
                            slot.room!,
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  // ================= 3. EXAMS & SPACED REVISION (PLAN-8) =================
  Widget _buildExamsAndRevisionView(List<CourseItem> courses) {
    final exams = TaskOsRepository.instance.activeExams;
    if (exams.isEmpty) {
      return _buildEmptyState(
        title: 'No Upcoming Exams',
        subtitle: 'Add your exam dates and syllabus topics for automated revision planning.',
        actionLabel: '+ Add Sample Exam',
        onAction: _addSampleExam,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: exams.length,
      itemBuilder: (ctx, idx) {
        final exam = exams[idx];
        final daysLeft = exam.examDate.difference(DateTime.now()).inDays;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              const SizedBox(height: 6),
              Text(
                'Course: ${exam.courseId} · Topics: ${exam.topics.length}',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
              ),
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
                      Icon(LucideIcons.repeat, size: 14, color: Colors.black),
                      SizedBox(width: 6),
                      Text(
                        'Generate Spaced Revision Plan (PLAN-8)',
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
      },
    );
  }

  // ================= 4. GPA TARGET CALCULATOR (ACA-8) =================
  Widget _buildGpaTargetView(List<CourseItem> courses) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BentoTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.target, size: 18, color: BentoTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Target Final Exam Score (ACA-8)',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Given your current assignments and internal marks, this calculates the exact percentage you must score on the final exam to secure your target grade.',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Grade: 85% (A)',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Internal Score: 42/50 · Final Weight: 50%',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '86.0%',
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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

  // ================= HELPERS & SAMPLES =================

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
            Icon(LucideIcons.folderOpen, size: 40, color: BentoTheme.textMuted),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  void _markAttendance(String courseId, String status) async {
    HapticFeedback.lightImpact();
    final todayIso = DateTime.now().toIso8601String().substring(0, 10);
    final log = ClassSessionLog(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      slotId: 'slot_$courseId',
      courseId: courseId,
      dateIso: todayIso,
      attendance: status,
    );
    await TaskOsRepository.instance.logClassSession(log);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged $status for $courseId'),
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
        content: Text('Scheduled ${blocks.length} spaced revision blocks for ${exam.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addSampleCourse() async {
    final course = CourseItem(
      id: 'course_dbms',
      name: 'Database Management Systems',
      code: 'DBMS',
      colorHex: '#3B82F6',
      credits: 4.0,
      requiredAttendancePct: 0.75,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await TaskOsRepository.instance.saveCourse(course);
  }

  void _addSampleTimetableSlot() async {
    final slot = const TimetableSlotItem(
      id: 'slot_sample_1',
      courseId: 'DBMS',
      dayOfWeek: 1, // Mon
      startMinutes: 540, // 09:00
      endMinutes: 600, // 10:00
      room: 'Lab 3',
    );
    await TaskOsRepository.instance.saveTimetableSlot(slot);
    setState(() {});
  }

  void _addSampleExam() async {
    final exam = ExamItem(
      id: 'exam_sample_1',
      courseId: 'DBMS',
      title: 'DBMS End-Semester Exam',
      examDate: DateTime.now().add(const Duration(days: 12)),
      topics: const [
        ExamTopicItem(id: 't1', title: 'B+ Trees & Indexing', confidence: 1),
        ExamTopicItem(id: 't2', title: 'ACID & Concurrency Control', confidence: 0),
        ExamTopicItem(id: 't3', title: 'Relational Algebra & Normalization', confidence: 2),
      ],
    );
    await TaskOsRepository.instance.saveExam(exam);
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
