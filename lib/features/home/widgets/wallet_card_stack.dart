import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';

/// A spatial, wallet-style card stack for the home screen.
///
/// The closest card stays crisp and full sized while surrounding cards recede
/// into the stack. Each layer has a slightly different scroll rate, scale and
/// 3D tilt so a swipe feels like moving a camera through the cards instead of
/// moving a flat list.
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
  }

  @override
  void dispose() {
    if (_internalController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// Gives the stack a small, tactile settle after a drag or fling. The
  /// scroll physics still handle the live gesture; this only resolves the
  /// resting position to the nearest card layer.
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

    // Avoid emitting an extra ScrollEndNotification for an imperceptible move.
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
      valueListenable: Hive.box('settings').listenable(),
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

            // A focused card rests just below the peek strips above it.
            // Giving the sliver this exact extent keeps even the last card
            // reachable as the sharp foreground layer.
            final totalScrollHeight =
                (viewportHeight + (visibleCards.length - 1) * _focusSpacing)
                    .toDouble();

            final reduceMotion = MediaQuery.of(context).disableAnimations;

            return Stack(
              children: [
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
                          final travel = scrollOffset / _focusSpacing;
                          final betweenCards = (travel - travel.round()).abs();
                          final lensBlur =
                              reduceMotion ? 0.0 : 9.0 + (betweenCards * 4.0);

                          // One lens over the ambient field creates the
                          // depth-of-field without softening the card painted
                          // at the front of the stack.
                          return BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: lensBlur,
                              sigmaY: lensBlur,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: BentoTheme.background
                                    .withValues(alpha: 0.10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0) {
                      _settleToNearestCard(visibleCards.length);
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: reduceMotion
                        ? const ClampingScrollPhysics()
                        : const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: totalScrollHeight,
                          child: AnimatedBuilder(
                            animation: _scrollController,
                            builder: (context, _) {
                              final scrollOffset = _scrollController.hasClients
                                  ? math
                                      .max(0.0, _scrollController.offset)
                                      .toDouble()
                                  : 0.0;
                              final cameraPosition =
                                  scrollOffset / _focusSpacing;
                              final activeIndex = cameraPosition
                                  .round()
                                  .clamp(0, visibleCards.length - 1)
                                  .toInt();
                              final paintOrder = List<int>.generate(
                                  visibleCards.length, (i) => i)
                                ..remove(activeIndex)
                                ..add(activeIndex);

                              return Stack(
                                clipBehavior: Clip.none,
                                children: paintOrder.map((index) {
                                  final spec = visibleCards[index];
                                  final yTuck = index * _tuckOffset;
                                  final yBase = index * _cardSpacing;
                                  final isActive = index == activeIndex;

                                  // Cards further away from the camera glide a
                                  // touch more slowly. That difference is small
                                  // enough to retain the familiar wallet-stack
                                  // affordance, but perceptible as parallax.
                                  final relativeDepth = index - cameraPosition;
                                  final depthAmount = isActive
                                      ? 0.0
                                      : (index - activeIndex)
                                              .abs()
                                              .clamp(0.0, 2.4)
                                              .toDouble() /
                                          2.4;
                                  final parallaxRate = reduceMotion
                                      ? 1.0
                                      : (1.0 -
                                              (relativeDepth.clamp(0.0, 3.0) *
                                                  0.035) +
                                              ((-relativeDepth)
                                                      .clamp(0.0, 3.0) *
                                                  0.012))
                                          .clamp(0.89, 1.04)
                                          .toDouble();
                                  final cameraScroll =
                                      scrollOffset * parallaxRate;
                                  final visualY = math
                                      .max(
                                        yTuck,
                                        yBase - cameraScroll,
                                      )
                                      .toDouble();

                                  // The sliver itself is scrolling, so translate
                                  // the desired screen position back into its
                                  // content coordinates before positioning.
                                  final yChild = visualY + scrollOffset;
                                  final scale = 1.0 - (depthAmount * 0.085);
                                  final blurSigma =
                                      reduceMotion ? 0.0 : depthAmount * 3.2;
                                  final opacity = isActive
                                      ? 1.0
                                      : 0.68 + ((1.0 - depthAmount) * 0.18);
                                  final tilt = reduceMotion || isActive
                                      ? 0.0
                                      : relativeDepth
                                              .clamp(-1.0, 1.0)
                                              .toDouble() *
                                          0.045;
                                  final zOffset = reduceMotion || isActive
                                      ? 0.0
                                      : -depthAmount * 34.0;
                                  final horizontalParallax =
                                      reduceMotion || isActive
                                          ? 0.0
                                          : relativeDepth
                                                  .clamp(-2.0, 2.0)
                                                  .toDouble() *
                                              1.6;

                                  return Positioned(
                                    top: yChild,
                                    left: 16,
                                    right: 16,
                                    child: IgnorePointer(
                                      // A blurred layer should not intercept a
                                      // tap intended for the crisp card above
                                      // it. Scroll gestures remain handled by
                                      // the parent scroll view.
                                      ignoring: !isActive,
                                      child: Transform.translate(
                                        offset: Offset(horizontalParallax, 0),
                                        child: Transform(
                                          alignment: Alignment.topCenter,
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, _perspective)
                                            ..translate(0.0, 0.0, zOffset)
                                            ..rotateX(tilt),
                                          child: Transform.scale(
                                            scale: reduceMotion ? 1.0 : scale,
                                            alignment: Alignment.topCenter,
                                            child: Opacity(
                                              opacity:
                                                  reduceMotion ? 1.0 : opacity,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                child: ImageFiltered(
                                                  imageFilter: ImageFilter.blur(
                                                    sigmaX: blurSigma,
                                                    sigmaY: blurSigma,
                                                    tileMode: TileMode.decal,
                                                  ),
                                                  child: RepaintBoundary(
                                                    child: spec.compactBuilder(
                                                        context),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
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
