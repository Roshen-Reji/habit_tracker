import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/core/motion/animated_metric_ticker.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/attendance_gpa_engine.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class TaskAnalyticsPage extends StatelessWidget {
  const TaskAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "TASK & ACADEMIC ANALYTICS",
          style: TextStyle(
            color: AppColors.textPrimary,
            letterSpacing: 2,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: BentoTheme.accent),
      ),
      body: ListenableBuilder(
        listenable: TaskOsRepository.instance,
        builder: (context, _) {
          final tasks = TaskOsRepository.instance.activeTasks;
          final courses = TaskOsRepository.instance.activeCourses;
          final sessionLogs = TaskOsRepository.instance.sessionLogsNotifier.value;
          final habits = TaskOsRepository.instance.activeHabits;
          final focusLogs = TaskOsRepository.instance.focusLogs;

          // Legacy goals if open
          List<Goal> legacyGoals = [];
          if (Hive.isBoxOpen('mission_box_v4')) {
            try {
              legacyGoals = Hive.box<Goal>('mission_box_v4').values.toList();
            } catch (_) {}
          }

          final completedTasks =
              tasks.where((t) => t.status == TaskStatus.done).length;
          final totalTasks = tasks.length;
          final taskRate = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

          final totalFocusMin =
              focusLogs.fold<int>(0, (sum, f) => sum + f.actualMin);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Master Card
                _buildOverallProgressCard(
                  taskRate,
                  completedTasks,
                  totalTasks,
                  totalFocusMin,
                ),
                const SizedBox(height: 20),

                // 4-Pillar Stat Grid
                _buildMetricPillars(
                  completedTasks: completedTasks,
                  totalFocusMin: totalFocusMin,
                  activeHabitsCount: habits.length,
                  coursesCount: courses.length,
                ),
                const SizedBox(height: 24),

                // Course Attendance Section
                if (courses.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(LucideIcons.graduationCap,
                          size: 16, color: BentoTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        "ACADEMIC ATTENDANCE HEALTH",
                        style: TextStyle(
                          color: BentoTheme.accent,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCourseAttendanceList(courses, sessionLogs),
                  const SizedBox(height: 24),
                ],

                // Habit Streaks Section
                if (habits.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(LucideIcons.flame,
                          size: 16, color: Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Text(
                        "FORGIVING HABIT STREAKS",
                        style: TextStyle(
                          color: BentoTheme.accent,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHabitStreaks(habits),
                  const SizedBox(height: 24),
                ],

                // Legacy Goals Radar Chart (if available)
                if (legacyGoals.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(LucideIcons.radar,
                          size: 16, color: BentoTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        "MISSION CATEGORY FOCUS",
                        style: TextStyle(
                          color: BentoTheme.accent,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryBreakdown(legacyGoals),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallProgressCard(
    double rate,
    int completed,
    int total,
    int focusMin,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BentoTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 96,
            width: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: rate.clamp(0.0, 1.0),
                  strokeWidth: 9,
                  backgroundColor: BentoTheme.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(BentoTheme.accent),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${(rate * 100).toInt()}%",
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "DONE",
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 9,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Task Completion Velocity",
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "$completed of $total Tasks Finished",
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.timer, size: 13, color: BentoTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      "$focusMin min focus logged",
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPillars({
    required int completedTasks,
    required int totalFocusMin,
    required int activeHabitsCount,
    required int coursesCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: "Tasks Done",
            value: completedTasks,
            icon: LucideIcons.checkCheck,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: "Focus Time",
            value: totalFocusMin,
            suffix: "m",
            icon: LucideIcons.hourglass,
            color: const Color(0xFF38BDF8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: "Active Habits",
            value: activeHabitsCount,
            icon: LucideIcons.sparkles,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: "Courses",
            value: coursesCount,
            icon: LucideIcons.bookOpen,
            color: const Color(0xFFA855F7),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required num value,
    String suffix = '',
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BentoTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          AnimatedMetricTicker(
            value: value,
            suffix: suffix,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseAttendanceList(
      List<CourseItem> courses, List<ClassSessionLog> logs) {
    return Column(
      children: courses.map((course) {
        final stats = AttendanceGpaEngine.calculateAttendanceStats(
          course: course,
          sessionLogs: logs,
        );

        final color = Color(int.parse(
          course.colorHex.replaceFirst('#', '0xFF'),
        ));

        final isSafe = stats.status == AttendanceStatus.safe;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${course.code} · ${course.name}",
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${stats.attendancePercentage.toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: isSafe ? AppColors.success : AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressBarX(
                value: (stats.attendancePercentage / 100.0).clamp(0.0, 1.0),
                color: isSafe ? AppColors.success : AppColors.error,
                height: 5,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Attended: ${stats.attendedClasses}/${stats.totalClasses} classes",
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    stats.statusMessage,
                    style: TextStyle(
                      color: isSafe ? BentoTheme.accent : AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHabitStreaks(List<ForgivingHabitItem> habits) {
    return Column(
      children: habits.map((habit) {
        final streak = habit.completedDatesIso.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BentoTheme.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${habit.freezesLeft} streak freeze(s) available",
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(LucideIcons.flame,
                      size: 16, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text(
                    "$streak days",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryBreakdown(List<Goal> goals) {
    Map<GoalCategory, int> categoryCounts = {};
    for (var cat in GoalCategory.values) {
      categoryCounts[cat] = 0;
    }
    for (var g in goals) {
      categoryCounts[g.category] = (categoryCounts[g.category] ?? 0) + 1;
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              radarBorderData: BorderSide(color: BentoTheme.divider),
              tickBorderData: const BorderSide(color: Colors.transparent),
              gridBorderData: BorderSide(
                color: BentoTheme.accent.withValues(alpha: 0.2),
                width: 1,
              ),
              titlePositionPercentageOffset: 0.1,
              getTitle: (index, angle) {
                final cat = GoalCategory.values[index];
                return RadarChartTitle(
                  text: cat.name.toUpperCase(),
                  angle: angle,
                  positionPercentageOffset: 0.2,
                );
              },
              titleTextStyle: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              dataSets: [
                RadarDataSet(
                  fillColor: BentoTheme.accent.withValues(alpha: 0.3),
                  borderColor: BentoTheme.accent,
                  entryRadius: 3,
                  dataEntries: GoalCategory.values.map((cat) {
                    return RadarEntry(
                      value: (categoryCounts[cat] ?? 0).toDouble(),
                    );
                  }).toList(),
                  borderWidth: 2,
                ),
              ],
            ),
            duration: const Duration(milliseconds: 320),
          ),
        ),
      ],
    );
  }
}
