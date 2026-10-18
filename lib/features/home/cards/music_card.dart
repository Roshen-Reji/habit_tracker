import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/home/widgets/expanded_player_sheet.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MusicCard extends StatelessWidget {
  final HomeCardSize size;

  const MusicCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  String _formatMs(int ms) {
    if (ms <= 0) return '0:00';
    final sec = (ms / 1000).floor();
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildBadge(String text, Color color, {bool isPlaying = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying) ...[
            MicroEqualizerBars(isPlaying: true, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && !Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: NowPlayingService.instance.hasNotificationAccess,
      builder: (context, hasAccess, _) {
        return ValueListenableBuilder<NowPlaying?>(
          valueListenable: NowPlayingService.instance.nowPlaying,
          builder: (context, track, _) {
            if (!hasAccess) {
              return HomeCardFrame(
                domain: HomeCardDomain.audio,
                icon: LucideIcons.music,
                title: 'Audio Hardware Deck',
                trailing: _buildBadge('Setup Required', Colors.amber),
                onTap: () => NowPlayingService.instance.openAccessSettings(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.bellRing,
                          color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Notification Access',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to detect Spotify, YouTube, etc.',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight,
                        color: BentoTheme.textSecondary, size: 18),
                  ],
                ),
              );
            }

            if (track == null) {
              return HomeCardFrame(
                domain: HomeCardDomain.audio,
                icon: LucideIcons.disc,
                title: 'Audio Hardware Deck',
                trailing: _buildBadge('Idle', BentoTheme.textSecondary),
                onTap: () => NowPlayingService.instance.refresh(),
                child: size == HomeCardSize.hero
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          const HardwareVinylGraphic(
                            isPlaying: false,
                            size: 80,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No media currently playing',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start audio in Spotify, YouTube Music, or any media app',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      )
                    : Row(
                        children: [
                          const HardwareVinylGraphic(
                            isPlaying: false,
                            size: 44,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No media playing',
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Play music in any app to control it here',
                                  style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            }

            return HomeCardFrame(
              domain: HomeCardDomain.audio,
              icon: LucideIcons.music,
              title: 'Audio Hardware Deck',
              trailing: _buildBadge(
                track.isPlaying ? 'Active' : 'Paused',
                track.isPlaying
                    ? TactileTokens.accentVermilion
                    : Colors.white38,
                isPlaying: track.isPlaying,
              ),
              onTap: () => ExpandedPlayerSheet.show(context),
              child: _buildTrackContent(context, track),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackContent(BuildContext context, NowPlaying track) {
    if (size == HomeCardSize.hero) {
      return _buildHero(context, track);
    }
    if (size == HomeCardSize.large) {
      return _buildLarge(context, track);
    }
    return _buildCompact(context, track);
  }

  Widget _buildCompact(BuildContext context, NowPlaying track) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            HardwareVinylGraphic(
              isPlaying: track.isPlaying,
              artworkBytes: track.artworkBytes,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title.isEmpty ? 'Unknown Track' : track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist.isEmpty ? 'Unknown Artist' : track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TactileIconButton(
              icon: LucideIcons.skipBack,
              size: 38,
              iconSize: 18,
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.previous),
            ),
            const SizedBox(width: 4),
            TactileIconButton(
              icon: track.isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 42,
              iconSize: 20,
              color: track.isPlaying ? Colors.black : Colors.white,
              backgroundColor: track.isPlaying
                  ? TactileTokens.accentVermilion
                  : TactileTokens.surfaceRaised,
              onPressed: () {
                NowPlayingService.instance.send(
                  track.isPlaying ? MediaCommand.pause : MediaCommand.play,
                );
              },
            ),
            const SizedBox(width: 4),
            TactileIconButton(
              icon: LucideIcons.skipForward,
              size: 38,
              iconSize: 18,
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.next),
            ),
          ],
        ),
        if (track.durationMs > 0) ...[
          const SizedBox(height: 8),
          ProgressBarX(
            value: track.progressRatio,
            height: 3,
            color: TactileTokens.accentVermilion,
          ),
        ],
      ],
    );
  }

  Widget _buildLarge(BuildContext context, NowPlaying track) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HardwareVinylGraphic(
              isPlaying: track.isPlaying,
              artworkBytes: track.artworkBytes,
              size: 68,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title.isEmpty ? 'Unknown Track' : track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist.isEmpty ? 'Unknown Artist' : track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (track.packageName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.packageName.split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (track.durationMs > 0) ...[
          ProgressBarX(
            value: track.progressRatio,
            height: 4,
            color: TactileTokens.accentVermilion,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMs(track.positionMs),
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatMs(track.durationMs),
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TactileIconButton(
              icon: LucideIcons.skipBack,
              size: 42,
              iconSize: 20,
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.previous),
            ),
            const SizedBox(width: 16),
            TactileIconButton(
              icon: track.isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 52,
              iconSize: 24,
              color: track.isPlaying ? Colors.black : Colors.white,
              backgroundColor: track.isPlaying
                  ? TactileTokens.accentVermilion
                  : TactileTokens.surfaceRaised,
              onPressed: () {
                NowPlayingService.instance.send(
                  track.isPlaying ? MediaCommand.pause : MediaCommand.play,
                );
              },
            ),
            const SizedBox(width: 16),
            TactileIconButton(
              icon: LucideIcons.skipForward,
              size: 42,
              iconSize: 20,
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.next),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context, NowPlaying track) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Center(
          child: HardwareVinylGraphic(
            isPlaying: track.isPlaying,
            artworkBytes: track.artworkBytes,
            size: 130,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          track.title.isEmpty ? 'Unknown Track' : track.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track.artist.isEmpty ? 'Unknown Artist' : track.artist,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        if (track.durationMs > 0) ...[
          ProgressBarX(
            value: track.progressRatio,
            height: 5,
            color: TactileTokens.accentVermilion,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMs(track.positionMs),
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatMs(track.durationMs),
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TactileIconButton(
              icon: LucideIcons.skipBack,
              size: 46,
              iconSize: 22,
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.previous),
            ),
            const SizedBox(width: 20),
            TactileIconButton(
              icon: track.isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 58,
              iconSize: 28,
              color: track.isPlaying ? Colors.black : Colors.white,
              backgroundColor: track.isPlaying
                  ? TactileTokens.accentVermilion
                  : TactileTokens.surfaceRaised,
              onPressed: () {
                NowPlayingService.instance.send(
                  track.isPlaying ? MediaCommand.pause : MediaCommand.play,
                );
              },
            ),
            const SizedBox(width: 20),
            TactileIconButton(
              icon: LucideIcons.skipForward,
              size: 46,
              iconSize: 22,
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.next),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rotating vinyl micro-graphic representing a physical hardware audio deck.
class HardwareVinylGraphic extends StatefulWidget {
  final bool isPlaying;
  final Uint8List? artworkBytes;
  final double size;

  const HardwareVinylGraphic({
    super.key,
    required this.isPlaying,
    this.artworkBytes,
    this.size = 46.0,
  });

  @override
  State<HardwareVinylGraphic> createState() => _HardwareVinylGraphicState();
}

class _HardwareVinylGraphicState extends State<HardwareVinylGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.isPlaying) _rotationController.repeat();
  }

  @override
  void didUpdateWidget(covariant HardwareVinylGraphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _rotationController,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0C0D10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vinyl micro-groove rings
              Container(
                margin: EdgeInsets.all(widget.size * 0.14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.all(widget.size * 0.24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                ),
              ),
              // Center record label / artwork
              ClipOval(
                child: SizedBox(
                  width: widget.size * 0.46,
                  height: widget.size * 0.46,
                  child: widget.artworkBytes != null &&
                          widget.artworkBytes!.isNotEmpty
                      ? Image.memory(
                          widget.artworkBytes!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: TactileTokens.accentVermilion,
                          child: Icon(
                            LucideIcons.disc,
                            size: widget.size * 0.28,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              // Spindle center hole
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated equalizer micro-bars showing live audio activity.
class MicroEqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color? color;

  const MicroEqualizerBars({
    super.key,
    required this.isPlaying,
    this.color,
  });

  @override
  State<MicroEqualizerBars> createState() => _MicroEqualizerBarsState();
}

class _MicroEqualizerBarsState extends State<MicroEqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isPlaying) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MicroEqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.value = 0.2;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? TactileTokens.accentVermilion;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(barColor, widget.isPlaying ? 4.0 + (t * 8.0) : 3.0),
              const SizedBox(width: 2.5),
              _buildBar(barColor, widget.isPlaying ? 12.0 - (t * 7.0) : 4.0),
              const SizedBox(width: 2.5),
              _buildBar(barColor, widget.isPlaying ? 6.0 + (t * 6.0) : 3.0),
              const SizedBox(width: 2.5),
              _buildBar(barColor, widget.isPlaying ? 11.0 - (t * 8.0) : 2.5),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBar(Color color, double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

