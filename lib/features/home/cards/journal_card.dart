import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/journal/journal_editor_page.dart';
import 'package:habit_tracker/features/journal/journal_list_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6366F1); // Indigo accent

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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldCheck, color: accent, size: 12),
            SizedBox(width: 4),
            Text(
              'AES-256',
              style: TextStyle(
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
            'Encrypted private thoughts, daily reflections & notes protected with device biometrics.',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Create action (Open editor directly)
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
                    'Create',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JournalEditorPage(),
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
