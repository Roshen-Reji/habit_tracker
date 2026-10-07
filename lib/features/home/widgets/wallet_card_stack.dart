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
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
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
            final totalScrollHeight = focusOffsets.last + lastCardHeight + 60.0;

            final reduceMotion = MediaQuery.of(context).disableAnimations;
            final activeClamped =
                _activeIndex.clamp(0, visibleCards.length - 1);

            return NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification.dragDetails != null) {
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(visibleCards.length, (index) {
                      if ((index - activeClamped).abs() > 3) {
                        return const SizedBox.shrink();
                      }

                      final cardSpec = visibleCards[index];
                      final cardSize = cardSizes[index];
                      final isCardActive = index == activeClamped;
                      final cardTop = focusOffsets[index];

                      return Positioned(
                        top: cardTop,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _scrollController,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: isCardActive
                                    ? null
                                    : () {
                                        _scrollController.animateTo(
                                          focusOffsets[index],
                                          duration:
                                              const Duration(milliseconds: 340),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                onLongPress: () =>
                                    HomeCardSizeSheet.show(context, cardSpec),
                                child: cardSpec.buildWidget(context, cardSize),
                              ),
                            ),
                            builder: (context, child) {
                              if (reduceMotion) {
                                return child!;
                              }

                              final scrollOffset = _scrollController.hasClients
                                  ? _scrollController.offset
                                  : 0.0;
                              final delta = cardTop - scrollOffset;
                              final relativeDist =
                                  (delta / 280.0).clamp(-1.2, 1.2);
                              final depthAmount = relativeDist.abs();

                              final scale =
                                  (1.0 - (depthAmount * 0.03)).clamp(0.96, 1.0);
                              final opacity =
                                  (1.0 - (depthAmount * 0.12)).clamp(0.82, 1.0);
                              final tilt = relativeDist * 0.025;

                              final transform = Matrix4.identity()
                                ..setEntry(3, 2, _perspective)
                                ..rotateX(tilt)
                                ..scale(scale, scale, 1.0);

                              return Transform(
                                alignment: Alignment.center,
                                transform: transform,
                                child: Opacity(
                                  opacity: opacity,
                                  child: child,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
