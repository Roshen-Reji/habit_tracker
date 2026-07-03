import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/services/music_manager.dart';
import 'package:habit_tracker/services/lyrics_service.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/features/music/widgets/procedural_artwork.dart';
// --- Persistent Global State ---
final ValueNotifier<Set<String>> likedSongIds = ValueNotifier<Set<String>>({});
final ValueNotifier<List<PlaylistModel>> userPlaylists = ValueNotifier<List<PlaylistModel>>([]);

bool _isMusicStateInitialized = false;

// Synchronizes our ValueNotifiers with Hive for data persistence
void initializeMusicState() {
  if (_isMusicStateInitialized) return;
  _isMusicStateInitialized = true;
  
  final box = Hive.box('settings');
  
  // Load Likes
  final List<dynamic>? savedLikes = box.get('liked_songs');
  if (savedLikes != null) likedSongIds.value = savedLikes.map((e) => e.toString()).toSet();
  
  likedSongIds.addListener(() {
    box.put('liked_songs', likedSongIds.value.toList());
  });

  // Load Playlists via JSON
  final String? playlistsStr = box.get('user_playlists_json');
  if (playlistsStr != null) {
    try {
      final List decoded = jsonDecode(playlistsStr);
      userPlaylists.value = decoded.map((e) => PlaylistModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading playlists: $e");
    }
  }

  userPlaylists.addListener(() {
    final encoded = jsonEncode(userPlaylists.value.map((e) => e.toJson()).toList());
    box.put('user_playlists_json', encoded);
  });
}

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
  bool _isUserScrolling = false;
  Timer? _scrollResumeTimer;
  int _lastAutoScrollIndex = -1;
  List<GlobalKey> _lyricKeys = [];
  Duration totalDuration = Duration.zero;

  // Added state for Shuffle and Repeat
  bool isShuffleOn = false;
  LoopMode loopMode = LoopMode.off;

  // Content Resources
  List<LyricLine>? _lyrics;
  bool _isLoadingLyrics = false;
  Uint8List? _artworkData;

  SongModel get currentSong => widget.playlist[currentIndex];

  @override
  void initState() {
    super.initState();
    initializeMusicState(); // Initialize persistence hook
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

    // Listeners for Shuffle and Loop
    _audioPlayer.shuffleModeEnabledStream.listen((shuffle) {
      if (mounted) setState(() => isShuffleOn = shuffle);
    });

    _audioPlayer.loopModeStream.listen((loop) {
      if (mounted) setState(() => loopMode = loop);
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
      // Force high-resolution extraction
      quality: 100,
      size: 1000, 
      format: audio_query.ArtworkFormat.JPEG,
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
        // Generate a key for every lyric line for accurate scrolling
        _lyricKeys = List.generate(data?.length ?? 0, (index) => GlobalKey());
        _lastAutoScrollIndex = -1; // Reset scroll tracker
      });
    }
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    _scrollResumeTimer?.cancel(); // Prevent memory leaks
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
            color: const Color(0xFF141414).withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(LucideIcons.listPlus, color: Colors.white),
                  title: const Text("Add to Playlist", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaylistSelector();
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.share2, color: Colors.white),
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
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xFF141414).withValues(alpha: 0.6),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ValueListenableBuilder<List<PlaylistModel>>(
              valueListenable: userPlaylists,
              builder: (context, playlists, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(margin: const EdgeInsets.only(top: 16, bottom: 8), width: 40, height: 5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(10))),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Add to Playlist", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.plus, color: AppColors.primary)),
                      title: const Text("Create New Playlist", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreatePlaylistDialog();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    if (playlists.isEmpty) 
                      const Padding(padding: EdgeInsets.all(40), child: Text("No custom playlists yet.", style: TextStyle(color: Colors.white54)))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final p = playlists[index];
                          final bool alreadyAdded = p.songs.contains(currentSong);
                          return ListTile(
                            leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.listMusic, color: Colors.white54)),
                            title: Text(p.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text('${p.songs.length} Tracks', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: alreadyAdded ? const Icon(LucideIcons.checkCircle2, color: AppColors.primary) : null,
                            onTap: () {
                              if (!alreadyAdded) {
                                final updatedSongs = List<SongModel>.from(p.songs)..add(currentSong);
                                final newList = List<PlaylistModel>.from(userPlaylists.value);
                                newList[index] = p.copyWith(songs: updatedSongs);
                                userPlaylists.value = newList;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added to ${p.name}"), backgroundColor: Colors.teal));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Already in ${p.name}"), backgroundColor: Colors.white24));
                              }
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      )
    );
  }

  void _showCreatePlaylistDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E).withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Name your playlist...',
            hintStyle: TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newPlaylist = PlaylistModel(
                  id: DateTime.now().toString(), 
                  name: controller.text, 
                  coverUrl: '',
                  songs: [currentSong], // Directly append the current song!
                );
                final newList = List<PlaylistModel>.from(userPlaylists.value)..add(newPlaylist);
                userPlaylists.value = newList;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Created & added to ${controller.text}"), backgroundColor: Colors.teal));
              }
            },
            child: const Text('Create & Add', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCurrentQueue() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // Starts at 60% of screen height
          minChildSize: 0.4,
          maxChildSize: 0.9,     // Can be dragged up to 90%
          builder: (_, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: const Color(0xFF141414).withValues(alpha: 0.8),
                  child: Column(
                    children: [
                      // Handle bar for dragging
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16), 
                        width: 40, height: 5, 
                        decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(10))
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Text("UP NEXT", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ),
                      // The Queue List
                      Expanded(
                        child: StreamBuilder<int?>(
                          stream: _audioPlayer.currentIndexStream,
                          builder: (context, snapshot) {
                            final activeIndex = snapshot.data ?? currentIndex;
                            
                            return ListView.builder(
                              controller: controller,
                              physics: const BouncingScrollPhysics(),
                              itemCount: widget.playlist.length,
                              itemBuilder: (context, i) {
                                final song = widget.playlist[i];
                                final isPlayingThis = i == activeIndex;
                                
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  leading: Container(
                                    width: 45, height: 45,
                                    decoration: BoxDecoration(
                                      color: isPlayingThis ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), 
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: isPlayingThis
                                        ? const Icon(LucideIcons.barChart2, color: AppColors.primary)
                                        : const Icon(LucideIcons.music, color: Colors.white38),
                                  ),
                                  title: Text(
                                    song.title, 
                                    style: TextStyle(
                                      color: isPlayingThis ? AppColors.primary : Colors.white, 
                                      fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w500
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    song.artist, 
                                    style: TextStyle(color: isPlayingThis ? AppColors.primary.withValues(alpha: 0.7) : Colors.white54, fontSize: 12),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isPlayingThis 
                                      ? const Icon(LucideIcons.volume2, color: AppColors.primary, size: 20)
                                      : null,
                                  onTap: () {
                                    // Use JustAudio's seek to jump to the specific index in the ConcatenatingAudioSource
                                    _audioPlayer.seek(Duration.zero, index: i);
                                    Navigator.pop(context); // Close sheet on tap
                                  },
                                );
                              }
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  String _format(Duration d) => "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  Widget _buildSleekProgressBar(Duration pos, Duration total) {
    if (total == Duration.zero) return const SizedBox(height: 32);
    
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 12,
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), // Hidden thumb
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: pos.inMilliseconds.toDouble().clamp(0.0, total.inMilliseconds.toDouble()),
        max: total.inMilliseconds.toDouble(),
        onChanged: (val) {
          _audioPlayer.seek(Duration(milliseconds: val.toInt()));
        },
      ),
    );
  }

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
          if (_artworkData != null) 
            Image.memory(
              _artworkData!, 
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high, // Smooths out any remaining jagged edges
            )
          else 
            Container(color: const Color(0xFF120024)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
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
          IconButton(icon: const Icon(LucideIcons.chevronDown, color: Colors.white, size: 36), onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Column(
              children: [
                const Text("NOW PLAYING", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text(currentSong.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(icon: const Icon(LucideIcons.moreHorizontal, color: Colors.white, size: 28), onPressed: _showOptions),
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
        child: AnimatedScale(
        scale: isPlaying ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: BentoContainer(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: _artworkData != null 
                ? Image.memory(
                    _artworkData!, 
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  )
                : ProceduralArtwork(
                    title: currentSong.title, 
                    artist: currentSong.artist, 
                    size: MediaQuery.of(context).size.width * 0.8,
                    borderRadius: 24,
                  ),
            )
          )
        )
      )
      )
    );
  }

  // ... (keeping LyricEngine as is) ...
  Widget _buildLyricEngine() {
    if (_isLoadingLyrics) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_lyrics == null || _lyrics!.isEmpty) return const Center(child: Text("Lyrics not synced.", style: TextStyle(color: Colors.white54, fontSize: 18)));
    
    return StreamBuilder<Duration>(
      stream: _audioPlayer.positionStream, 
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        
        // Find the active lyric line index
        int activeIdx = _lyrics!.indexWhere((l) => l.startTime > pos) - 1;
        if (activeIdx < -1) activeIdx = _lyrics!.length - 1;
        
        // Handle Smart Auto-Scrolling
        if (!_isUserScrolling && activeIdx >= 0 && activeIdx != _lastAutoScrollIndex) {
          _lastAutoScrollIndex = activeIdx;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isUserScrolling && activeIdx < _lyricKeys.length) {
              final keyContext = _lyricKeys[activeIdx].currentContext;
              if (keyContext != null) {
                Scrollable.ensureVisible(
                  keyContext,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  alignment: 0.35, 
                );
              }
            }
          });
        }
        
        return NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            // Detect manual user touch/drag
            if (scrollNotification is ScrollUpdateNotification && scrollNotification.dragDetails != null) {
              _isUserScrolling = true;
              _scrollResumeTimer?.cancel();
              
              // Resume auto-scroll after 4 seconds of inactivity
              _scrollResumeTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) {
                  setState(() {
                    _isUserScrolling = false;
                    _lastAutoScrollIndex = -1; // Force a re-snap
                  });
                }
              });
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _lyricsScrollController, 
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height / 2.5, 
              horizontal: 30
            ), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_lyrics!.length, (index) {
                final line = _lyrics![index];
                final active = index == activeIdx;
                final isPast = index < activeIdx;
                
                // Determine the boundary for this line
                Duration nextLineStart = (index + 1 < _lyrics!.length) 
                    ? _lyrics![index + 1].startTime 
                    : totalDuration;
                
                return Container(
                  key: _lyricKeys[index],
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400), 
                    // Dim future lines slightly more than past lines for depth
                    opacity: active ? 1.0 : (isPast ? 0.4 : 0.2), 
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.identity()..scale(active ? 1.05 : 1.0),
                      transformAlignment: Alignment.centerLeft,
                      
                      // Inject the Word-by-Word renderer
                      child: WordByWordLyricLine(
                        text: line.text,
                        lineStart: line.startTime,
                        lineDuration: nextLineStart - line.startTime,
                        currentPosition: pos,
                        isActiveLine: active,
                        isPastLine: isPast,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGlassConsole() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: BentoContainer(
        borderRadius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            Text(currentSong.artist, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: likedSongIds,
                        builder: (context, likes, _) {
                          final isLiked = likes.contains(currentSong.id);
                          return IconButton(
                            icon: Icon(isLiked ? LucideIcons.heart : LucideIcons.heart, color: isLiked ? AppColors.primary : Colors.white, size: 28), 
                            onPressed: _toggleLike
                          );
                        }
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // StreamBuilder for Position (Aesthetic Waveform)
                StreamBuilder<Duration>(
                  stream: _audioPlayer.positionStream, 
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    return Column(
                      children: [
                        _buildSleekProgressBar(pos, totalDuration),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                          children: [
                            Text(_format(pos), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)), 
                            Text("-${_format(totalDuration - pos)}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500))
                          ]
                        ),
                      ]
                    );
                  }
                ),
                
                const SizedBox(height: 16),
                
                // Playback Controls (Shuffle, Prev, Play, Next, Repeat)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    // Shuffle Button
                    IconButton(
                      icon: Icon(LucideIcons.shuffle, color: isShuffleOn ? AppColors.primary : Colors.white54, size: 24), 
                      onPressed: () {
                        _audioPlayer.setShuffleModeEnabled(!isShuffleOn);
                        HapticFeedback.selectionClick();
                      }
                    ),
                    // Skip Previous
                    IconButton(icon: const Icon(LucideIcons.skipBack, size: 36, color: Colors.white), onPressed: () => _audioPlayer.seekToPrevious()),
                    // Play/Pause
                    GestureDetector(
                      onTap: _onPlayPause, 
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Icon(isPlaying ? LucideIcons.pause : LucideIcons.play, size: 40, color: AppTheme.primary)
                      )
                    ),
                    // Skip Next
                    IconButton(icon: const Icon(LucideIcons.skipForward, size: 36, color: Colors.white), onPressed: () => _audioPlayer.seekToNext()),
                    // Repeat Button
                    IconButton(
                      icon: Icon(
                        loopMode == LoopMode.one ? LucideIcons.repeat1 : LucideIcons.repeat, 
                        color: loopMode != LoopMode.off ? AppColors.primary : Colors.white54, 
                        size: 24
                      ), 
                      onPressed: () {
                        LoopMode nextMode;
                        if (loopMode == LoopMode.off) nextMode = LoopMode.all;
                        else if (loopMode == LoopMode.all) nextMode = LoopMode.one;
                        else nextMode = LoopMode.off;
                        _audioPlayer.setLoopMode(nextMode);
                        HapticFeedback.selectionClick();
                      }
                    ),
                  ]
                ),

                const SizedBox(height: 12),

                // Bottom Tools Row: Lyrics & Queue
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    IconButton(icon: Icon(LucideIcons.messageSquare, color: showLyrics ? AppColors.primary : Colors.white54, size: 22), onPressed: () => setState(() => showLyrics = !showLyrics)),
                    const SizedBox(width: 40),
                    IconButton(
                      icon: const Icon(LucideIcons.list, color: Colors.white54, size: 22), 
                      onPressed: _showCurrentQueue, 
                    ),
                  ]
                ),
              ]
            )
        ),
    );
  }
}
// --- Word-by-Word Engine ---
class WordByWordLyricLine extends StatelessWidget {
  final String text;
  final Duration lineStart;
  final Duration lineDuration;
  final Duration currentPosition;
  final bool isActiveLine;
  final bool isPastLine;

  const WordByWordLyricLine({
    super.key,
    required this.text,
    required this.lineStart,
    required this.lineDuration,
    required this.currentPosition,
    required this.isActiveLine,
    required this.isPastLine,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox(height: 20);

    // Split text keeping the trailing spaces attached to words for natural wrapping
    final words = text.split(RegExp(r'(?<=\s)')); 
    
    // Count pure letters to calculate accurate timing weights
    int totalChars = words.fold(0, (sum, word) => sum + word.trim().length);
    if (totalChars == 0) totalChars = 1; // Safety fallback

    Duration currentWordStart = lineStart;
    List<Widget> wordWidgets = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final trimmedWord = word.trim();
      
      // Heuristic: Allocate time based on how long the word is
      double timeWeight = trimmedWord.length / totalChars;
      Duration wordDuration = lineDuration * timeWeight;
      
      // A word is "sung" if it's in a past line, OR if it's the active line and the audio has reached this word's start time
      bool isWordSung = isPastLine || (isActiveLine && currentPosition >= currentWordStart);

      wordWidgets.add(
        AnimatedDefaultTextStyle(
          // This 350ms duration ensures the fade-in is buttery smooth and luxurious
          duration: const Duration(milliseconds: 350), 
          curve: Curves.easeOut,
          style: TextStyle(
            // Smoothly fade from a dim 20% opacity to a brilliant bright white
            color: isWordSung ? Colors.white : Colors.white.withValues(alpha: 0.2),
            // The active line is larger, making it pop out
            fontSize: isActiveLine ? 32 : 26,
            fontWeight: isActiveLine ? FontWeight.w800 : FontWeight.w600,
            height: 1.3,
            // Adds a beautiful blooming glow specifically to the words currently being sung
            shadows: isWordSung && isActiveLine 
                ? [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 12)] 
                : [],
          ),
          child: Text(word), 
        ),
      );

      // Advance the tracker for the next word
      currentWordStart += wordDuration;
    }

    return Wrap(
      children: wordWidgets,
    );
  }
}
