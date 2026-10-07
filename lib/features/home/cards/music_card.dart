import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
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
                child: size == HomeCardSize.hero
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: BentoTheme.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.disc,
                              color: BentoTheme.textSecondary,
                              size: 40,
                            ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 46,
                height: 46,
                color: BentoTheme.surfaceElevated,
                child:
                    track.artworkBytes != null && track.artworkBytes!.isNotEmpty
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
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(LucideIcons.skipBack, color: BentoTheme.textPrimary),
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.previous),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 22,
              icon: Icon(
                track.isPlaying ? LucideIcons.pause : LucideIcons.play,
                color: BentoTheme.accent,
              ),
              onPressed: () {
                NowPlayingService.instance.send(
                  track.isPlaying ? MediaCommand.pause : MediaCommand.play,
                );
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon:
                  Icon(LucideIcons.skipForward, color: BentoTheme.textPrimary),
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
            color: BentoTheme.mediaAccent,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 68,
                height: 68,
                color: BentoTheme.surfaceElevated,
                child:
                    track.artworkBytes != null && track.artworkBytes!.isNotEmpty
                        ? Image.memory(
                            track.artworkBytes!,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            LucideIcons.music,
                            color: BentoTheme.textSecondary,
                            size: 30,
                          ),
              ),
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
            color: BentoTheme.mediaAccent,
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
                ),
              ),
              Text(
                _formatMs(track.durationMs),
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 24,
              icon: Icon(LucideIcons.skipBack, color: BentoTheme.textPrimary),
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.previous),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                color: BentoTheme.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                iconSize: 28,
                icon: Icon(
                  track.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  color: BentoTheme.accent,
                ),
                onPressed: () {
                  NowPlayingService.instance.send(
                    track.isPlaying ? MediaCommand.pause : MediaCommand.play,
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 24,
              icon:
                  Icon(LucideIcons.skipForward, color: BentoTheme.textPrimary),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 120,
              height: 120,
              color: BentoTheme.surfaceElevated,
              child:
                  track.artworkBytes != null && track.artworkBytes!.isNotEmpty
                      ? Image.memory(
                          track.artworkBytes!,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          LucideIcons.music,
                          color: BentoTheme.textSecondary,
                          size: 54,
                        ),
            ),
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
            color: BentoTheme.mediaAccent,
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
                ),
              ),
              Text(
                _formatMs(track.durationMs),
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 28,
              icon: Icon(LucideIcons.skipBack, color: BentoTheme.textPrimary),
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.previous),
            ),
            const SizedBox(width: 24),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: BentoTheme.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: IconButton(
                iconSize: 28,
                icon: Icon(
                  track.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  color: Colors.black,
                ),
                onPressed: () {
                  NowPlayingService.instance.send(
                    track.isPlaying ? MediaCommand.pause : MediaCommand.play,
                  );
                },
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              iconSize: 28,
              icon:
                  Icon(LucideIcons.skipForward, color: BentoTheme.textPrimary),
              onPressed: () =>
                  NowPlayingService.instance.send(MediaCommand.next),
            ),
          ],
        ),
      ],
    );
  }
}
