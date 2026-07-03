import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

  Future<void> setPlaylist(List<SongModel> playlist, int index) async {
    if (currentPlaylist == playlist && currentIndex == index && audioPlayer.playing) {
      return; 
    }

    currentPlaylist = playlist;
    currentIndex = index;

    try {
      final audioSources = playlist.map((song) {
        return AudioSource.uri(Uri.parse(song.audioUrl), tag: song.id);
      }).toList();

      final playlistSource = ConcatenatingAudioSource(children: audioSources);
      await audioPlayer.setAudioSource(playlistSource, initialIndex: index);
      audioPlayer.play();
    } catch (e) {
      print("Error loading playlist: \$e");
    }
  }
}
