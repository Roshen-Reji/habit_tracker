import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/widgets/glass_tab_bar.dart' show GlassTabItem;
import 'package:habit_tracker/widgets/mini_player_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Central Floating Adaptive Dock unifying BottomNavBar and GlassTabBar (AGENTS.md Phase 4).
///
/// Features:
/// - Physics-Driven Sliding Indicator: SpringSimulation (stiffness: 380, damping: 28)
///   with directional liquid/elastic morphing stretch before settling on the target tab.
/// - Icon & Label Choreography: Active tab icon vertical bounce (-3px translate)
///   and stroke/fill transition while label slides and fades in horizontally.
/// - Tactile Haptics: HapticFeedback.selectionClick() on every tab change and drag scrub.
/// - Seamless Mini-Player Docking: MiniPlayerDockLip integrated into the top lip of the dock
///   behaving as a unified hardware unit.
class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<GlassTabItem>? items;
  final bool showMiniPlayer;
  final bool isVisible;
  final double height;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.items,
    this.showMiniPlayer = true,
    this.isVisible = true,
    this.height = 62.0,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _positionController;
  int? _scrubIndex;

  late List<GlassTabItem> _resolvedItems;

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResolvedItems();
  }

  @override
  void didUpdateWidget(covariant BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateResolvedItems();

    if (oldWidget.selectedIndex != widget.selectedIndex &&
        widget.selectedIndex != _positionController.value.round()) {
      _animateToTab(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  void _updateResolvedItems() {
    _resolvedItems = widget.items ??
        const [
          GlassTabItem(icon: LucideIcons.home, label: 'Home'),
          GlassTabItem(icon: LucideIcons.heartPulse, label: 'Health'),
          GlassTabItem(icon: LucideIcons.utensils, label: 'Diet'),
          GlassTabItem(icon: LucideIcons.checkCircle2, label: 'Tasks'),
          GlassTabItem(icon: LucideIcons.wallet, label: 'Finance'),
        ];
  }

  void _animateToTab(int targetIndex) {
    if (_resolvedItems.isEmpty) return;
    final clampedTarget = targetIndex.clamp(0, _resolvedItems.length - 1).toDouble();
    if ((clampedTarget - _positionController.value).abs() < 0.001) return;

    final simulation = SpringSimulation(
      const SpringDescription(mass: 1.0, stiffness: 340.0, damping: 26.0),
      _positionController.value,
      clampedTarget,
      _positionController.velocity,
    );

    _positionController.animateWith(simulation);
  }

  void _handleDrag(Offset localPosition, double totalWidth) {
    if (_resolvedItems.isEmpty) return;
    const horizontalPadding = 8.0;
    final usableWidth =
        (totalWidth - (horizontalPadding * 2)).clamp(1.0, double.infinity);
    final itemWidth = usableWidth / _resolvedItems.length;
    final adjustedX =
        (localPosition.dx - horizontalPadding).clamp(0.0, usableWidth - 1);
    final targetIndex =
        (adjustedX / itemWidth).floor().clamp(0, _resolvedItems.length - 1);

    if (targetIndex != widget.selectedIndex && targetIndex != _scrubIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _scrubIndex = targetIndex;
      });
      _animateToTab(targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePillColor = isDark
        ? const Color(0xFF2C323D)
        : Colors.white;
    final activeItemColor = isDark ? Colors.white : const Color(0xFF111417);
    final inactiveItemColor = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF757D8A);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: AnimatedSlide(
        offset: widget.isVisible ? Offset.zero : const Offset(0, 1.4),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          // LAYER 1: Outer Transparent Shell (Holds 3D Drop Shadows Outside ClipRRect)
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                constraints: const BoxConstraints(minHeight: 70),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    // Deep 3D floating elevation shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.65 : 0.18),
                      blurRadius: 32,
                      spreadRadius: 0,
                      offset: const Offset(0, 16),
                    ),
                    // Tight physical contact shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.40 : 0.10),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // LAYER 2: Strict ClipRRect + Frosted BackdropFilter
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28.0, sigmaY: 28.0),
                    // LAYER 3: 3D Bevel Body (Top Specular Rim + Vertical Depth Gradient)
                    child: CustomPaint(
                      foregroundPainter: _Nav3DBevelRimPainter(isDark: isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(38),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                                    const Color(0xD92C313A), // Lighter top lip catches light
                                    const Color(0xEB16191E), // Deeper bottom base for 3D mass
                                  ]
                                : [
                                    Colors.white.withOpacity(0.88),
                                    const Color(0xE6E8ECF2),
                                  ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Integrated Top-Lip Mini-Player Dock
                            if (widget.showMiniPlayer)
                              const MiniPlayerDockLip(),

                            // LAYER 4: Spring-Animated 3D Active Tab Capsule + Icons
                            SizedBox(
                              height: 56.0,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalWidth = constraints.maxWidth;
                                  final itemCount = _resolvedItems.length;
                                  if (itemCount == 0) return const SizedBox.shrink();

                                  final itemWidth = totalWidth / itemCount;

                                  return AnimatedBuilder(
                                    animation: _positionController,
                                    builder: (context, _) {
                                      final pos = _positionController.value;
                                      final velocity = _positionController.velocity;
                                      final stretchFactor = (velocity.abs() * 0.05).clamp(0.0, 0.40);
                                      final indicatorWidth = itemWidth * (1.0 + stretchFactor);
                                      final center = (pos * itemWidth) + (itemWidth / 2);
                                      final indicatorLeft = (center - (indicatorWidth / 2)).clamp(
                                        0.0,
                                        (totalWidth - indicatorWidth).clamp(0.0, totalWidth),
                                      );

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
                                            widget.onItemTapped(_scrubIndex!);
                                            _scrubIndex = null;
                                          }
                                        },
                                        onHorizontalDragCancel: () {
                                          _scrubIndex = null;
                                        },
                                        child: Stack(
                                          children: [
                                            // Raised 3D Active Tab Pill
                                            Positioned(
                                              left: indicatorLeft,
                                              top: 0,
                                              bottom: 0,
                                              width: indicatorWidth,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(30),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      activePillColor.withOpacity(0.95),
                                                      activePillColor.withOpacity(0.75),
                                                    ],
                                                  ),
                                                  border: Border(
                                                    top: BorderSide(
                                                      color: Colors.white.withOpacity(0.35),
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.30),
                                                      blurRadius: 10,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Tab Items Row with Icon & Label Choreography
                                            Row(
                                              children: List.generate(itemCount, (index) {
                                                final item = _resolvedItems[index];
                                                final proximity = (1.0 -
                                                        (index - pos).abs())
                                                    .clamp(0.0, 1.0);
                                                final isSelected =
                                                    widget.selectedIndex == index;

                                                return Expanded(
                                                  child: LayoutBuilder(
                                                    builder: (context, itemConstraints) {
                                                      const double iconWidth = 20.0;
                                                      const double iconMargin = 6.0;
                                                      const double horizontalItemPadding = iconWidth + iconMargin + 12.0;
                                                      final availableTextWidth = itemConstraints.maxWidth - horizontalItemPadding;

                                                      final itemColor = Color.lerp(
                                                            inactiveItemColor,
                                                            activeItemColor,
                                                            proximity,
                                                          ) ??
                                                          inactiveItemColor;

                                                      final effectiveLabelStyle = TextStyle(
                                                        fontFamily: 'Roboto',
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        letterSpacing: -0.3,
                                                        color: itemColor,
                                                      );

                                                      final textPainter = TextPainter(
                                                        text: TextSpan(text: item.label, style: effectiveLabelStyle),
                                                        maxLines: 1,
                                                        textDirection: Directionality.of(context),
                                                        textScaler: MediaQuery.textScalerOf(context),
                                                      )..layout(minWidth: 0, maxWidth: double.infinity);

                                                      final bool cutsOff = textPainter.width > availableTextWidth;

                                                      final iconWidget = Transform.translate(
                                                        offset: Offset(
                                                          0,
                                                          -3.0 * proximity,
                                                        ),
                                                        child: Transform.scale(
                                                          scale: 1.0 + (0.10 * proximity),
                                                          child: Icon(
                                                            item.icon,
                                                            size: 20,
                                                            color: itemColor,
                                                          ),
                                                        ),
                                                      );

                                                      Widget contentWidget;
                                                      if (cutsOff) {
                                                        contentWidget = Tooltip(
                                                          message: item.label,
                                                          child: Center(
                                                            child: iconWidget,
                                                          ),
                                                        );
                                                      } else {
                                                        contentWidget = Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            iconWidget,
                                                            Flexible(
                                                              child: ClipRect(
                                                                child: Align(
                                                                  alignment: Alignment.centerLeft,
                                                                  widthFactor: proximity,
                                                                  child: Opacity(
                                                                    opacity: proximity.clamp(0.0, 1.0),
                                                                    child: Transform.translate(
                                                                      offset: Offset(
                                                                        4.0 * (1.0 - proximity),
                                                                        0,
                                                                      ),
                                                                      child: Padding(
                                                                        padding: const EdgeInsets.only(left: 6.0),
                                                                        child: Text(
                                                                          item.label,
                                                                          style: effectiveLabelStyle,
                                                                          maxLines: 1,
                                                                          softWrap: false,
                                                                          overflow: TextOverflow.clip,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }

                                                      return Semantics(
                                                        button: true,
                                                        selected: isSelected,
                                                        label: item.label,
                                                        hint: item.tooltip,
                                                        child: Material(
                                                          color: Colors.transparent,
                                                          child: InkWell(
                                                            onTap: () {
                                                              HapticFeedback.selectionClick();
                                                              widget.onItemTapped(index);
                                                              _animateToTab(index);
                                                            },
                                                            borderRadius:
                                                                BorderRadius.circular(20.0),
                                                            splashColor: Colors.transparent,
                                                            highlightColor: Colors.transparent,
                                                            child: SizedBox(
                                                              height: double.infinity,
                                                              child: contentWidget,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// 3D Bevel Rim Custom Painter for the Floating Capsule dock.
/// Paints a 1.5px vertical specular highlight & drop shadow rim along the 38dp squircle contour.
class _Nav3DBevelRimPainter extends CustomPainter {
  final bool isDark;

  const _Nav3DBevelRimPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.75), const Radius.circular(38));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.5, 1.0],
        colors: [
          Colors.white.withOpacity(isDark ? 0.38 : 0.90),
          Colors.white.withOpacity(0.06),
          Colors.black.withOpacity(isDark ? 0.65 : 0.15),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _Nav3DBevelRimPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
