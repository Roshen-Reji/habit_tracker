import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BrainstormPage extends StatefulWidget {
  const BrainstormPage({super.key});

  @override
  State<BrainstormPage> createState() => _BrainstormPageState();
}

class _BrainstormPageState extends State<BrainstormPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showIdeaDialog({Idea? existingIdea}) {
    final titleController =
        TextEditingController(text: existingIdea?.title ?? '');
    final descController =
        TextEditingController(text: existingIdea?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusDialog),
        ),
        title: Text(
          existingIdea != null ? 'Edit Idea' : 'Capture Idea',
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
              maxLines: 4,
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Describe your idea, notes, next steps...',
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
              backgroundColor: const Color(0xFFF59E0B), // Amber accent
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              final desc = descController.text.trim();
              if (title.isNotEmpty) {
                final box = Hive.box<Idea>('ideas');
                if (existingIdea != null) {
                  existingIdea.title = title;
                  existingIdea.description = desc;
                  existingIdea.updatedAt = DateTime.now();
                  await existingIdea.save();
                } else {
                  final newIdea = Idea(
                    id: 'idea_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    description: desc,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await box.put(newIdea.id, newIdea);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existingIdea != null ? 'Update' : 'Save Idea'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B); // Amber accent

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'BRAINSTORM VAULT',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: accent),
            tooltip: 'Add Idea',
            onPressed: () => _showIdeaDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () => _showIdeaDialog(),
        child: const Icon(LucideIcons.lightbulb, size: 22),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Idea>('ideas').listenable(),
        builder: (context, Box<Idea> box, _) {
          final ideas = box.values.toList();
          ideas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final filtered = ideas.where((idea) {
            if (_searchQuery.isEmpty) return true;
            return idea.title.toLowerCase().contains(_searchQuery) ||
                idea.description.toLowerCase().contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              // Search input
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: BentoTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search ideas...',
                    hintStyle: TextStyle(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.6)),
                    prefixIcon: Icon(LucideIcons.search,
                        color: BentoTheme.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(LucideIcons.x,
                                color: BentoTheme.textSecondary, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: BentoTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Ideas list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No ideas captured yet.\nTap "+" to capture your next big breakthrough.'
                              : 'No ideas matching "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final idea = filtered[index];
                          final dateStr = DateFormat('MMM d, y · h:mm a')
                              .format(idea.updatedAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: BentoTheme.surface,
                              borderRadius: BorderRadius.circular(
                                  ExpressiveTokens.radiusCard),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 1.2,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                    ExpressiveTokens.radiusCard),
                                onTap: () =>
                                    _showIdeaDialog(existingIdea: idea),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: accent.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              LucideIcons.lightbulb,
                                              color: accent,
                                              size: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              idea.title,
                                              style: TextStyle(
                                                color: BentoTheme.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(LucideIcons.trash2,
                                                color: Colors.redAccent,
                                                size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor:
                                                      BentoTheme.surface,
                                                  title: Text(
                                                    'Delete Idea?',
                                                    style: TextStyle(
                                                        color: BentoTheme
                                                            .textPrimary),
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to delete "${idea.title}"?',
                                                    style: TextStyle(
                                                        color: BentoTheme
                                                            .textSecondary),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child: Text('Cancel',
                                                          style: TextStyle(
                                                              color: BentoTheme
                                                                  .textSecondary)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.redAccent,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, true),
                                                      child:
                                                          const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await idea.delete();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      if (idea.description.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          idea.description,
                                          style: TextStyle(
                                            color: BentoTheme.textSecondary,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          color: BentoTheme.textSecondary
                                              .withValues(alpha: 0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
