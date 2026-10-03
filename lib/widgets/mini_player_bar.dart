import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/widgets/expanded_player_sheet.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: 240, minWidth: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          color: BentoTheme.surfaceElevated,
                          child: track.artworkBytes != null &&
                                  track.artworkBytes!.isNotEmpty
                              ? Image.memory(
                                  track.artworkBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  LucideIcons.music,
                                  color: BentoTheme.textSecondary,
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
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              track.artist.isEmpty
                                  ? 'Active Session'
                                  : track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
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
                          color: BentoTheme.accent,
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
            ),
          ),
        );
      },
    );
  }
}
