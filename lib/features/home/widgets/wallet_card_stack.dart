import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/widgets/home_card_size_sheet.dart';

/// A sleek 3D spatial card stack for the home screen.
///
/// Features depth blur, 3D perspective tilt, depth zOffset, horizontal parallax,
/// and wallet-style layering while supporting flexible card heights (compact, large, hero)
/// and full vertical scrolling past any card.
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
        return 145.0;
      case HomeCardSize.large:
        return 245.0;
      case HomeCardSize.hero:
        return math.max(320.0, viewportHeight * 0.46);
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

    if ((current - clampedTarget).abs() < 4.0) return;

    _isSettling = true;
    _scrollController
        .animateTo(
      clampedTarget,
      duration: const Duration(milliseconds: 420),
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
            for (int i = 1; i < visibleCards.length; i++) {
              final prevSize = cardSizes[i - 1];
              final sp = _cardSpacingFor(prevSize, viewportHeight);
              focusOffsets.add(focusOffsets[i - 1] + sp);
            }

            _focusOffsets = focusOffsets;

            final lastCardSize = cardSizes.last;
            final lastCardHeight =
                _cardSpacingFor(lastCardSize, viewportHeight);
            final totalScrollHeight =
                focusOffsets.last + lastCardHeight + 120.0;

            final reduceMotion = MediaQuery.of(context).disableAnimations;
            final activeClamped =
                _activeIndex.clamp(0, visibleCards.length - 1);

            // Layer ordering: cards furthest from active are painted first (deepest in stack),
            // active card is painted last (at the very top of the stack).
            final paintOrder =
                List<int>.generate(visibleCards.length, (i) => i);
            paintOrder.sort((a, b) {
              final distA = (a - activeClamped).abs();
              final distB = (b - activeClamped).abs();
              if (distA != distB) {
                return distB.compareTo(distA);
              }
              return a.compareTo(b);
            });

            return Stack(
              children: [
                // Ambient backdrop depth lens
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, _) {
                          final scrollOffset = _scrollController.hasClients
                              ? math
                                  .max(0.0, _scrollController.offset)
                                  .toDouble()
                              : 0.0;
                          final currentStep = focusOffsets.length > 1
                              ? (focusOffsets[1] - focusOffsets[0])
                                  .clamp(100.0, 400.0)
                              : 145.0;
                          final travel = scrollOffset / currentStep;
                          final betweenCards = (travel - travel.round()).abs();
                          final lensBlur =
                              reduceMotion ? 0.0 : 8.0 + (betweenCards * 4.0);

                          return BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: lensBlur,
                              sigmaY: lensBlur,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: BentoTheme.background
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Card stack scroll container
                NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0 &&
                        notification.dragDetails != null) {
                      _settleToNearestCard(focusOffsets);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: reduceMotion
                        ? const ClampingScrollPhysics()
                        : const BouncingScrollPhysics(
                            decelerationRate: ScrollDecelerationRate.normal,
                          ),
                    child: SizedBox(
                      height: totalScrollHeight,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: paintOrder.map((index) {
                          if ((index - activeClamped).abs() > 3) {
                            return Positioned(
                              top: focusOffsets[index],
                              left: 16,
                              right: 16,
                              child: const SizedBox.shrink(),
                            );
                          }

                          final cardSpec = visibleCards[index];
                          final cardSize = cardSizes[index];
                          final cardTop = focusOffsets[index];
                          final cardStep =
                              _cardSpacingFor(cardSize, viewportHeight);

                          return Positioned(
                            top: cardTop,
                            left: 16,
                            right: 16,
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _scrollController,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: index == activeClamped
                                      ? null
                                      : () {
                                          _scrollController.animateTo(
                                            focusOffsets[index],
                                            duration: const Duration(
                                                milliseconds: 380),
                                            curve: Curves.easeOutCubic,
                                          );
                                        },
                                  onLongPress: () =>
                                      HomeCardSizeSheet.show(context, cardSpec),
                                  child: IgnorePointer(
                                    ignoring: index != activeClamped,
                                    child:
                                        cardSpec.buildWidget(context, cardSize),
                                  ),
                                ),
                                builder: (context, child) {
                                  if (reduceMotion) {
                                    return child!;
                                  }

                                  final scrollOffset =
                                      _scrollController.hasClients
                                          ? _scrollController.offset
                                          : 0.0;
                                  final delta = cardTop - scrollOffset;
                                  final relativeDepth = delta / cardStep;
                                  final isCardActive = (index == activeClamped);

                                  // Depth amount: 0.0 when active, up to 1.0 when receding
                                  final depthAmount = isCardActive
                                      ? 0.0
                                      : relativeDepth.abs().clamp(0.0, 2.2) /
                                          2.2;

                                  // Vertical tuck parallax
                                  final double yParallax;
                                  if (delta > 0) {
                                    // Peeking cards below tuck closer into the stack
                                    yParallax =
                                        -(delta * 0.15).clamp(0.0, 45.0);
                                  } else {
                                    // Past cards glide up with slight inertia lag,
                                    // never stuck, freely exiting off the top
                                    yParallax =
                                        ((-delta) * 0.10).clamp(0.0, 32.0);
                                  }

                                  // 3D Spatial Transforms
                                  final horizontalParallax = isCardActive
                                      ? 0.0
                                      : relativeDepth.clamp(-2.0, 2.0) * 1.8;

                                  final zOffset =
                                      isCardActive ? 0.0 : -depthAmount * 34.0;

                                  final tilt = isCardActive
                                      ? 0.0
                                      : relativeDepth.clamp(-1.0, 1.0) * 0.045;

                                  final scale = (1.0 - (depthAmount * 0.085))
                                      .clamp(0.90, 1.0);

                                  final opacity = isCardActive
                                      ? 1.0
                                      : (0.72 + ((1.0 - depthAmount) * 0.20))
                                          .clamp(0.70, 1.0);

                                  final blurSigma = isCardActive
                                      ? 0.0
                                      : (depthAmount * 3.4).clamp(0.0, 4.0);

                                  final transform = Matrix4.identity()
                                    ..setEntry(3, 2, _perspective)
                                    ..translate(0.0, 0.0, zOffset)
                                    ..rotateX(tilt);

                                  return Transform.translate(
                                    offset:
                                        Offset(horizontalParallax, yParallax),
                                    child: Transform(
                                      alignment: Alignment.topCenter,
                                      transform: transform,
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.topCenter,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: blurSigma > 0.1
                                                ? ImageFiltered(
                                                    imageFilter:
                                                        ImageFilter.blur(
                                                      sigmaX: blurSigma,
                                                      sigmaY: blurSigma,
                                                      tileMode: TileMode.decal,
                                                    ),
                                                    child: child!,
                                                  )
                                                : child!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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
