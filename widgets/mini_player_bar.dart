import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/services/music_manager.dart';
import 'package:habit_tracker/screens/music_player_page.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final musicManager = MusicManager();

    return StreamBuilder<SequenceState?>(
      stream: musicManager.audioPlayer.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        
        // Hide the bar entirely if no music is loaded or playlist is missing
        if (state == null || musicManager.currentPlaylist == null) {
          return const SizedBox.shrink();
        }

        final currentIndex = state.currentIndex;
        final currentSong = musicManager.currentPlaylist![currentIndex];

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MysteriousMusicPlayer(
                playlist: musicManager.currentPlaylist!,
                initialIndex: currentIndex,
              ),
            ),
          ),
          child: Container(
            height: 70, // Slightly taller for better touch targets in the unified bar
            decoration: BoxDecoration(
              // Semi-transparent to allow the HomePage's BackdropFilter to layer correctly
              color: const Color(0xFF120024).withOpacity(0.4), 
              border: Border(
                bottom: BorderSide(
                  color: Colors.tealAccent.withOpacity(0.1), 
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Mini Artwork
                  _buildMiniArtwork(currentSong),
                  const SizedBox(width: 12),
                  
                  // Song Details
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.tealAccent.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Play/Pause Interaction
                  StreamBuilder<PlayerState>(
                    stream: musicManager.audioPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => playing 
                            ? musicManager.audioPlayer.pause() 
                            : musicManager.audioPlayer.play(),
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

  Widget _buildMiniArtwork(SongModel song) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: song.source == SongSource.local
            ? audio_query.QueryArtworkWidget(
                id: int.parse(song.id),
                type: audio_query.ArtworkType.AUDIO,
                nullArtworkWidget: Container(
                  color: Colors.white.withOpacity(0.05),
                  child: const Icon(Icons.music_note, color: Colors.tealAccent, size: 20),
                ),
              )
            : Image.network(
                "https://placehold.co/100x100/120024/teal?text=CMD",
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}