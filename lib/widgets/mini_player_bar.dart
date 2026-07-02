import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui'; // Required for ImageFilter (Glass effect)
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/services/music_manager.dart';
import 'package:habit_tracker/features/music/music_player_page.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
class GlobalFloatingPlayer extends StatefulWidget {
  const GlobalFloatingPlayer({super.key});

  @override
  State<GlobalFloatingPlayer> createState() => _GlobalFloatingPlayerState();
}

class _GlobalFloatingPlayerState extends State<GlobalFloatingPlayer> {
  double xOffset = 20;
  double yOffset = 100;
  bool isInitialized = false;
  bool isMinimized = false; // Added state for minimized mode
  
  final musicManager = MusicManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitialized) {
      final size = MediaQuery.of(context).size;
      xOffset = (size.width - 150) / 2;
      yOffset = size.height - 250;
      isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: musicManager.audioPlayer.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        
        // Hide completely if nothing is playing
        if (state == null || musicManager.currentPlaylist == null) {
          return const SizedBox.shrink(); 
        }

        final currentIndex = state.currentIndex;
        final currentSong = musicManager.currentPlaylist![currentIndex];
        final size = MediaQuery.of(context).size;
        
        // Dynamic sizing based on minimized state
        final playerWidth = isMinimized ? 60.0 : 140.0;
        final playerHeight = isMinimized ? 60.0 : 180.0;

        xOffset = xOffset.clamp(0.0, size.width - playerWidth);
        yOffset = yOffset.clamp(0.0, size.height - playerHeight);

        return Positioned(
          left: xOffset,
          top: yOffset,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                xOffset += details.delta.dx;
                yOffset += details.delta.dy;
              });
            },
            onTap: () {
              if (isMinimized) {
                // If minimized, tap expands it back to mini player
                setState(() => isMinimized = false);
              } else {
                // If not minimized, tap opens full player page
                globalNavigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => MysteriousMusicPlayer(
                      playlist: musicManager.currentPlaylist!,
                      initialIndex: currentIndex,
                    ),
                  ),
                );
              }
            },
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: playerWidth,
                height: playerHeight,
                child: isMinimized 
                    ? _buildMinimizedUI() 
                    : _buildExactReferenceUI(currentSong, playerWidth, playerHeight),
              ),
            ),
          ),
        );
      },
    );
  }

  // New Widget specifically for the minimized icon
  Widget _buildMinimizedUI() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: const Center(
              child: Icon(LucideIcons.music, color: AppColors.primary, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExactReferenceUI(SongModel song, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            offset: const Offset(0, 15),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.3),  
                  Colors.white.withValues(alpha: 0.05), 
                  Colors.black.withValues(alpha: 0.4),  
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vinyl/CD Top Graphic
                Positioned(
                  top: -25,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFD1D1D1), Color(0xFFF3F3F3), Color(0xFFAFAFAF),
                          Color(0xFFD1D1D1), Color(0xFFF3F3F3), Color(0xFFAFAFAF), Color(0xFFD1D1D1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 15, offset: const Offset(0, 8))
                      ]
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(25.0), 
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 2),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipOval(child: _buildArtwork(song)),
                            Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF9FA1A3), 
                                  border: Border.all(color: Colors.black26, width: 1.0),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // NEW: Minimize Button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isMinimized = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: const Icon(LucideIcons.minimize, color: Colors.white70, size: 14),
                    ),
                  ),
                ),

                // Text and Controls Area
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Icon(LucideIcons.activity, color: Colors.white.withValues(alpha: 0.8), size: 12),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => musicManager.audioPlayer.seekToPrevious(),
                            child: const Icon(LucideIcons.skipBack, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 16),
                          StreamBuilder<PlayerState>(
                            stream: musicManager.audioPlayer.playerStateStream,
                            builder: (context, snap) {
                              final playing = snap.data?.playing ?? false;
                              return GestureDetector(
                                onTap: () => playing ? musicManager.audioPlayer.pause() : musicManager.audioPlayer.play(),
                                child: Icon(playing ? LucideIcons.pause : LucideIcons.play, color: Colors.white, size: 24),
                              );
                            }
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => musicManager.audioPlayer.seekToNext(),
                            child: const Icon(LucideIcons.skipForward, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      _buildProgressLine(),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(SongModel song) {
    if (song.source == SongSource.local) {
      return audio_query.QueryArtworkWidget(
        id: int.parse(song.id),
        type: audio_query.ArtworkType.AUDIO,
        quality: 100,
        artworkFit: BoxFit.cover,
        nullArtworkWidget: Container(
          color: const Color(0xFF2C2C2E),
          child: const Icon(LucideIcons.music, color: Colors.white38, size: 20),
        ),
      );
    }
    return Image.network("https://placehold.co/100x100/2C2C2E/FFFFFF?text=ART", fit: BoxFit.cover);
  }

  Widget _buildProgressLine() {
    return StreamBuilder<Duration>(
      stream: musicManager.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final total = musicManager.audioPlayer.duration ?? Duration.zero;
        final progress = total.inMilliseconds > 0 ? pos.inMilliseconds / total.inMilliseconds : 0.0;

        return Column(
          children: [
            Container(
              width: 90,
              height: 2,
              color: Colors.white.withValues(alpha: 0.3),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${_format(pos)} - ${_format(total)}",
              style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500),
            )
          ],
        );
      }
    );
  }

  String _format(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$min:$sec";
  }
}
