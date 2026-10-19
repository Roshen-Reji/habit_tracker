import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple iOS 18 / ColorOS 15 style sliding segmented control for workspace switching.
///
/// Uses [LayoutBuilder] and [AnimatedAlign] with a critically-tuned cubic curve
/// `Cubic(0.22, 1.0, 0.36, 1.0)` over 280ms to glide a physical pill thumb behind
/// the active workspace tab.
class SlidingWorkspacePillBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onWorkspaceSelected;
  final int inboxBadgeCount;
  final List<String> titles;

  static const List<String> defaultWorkspaceTitles = [
    'Tasks',
    'Habits',
    'Academics',
  ];

  const SlidingWorkspacePillBar({
    super.key,
    required this.selectedIndex,
    required this.onWorkspaceSelected,
    this.inboxBadgeCount = 0,
    this.titles = defaultWorkspaceTitles,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabCount = titles.length;
          final tabWidth = constraints.maxWidth / tabCount;

          final alignmentX = tabCount > 1
              ? -1.0 + (2.0 / (tabCount - 1)) * selectedIndex
              : 0.0;

          return Stack(
            children: [
              // Gliding thumb pill
              AnimatedAlign(
                alignment: Alignment(alignmentX, 0.0),
                duration: const Duration(milliseconds: 280),
                curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                child: Container(
                  width: tabWidth,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              // Tab labels
              Row(
                children: List.generate(tabCount, (index) {
                  final isSelected = selectedIndex == index;
                  final title = titles[index];
                  final isInbox = title == 'Inbox';

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (selectedIndex != index) {
                          HapticFeedback.selectionClick();
                          onWorkspaceSelected(index);
                        }
                      },
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                  child: Text(title, maxLines: 1),
                                ),
                              ),
                            ),
                            if (isInbox && inboxBadgeCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.2)
                                      : colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$inboxBadgeCount',
                                  style: TextStyle(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSecondaryContainer,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
