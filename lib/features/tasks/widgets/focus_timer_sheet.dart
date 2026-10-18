import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class FocusTimerSheet extends StatefulWidget {
  final TaskItem task;
  final bool startJust5Min;

  const FocusTimerSheet({
    super.key,
    required this.task,
    this.startJust5Min = false,
  });

  @override
  State<FocusTimerSheet> createState() => _FocusTimerSheetState();
}

class _FocusTimerSheetState extends State<FocusTimerSheet> {
  late int _initialSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  int _interruptions = 0;
  late DateTime _sessionStart;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _initialSeconds = widget.startJust5Min
        ? (5 * 60)
        : ((widget.task.estimateMin ?? 25) * 60);
    _remainingSeconds = _initialSeconds;

    if (widget.startJust5Min) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);
    HapticFeedback.lightImpact();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _completeSession();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _interruptions++;
    });
    HapticFeedback.selectionClick();
  }

  void _resetTimer(int minutes) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _initialSeconds = minutes * 60;
      _remainingSeconds = _initialSeconds;
    });
    HapticFeedback.selectionClick();
  }

  void _completeSession() async {
    HapticFeedback.heavyImpact();
    final sessionEnd = DateTime.now();
    final elapsedMin = (_initialSeconds - _remainingSeconds) ~/ 60;

    final log = FocusSessionLog(
      id: 'focus_${DateTime.now().millisecondsSinceEpoch}',
      taskId: widget.task.id,
      courseId: widget.task.courseId,
      startAt: _sessionStart,
      endAt: sessionEnd,
      plannedMin: _initialSeconds ~/ 60,
      actualMin: elapsedMin > 0 ? elapsedMin : 1,
      interruptions: _interruptions,
    );

    await TaskOsRepository.instance.logFocusSession(log);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Focus session logged: ${log.actualMin}m (+20 XP) for "${widget.task.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = _initialSeconds > 0
        ? (_initialSeconds - _remainingSeconds) / _initialSeconds
        : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: BentoTheme.divider),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: BentoTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          // Task Title
          Text(
            widget.task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.task.courseId != null
                ? '#${widget.task.courseId} · Focus Session'
                : 'Focus Session',
            style: TextStyle(
              color: BentoTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          // Circular Countdown Timer Display
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: BentoTheme.surfaceElevated,
                  color: BentoTheme.accent,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (_interruptions > 0)
                    Text(
                      '$_interruptions pause${_interruptions > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quick presets: 5m (Just 5 Min), 25m (Pomodoro), 50m (Deep Work)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPresetPill(
                label: '⚡ Just 5m',
                isSelected: _initialSeconds == 300,
                onTap: () => _resetTimer(5),
              ),
              const SizedBox(width: 8),
              _buildPresetPill(
                label: '25m Pomodoro',
                isSelected: _initialSeconds == 1500,
                onTap: () => _resetTimer(25),
              ),
              const SizedBox(width: 8),
              _buildPresetPill(
                label: '50m Deep Work',
                isSelected: _initialSeconds == 3000,
                onTap: () => _resetTimer(50),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Main action row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play / Pause
              TactileButton(
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isRunning ? LucideIcons.pause : LucideIcons.play,
                        color: Colors.black,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRunning ? 'Pause' : 'Start Focus',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Finish / Log session button
              TactileButton(
                onPressed: _completeSession,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BentoTheme.divider),
                  ),
                  child: Text(
                    'Done & Log',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildPresetPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? BentoTheme.accent.withValues(alpha: 0.15)
              : BentoTheme.surfaceElevated,
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
}
