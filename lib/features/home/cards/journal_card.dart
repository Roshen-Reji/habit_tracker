import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/journal/journal_editor_page.dart';
import 'package:habit_tracker/features/journal/journal_list_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6366F1); // Indigo accent
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int autoLogCount = 0;
    if (Hive.isBoxOpen(JournalService.boxName)) {
      final dayDoc = Hive.box<JournalEntry>(JournalService.boxName).get('day_$todayKey');
      if (dayDoc != null) {
        autoLogCount = JournalDayRepository.instance.getAutoLogs(dayDoc).length;
      }
    }

    return HomeCardFrame(
      icon: LucideIcons.bookLock,
      title: 'Private Journal',
      accentColor: accent,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const JournalListPage(),
          ),
        );
      },
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.shieldCheck, color: accent, size: 12),
            const SizedBox(width: 4),
            Text(
              autoLogCount > 0 ? '$autoLogCount logged' : 'AES-256',
              style: const TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            autoLogCount > 0
                ? '$autoLogCount activity event${autoLogCount > 1 ? 's' : ''} auto-recorded in today’s journal.'
                : 'Encrypted private thoughts, daily reflections & notes protected with device biometrics.',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Create action (Open today's day document directly)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.surfaceElevated,
                    foregroundColor: BentoTheme.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusSm),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  icon: const Icon(LucideIcons.penLine, size: 16),
                  label: const Text(
                    'Today',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final todayDoc = await JournalDayRepository.instance.getOrCreateDay(todayKey);
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEditorPage(initialEntry: todayDoc),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // View action (Asks for PIN / Fingerprint)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0.15),
                    foregroundColor: accent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusSm),
                      side: BorderSide(
                        color: accent.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  icon: const Icon(LucideIcons.keyRound, size: 16),
                  label: const Text(
                    'View Vault',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JournalListPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
