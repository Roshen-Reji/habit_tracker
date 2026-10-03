import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:habit_tracker/models/song_model.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'dart:typed_data';

class MusicManager {
  // Singleton instance
  static final MusicManager _instance = MusicManager._internal();
  factory MusicManager() => _instance;
  MusicManager._internal() {
    audioPlayer.currentIndexStream.listen((index) {
      if (index != null && currentPlaylist != null && index < currentPlaylist!.length) {
        _extractColor(currentPlaylist![index]);
      }
    });
  }

  final AudioPlayer audioPlayer = AudioPlayer();
  
  List<SongModel>? currentPlaylist;
  int? currentIndex;
  // Track the playlist identity to avoid redundant reloads
  int? _currentPlaylistHash;

  final ValueNotifier<Color?> currentDominantColor = ValueNotifier(null);

  Future<void> _extractColor(SongModel song) async {
    try {
      final data = await audio_query.OnAudioQuery().queryArtwork(
        int.parse(song.id),
        audio_query.ArtworkType.AUDIO,
        quality: 50,
      );
      if (data != null) {
        final image = MemoryImage(data);
        final palette = await PaletteGenerator.fromImageProvider(image);
        if (palette.dominantColor != null) {
          currentDominantColor.value = palette.dominantColor!.color;
        } else if (palette.lightVibrantColor != null) {
          currentDominantColor.value = palette.lightVibrantColor!.color;
        } else if (palette.darkVibrantColor != null) {
          currentDominantColor.value = palette.darkVibrantColor!.color;
        } else {
          currentDominantColor.value = null;
        }
      } else {
        currentDominantColor.value = null;
      }
    } catch (e) {
      currentDominantColor.value = null;
    }
  }

  Uri _buildSongUri(SongModel song) {
    if (song.audioUrl.isNotEmpty) {
      if (song.audioUrl.startsWith('http') || song.audioUrl.startsWith('content://')) {
        return Uri.parse(song.audioUrl);
      }
    }
    
    if (song.source == SongSource.local) {
      return Uri.parse('content://media/external/audio/media/${song.id}');
    }
    
    return Uri.file(song.audioUrl);
  }

  Future<void> setPlaylist(List<SongModel> playlist, int index) async {
    // Use hash-based identity check to avoid redundant reloads
    final newHash = Object.hashAll([playlist.length, index, ...playlist.take(3).map((s) => s.id)]);
    if (_currentPlaylistHash == newHash && audioPlayer.playing) {
      return; 
    }

    currentPlaylist = playlist;
    currentIndex = index;
    _currentPlaylistHash = newHash;

    try {
      final audioSources = <AudioSource>[];
      for (final song in playlist) {
        try {
          final uri = _buildSongUri(song);
          audioSources.add(AudioSource.uri(
            uri, 
            tag: MediaItem(
              id: song.id,
              title: song.title,
              artist: song.artist,
              album: song.album,
            ),
          ));
        } catch (e) {
          debugPrint("Failed to build URI for song ${song.id}: $e");
        }
      }

      final playlistSource = ConcatenatingAudioSource(
        children: audioSources,
        useLazyPreparation: true,
      );
      
      await audioPlayer.setAudioSource(playlistSource, initialIndex: index);
      audioPlayer.play();
    } catch (e) {
      debugPrint("Error loading playlist: $e");
      // Fallback: If ConcatenatingAudioSource fails (e.g. due to size or a bad track), try loading just the single requested song.
      try {
        final uri = _buildSongUri(playlist[index]);
        final fallbackSource = AudioSource.uri(
          uri, 
          tag: MediaItem(
            id: playlist[index].id,
            title: playlist[index].title,
            artist: playlist[index].artist,
            album: playlist[index].album,
          ),
        );
        await audioPlayer.setAudioSource(fallbackSource);
        audioPlayer.play();
      } catch (e2) {
        debugPrint("Fallback single-song load also failed: $e2");
      }
    }
  }
}
