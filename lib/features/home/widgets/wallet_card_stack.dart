import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';

/// Wallet-style scrolling card stack for the home screen.
/// Cards overlap with peek strips. As you scroll, earlier cards
/// scale down slightly, dim, and tuck under the next card.
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

  static const double _cardSpacing = 135.0;
  static const double _tuckOffset = 10.0;
  static const double _cardHeight = 190.0;

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

            final totalScrollHeight = math.max(
              viewportHeight + 50.0,
              (visibleCards.length - 1) * _cardSpacing + _cardHeight + 120.0,
            );

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: totalScrollHeight,
                    child: AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, _) {
                        final scrollOffset = _scrollController.hasClients
                            ? math.max(0.0, _scrollController.offset)
                            : 0.0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(visibleCards.length, (index) {
                            final spec = visibleCards[index];
                            final yTuck = index * _tuckOffset;
                            final yBase = index * _cardSpacing;

                            // Calculate pinned position inside stack so on-screen position is max(yTuck, yBase - scrollOffset)
                            final yChild =
                                math.max(yBase, yTuck + scrollOffset);

                            // Calculate tucking progress for scale and opacity dimming
                            final di = yBase - scrollOffset;
                            final delta = (yTuck - di).clamp(0.0, _cardSpacing);
                            final progress = delta / _cardSpacing;

                            // Slight scale down (1.0 -> 0.94) and dimming (1.0 -> 0.55) when tucked under
                            final scale = 1.0 - (progress * 0.06);
                            final opacity =
                                (1.0 - (progress * 0.45)).clamp(0.55, 1.0);

                            return Positioned(
                              top: yChild,
                              left: 16,
                              right: 16,
                              child: Transform.scale(
                                scale: scale,
                                alignment: Alignment.topCenter,
                                child: Opacity(
                                  opacity: opacity,
                                  child: RepaintBoundary(
                                    child: spec.compactBuilder(context),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
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
