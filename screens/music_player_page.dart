import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/services/music_manager.dart';
import 'package:habit_tracker/services/lyrics_service.dart';

// --- Persistent Global State ---
final ValueNotifier<Set<String>> likedSongIds = ValueNotifier<Set<String>>({});
final ValueNotifier<List<PlaylistModel>> userPlaylists = ValueNotifier<List<PlaylistModel>>([]);

class MysteriousMusicPlayer extends StatefulWidget {
  final List<SongModel> playlist;
  final int initialIndex;

  const MysteriousMusicPlayer({
    super.key,
    required this.playlist,
    required this.initialIndex,
  });

  @override
  State<MysteriousMusicPlayer> createState() => _MysteriousMusicPlayerState();
}

class _MysteriousMusicPlayerState extends State<MysteriousMusicPlayer> with TickerProviderStateMixin {
  final MusicManager _musicManager = MusicManager();
  AudioPlayer get _audioPlayer => _musicManager.audioPlayer;
  
  late final ScrollController _lyricsScrollController;
  late int currentIndex;
  
  bool isPlaying = false;
  bool showLyrics = false; 
  Duration totalDuration = Duration.zero;

  // Content Resources
  List<LyricLine>? _lyrics;
  bool _isLoadingLyrics = false;
  Uint8List? _artworkData;

  SongModel get currentSong => widget.playlist[currentIndex];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _lyricsScrollController = ScrollController();
    
    _musicManager.setPlaylist(widget.playlist, widget.initialIndex);
    _initializeSystems();
  }

  void _initializeSystems() {
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && mounted && index != currentIndex) {
        setState(() {
          currentIndex = index;
          _lyrics = null;
          _artworkData = null;
        });
        _refreshResources();
      }
    });

    _audioPlayer.durationStream.listen((d) {
      if (d != null && mounted) setState(() => totalDuration = d);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => isPlaying = state.playing);
    });
    
    _refreshResources();
  }

  Future<void> _refreshResources() async {
    await Future.wait([
      _extractArtwork(),
      _fetchLyrics(),
    ]);
  }

  Future<void> _extractArtwork() async {
    final data = await audio_query.OnAudioQuery().queryArtwork(
      int.parse(currentSong.id),
      audio_query.ArtworkType.AUDIO,
    );
    if (mounted && data != null) setState(() { _artworkData = data; });
  }

  Future<void> _fetchLyrics() async {
    if (!mounted) return;
    setState(() => _isLoadingLyrics = true);
    final data = await LyricsService.fetchLyrics(currentSong.title, currentSong.artist);
    if (mounted) {
      setState(() {
        _lyrics = data;
        _isLoadingLyrics = false;
      });
    }
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _onPlayPause() {
    isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
    HapticFeedback.lightImpact();
  }

  void _toggleLike() {
    final likes = Set<String>.from(likedSongIds.value);
    if (likes.contains(currentSong.id)) {
      likes.remove(currentSong.id);
    } else {
      likes.add(currentSong.id);
      HapticFeedback.mediumImpact();
    }
    likedSongIds.value = likes;
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xFF141414).withOpacity(0.6),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: Colors.white),
                  title: const Text("Add to Playlist", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaylistSelector();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text("Share Song", style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context)
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaylistSelector() {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xFF141414).withOpacity(0.6),
            child: ValueListenableBuilder<List<PlaylistModel>>(
              valueListenable: userPlaylists,
              builder: (context, playlists, child) {
                if (playlists.isEmpty) return const Padding(padding: EdgeInsets.all(40), child: Text("No playlists available. Create one in Library.", style: TextStyle(color: Colors.white70)));
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final p = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music, color: Colors.white),
                      title: Text(p.name, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        final updatedSongs = List<SongModel>.from(p.songs);
                        if (!updatedSongs.contains(currentSong)) {
                          updatedSongs.add(currentSong);
                          final newList = List<PlaylistModel>.from(userPlaylists.value);
                          newList[index] = p.copyWith(songs: updatedSongs);
                          userPlaylists.value = newList;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added to ${p.name}"), backgroundColor: Colors.teal));
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      )
    );
  }

  String _format(Duration d) => "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBlurredBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: showLyrics ? _buildLyricEngine() : _buildArtworkView(),
                  ),
                ),
                _buildGlassConsole(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground() {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_artworkData != null) Image.memory(_artworkData!, fit: BoxFit.cover)
          else Container(color: const Color(0xFF120024)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 36), onPressed: () => Navigator.pop(context)),
          Column(
            children: [
              const Text("NOW PLAYING", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(currentSong.album, style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          IconButton(icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28), onPressed: _showOptions),
        ]
      )
    );
  }

  Widget _buildArtworkView() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(isPlaying ? 30 : 45),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: _artworkData != null 
                ? Image.memory(_artworkData!, fit: BoxFit.cover)
                : Container(color: const Color(0xFF2C2C2E), child: const Icon(Icons.music_note, color: Colors.white38, size: 100)),
            )
          )
        )
      )
    );
  }

  Widget _buildLyricEngine() {
    if (_isLoadingLyrics) return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
    if (_lyrics == null || _lyrics!.isEmpty) return const Center(child: Text("Lyrics not synced.", style: TextStyle(color: Colors.white54, fontSize: 18)));
    
    return StreamBuilder<Duration>(
      stream: _audioPlayer.positionStream, 
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        int activeIdx = _lyrics!.indexWhere((l) => l.startTime > pos) - 1;
        if (activeIdx < -1) activeIdx = _lyrics!.length - 1;
        
        return ListView.builder(
          controller: _lyricsScrollController, 
          padding: const EdgeInsets.symmetric(vertical: 200, horizontal: 30), 
          itemCount: _lyrics!.length, 
          itemBuilder: (context, index) {
            final active = index == activeIdx;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300), 
              opacity: active ? 1.0 : 0.3, 
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16), 
                child: Text(_lyrics![index].text, style: TextStyle(color: Colors.white, fontSize: active ? 32 : 24, fontWeight: FontWeight.bold))
              )
            );
          }
        );
      }
    );
  }

  Widget _buildGlassConsole() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                if (!showLyrics) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentSong.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(currentSong.artist, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: likedSongIds,
                        builder: (context, likes, _) {
                          final isLiked = likes.contains(currentSong.id);
                          return IconButton(
                            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border_rounded, color: isLiked ? Colors.tealAccent : Colors.white, size: 28), 
                            onPressed: _toggleLike
                          );
                        }
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                StreamBuilder<Duration>(
                  stream: _audioPlayer.positionStream, 
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4, 
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: Colors.tealAccent, 
                            inactiveTrackColor: Colors.white.withOpacity(0.2), 
                            thumbColor: Colors.white
                          ), 
                          child: Slider(
                            value: pos.inMilliseconds.toDouble().clamp(0, totalDuration.inMilliseconds.toDouble()), 
                            max: totalDuration.inMilliseconds.toDouble() > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0, 
                            onChanged: (v) => _audioPlayer.seek(Duration(milliseconds: v.toInt()))
                          )
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                          children: [
                            Text(_format(pos), style: const TextStyle(color: Colors.white54, fontSize: 12)), 
                            Text("-${_format(totalDuration - pos)}", style: const TextStyle(color: Colors.white54, fontSize: 12))
                          ]
                        ),
                      ]
                    );
                  }
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                  children: [
                    IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 40, color: Colors.white), onPressed: () => _audioPlayer.seekToPrevious()),
                    GestureDetector(
                      onTap: _onPlayPause, 
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 50, color: Colors.tealAccent)
                      )
                    ),
                    IconButton(icon: const Icon(Icons.skip_next_rounded, size: 40, color: Colors.white), onPressed: () => _audioPlayer.seekToNext()),
                  ]
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    IconButton(icon: Icon(Icons.chat_bubble_outline_rounded, color: showLyrics ? Colors.tealAccent : Colors.white54, size: 24), onPressed: () => setState(() => showLyrics = !showLyrics)),
                    IconButton(icon: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white54, size: 24), onPressed: () {}),
                  ]
                ),
              ]
            )
          ),
        ),
      ),
    );
  }
}