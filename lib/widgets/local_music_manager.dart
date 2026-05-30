import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart' as on_audio_query;
import 'package:permission_handler/permission_handler.dart';
import 'package:habit_tracker/models/song_model.dart';

class LocalMusicManager extends StatefulWidget {
  final Function(List<SongModel>) onSongsLoaded;

  const LocalMusicManager({super.key, required this.onSongsLoaded});

  @override
  State<LocalMusicManager> createState() => _LocalMusicManagerState();
}

class _LocalMusicManagerState extends State<LocalMusicManager> {
  final on_audio_query.OnAudioQuery _audioQuery = on_audio_query.OnAudioQuery();

  @override
  void initState() {
    super.initState();
    _checkPermissionAndScan();
  }

  Future<void> _checkPermissionAndScan() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      await _scanForMusic();
    } else {
      if (!mounted) return;
      // Handle permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to scan for music.')),
      );
    }
  }

  Future<void> _scanForMusic() async {
    List<SongModel> localSongs = [];
    List<on_audio_query.SongModel> songModels = await _audioQuery.querySongs(
      sortType: on_audio_query.SongSortType.TITLE,
      orderType: on_audio_query.OrderType.ASC_OR_SMALLER,
      uriType: on_audio_query.UriType.EXTERNAL,
      ignoreCase: true,
    );

    for (var song in songModels) {
      localSongs.add(SongModel(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        artworkUrl: '', // You might need a way to get artwork
        audioUrl: song.uri!,
        source: SongSource.local,
      ));
    }

    widget.onSongsLoaded(localSongs);
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning for local music...'),
        ],
      ),
    );
  }
}
