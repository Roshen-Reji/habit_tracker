import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ExpandedPlayerSheet extends StatefulWidget {
  const ExpandedPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExpandedPlayerSheet(),
    );
  }

  @override
  State<ExpandedPlayerSheet> createState() => _ExpandedPlayerSheetState();
}

class _ExpandedPlayerSheetState extends State<ExpandedPlayerSheet> {
  double? _dragValue;

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlaying?>(
      valueListenable: NowPlayingService.instance.nowPlaying,
      builder: (context, track, _) {
        if (track == null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Icon(LucideIcons.disc,
                    size: 48, color: BentoTheme.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'No media actively playing',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }

        final currentMs =
            _dragValue != null ? _dragValue!.round() : track.currentPositionMs;
        final totalMs = track.durationMs > 0 ? track.durationMs : 1;
        final sliderValue = currentMs.toDouble().clamp(0.0, totalMs.toDouble());

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Artwork
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(ExpressiveTokens.radiusCard),
                child: Container(
                  width: 200,
                  height: 200,
                  color: BentoTheme.surfaceElevated,
                  child: track.artworkBytes != null &&
                          track.artworkBytes!.isNotEmpty
                      ? Image.memory(
                          track.artworkBytes!,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Icon(
                            LucideIcons.music,
                            size: 64,
                            color: BentoTheme.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Title and artist
              Text(
                track.title.isEmpty ? 'Unknown Title' : track.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                track.artist.isEmpty ? 'Unknown Artist' : track.artist,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (track.album.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  track.album,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Progress Bar
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: BentoTheme.accent,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: BentoTheme.accent,
                ),
                child: Slider(
                  min: 0.0,
                  max: totalMs.toDouble(),
                  value: sliderValue,
                  onChanged: (val) {
                    setState(() {
                      _dragValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    NowPlayingService.instance.send(
                      MediaCommand.seekTo,
                      argument: val.round(),
                    );
                    setState(() {
                      _dragValue = null;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(currentMs),
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDuration(track.durationMs),
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transport Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: Icon(LucideIcons.skipBack,
                        color: BentoTheme.textPrimary),
                    onPressed: () =>
                        NowPlayingService.instance.send(MediaCommand.previous),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BentoTheme.accent,
                    ),
                    child: IconButton(
                      iconSize: 36,
                      icon: Icon(
                        track.isPlaying ? LucideIcons.pause : LucideIcons.play,
                        color: BentoTheme.background,
                      ),
                      onPressed: () {
                        NowPlayingService.instance.send(
                          track.isPlaying
                              ? MediaCommand.pause
                              : MediaCommand.play,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    iconSize: 32,
                    icon: Icon(LucideIcons.skipForward,
                        color: BentoTheme.textPrimary),
                    onPressed: () =>
                        NowPlayingService.instance.send(MediaCommand.next),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Open app button
              TextButton.icon(
                onPressed: () =>
                    NowPlayingService.instance.send(MediaCommand.openApp),
                icon: Icon(LucideIcons.externalLink,
                    size: 16, color: BentoTheme.textSecondary),
                label: Text(
                  'Open Player App',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
