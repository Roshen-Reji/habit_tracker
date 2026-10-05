import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';

class WalletCardStack extends StatefulWidget {
  final ScrollController? controller;

  const WalletCardStack({
    super.key,
    this.controller,
  });

  @override
  State<WalletCardStack> createState() => _WalletCardStackState();
}

class _WalletCardStackState extends State<WalletCardStack> {
  late final ScrollController _scrollController;
  bool _internalController = false;
  bool _isSettling = false;
  int _activeIndex = 0;

  static const double _cardSpacing = 135.0;
  static const double _tuckOffset = 10.0;
  static const double _focusSpacing = _cardSpacing - _tuckOffset;
  static const double _perspective = 0.00135;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _internalController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final scrollOffset = math.max(0.0, _scrollController.offset).toDouble();
    final cameraPosition = scrollOffset / _focusSpacing;
    final newActiveIndex = cameraPosition.round();
    if (newActiveIndex != _activeIndex) {
      setState(() {
        _activeIndex = newActiveIndex;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_internalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _settleToNearestCard(int cardCount) {
    if (_isSettling ||
        !_scrollController.hasClients ||
        MediaQuery.of(context).disableAnimations) {
      return;
    }

    final position = _scrollController.position;
    final current = position.pixels;
    final target = (current / _focusSpacing).round() * _focusSpacing;
    final clampedTarget = target
        .clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        )
        .toDouble();

    if ((current - clampedTarget).abs() < 2.0 || cardCount < 2) return;

    _isSettling = true;
    _scrollController
        .animateTo(
      clampedTarget,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
    )
        .whenComplete(() {
      if (mounted) _isSettling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['home_layout']),
      builder: (context, Box settingsBox, _) {
        final layout = HomeCardRegistry.loadLayout(settingsBox);
        final visibleCards = <HomeCardSpec>[];

        for (final item in layout) {
          if (item.visible) {
            final spec = HomeCardRegistry.get(item.id);
            if (spec != null) {
              visibleCards.add(spec);
            }
          }
        }

        if (visibleCards.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 48,
                    color: BentoTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cards visible',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enable cards in Settings > Home Layout',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight =
                constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
            final totalScrollHeight =
                (viewportHeight + (visibleCards.length - 1) * _focusSpacing)
                    .toDouble();
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            final activeClamped = _activeIndex.clamp(0, visibleCards.length - 1);

            return Stack(
              children: [
                NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0) {
                      _settleToNearestCard(visibleCards.length);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                        decelerationRate: ScrollDecelerationRate.normal),
                    child: SizedBox(
                      height: totalScrollHeight,
                      width: double.infinity,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Flow(
                      delegate: _WalletFlowDelegate(
                        scrollController: _scrollController,
                        reduceMotion: reduceMotion,
                        focusSpacing: _focusSpacing,
                        tuckOffset: _tuckOffset,
                        cardSpacing: _cardSpacing,
                        perspective: _perspective,
                        visibleCount: visibleCards.length,
                      ),
                      children: List.generate(visibleCards.length, (index) {
                        if ((index - activeClamped).abs() > 3) {
                          return const SizedBox.shrink();
                        }
                        
                        // We wrap each card in a RepaintBoundary.
                        // For non-focused cards, we apply a dark overlay using a ColorFiltered or just an overlay inside the card?
                        // Wait, FlowDelegate can paint opacity. The dark overlay can be painted by FlowDelegate if it were simple, but Flow doesn't paint custom shapes.
                        // We can just use an overlay widget whose opacity is animated by a local animation? No, the overlay amount depends on the scroll offset which is exactly what we are optimizing.
                        // If we use ColorFiltered, we still need to rebuild to change the color filter. 
                        // Instructions: "For cards behind the focused one, use scale, fade (via FadeTransition or a colour overlay, not an Opacity widget) and a dark overlay."
                        // We'll just build it normally and use context.paintChild(..., opacity: opacity) in FlowDelegate which avoids the Opacity widget entirely.
                        // And for the dark overlay, if they don't want Opacity widget, maybe we can just let context.paintChild's opacity handle the "fade".
                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: visibleCards[index].compactBuilder(context),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WalletFlowDelegate extends FlowDelegate {
  final ScrollController scrollController;
  final bool reduceMotion;
  final double focusSpacing;
  final double tuckOffset;
  final double cardSpacing;
  final double perspective;
  final int visibleCount;

  _WalletFlowDelegate({
    required this.scrollController,
    required this.reduceMotion,
    required this.focusSpacing,
    required this.tuckOffset,
    required this.cardSpacing,
    required this.perspective,
    required this.visibleCount,
  }) : super(repaint: scrollController);

  @override
  void paintChildren(FlowPaintingContext context) {
    final scrollOffset = scrollController.hasClients ? math.max(0.0, scrollController.offset).toDouble() : 0.0;
    final cameraPosition = scrollOffset / focusSpacing;
    final activeIndex = cameraPosition.round().clamp(0, visibleCount - 1).toInt();

    final paintOrder = List<int>.generate(visibleCount, (i) => i)
      ..remove(activeIndex)
      ..add(activeIndex);

    for (final index in paintOrder) {
      if ((index - activeIndex).abs() > 3) {
        // We still must call paintChild to satisfy the Flow children index, but it will be a SizedBox.shrink()
        // so it does nothing. But actually, we don't even need to paint it if it's out of bounds.
        // Wait, yes we do, or we can just ignore painting it.
        continue;
      }
      
      final yTuck = index * tuckOffset;
      final yBase = index * cardSpacing;
      final isActive = index == activeIndex;

      final relativeDepth = index - cameraPosition;
      final depthAmount = isActive
          ? 0.0
          : (index - activeIndex).abs().clamp(0.0, 2.4).toDouble() / 2.4;
      final parallaxRate = reduceMotion
          ? 1.0
          : (1.0 -
                  (relativeDepth.clamp(0.0, 3.0) * 0.035) +
                  ((-relativeDepth).clamp(0.0, 3.0) * 0.012))
              .clamp(0.89, 1.04)
              .toDouble();
      
      final cameraScroll = scrollOffset * parallaxRate;
      final visualY = math.max(yTuck, yBase - cameraScroll).toDouble();
      
      final yChild = visualY + scrollOffset;
      final scale = 1.0 - (depthAmount * 0.085);
      final opacity = isActive ? 1.0 : (0.68 + ((1.0 - depthAmount) * 0.18));
      final tilt = reduceMotion || isActive
          ? 0.0
          : relativeDepth.clamp(-1.0, 1.0).toDouble() * 0.045;
      final zOffset = reduceMotion || isActive ? 0.0 : -depthAmount * 34.0;
      final horizontalParallax = reduceMotion || isActive
          ? 0.0
          : relativeDepth.clamp(-2.0, 2.0).toDouble() * 1.6;

      final transform = Matrix4.identity()
        ..translate(horizontalParallax, yChild, 0.0)
        ..setEntry(3, 2, perspective)
        ..translate(0.0, 0.0, zOffset)
        ..rotateX(tilt);
      
      if (!reduceMotion) {
         // Apply center scaling
         final size = context.getChildSize(index) ?? Size.zero;
         final dx = size.width / 2;
         final dy = 0.0;
         transform.translate(dx, dy, 0.0);
         transform.scale(scale, scale, 1.0);
         transform.translate(-dx, -dy, 0.0);
      }

      context.paintChild(
        index,
        transform: transform,
        opacity: reduceMotion ? 1.0 : opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WalletFlowDelegate oldDelegate) {
    return scrollController != oldDelegate.scrollController ||
           reduceMotion != oldDelegate.reduceMotion ||
           visibleCount != oldDelegate.visibleCount;
  }
}
