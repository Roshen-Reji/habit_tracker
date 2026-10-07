import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/widgets/home_card_size_sheet.dart';

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
  List<double> _focusOffsets = const [0.0];

  static const double _perspective = 0.00135;

  static double _cardSpacingFor(HomeCardSize size, double viewportHeight) {
    switch (size) {
      case HomeCardSize.compact:
        return 135.0;
      case HomeCardSize.large:
        return 235.0;
      case HomeCardSize.hero:
        return math.max(320.0, viewportHeight * 0.46);
    }
  }

  static double _tuckOffsetFor(HomeCardSize size) {
    switch (size) {
      case HomeCardSize.compact:
        return 10.0;
      case HomeCardSize.large:
        return 12.0;
      case HomeCardSize.hero:
        return 14.0;
    }
  }

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
    if (!_scrollController.hasClients || _focusOffsets.isEmpty) return;
    final scrollOffset = math.max(0.0, _scrollController.offset).toDouble();
    final newActiveIndex = _findActiveIndex(scrollOffset, _focusOffsets);
    if (newActiveIndex != _activeIndex) {
      setState(() {
        _activeIndex = newActiveIndex;
      });
    }
  }

  int _findActiveIndex(double scrollOffset, List<double> offsets) {
    if (offsets.isEmpty) return 0;
    int closest = 0;
    double minDiff = (scrollOffset - offsets[0]).abs();
    for (int i = 1; i < offsets.length; i++) {
      final diff = (scrollOffset - offsets[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_internalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _settleToNearestCard(List<double> offsets) {
    if (_isSettling ||
        !_scrollController.hasClients ||
        offsets.length < 2 ||
        MediaQuery.of(context).disableAnimations) {
      return;
    }

    final position = _scrollController.position;
    final current = position.pixels;
    final activeIndex = _findActiveIndex(current, offsets);
    final target = offsets[activeIndex];
    final clampedTarget = target
        .clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        )
        .toDouble();

    if ((current - clampedTarget).abs() < 2.0) return;

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
      valueListenable: Hive.box('settings')
          .listenable(keys: ['home_layout', 'home_card_sizes']),
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

            final cardSizes = visibleCards
                .map((s) => HomeCardRegistry.getCardSize(settingsBox, s.id))
                .toList();

            final focusOffsets = <double>[0.0];
            final baseY = <double>[0.0];
            final tuckY = <double>[0.0];

            for (int i = 0; i < visibleCards.length; i++) {
              final sp = _cardSpacingFor(cardSizes[i], viewportHeight);
              final tk = _tuckOffsetFor(cardSizes[i]);
              final fs = sp - tk;
              if (i > 0) {
                focusOffsets.add(focusOffsets[i - 1] + fs);
                baseY.add(baseY[i - 1] + sp);
                tuckY.add(tuckY[i - 1] + tk);
              }
            }

            _focusOffsets = focusOffsets;

            final totalScrollHeight = focusOffsets.length > 1
                ? (viewportHeight + focusOffsets.last).toDouble()
                : viewportHeight;
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            final activeClamped =
                _activeIndex.clamp(0, visibleCards.length - 1);

            return Stack(
              children: [
                NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0) {
                      _settleToNearestCard(focusOffsets);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.normal,
                    ),
                    child: SizedBox(
                      height: totalScrollHeight,
                      width: double.infinity,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Flow(
                    delegate: _WalletFlowDelegate(
                      scrollController: _scrollController,
                      reduceMotion: reduceMotion,
                      focusOffsets: focusOffsets,
                      baseY: baseY,
                      tuckY: tuckY,
                      perspective: _perspective,
                      visibleCount: visibleCards.length,
                    ),
                    children: List.generate(visibleCards.length, (index) {
                      if ((index - activeClamped).abs() > 3) {
                        return const SizedBox.shrink();
                      }

                      final cardSpec = visibleCards[index];
                      final cardSize = cardSizes[index];

                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: GestureDetector(
                            onLongPress: () =>
                                HomeCardSizeSheet.show(context, cardSpec),
                            child: cardSpec.buildWidget(context, cardSize),
                          ),
                        ),
                      );
                    }),
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
  final List<double> focusOffsets;
  final List<double> baseY;
  final List<double> tuckY;
  final double perspective;
  final int visibleCount;

  _WalletFlowDelegate({
    required this.scrollController,
    required this.reduceMotion,
    required this.focusOffsets,
    required this.baseY,
    required this.tuckY,
    required this.perspective,
    required this.visibleCount,
  }) : super(repaint: scrollController);

  @override
  void paintChildren(FlowPaintingContext context) {
    final scrollOffset = scrollController.hasClients
        ? math.max(0.0, scrollController.offset).toDouble()
        : 0.0;

    int activeIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < focusOffsets.length; i++) {
      final diff = (scrollOffset - focusOffsets[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        activeIndex = i;
      }
    }
    activeIndex = activeIndex.clamp(0, visibleCount - 1);

    final paintOrder = List<int>.generate(visibleCount, (i) => i)
      ..remove(activeIndex)
      ..add(activeIndex);

    for (final index in paintOrder) {
      if ((index - activeIndex).abs() > 3) {
        continue;
      }

      final yTuck = index < tuckY.length ? tuckY[index] : index * 10.0;
      final yBase = index < baseY.length ? baseY[index] : index * 135.0;
      final isActive = index == activeIndex;

      final cardFocus = index < focusOffsets.length ? focusOffsets[index] : 0.0;
      final currentFocusStep = index < focusOffsets.length - 1
          ? (focusOffsets[index + 1] - focusOffsets[index])
          : (index > 0 ? focusOffsets[index] - focusOffsets[index - 1] : 135.0);

      final relativeDepth = (cardFocus - scrollOffset) /
          (currentFocusStep > 0 ? currentFocusStep : 135.0);
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
        final size = context.getChildSize(index) ?? Size.zero;
        final dx = size.width / 2;
        const dy = 0.0;
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
        visibleCount != oldDelegate.visibleCount ||
        focusOffsets != oldDelegate.focusOffsets;
  }
}
