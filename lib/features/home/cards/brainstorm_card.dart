import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/features/brainstorm/brainstorm_page.dart';
import 'package:habit_tracker/core/motion/spring_sheet.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BrainstormCard extends StatelessWidget {
  final HomeCardSize size;

  const BrainstormCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  void _showAddIdeaDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showSpringDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13151A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusDialog),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: TactileTokens.amberWarning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.lightbulb,
                  size: 16, color: TactileTokens.amberWarning),
            ),
            const SizedBox(width: 10),
            const Text(
              'Capture Idea',
              style: TextStyle(
                color: TactileTokens.warmIvory,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: TactileTokens.warmIvory),
              decoration: InputDecoration(
                hintText: 'Idea title or spark...',
                hintStyle: TextStyle(
                    color: TactileTokens.warmIvory.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF1C1F26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              style: const TextStyle(color: TactileTokens.warmIvory),
              decoration: InputDecoration(
                hintText: 'Supporting notes or context...',
                hintStyle: TextStyle(
                    color: TactileTokens.warmIvory.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF1C1F26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TactileButton(
            size: TactileButtonSize.small,
            variant: TactileButtonVariant.outline,
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          TactileButton(
            size: TactileButtonSize.small,
            variant: TactileButtonVariant.primary,
            label: 'Save Idea',
            onPressed: () async {
              final title = titleController.text.trim();
              final desc = descController.text.trim();
              if (title.isNotEmpty) {
                final box = Hive.box<Idea>('ideas');
                final newIdea = Idea(
                  id: 'idea_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  description: desc,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await box.put(newIdea.id, newIdea);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = TactileTokens.amberWarning;

    return ValueListenableBuilder(
      valueListenable: Hive.box<Idea>('ideas').listenable(),
      builder: (context, Box<Idea> box, _) {
        final ideas = box.values.toList();
        final count = size == HomeCardSize.large ? 4 : 2;
        final topIdeas = ideas.take(count).toList();

        return HomeCardFrame(
          icon: LucideIcons.lightbulb,
          title: 'Brainstorm & Ideas',
          subtitle: 'Tactile Ideation Desk',
          domain: HomeCardDomain.editorial,
          accentColor: accent,
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.containerTransform(
                const BrainstormPage(),
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
            child: Text(
              '${ideas.length} IDEAS',
              style: const TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: 0.6,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topIdeas.isNotEmpty) ...[
                ...topIdeas.map(
                  (idea) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
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
                            idea.title,
                            style: const TextStyle(
                              color: TactileTokens.warmIvory,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (idea.description.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(
                            LucideIcons.alignLeft,
                            size: 11,
                            color: BentoTheme.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Capture instant flashes of insight, project architectures, and upcoming strategies.',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TactileButton.icon(
                      size: TactileButtonSize.small,
                      variant: TactileButtonVariant.secondary,
                      icon: LucideIcons.plus,
                      label: 'Capture Idea',
                      onPressed: () => _showAddIdeaDialog(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton.icon(
                      size: TactileButtonSize.small,
                      variant: TactileButtonVariant.outline,
                      icon: LucideIcons.layoutList,
                      label: 'Desk View',
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageTransitions.containerTransform(
                            const BrainstormPage(),
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
