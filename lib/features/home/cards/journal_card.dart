import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/journal/journal_editor_page.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/features/journal/journal_list_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class JournalCard extends StatelessWidget {
  final HomeCardSize size;

  const JournalCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    const accent = TactileTokens.violetInk;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return ValueListenableBuilder(
      valueListenable: Hive.box<JournalEntry>(JournalService.boxName).listenable(),
      builder: (context, Box<JournalEntry> box, _) {
        final dayDoc = box.get('day_$todayKey');
        int autoLogCount = 0;
        String? entryExcerpt;
        if (dayDoc != null) {
          autoLogCount = JournalDayRepository.instance.getAutoLogs(dayDoc).length;
          try {
            final decoded = jsonDecode(dayDoc.bodyDelta);
            if (decoded is List) {
              final buffer = StringBuffer();
              for (final op in decoded) {
                if (op is Map && op['insert'] is String) {
                  buffer.write(op['insert']);
                }
              }
              final text = buffer.toString().trim();
              if (text.isNotEmpty) {
                entryExcerpt = text;
              }
            }
          } catch (_) {
            if (dayDoc.title.trim().isNotEmpty) {
              entryExcerpt = dayDoc.title.trim();
            }
          }
        }

        return HomeCardFrame(
          icon: LucideIcons.bookLock,
          title: 'Private Journal',
          subtitle: 'Encrypted Daily Chronicle',
          domain: HomeCardDomain.editorial,
          accentColor: accent,
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.containerTransform(
                const JournalListPage(),
              ),
            );
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.shieldCheck, color: accent, size: 12),
                const SizedBox(width: 5),
                Text(
                  autoLogCount > 0 ? '$autoLogCount LOGGED' : 'AES-256',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Editorial Note Slate
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF13151B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entryExcerpt != null) ...[
                      Row(
                        children: [
                          Icon(LucideIcons.penTool,
                              size: 11, color: TactileTokens.warmIvory.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            'TODAY’S ENTRY PREVIEW',
                            style: TextStyle(
                              color: TactileTokens.warmIvory.withValues(alpha: 0.6),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"$entryExcerpt"',
                        maxLines: size == HomeCardSize.large ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TactileTokens.warmIvory,
                          fontSize: 12.5,
                          height: 1.45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(LucideIcons.sparkles, size: 12, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            'DAILY REFLECTION PROMPT',
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.9),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'What was your defining highlight, challenge, or breakthrough today?',
                        style: TextStyle(
                          color: TactileTokens.warmIvory,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],

                    if (autoLogCount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$autoLogCount system activity event${autoLogCount > 1 ? 's' : ''} captured today',
                            style: TextStyle(
                              color: BentoTheme.textMuted,
                              fontSize: 10.5,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Interactive Tactile Buttons
              Row(
                children: [
                  Expanded(
                    child: TactileButton.icon(
                      size: TactileButtonSize.small,
                      variant: TactileButtonVariant.secondary,
                      icon: LucideIcons.penLine,
                      label: entryExcerpt != null ? 'Edit Today' : 'Write Entry',
                      onPressed: () async {
                        final todayDoc = await JournalDayRepository.instance
                            .getOrCreateDay(todayKey);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          PageTransitions.containerTransform(
                            JournalEditorPage(initialEntry: todayDoc),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton.icon(
                      size: TactileButtonSize.small,
                      variant: TactileButtonVariant.outline,
                      icon: LucideIcons.keyRound,
                      label: 'Open Vault',
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageTransitions.containerTransform(
                            const JournalListPage(),
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
      },
    );
  }
}
