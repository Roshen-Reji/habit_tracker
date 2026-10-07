import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/features/wearables/data/wake_service.dart';

class WakeupDetailSheet extends StatefulWidget {
  final Goal goal;

  const WakeupDetailSheet({super.key, required this.goal});

  @override
  State<WakeupDetailSheet> createState() => _WakeupDetailSheetState();
}

class _WakeupDetailSheetState extends State<WakeupDetailSheet> {
  late int _targetMinutes;
  late int _graceMinutes;
  late String _direction;

  @override
  void initState() {
    super.initState();
    _targetMinutes = widget.goal.targetMinutes ?? 300;
    _graceMinutes = widget.goal.graceMinutes ?? 0;
    _direction = (widget.goal.metricOp == '<=') ? 'by' : 'from';
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final dt = DateTime(2026, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayLog = WakeLogRepository.instance.getLog(todayKey);
    final allLogs = WakeLogRepository.instance.getAllLogs().take(30).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.sunMedium,
                      color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Wake-Up',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Target: ${_formatMinutes(_targetMinutes)} · Streak: ${widget.goal.streakCount} days',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Today's Status Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: todayLog != null
                      ? (todayLog.onTime ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        todayLog != null
                            ? DateFormat('h:mm a').format(todayLog.wakeAt)
                            : 'Not logged yet',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (todayLog != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          todayLog.onTime ? 'On time ✓ (+5 XP)' : 'Missed ✕',
                          style: TextStyle(
                            color: todayLog.onTime
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BentoTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(LucideIcons.penLine, size: 14),
                    label: Text(todayLog != null ? 'Edit Time' : 'Log Time',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () async {
                      final now = DateTime.now();
                      final initialTime = todayLog != null
                          ? TimeOfDay(
                              hour: todayLog.wakeAt.hour,
                              minute: todayLog.wakeAt.minute)
                          : TimeOfDay.now();

                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (picked != null) {
                        final wakeAt = DateTime(now.year, now.month, now.day,
                            picked.hour, picked.minute);
                        await WakeService.instance
                            .logWake(wakeAt, source: 'manual');
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Target Settings Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.clock, color: Colors.white70),
              title: const Text('Change Target Time',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(_formatMinutes(_targetMinutes),
                  style: TextStyle(color: BentoTheme.accent, fontSize: 12)),
              trailing: const Icon(LucideIcons.chevronRight,
                  color: Colors.white38, size: 16),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: _targetMinutes ~/ 60,
                    minute: _targetMinutes % 60,
                  ),
                );
                if (picked != null) {
                  final newTarget = picked.hour * 60 + picked.minute;
                  await WakeService.instance.createOrUpdateWakeupTask(
                    targetMinutes: newTarget,
                    graceMinutes: _graceMinutes,
                    direction: _direction,
                  );
                  setState(() {
                    _targetMinutes = newTarget;
                  });
                }
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),

            // Direction Selector Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.compass,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wake Rule Direction',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14)),
                            Text(
                              _direction == 'by'
                                  ? 'Ticked if I wake at or before ${_formatMinutes(_targetMinutes)}'
                                  : 'Ticked if I wake at or after ${_formatMinutes(_targetMinutes)}',
                              style: TextStyle(
                                  color: BentoTheme.accent, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('Waking by (at or before)')),
                          selected: _direction == 'by',
                          selectedColor:
                              BentoTheme.accent.withValues(alpha: 0.25),
                          onSelected: (selected) async {
                            if (selected) {
                              setState(() => _direction = 'by');
                              await WakeService.instance
                                  .createOrUpdateWakeupTask(
                                targetMinutes: _targetMinutes,
                                graceMinutes: _graceMinutes,
                                direction: 'by',
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                              child: Text('Waking from (at or after)')),
                          selected: _direction == 'from',
                          selectedColor:
                              BentoTheme.accent.withValues(alpha: 0.25),
                          onSelected: (selected) async {
                            if (selected) {
                              setState(() => _direction = 'from');
                              await WakeService.instance
                                  .createOrUpdateWakeupTask(
                                targetMinutes: _targetMinutes,
                                graceMinutes: _graceMinutes,
                                direction: 'from',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),

            const SizedBox(height: 16),
            Text(
              'LAST 30 DAYS HISTORY',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),

            if (allLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No wake-up history recorded yet.',
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12)),
              )
            else
              ...allLogs.map((log) {
                DateTime d;
                try {
                  final parts = log.dayKey.split('-');
                  d = DateTime(int.parse(parts[0]), int.parse(parts[1]),
                      int.parse(parts[2]));
                } catch (_) {
                  d = log.wakeAt;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              log.onTime ? AppColors.success : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('EEE, d MMM').format(d),
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('h:mm a').format(log.wakeAt),
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        log.onTime ? '✓' : '✕',
                        style: TextStyle(
                          color:
                              log.onTime ? AppColors.success : AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
