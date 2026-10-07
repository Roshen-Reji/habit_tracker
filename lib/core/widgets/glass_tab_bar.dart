import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';

/// Single item descriptor for [GlassTabBar].
class GlassTabItem {
  final IconData icon;
  final String label;
  final String? tooltip;

  const GlassTabItem({
    required this.icon,
    required this.label,
    this.tooltip,
  });
}

/// Floating glass tab bar adhering to Apple-style floating capsule navigation
/// and the MVP 5 calm, borderless design system.
///
/// Features:
/// - Floating rounded capsule above safe area (16px side margins, 12px above bottom inset)
/// - e4 elevation with soft dual shadows and no stroke
/// - Translucent frosted glass effect (86% alpha surface + 16px blur)
/// - Sliding spring-animated selection capsule (surfaceRaised, no stroke)
/// - Smooth drag-scrubbing with tactile haptic feedback ([HapticFeedback.selectionClick])
/// - Animated auto-hide on scroll (translate + fade, 200ms)
/// - Fully accessible [Semantics] for tab roles and selection
class GlassTabBar extends StatefulWidget {
  final int selectedIndex;
  final List<GlassTabItem> items;
  final ValueChanged<int> onItemSelected;
  final bool isVisible;
  final double height;

  const GlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    this.isVisible = true,
    this.height = 64.0,
  });

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar> {
  int? _scrubIndex;

  int get _activeVisualIndex => _scrubIndex ?? widget.selectedIndex;

  void _handleDrag(Offset localPosition, double totalWidth) {
    if (widget.items.isEmpty) return;
    const horizontalPadding = 6.0;
    final usableWidth =
        (totalWidth - (horizontalPadding * 2)).clamp(1.0, double.infinity);
    final itemWidth = usableWidth / widget.items.length;
    final adjustedX =
        (localPosition.dx - horizontalPadding).clamp(0.0, usableWidth - 1);
    final targetIndex =
        (adjustedX / itemWidth).floor().clamp(0, widget.items.length - 1);

    if (targetIndex != _activeVisualIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _scrubIndex = targetIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = tokens.isDark;

    return AnimatedSlide(
      offset: widget.isVisible ? Offset.zero : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 12.0 + bottomInset,
          ),
          child: RepaintBoundary(
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32.0),
                boxShadow:
                    AppElevation.shadows(DepthElevation.e4, isDark: isDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(32.0),
                    ),
                    padding: const EdgeInsets.all(6.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        final itemCount = widget.items.length;
                        if (itemCount == 0) return const SizedBox.shrink();

                        final itemWidth = totalWidth / itemCount;
                        final activeIndex =
                            _activeVisualIndex.clamp(0, itemCount - 1);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (details) {
                            _handleDrag(details.localPosition, totalWidth);
                          },
                          onHorizontalDragUpdate: (details) {
                            _handleDrag(details.localPosition, totalWidth);
                          },
                          onHorizontalDragEnd: (_) {
                            if (_scrubIndex != null) {
                              widget.onItemSelected(_scrubIndex!);
                              setState(() {
                                _scrubIndex = null;
                              });
                            }
                          },
                          onHorizontalDragCancel: () {
                            setState(() {
                              _scrubIndex = null;
                            });
                          },
                          child: Stack(
                            children: [
                              // Sliding selection capsule with spring-damped ease
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                left: activeIndex * itemWidth,
                                top: 0,
                                bottom: 0,
                                width: itemWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceRaised,
                                    borderRadius: BorderRadius.circular(26.0),
                                    boxShadow: AppElevation.shadows(
                                      DepthElevation.e1,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),

                              // Interactive items row
                              Row(
                                children: List.generate(itemCount, (index) {
                                  final item = widget.items[index];
                                  final isSelected = index == activeIndex;

                                  return Expanded(
                                    child: Semantics(
                                      role: SemanticsRole.tab,
                                      selected: isSelected,
                                      label: item.label,
                                      hint: item.tooltip,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            widget.onItemSelected(index);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(26.0),
                                          splashColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          child: SizedBox(
                                            height: double.infinity,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                AnimatedScale(
                                                  scale:
                                                      isSelected ? 1.06 : 0.96,
                                                  duration: const Duration(
                                                      milliseconds: 240),
                                                  curve: Curves.easeOutCubic,
                                                  child: Icon(
                                                    item.icon,
                                                    size: 20,
                                                    color: isSelected
                                                        ? tokens.textPrimary
                                                        : tokens.textMuted,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                AnimatedDefaultTextStyle(
                                                  duration: const Duration(
                                                      milliseconds: 240),
                                                  curve: Curves.easeOutCubic,
                                                  style: TextStyle(
                                                    fontFamily: 'Roboto',
                                                    fontSize: 10,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    letterSpacing: 0.2,
                                                    color: isSelected
                                                        ? tokens.textPrimary
                                                        : tokens.textMuted,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  child: Text(item.label),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
