import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/motion/animated_strikethrough.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/motion/SHealthCelebrationOverlay.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

/// Flagship task card adhering to Apple iOS 18 / ColorOS 15 physics.
class AnimatedTaskOsTile extends StatefulWidget {
  final TaskItem task;
  final CourseItem? course;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final VoidCallback? onDelete;
  final VoidCallback? onScheduleToday;
  final VoidCallback? onStartFocus;
  final bool isInbox;

  const AnimatedTaskOsTile({
    super.key,
    required this.task,
    this.course,
    required this.onTap,
    required this.onToggleDone,
    this.onDelete,
    this.onScheduleToday,
    this.onStartFocus,
    this.isInbox = false,
  });

  @override
  State<AnimatedTaskOsTile> createState() => _AnimatedTaskOsTileState();
}

class _AnimatedTaskOsTileState extends State<AnimatedTaskOsTile>
    with TickerProviderStateMixin {
  late final AnimationController _completionController;
  late final AnimationController _burstController;
  late final Animation<double> _checkScaleAnimation;
  late final Animation<double> _collapseAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Elastic spring bounce (mass: 0.8, stiffness: 500.0, damping: 18.0)
    // Underdamped overshooting to 1.18x before settling at 1.0x
    _checkScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(CurvedAnimation(
      parent: _completionController,
      curve: const Interval(0.0, 0.50),
    ));

    _collapseAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _completionController,
        curve: const Interval(0.55, 1.0, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _completionController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _completionController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _handleCheckboxTap() async {
    final isDone = widget.task.status == TaskStatus.done;
    if (isDone) {
      // Uncompleting is instantaneous
      HapticFeedback.selectionClick();
      widget.onToggleDone();
      return;
    }

    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    // Phase 4: Double-tap celebratory haptic feedback (medium then light after 80ms)
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.lightImpact();
    });

    _burstController.forward(from: 0.0);
    await _completionController.forward();
    if (mounted) {
      widget.onToggleDone();
      _completionController.reset();
      setState(() => _isCompleting = false);
    }
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return const Color(0xFFEF4444); // Red
      case TaskPriority.high:
        return const Color(0xFFF97316); // Orange
      case TaskPriority.medium:
        return const Color(0xFFFACC15); // Yellow
      case TaskPriority.low:
      default:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  String _priorityBadgeText(int priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 'P1';
      case TaskPriority.high:
        return 'P2';
      case TaskPriority.medium:
        return 'P3';
      case TaskPriority.low:
      default:
        return 'P4';
    }
  }

  Color _getCourseColor() {
    if (widget.course != null) {
      try {
        return Color(int.parse(
          widget.course!.colorHex.replaceFirst('#', '0xFF'),
        ));
      } catch (_) {}
    }
    return BentoTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isDone = widget.task.status == TaskStatus.done || _isCompleting;
    final isOverdue = widget.task.isOverdue(now) && !isDone;
    final priorityColor = _priorityColor(widget.task.priority);
    final courseColor = _getCourseColor();

    final subtasksDone =
        widget.task.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = widget.task.subtasks.length;

    Widget cardBody = RepaintBoundary(
      child: PressScale(
        minScale: 0.965,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: isDone
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue
                  ? colorScheme.error
                  : colorScheme.outlineVariant,
              width: isOverdue ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Row: Checkbox, Title, and Trailing Quick-Focus
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Morphing Interactive Checkbox (28dp circle -> squircle) with 12-particle burst
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleCheckboxTap,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, top: 0),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // 12-Particle Radial Burst
                          AnimatedBuilder(
                            animation: _burstController,
                            builder: (context, _) {
                              if (_burstController.value <= 0.01 || _burstController.value >= 1.0) {
                                return const SizedBox(width: 44, height: 44);
                              }
                              return SizedBox(
                                width: 44,
                                height: 44,
                                child: CustomPaint(
                                  painter: CelebrationBurstPainter(
                                    progress: _burstController.value,
                                    burstColor: colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Morphing Checkbox Container
                          AnimatedBuilder(
                            animation: _checkScaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _isCompleting
                                    ? _checkScaleAnimation.value
                                    : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(isDone ? 8 : 14),
                                    color: isDone
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isDone
                                          ? colorScheme.primary
                                          : priorityColor,
                                      width: 2.0,
                                    ),
                                    boxShadow: isDone
                                        ? [
                                            BoxShadow(
                                              color: colorScheme.primary.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isDone
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: colorScheme.onPrimary,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Title with AnimatedStrikethrough
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedStrikethrough(
                          text: widget.task.title,
                          isDone: isDone,
                          strikeColor: colorScheme.primary,
                          style: TextStyle(
                            color: isDone
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                            fontSize: 14.5,
                            fontWeight: isDone
                                ? FontWeight.normal
                                : FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (widget.task.notes != null &&
                            widget.task.notes!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.task.notes!,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Trailing 1-tap quick focus button
                  if (widget.onStartFocus != null && !isDone) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onStartFocus!();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.timer,
                          size: 14,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Rich Metadata Strip
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Priority Badge (P1..P4)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: priorityColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _priorityBadgeText(widget.task.priority),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Course Badge (e.g. #CS302)
                  if (widget.task.courseId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: courseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: courseColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.hash, size: 10, color: courseColor),
                          const SizedBox(width: 2),
                          Text(
                            widget.task.courseId!,
                            style: TextStyle(
                              color: courseColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Due Date/Time Badge
                  if (widget.task.dueAt != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? AppColors.error.withValues(alpha: 0.18)
                            : BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOverdue
                              ? AppColors.error.withValues(alpha: 0.5)
                              : BentoTheme.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOverdue
                                ? LucideIcons.alertTriangle
                                : LucideIcons.clock,
                            size: 10,
                            color: isOverdue
                                ? AppColors.error
                                : BentoTheme.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.task.hasDueTime
                                ? DateFormat('E HH:mm').format(widget.task.dueAt!)
                                : DateFormat('E, d MMM').format(widget.task.dueAt!),
                            style: TextStyle(
                              color: isOverdue
                                  ? AppColors.error
                                  : BentoTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: isOverdue
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Estimate vs Actual Min
                  if (widget.task.estimateMin != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.task.actualMin > 0
                            ? '~${widget.task.estimateMin}m (${widget.task.actualMin}m spent)'
                            : '~${widget.task.estimateMin}m',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  // Subtasks Progress (e.g. 2/4)
                  if (totalSubtasks > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: subtasksDone == totalSubtasks
                            ? AppColors.success.withValues(alpha: 0.15)
                            : BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.listTodo,
                            size: 10,
                            color: subtasksDone == totalSubtasks
                                ? AppColors.success
                                : BentoTheme.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$subtasksDone/$totalSubtasks',
                            style: TextStyle(
                              color: subtasksDone == totalSubtasks
                                  ? AppColors.success
                                  : BentoTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tags
                  for (var tag in widget.task.tags.take(2)) ...[
                    Text(
                      '@$tag',
                      style: TextStyle(
                        color: BentoTheme.accent.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // If collapsing during completion animation:
    if (_isCompleting) {
      cardBody = SizeTransition(
        sizeFactor: _collapseAnimation,
        axisAlignment: 0.0,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: cardBody,
        ),
      );
    }

    // Wrap in Dismissible for physical swipe actions
    return Dismissible(
      key: ValueKey('dismiss_${widget.task.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: widget.isInbox ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              widget.isInbox ? LucideIcons.calendarDays : LucideIcons.check,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isInbox ? 'Schedule Today' : 'Complete',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 8),
            Icon(LucideIcons.trash2, color: Colors.white, size: 22),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          if (widget.isInbox && widget.onScheduleToday != null) {
            widget.onScheduleToday!();
          } else {
            _handleCheckboxTap();
          }
          return false; // Handled internally
        } else if (direction == DismissDirection.endToStart) {
          HapticFeedback.mediumImpact();
          widget.onDelete?.call();
          return true;
        }
        return false;
      },
      child: cardBody,
    );
  }
}
