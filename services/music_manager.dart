import 'package:just_audio/just_audio.dart';
import 'package:habit_tracker/models/song_model.dart';

class MusicManager {
  // Singleton instance
  static final MusicManager _instance = MusicManager._internal();
  factory MusicManager() => _instance;
  MusicManager._internal();

  final AudioPlayer audioPlayer = AudioPlayer();
  
  List<SongModel>? currentPlaylist;
  int? currentIndex;

  Future<void> setPlaylist(List<SongModel> playlist, int index) async {
    // Only reload if the playlist or song has actually changed or if nothing is playing
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
      print("Error loading playlist: $e");
    }
  }
}