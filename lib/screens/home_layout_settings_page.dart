import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';

class HomeLayoutSettingsPage extends StatefulWidget {
  const HomeLayoutSettingsPage({super.key});

  @override
  State<HomeLayoutSettingsPage> createState() => _HomeLayoutSettingsPageState();
}

class _HomeLayoutSettingsPageState extends State<HomeLayoutSettingsPage> {
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
  }

  void _onReorder(List<HomeCardLayoutItem> layout, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = layout.removeAt(oldIndex);
      layout.insert(newIndex, item);
    });
    HomeCardRegistry.saveLayout(_settingsBox, layout);
  }

  void _toggleVisibility(
      List<HomeCardLayoutItem> layout, int index, bool value) {
    setState(() {
      layout[index].visible = value;
    });
    HomeCardRegistry.saveLayout(_settingsBox, layout);
  }

  Future<void> _resetLayout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExpressiveTokens.radiusDialog),
        ),
        title: Text(
          'Reset Home Layout',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Restore the default card ordering and visibility for the home wallet stack?',
          style: TextStyle(
            color: BentoTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: BentoTheme.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: BentoTheme.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HomeCardRegistry.resetLayout(_settingsBox);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Home layout reset to default'),
            backgroundColor: BentoTheme.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _settingsBox.listenable(),
      builder: (context, Box box, _) {
        final layout = HomeCardRegistry.loadLayout(box);

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
              'Home Layout',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: _resetLayout,
                icon: Icon(
                  LucideIcons.rotateCcw,
                  size: 16,
                  color: BentoTheme.accent,
                ),
                label: Text(
                  'Reset',
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Text(
                  'Drag cards to reorder. Toggle switches to show or hide cards in your home wallet stack.',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: layout.length,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(layout, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final item = layout[index];
                    final spec = HomeCardRegistry.get(item.id);
                    final title = spec?.title ?? item.id;
                    final icon = spec?.icon ?? LucideIcons.layoutGrid;

                    return Container(
                      key: ValueKey(item.id),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: BentoTheme.surface,
                        borderRadius:
                            BorderRadius.circular(ExpressiveTokens.radiusM),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1.0,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: BentoTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            icon,
                            size: 18,
                            color: BentoTheme.accent,
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            color: item.visible
                                ? BentoTheme.textPrimary
                                : BentoTheme.textSecondary
                                    .withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.visible,
                              activeThumbColor: BentoTheme.accent,
                              onChanged: (val) =>
                                  _toggleVisibility(layout, index, val),
                            ),
                            const SizedBox(width: 8),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                LucideIcons.gripVertical,
                                color: BentoTheme.textSecondary
                                    .withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
