import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/features/brainstorm/brainstorm_page.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BrainstormCard extends StatelessWidget {
  const BrainstormCard({super.key});

  void _showAddIdeaDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusDialog),
        ),
        title: Text(
          'Capture Idea',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Idea Title...',
                hintStyle: TextStyle(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: BentoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Description or notes...',
                hintStyle: TextStyle(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: BentoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: BentoTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
            ),
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
            child: const Text('Save Idea'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B); // Amber accent

    return ValueListenableBuilder(
      valueListenable: Hive.box<Idea>('ideas').listenable(),
      builder: (context, Box<Idea> box, _) {
        final ideas = box.values.toList();
        ideas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final topIdeas = ideas.take(2).toList();

        return HomeCardFrame(
          icon: LucideIcons.lightbulb,
          title: 'Brainstorm',
          accentColor: accent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BrainstormPage(),
              ),
            );
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${ideas.length} ideas',
              style: const TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
                      color: BentoTheme.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(ExpressiveTokens.radiusSm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.sparkles,
                            color: accent, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            idea.title,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Capture instant flashes of insight, project concepts, and future strategies.',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BentoTheme.surfaceElevated,
                        foregroundColor: BentoTheme.textPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ExpressiveTokens.radiusSm),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 15),
                      label: const Text(
                        'Add Idea',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showAddIdeaDialog(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent.withValues(alpha: 0.15),
                        foregroundColor: accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ExpressiveTokens.radiusSm),
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.layoutList, size: 15),
                      label: const Text(
                        'View All',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BrainstormPage(),
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
