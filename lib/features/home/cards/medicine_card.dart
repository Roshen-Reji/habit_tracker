import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2DD4BF); // Teal accent

    return ValueListenableBuilder(
      valueListenable: Hive.box<Medicine>('medicines').listenable(),
      builder: (context, Box<Medicine> medBox, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<MedicineLog>('medicine_logs').listenable(),
          builder: (context, Box<MedicineLog> logBox, __) {
            final stats = MedicineService.getDailyStats(
              medicines: medBox.values.toList(),
              logs: logBox.values.toList(),
            );

            final hasMeds = medBox.values.any((m) => m.active);
            final trailingText = stats.hasDosesToday
                ? '${stats.takenDosesToday}/${stats.totalDosesToday} taken'
                : (hasMeds ? 'All taken' : 'No meds');

            return HomeCardFrame(
              icon: LucideIcons.pill,
              title: 'Medicine Reminder',
              accentColor: accent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HealthPage(initialTab: 0),
                  ),
                );
              },
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stats.complianceRate >= 1.0 && stats.hasDosesToday
                      ? Colors.green.withValues(alpha: 0.15)
                      : accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailingText,
                  style: TextStyle(
                    color: stats.complianceRate >= 1.0 && stats.hasDosesToday
                        ? BentoTheme.positive
                        : accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertTriangle,
                              color: BentoTheme.warning, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inexact reminders. Allow exact alarms in device settings for precise timing.',
                              style: TextStyle(
                                color: Colors.amber.shade200,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (stats.nextDoseMedicine != null &&
                      stats.nextDoseTime != null) ...[
                    // Next upcoming dose card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(ExpressiveTokens.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              LucideIcons.clock,
                              color: accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stats.nextDoseMedicine!.name,
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stats.nextDoseMedicine!.doseLabel} · Next at ${DateFormat.jm().format(stats.nextDoseTime!)}',
                                  style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(ExpressiveTokens.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasMeds
                                ? LucideIcons.checkCircle2
                                : LucideIcons.plusCircle,
                            color: hasMeds
                                ? BentoTheme.positive
                                : BentoTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hasMeds
                                  ? 'All doses for today have been completed!'
                                  : 'No active medications. Tap to configure your schedule.',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.size == HomeCardSize.large &&
                      medBox.values.where((m) => m.active).isNotEmpty) ...[
                    Text(
                      'ACTIVE MEDICATIONS',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...medBox.values.where((m) => m.active).take(3).map((m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m.name,
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              m.doseLabel,
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // Daily progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ProgressBarX(
                          value: ProgressMath.ratio(
                            stats.takenDosesToday,
                            stats.totalDosesToday,
                          ),
                          color: accent,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        stats.totalDosesToday > 0
                            ? '${(stats.complianceRate * 100).toInt()}%'
                            : '0%',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
}
