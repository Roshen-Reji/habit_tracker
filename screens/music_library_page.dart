import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:permission_handler/permission_handler.dart';
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/screens/music_player_page.dart';
import 'package:habit_tracker/services/music_manager.dart';

class MusicLibraryPage extends StatefulWidget {
  const MusicLibraryPage({super.key});

  @override
  State<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends State<MusicLibraryPage> with SingleTickerProviderStateMixin {
  final audio_query.OnAudioQuery _audioQuery = audio_query.OnAudioQuery();
  late TabController _tabController;
  
  List<SongModel> _localSongs = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  final Color _accent = Colors.tealAccent; // Keeping the transparent personality

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _requestPermissionsAndScan();

    likedSongIds.addListener(() { if (mounted) setState(() {}); });
    userPlaylists.addListener(() { if (mounted) setState(() {}); });
  }

  Future<void> _requestPermissionsAndScan() async {
    var sStatus = await Permission.storage.request();
    var aStatus = await Permission.audio.request();
    if (sStatus.isGranted || aStatus.isGranted) {
      await _fetchLocalMusic();
    } else {
      setState(() { _isLoading = false; _hasPermission = false; });
    }
  }

  Future<void> _fetchLocalMusic() async {
    List<audio_query.SongModel> fetchedSongs = await _audioQuery.querySongs(
      sortType: audio_query.SongSortType.TITLE,
      uriType: audio_query.UriType.EXTERNAL,
    );
    setState(() {
      _localSongs = fetchedSongs.map((s) => SongModel(
        id: s.id.toString(),
        title: s.title,
        artist: s.artist ?? 'Unknown Artist',
        album: s.album ?? 'Unknown Album', // Mapped album correctly
        artworkUrl: '',
        audioUrl: s.uri ?? '',
        source: SongSource.local,
      )).toList();
      _isLoading = false;
      _hasPermission = true;
    });
  }

  void _showCreatePlaylistDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E).withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Name your playlist...',
            hintStyle: const TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newList = List<PlaylistModel>.from(userPlaylists.value);
                newList.add(PlaylistModel(id: DateTime.now().toString(), name: controller.text, coverUrl: ''));
                userPlaylists.value = newList;
                Navigator.pop(context);
              }
            },
            child: Text('Create', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: _accent)));
    if (!_hasPermission) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Storage permission required.", style: TextStyle(color: Colors.white54))));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          tabs: const [Tab(text: 'LISTEN NOW'), Tab(text: 'LIBRARY'), Tab(text: 'SEARCH')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ListenNowView(songs: _localSongs, accent: _accent),
          _LibraryView(songs: _localSongs, accent: _accent, onCreatePlaylist: _showCreatePlaylistDialog),
          _SearchView(songs: _localSongs, accent: _accent),
        ],
      ),
    );
  }
}

// --- SUB-VIEWS ---

class _ListenNowView extends StatelessWidget {
  final List<SongModel> songs;
  final Color accent;
  const _ListenNowView({required this.songs, required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              if (songs.isNotEmpty) _buildGlassCard(context),
              const SizedBox(height: 30),
              _buildHorizontalList(context, 'Recently Added', songs.reversed.take(12).toList()),
              const SizedBox(height: 120),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        MusicManager().setPlaylist(songs, 0);
        Navigator.push(context, MaterialPageRoute(builder: (context) => MysteriousMusicPlayer(playlist: songs, initialIndex: 0)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          gradient: LinearGradient(
            colors: [const Color(0xFF120024).withOpacity(0.8), Colors.black],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Stack(
              children: [
                Positioned(right: -20, bottom: -20, child: Icon(Icons.graphic_eq, size: 150, color: accent.withOpacity(0.1))),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: accent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text('AUTO-GENERATED', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                      const Spacer(),
                      const Text('Full Library Mix', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      Text('Shuffle all your local tracks', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, String title, List<SongModel> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MysteriousMusicPlayer(playlist: list, initialIndex: i))),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: audio_query.QueryArtworkWidget(
                            id: int.parse(s.id), type: audio_query.ArtworkType.AUDIO,
                            nullArtworkWidget: Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.music_note, color: Colors.white38, size: 40)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LibraryView extends StatelessWidget {
  final List<SongModel> songs;
  final Color accent;
  final VoidCallback onCreatePlaylist;
  const _LibraryView({required this.songs, required this.accent, required this.onCreatePlaylist});

  // Automatic Data Grouping
  Map<String, List<SongModel>> get _groupedByArtist {
    final map = <String, List<SongModel>>{};
    for (var song in songs) {
      map.putIfAbsent(song.artist, () => []).add(song);
    }
    return map;
  }

  Map<String, List<SongModel>> get _groupedByAlbum {
    final map = <String, List<SongModel>>{};
    for (var song in songs) {
      map.putIfAbsent(song.album, () => []).add(song);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 120),
      children: [
        _buildLibraryItem(context, 'Playlists', Icons.queue_music, () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PlaylistsPage(onCreate: onCreatePlaylist)))),
        _buildLibraryItem(context, 'Artists', Icons.mic, () => Navigator.push(context, MaterialPageRoute(builder: (_) => _GroupedListPage(title: 'Artists', groupedData: _groupedByArtist)))),
        _buildLibraryItem(context, 'Albums', Icons.album, () => Navigator.push(context, MaterialPageRoute(builder: (_) => _GroupedListPage(title: 'Albums', groupedData: _groupedByAlbum, isGrid: true)))),
        _buildLibraryItem(context, 'Songs', Icons.music_note, () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SongsListPage(songs: songs)))),
      ],
    );
  }

  Widget _buildLibraryItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: accent, size: 24),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

// --- DEDICATED LIBRARY SUB-PAGES ---

class _PlaylistsPage extends StatelessWidget {
  final VoidCallback onCreate;
  const _PlaylistsPage({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Playlists', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.tealAccent)),
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.tealAccent, onPressed: onCreate, child: const Icon(Icons.add, color: Colors.black)),
      body: ValueListenableBuilder<List<PlaylistModel>>(
        valueListenable: userPlaylists,
        builder: (context, playlists, _) {
          if (playlists.isEmpty) return const Center(child: Text("No Playlists Found", style: TextStyle(color: Colors.white54)));
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, i) {
              final p = playlists[i];
              return ListTile(
                leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.queue_music, color: Colors.white54)),
                title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${p.songs.length} Tracks', style: const TextStyle(color: Colors.white54)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SongsListPage(title: p.name, songs: p.songs))),
              );
            }
          );
        }
      ),
    );
  }
}

class _GroupedListPage extends StatelessWidget {
  final String title;
  final Map<String, List<SongModel>> groupedData;
  final bool isGrid;

  const _GroupedListPage({required this.title, required this.groupedData, this.isGrid = false});

  @override
  Widget build(BuildContext context) {
    final keys = groupedData.keys.toList()..sort();
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.tealAccent)),
      body: isGrid 
        ? GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final groupName = keys[i];
              final songs = groupedData[groupName]!;
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SongsListPage(title: groupName, songs: songs))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.05),
                          child: audio_query.QueryArtworkWidget(id: int.parse(songs.first.id), type: audio_query.ArtworkType.AUDIO, nullArtworkWidget: const Icon(Icons.album, color: Colors.white38, size: 50)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${songs.length} Tracks', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              );
            },
          )
        : ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final groupName = keys[i];
              final songs = groupedData[groupName]!;
              return ListTile(
                title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${songs.length} Tracks', style: const TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SongsListPage(title: groupName, songs: songs))),
              );
            },
          ),
    );
  }
}

class _SongsListPage extends StatelessWidget {
  final String title;
  final List<SongModel> songs;
  const _SongsListPage({this.title = 'Songs', required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.tealAccent)),
      body: songs.isEmpty 
        ? const Center(child: Text("No tracks found.", style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final s = songs[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(width: 45, height: 45, child: audio_query.QueryArtworkWidget(id: int.parse(s.id), type: audio_query.ArtworkType.AUDIO, nullArtworkWidget: Container(color: Colors.white.withOpacity(0.1), child: const Icon(Icons.music_note, color: Colors.white38)))),
                ),
                title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MysteriousMusicPlayer(playlist: songs, initialIndex: i))),
              );
            }
          ),
    );
  }
}

class _SearchView extends StatefulWidget {
  final List<SongModel> songs;
  final Color accent;
  const _SearchView({required this.songs, required this.accent});
  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _ctrl = TextEditingController();
  List<SongModel> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.songs;
    _ctrl.addListener(() => setState(() => _results = widget.songs.where((s) => s.title.toLowerCase().contains(_ctrl.text.toLowerCase())).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            height: 45,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Search Local Files...', hintStyle: TextStyle(color: Colors.white38, fontSize: 16), prefixIcon: Icon(Icons.search, color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final s = _results[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 50, height: 50, child: audio_query.QueryArtworkWidget(id: int.parse(s.id), type: audio_query.ArtworkType.AUDIO, nullArtworkWidget: Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.music_note, color: Colors.white38))))),
                  title: Text(s.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(s.artist, style: const TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MysteriousMusicPlayer(playlist: _results, initialIndex: i))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}