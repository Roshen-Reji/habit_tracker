import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/features/home/widgets/expanded_player_sheet.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Hardware Mini-Player Dock Lip designed to sit seamlessly on top of
/// the Floating Navigation Dock as a single unified hardware unit (AGENTS.md Phase 4).
class MiniPlayerDockLip extends StatefulWidget {
  final VoidCallback? onExpand;

  const MiniPlayerDockLip({
    super.key,
    this.onExpand,
  });

  @override
  State<MiniPlayerDockLip> createState() => _MiniPlayerDockLipState();
}

class _MiniPlayerDockLipState extends State<MiniPlayerDockLip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _syncRotation(bool isPlaying) {
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlaying?>(
      valueListenable: NowPlayingService.instance.nowPlaying,
      builder: (context, track, _) {
        if (track == null) {
          _syncRotation(false);
          return const SizedBox.shrink();
        }

        _syncRotation(track.isPlaying);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.onExpand != null) {
              widget.onExpand!();
            } else {
              ExpandedPlayerSheet.show(context);
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TactileTokens.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              border: Border.all(
                color: TactileTokens.specularBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // Rotating Vinyl / Album Artwork with Hero morph
                Hero(
                  tag: 'player_artwork_hero',
                  child: RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TactileTokens.surfacePressed,
                        border: Border.all(
                          color: TactileTokens.specularBorder,
                          width: 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: track.artworkBytes != null &&
                              track.artworkBytes!.isNotEmpty
                          ? Image.memory(
                              track.artworkBytes!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              LucideIcons.music,
                              color: TactileTokens.vermilion,
                              size: 14,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Track Info with tabular / tight tracking
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title.isEmpty ? 'Now Playing' : track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: TactileTokens.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        track.artist.isEmpty ? 'Active Session' : track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: TactileTokens.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Equalizer Bar Animation or Play/Pause Button
                TactileIconButton(
                  size: 36,
                  iconSize: 16,
                  borderRadius: 10,
                  backgroundColor: TactileTokens.surfacePressed,
                  color: track.isPlaying
                      ? TactileTokens.vermilion
                      : TactileTokens.textPrimary,
                  icon: track.isPlaying
                      ? LucideIcons.pause
                      : LucideIcons.play,
                  onPressed: () {
                    NowPlayingService.instance.send(
                      track.isPlaying
                          ? MediaCommand.pause
                          : MediaCommand.play,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Legacy floating player kept for backward-compatibility if used outside dock.
class GlobalFloatingPlayer extends StatefulWidget {
  const GlobalFloatingPlayer({super.key});

  @override
  State<GlobalFloatingPlayer> createState() => _GlobalFloatingPlayerState();
}

class _GlobalFloatingPlayerState extends State<GlobalFloatingPlayer> {
  double _xOffset = 16;
  double _yOffset = 100;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final size = MediaQuery.of(context).size;
      _xOffset = 16;
      _yOffset = size.height - 150;
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlaying?>(
      valueListenable: NowPlayingService.instance.nowPlaying,
      builder: (context, track, _) {
        if (track == null) {
          return const SizedBox.shrink();
        }

        final size = MediaQuery.of(context).size;
        final clampedX =
            _xOffset.clamp(8.0, (size.width - 240).clamp(8.0, double.infinity));
        final clampedY = _yOffset.clamp(
            40.0, (size.height - 80).clamp(40.0, double.infinity));

        return Positioned(
          left: clampedX,
          top: clampedY,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _xOffset += details.delta.dx;
                _yOffset += details.delta.dy;
              });
            },
            onTap: () {
              HapticFeedback.lightImpact();
              ExpandedPlayerSheet.show(context);
            },
            child: Container(
              constraints:
                  const BoxConstraints(maxWidth: 240, minWidth: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          color: TactileTokens.surfaceRaised,
                          child: track.artworkBytes != null &&
                                  track.artworkBytes!.isNotEmpty
                              ? Image.memory(
                                  track.artworkBytes!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  LucideIcons.music,
                                  color: TactileTokens.vermilion,
                                  size: 16,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Text
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title.isEmpty ? 'Now Playing' : track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: TactileTokens.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              track.artist.isEmpty
                                  ? 'Active Session'
                                  : track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: TactileTokens.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Play/Pause button
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          track.isPlaying
                              ? LucideIcons.pause
                              : LucideIcons.play,
                          size: 16,
                          color: TactileTokens.vermilion,
                        ),
                        onPressed: () {
                          NowPlayingService.instance.send(
                            track.isPlaying
                                ? MediaCommand.pause
                                : MediaCommand.play,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
      },
    );
  }
}
