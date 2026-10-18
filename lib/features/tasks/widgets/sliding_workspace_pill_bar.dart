import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';

/// Apple iOS 18 / ColorOS 15 style sliding segmented control for workspace switching.
///
/// Uses [LayoutBuilder] and [AnimatedAlign] with a critically-tuned cubic curve
/// `Cubic(0.22, 1.0, 0.36, 1.0)` over 280ms to glide a physical pill thumb behind
/// the active workspace tab.
class SlidingWorkspacePillBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onWorkspaceSelected;
  final int inboxBadgeCount;

  static const List<String> workspaceTitles = [
    'Today',
    'Upcoming',
    'Inbox',
    'Academic',
    'Board',
  ];

  const SlidingWorkspacePillBar({
    super.key,
    required this.selectedIndex,
    required this.onWorkspaceSelected,
    this.inboxBadgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BentoTheme.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabCount = workspaceTitles.length;
          final tabWidth = constraints.maxWidth / tabCount;

          // Convert selectedIndex (0..tabCount-1) to an Alignment.x between -1.0 and 1.0
          // x = -1.0 + (2.0 / (tabCount - 1)) * selectedIndex
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
                  height: 34,
                  decoration: BoxDecoration(
                    color: BentoTheme.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: BentoTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab labels
              Row(
                children: List.generate(tabCount, (index) {
                  final isSelected = selectedIndex == index;
                  final title = workspaceTitles[index];
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
                        height: 34,
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
                                        ? Colors.black
                                        : BentoTheme.textSecondary,
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
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : BentoTheme.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$inboxBadgeCount',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : BentoTheme.accent,
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
