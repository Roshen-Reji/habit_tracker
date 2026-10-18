import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

/// Dose slot representation for blister pack foil interaction
class _DoseSlotData {
  final Medicine medicine;
  final int timeMinutes;
  final DateTime scheduledTime;
  final MedicineLog? log;

  bool get isTaken => log != null && log!.status == 'taken';

  const _DoseSlotData({
    required this.medicine,
    required this.timeMinutes,
    required this.scheduledTime,
    this.log,
  });
}

class MedicineCard extends StatefulWidget {
  final HomeCardSize size;

  const MedicineCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  State<MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<MedicineCard> {
  bool _exactAlarmDenied = false;

  @override
  void initState() {
    super.initState();
    _checkExactAlarmPermission();
  }

  Future<void> _checkExactAlarmPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final status = await Permission.scheduleExactAlarm.status;
        if (mounted && status.isDenied) {
          setState(() => _exactAlarmDenied = true);
        }
      } catch (_) {
        // Platform or test environment without exact alarm support
      }
    }
  }

  /// Reconciles all active medications and their daily doses into blister slots
  List<_DoseSlotData> _buildDoseSlots(
    List<Medicine> medicines,
    List<MedicineLog> logs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeMeds = medicines.where((m) => m.appliesToDay(today)).toList();

    // Collect all taken logs for today
    final todayTakenLogs = logs.where((l) {
      final logDate = DateTime(
        l.scheduledAt.year,
        l.scheduledAt.month,
        l.scheduledAt.day,
      );
      return logDate == today && l.status == 'taken';
    }).toList();

    final List<_DoseSlotData> slots = [];

    for (final med in activeMeds) {
      // Find logs for this specific medicine
      final medLogs = todayTakenLogs.where((l) => l.medicineId == med.id).toList();

      for (final slotMinutes in med.timesMinutes) {
        final scheduledTime = DateTime(
          today.year,
          today.month,
          today.day,
          slotMinutes ~/ 60,
          slotMinutes % 60,
        );

        // Match log by exact hour/minute or take available log
        MedicineLog? matchedLog;
        for (final l in medLogs) {
          if (l.scheduledAt.hour == scheduledTime.hour &&
              l.scheduledAt.minute == scheduledTime.minute) {
            matchedLog = l;
            break;
          }
        }
        if (matchedLog == null && medLogs.isNotEmpty) {
          matchedLog = medLogs.removeAt(0);
        } else if (matchedLog != null) {
          medLogs.remove(matchedLog);
        }

        slots.add(_DoseSlotData(
          medicine: med,
          timeMinutes: slotMinutes,
          scheduledTime: scheduledTime,
          log: matchedLog,
        ));
      }
    }

    // Sort by scheduled time of day
    slots.sort((a, b) => a.timeMinutes.compareTo(b.timeMinutes));
    return slots;
  }

  Future<void> _toggleDoseSlot(_DoseSlotData slot) async {
    final logBox = Hive.box<MedicineLog>('medicine_logs');

    if (slot.isTaken && slot.log != null) {
      HapticFeedback.lightImpact();
      await logBox.delete(slot.log!.id);
    } else {
      HapticFeedback.mediumImpact();
      await MedicineService.markTaken(slot.medicine.id, slot.scheduledTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = TactileTokens.telemetryCyan;

    return ValueListenableBuilder(
      valueListenable: Hive.box<Medicine>('medicines').listenable(),
      builder: (context, Box<Medicine> medBox, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<MedicineLog>('medicine_logs').listenable(),
          builder: (context, Box<MedicineLog> logBox, __) {
            final allMeds = medBox.values.toList();
            final allLogs = logBox.values.toList();

            final stats = MedicineService.getDailyStats(
              medicines: allMeds,
              logs: allLogs,
            );

            final doseSlots = _buildDoseSlots(allMeds, allLogs);
            final hasMeds = allMeds.any((m) => m.active);
            final isAllTaken = stats.hasDosesToday && stats.takenDosesToday >= stats.totalDosesToday;

            return HomeCardFrame(
              icon: LucideIcons.pill,
              title: 'Prescription & Blister Pack',
              subtitle: 'Daily Scheduled Doses',
              domain: HomeCardDomain.editorial,
              accentColor: accent,
              onTap: () {
                Navigator.push(
                  context,
                  PageTransitions.containerTransform(
                    const HealthPage(initialTab: 0),
                  ),
                );
              },
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAllTaken
                      ? TactileTokens.financePositive.withValues(alpha: 0.15)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAllTaken
                        ? TactileTokens.financePositive.withValues(alpha: 0.3)
                        : accent.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  stats.hasDosesToday
                      ? '${stats.takenDosesToday}/${stats.totalDosesToday} TAKEN'
                      : (hasMeds ? 'ALL TAKEN' : 'NO MEDS'),
                  style: TextStyle(
                    color: isAllTaken ? TactileTokens.financePositive : accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exact alarm warning banner if denied on Android
                  if (_exactAlarmDenied)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: TactileTokens.amberWarning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: TactileTokens.amberWarning.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertTriangle,
                              color: TactileTokens.amberWarning, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inexact reminders. Allow exact alarms in settings for scheduled alerts.',
                              style: TextStyle(
                                color: TactileTokens.amberWarning.withValues(alpha: 0.9),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Interactive Blister Pack Tray
                  if (doseSlots.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101318),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.layers,
                                size: 12,
                                color: TactileTokens.warmIvory.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'BLISTER TRAY · 1-TAP TO POP / UNPOP',
                                style: TextStyle(
                                  color: TactileTokens.warmIvory.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Blister slots display
                          _buildBlisterSlotsGrid(doseSlots),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101318),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              hasMeds ? LucideIcons.checkCheck : LucideIcons.pill,
                              color: hasMeds
                                  ? TactileTokens.financePositive
                                  : BentoTheme.textSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasMeds
                                      ? 'All Prescriptions Completed'
                                      : 'No Scheduled Medications',
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasMeds
                                      ? 'All scheduled doses for today have been taken.'
                                      : 'Tap to configure your daily prescriptions & doses.',
                                  style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Next Upcoming Dose reminder if pending
                  if (!isAllTaken &&
                      stats.nextDoseMedicine != null &&
                      stats.nextDoseTime != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alarmClock, size: 14, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Next: ${stats.nextDoseMedicine!.name} (${stats.nextDoseMedicine!.doseLabel}) at ${DateFormat.jm().format(stats.nextDoseTime!)}',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Daily Progress & Compliance readout
                  Row(
                    children: [
                      Expanded(
                        child: ProgressBarX(
                          value: ProgressMath.ratio(
                            stats.takenDosesToday,
                            stats.totalDosesToday,
                          ),
                          color: isAllTaken ? TactileTokens.financePositive : accent,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        stats.totalDosesToday > 0
                            ? '${(stats.complianceRate * 100).toInt()}%'
                            : '0%',
                        style: TextStyle(
                          color: isAllTaken
                              ? TactileTokens.financePositive
                              : BentoTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlisterSlotsGrid(List<_DoseSlotData> slots) {
    final maxSlots = widget.size == HomeCardSize.large ? 6 : 4;
    final displaySlots = slots.take(maxSlots).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 320 ? 2 : 1;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: displaySlots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 64,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final slot = displaySlots[index];
            return _BlisterDoseSlot(
              slot: slot,
              onToggle: () => _toggleDoseSlot(slot),
            );
          },
        );
      },
    );
  }
}

/// A tactile blister-pack pill pocket that simulates pressed foil cavity physics
class _BlisterDoseSlot extends StatefulWidget {
  final _DoseSlotData slot;
  final VoidCallback onToggle;

  const _BlisterDoseSlot({
    required this.slot,
    required this.onToggle,
  });

  @override
  State<_BlisterDoseSlot> createState() => _BlisterDoseSlotState();
}

class _BlisterDoseSlotState extends State<_BlisterDoseSlot> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isTaken = widget.slot.isTaken;
    final timeStr = DateFormat.jm().format(widget.slot.scheduledTime);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onToggle();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            // Foil pressed cavity if taken, metallic embossed pocket if pending
            gradient: isTaken
                ? const LinearGradient(
                    colors: [Color(0xFF0C0E12), Color(0xFF14171E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1E222B), Color(0xFF161920)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isTaken
                  ? TactileTokens.financePositive.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: isTaken
                ? [
                    // Inset dark cavity shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ]
                : [
                    // Embossed specular foil highlight
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(-1, -1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(1, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // 3D Capsule / Foil Pill Pocket Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isTaken
                      ? TactileTokens.financePositive.withValues(alpha: 0.15)
                      : TactileTokens.telemetryCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isTaken
                        ? TactileTokens.financePositive.withValues(alpha: 0.4)
                        : TactileTokens.telemetryCyan.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isTaken ? LucideIcons.check : LucideIcons.pill,
                  size: 16,
                  color: isTaken
                      ? TactileTokens.financePositive
                      : TactileTokens.telemetryCyan,
                ),
              ),
              const SizedBox(width: 8),

              // Medication Info & Tabular Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.slot.medicine.name,
                      style: TextStyle(
                        color: isTaken
                            ? BentoTheme.textSecondary
                            : BentoTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                        decorationColor: BentoTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr · ${widget.slot.medicine.doseLabel}',
                      style: TextStyle(
                        color: isTaken
                            ? BentoTheme.textMuted
                            : BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Pill Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isTaken
                      ? TactileTokens.financePositive.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isTaken ? 'POPPED' : 'PENDING',
                  style: TextStyle(
                    color: isTaken
                        ? TactileTokens.financePositive
                        : BentoTheme.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
