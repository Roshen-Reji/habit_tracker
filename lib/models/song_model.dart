import 'package:flutter/material.dart';

enum SongSource { local, api, appleMusic }

enum RepeatMode { off, all, one }

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl; // URL for API, or path for Local
  final String audioUrl;
  final SongSource source;
  final Color dominantColor;
  final Duration duration;
  final int year;
  final String genre;
  final List<LyricLine>? lyrics;
  final bool isExplicit;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayed;
  final String? albumId;
  final String? artistId;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.audioUrl,
    required this.source,
    this.album = 'Unknown Album',
    this.dominantColor = const Color(0xFFFC3C44), // Apple Music Red
    this.duration = const Duration(minutes: 3, seconds: 30),
    this.year = 2024,
    this.genre = 'Unknown',
    this.lyrics,
    this.isExplicit = false,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayed,
    this.albumId,
    this.artistId,
  });

  // Copy with method for updating properties
  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    String? audioUrl,
    SongSource? source,
    Color? dominantColor,
    Duration? duration,
    int? year,
    String? genre,
    List<LyricLine>? lyrics,
    bool? isExplicit,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayed,
    String? albumId,
    String? artistId,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      source: source ?? this.source,
      dominantColor: dominantColor ?? this.dominantColor,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      lyrics: lyrics ?? this.lyrics,
      isExplicit: isExplicit ?? this.isExplicit,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'artworkUrl': artworkUrl,
      'audioUrl': audioUrl,
      'source': source.toString(),
      'dominantColor': dominantColor.value,
      'duration': duration.inSeconds,
      'year': year,
      'genre': genre,
      'lyrics': lyrics?.map((l) => l.toJson()).toList(),
      'isExplicit': isExplicit,
      'isFavorite': isFavorite,
      'playCount': playCount,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'albumId': albumId,
      'artistId': artistId,
    };
  }

  // Create from JSON
  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'] ?? 'Unknown Album',
      artworkUrl: json['artworkUrl'],
      audioUrl: json['audioUrl'],
      source: SongSource.values.firstWhere(
            (e) => e.toString() == json['source'],
        orElse: () => SongSource.api,
      ),
      dominantColor: Color(json['dominantColor'] ?? 0xFFFC3C44),
      duration: Duration(seconds: json['duration'] ?? 210),
      year: json['year'] ?? 2024,
      genre: json['genre'] ?? 'Unknown',
      lyrics: json['lyrics'] != null
          ? (json['lyrics'] as List).map((l) => LyricLine.fromJson(l)).toList()
          : null,
      isExplicit: json['isExplicit'] ?? false,
      isFavorite: json['isFavorite'] ?? false,
      playCount: json['playCount'] ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.parse(json['lastPlayed'])
          : null,
      albumId: json['albumId'],
      artistId: json['artistId'],
    );
  }

  // Format duration as string (3:45)
  String get formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Get display title with explicit tag
  String get displayTitle {
    return isExplicit ? '$title 🅴' : title;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SongModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Lyric Line Model
class LyricLine {
  final Duration startTime; // Changed from int to Duration for precision
  final String text;

  LyricLine({
    required this.startTime,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.inMilliseconds,
      'text': text,
    };
  }

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      startTime: Duration(milliseconds: json['startTime'] ?? 0),
      text: json['text'] ?? '',
    );
  }
}
// Playlist Model
class PlaylistModel {
  final String id;
  final String name;
  final String description;
  final String coverUrl;
  final List<SongModel> songs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final String? creatorId;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.coverUrl,
    this.description = '',
    this.songs = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPublic = false,
    this.creatorId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get songCount => songs.length;

  Duration get totalDuration {
    return songs.fold(
      Duration.zero,
          (total, song) => total + song.duration,
    );
  }

  PlaylistModel copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    List<SongModel>? songs,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? creatorId,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      creatorId: creatorId ?? this.creatorId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverUrl': coverUrl,
      'songs': songs.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPublic': isPublic,
      'creatorId': creatorId,
    };
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      coverUrl: json['coverUrl'],
      songs: json['songs'] != null
          ? (json['songs'] as List).map((s) => SongModel.fromJson(s)).toList()
          : [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isPublic: json['isPublic'] ?? false,
      creatorId: json['creatorId'],
    );
  }
}

// Album Model
class AlbumModel {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final int year;
  final String genre;
  final List<SongModel> tracks;
  final Color dominantColor;

  AlbumModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.year,
    this.genre = 'Unknown',
    this.tracks = const [],
    this.dominantColor = const Color(0xFFFC3C44),
  });

  int get trackCount => tracks.length;

  Duration get totalDuration {
    return tracks.fold(
      Duration.zero,
          (total, track) => total + track.duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artworkUrl': artworkUrl,
      'year': year,
      'genre': genre,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'dominantColor': dominantColor.value,
    };
  }

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      artworkUrl: json['artworkUrl'],
      year: json['year'],
      genre: json['genre'] ?? 'Unknown',
      tracks: json['tracks'] != null
          ? (json['tracks'] as List).map((t) => SongModel.fromJson(t)).toList()
          : [],
      dominantColor: Color(json['dominantColor'] ?? 0xFFFC3C44),
    );
  }
}

// Artist Model
class ArtistModel {
  final String id;
  final String name;
  final String imageUrl;
  final String bio;
  final List<AlbumModel> albums;
  final List<SongModel> topTracks;
  final int followers;

  ArtistModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.bio = '',
    this.albums = const [],
    this.topTracks = const [],
    this.followers = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'bio': bio,
      'albums': albums.map((a) => a.toJson()).toList(),
      'topTracks': topTracks.map((t) => t.toJson()).toList(),
      'followers': followers,
    };
  }

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      bio: json['bio'] ?? '',
      albums: json['albums'] != null
          ? (json['albums'] as List).map((a) => AlbumModel.fromJson(a)).toList()
          : [],
      topTracks: json['topTracks'] != null
          ? (json['topTracks'] as List).map((t) => SongModel.fromJson(t)).toList()
          : [],
      followers: json['followers'] ?? 0,
    );
  }
}
