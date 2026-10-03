import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';

enum MediaCommand {
  play,
  pause,
  next,
  previous,
  seekTo,
  stop,
  playFromSearch,
  openApp,
}

class NowPlaying {
  final String packageName;
  final String title;
  final String artist;
  final String album;
  final Uint8List? artworkBytes;
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final double speed;
  final DateTime updatedAt;

  const NowPlaying({
    required this.packageName,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkBytes,
    required this.isPlaying,
    required this.positionMs,
    required this.durationMs,
    this.speed = 1.0,
    required this.updatedAt,
  });

  factory NowPlaying.fromMap(Map<dynamic, dynamic> map) {
    return NowPlaying(
      packageName: (map['package'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      artist: (map['artist'] ?? '').toString(),
      album: (map['album'] ?? '').toString(),
      artworkBytes: map['artwork'] is Uint8List
          ? map['artwork'] as Uint8List
          : map['artwork'] is List
              ? Uint8List.fromList(List<int>.from(map['artwork'] as List))
              : null,
      isPlaying: map['isPlaying'] == true,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['updatedAt'] as num).toInt())
          : DateTime.now(),
    );
  }

  /// Calculates interpolated playback position without polling.
  int get currentPositionMs {
    if (!isPlaying || speed == 0) {
      if (durationMs > 0 && positionMs > durationMs) return durationMs;
      return positionMs < 0 ? 0 : positionMs;
    }
    final elapsedMs = DateTime.now().difference(updatedAt).inMilliseconds;
    final interpolated = positionMs + (elapsedMs * speed).round();
    if (durationMs > 0) {
      return interpolated.clamp(0, durationMs);
    }
    return interpolated < 0 ? 0 : interpolated;
  }

  double get progressRatio {
    if (durationMs <= 0) return 0.0;
    return (currentPositionMs / durationMs).clamp(0.0, 1.0);
  }
}

class NowPlayingService {
  static const MethodChannel _methodChannel =
      MethodChannel('habit/media_control');
  static const EventChannel _eventChannel = EventChannel('habit/now_playing');

  static final NowPlayingService instance = NowPlayingService._internal();
  factory NowPlayingService() => instance;

  NowPlayingService._internal() {
    _initStream();
  }

  final ValueNotifier<NowPlaying?> nowPlaying =
      ValueNotifier<NowPlaying?>(null);
  final ValueNotifier<Color?> currentDominantColor =
      ValueNotifier<Color?>(null);
  final ValueNotifier<bool> hasNotificationAccess = ValueNotifier<bool>(false);

  bool _isInitialized = false;

  void _initStream() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Platform guard: Android only
    if (!kIsWeb && Platform.isAndroid) {
      checkAccess();
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final parsed = NowPlaying.fromMap(event);
            nowPlaying.value = parsed;
            _extractColor(parsed.artworkBytes);
          } else {
            nowPlaying.value = null;
            currentDominantColor.value = null;
          }
        },
        onError: (dynamic error) {
          debugPrint('NowPlaying stream error: $error');
          nowPlaying.value = null;
        },
      );
    }
  }

  Future<void> _extractColor(Uint8List? artwork) async {
    if (artwork == null || artwork.isEmpty) {
      currentDominantColor.value = null;
      return;
    }
    try {
      final palette =
          await PaletteGenerator.fromImageProvider(MemoryImage(artwork));
      currentDominantColor.value =
          palette.dominantColor?.color ?? palette.vibrantColor?.color;
    } catch (_) {
      currentDominantColor.value = null;
    }
  }

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST'));

  Future<bool> checkAccess() async {
    if (!_isSupportedPlatform) return false;
    try {
      final bool access =
          await _methodChannel.invokeMethod<bool>('hasAccess') ?? false;
      hasNotificationAccess.value = access;
      return access;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    if (!_isSupportedPlatform) return;
    try {
      await _methodChannel.invokeMethod('openAccessSettings');
    } catch (e) {
      debugPrint('Error opening access settings: $e');
    }
  }

  Future<void> refresh() async {
    if (!_isSupportedPlatform) return;
    try {
      await _methodChannel.invokeMethod('refresh');
    } catch (_) {}
  }

  Future<bool> send(MediaCommand command, {dynamic argument}) async {
    if (!_isSupportedPlatform) return false;
    try {
      switch (command) {
        case MediaCommand.play:
          await _methodChannel.invokeMethod('play');
          return true;
        case MediaCommand.pause:
          await _methodChannel.invokeMethod('pause');
          return true;
        case MediaCommand.next:
          await _methodChannel.invokeMethod('next');
          return true;
        case MediaCommand.previous:
          await _methodChannel.invokeMethod('previous');
          return true;
        case MediaCommand.seekTo:
          final pos = argument is int ? argument : (argument as num).toInt();
          await _methodChannel.invokeMethod('seekTo', {'positionMs': pos});
          return true;
        case MediaCommand.stop:
          await _methodChannel.invokeMethod('stop');
          return true;
        case MediaCommand.playFromSearch:
          await _methodChannel.invokeMethod(
              'playFromSearch', {'query': argument?.toString() ?? ''});
          return true;
        case MediaCommand.openApp:
          final bool opened =
              await _methodChannel.invokeMethod<bool>('openApp') ?? false;
          return opened;
      }
    } catch (e) {
      debugPrint('Error executing media command $command: $e');
      return false;
    }
  }
}
