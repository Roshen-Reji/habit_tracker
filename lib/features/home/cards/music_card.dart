import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/home/widgets/expanded_player_sheet.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MusicCard extends StatelessWidget {
  const MusicCard({super.key});

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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
                icon: LucideIcons.music,
                title: 'MUSIC CONTROLLER',
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
                icon: LucideIcons.music,
                title: 'NOW PLAYING',
                trailing: _buildBadge('Idle', BentoTheme.textSecondary),
                onTap: () => NowPlayingService.instance.refresh(),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BentoTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.disc,
                        color: BentoTheme.textSecondary,
                        size: 22,
                      ),
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
              icon: LucideIcons.music,
              title: 'NOW PLAYING',
              trailing: _buildBadge(
                track.isPlaying ? 'Active' : 'Paused',
                track.isPlaying ? BentoTheme.accent : Colors.white38,
              ),
              onTap: () => ExpandedPlayerSheet.show(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Artwork thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 46,
                          height: 46,
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
                                  size: 20,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title.isEmpty
                                  ? 'Unknown Track'
                                  : track.title,
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
                              track.artist.isEmpty
                                  ? 'Unknown Artist'
                                  : track.artist,
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

                      // Quick controls
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        icon: Icon(LucideIcons.skipBack,
                            color: BentoTheme.textPrimary),
                        onPressed: () => NowPlayingService.instance
                            .send(MediaCommand.previous),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 22,
                        icon: Icon(
                          track.isPlaying
                              ? LucideIcons.pause
                              : LucideIcons.play,
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        icon: Icon(LucideIcons.skipForward,
                            color: BentoTheme.textPrimary),
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
                      color: BentoTheme.accent,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
