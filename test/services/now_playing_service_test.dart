import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_test_now_playing_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('finance_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('NowPlaying Model & Interpolation Tests (P3-1)', () {
    test('Calculates paused position without interpolation', () {
      final now = DateTime.now().subtract(const Duration(seconds: 10));
      final track = NowPlaying(
        packageName: 'com.spotify.music',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        isPlaying: false,
        positionMs: 30000,
        durationMs: 230000,
        speed: 1.0,
        updatedAt: now,
      );

      // Even though 10 seconds elapsed since updatedAt, isPlaying is false, so position is static
      expect(track.currentPositionMs, equals(30000));
      expect(track.progressRatio, closeTo(30000 / 230000, 0.001));
    });

    test('Interpolates position accurately when playing', () {
      final now = DateTime.now().subtract(const Duration(milliseconds: 5000));
      final track = NowPlaying(
        packageName: 'com.google.android.apps.youtube.music',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        isPlaying: true,
        positionMs: 10000,
        durationMs: 200000,
        speed: 1.0,
        updatedAt: now,
      );

      // 5 seconds elapsed + 10s base = ~15000ms
      expect(track.currentPositionMs, greaterThanOrEqualTo(14900));
      expect(track.currentPositionMs, lessThanOrEqualTo(16000));
    });

    test('Clamps interpolated position to durationMs', () {
      final now = DateTime.now().subtract(const Duration(minutes: 5));
      final track = NowPlaying(
        packageName: 'com.spotify.music',
        title: 'Short Jingle',
        artist: 'Unknown',
        album: '',
        isPlaying: true,
        positionMs: 50000,
        durationMs: 60000,
        speed: 1.0,
        updatedAt: now,
      );

      expect(track.currentPositionMs, equals(60000));
      expect(track.progressRatio, equals(1.0));
    });

    test('Handles 0 duration gracefully without division by zero', () {
      final track = NowPlaying(
        packageName: 'com.unknown.player',
        title: 'Live Stream',
        artist: 'Radio',
        album: '',
        isPlaying: true,
        positionMs: 5000,
        durationMs: 0,
        speed: 1.0,
        updatedAt: DateTime.now(),
      );

      expect(track.progressRatio, equals(0.0));
    });
  });

  group('AI Media Command Parsing Tests (P3-3)', () {
    final aiService = AiService.instance;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('habit/media_control'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'hasAccess') return true;
          if (methodCall.method == 'openApp') return true;
          return true;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('habit/media_control'),
        null,
      );
    });

    test('Parses English pause and stop commands', () async {
      final res = await aiService.handleMediaIntent('pause the music please');
      expect(res, isNotNull);
      expect(res!.intent, equals('music'));
      expect(res.message, contains('Paused'));
      expect(methodCalls.any((call) => call.method == 'pause'), isTrue);
    });

    test('Parses Hinglish pause commands', () async {
      methodCalls.clear();
      final res = await aiService.handleMediaIntent('gana rok do');
      expect(res, isNotNull);
      expect(res!.intent, equals('music'));
      expect(res.message, contains('Paused'));
      expect(methodCalls.any((call) => call.method == 'pause'), isTrue);
    });

    test('Parses next / skip commands in English and Hinglish', () async {
      methodCalls.clear();
      final res1 = await aiService.handleMediaIntent('skip this song');
      expect(res1, isNotNull);
      expect(res1!.message, contains('Skipped to next'));
      expect(methodCalls.any((call) => call.method == 'next'), isTrue);

      methodCalls.clear();
      final res2 = await aiService.handleMediaIntent('agla gana chalao');
      expect(res2, isNotNull);
      expect(methodCalls.any((call) => call.method == 'next'), isTrue);
    });

    test('Parses previous / back commands in English and Hinglish', () async {
      methodCalls.clear();
      final res1 = await aiService.handleMediaIntent('previous track');
      expect(res1, isNotNull);
      expect(res1!.message, contains('previous track'));
      expect(methodCalls.any((call) => call.method == 'previous'), isTrue);

      methodCalls.clear();
      final res2 = await aiService.handleMediaIntent('pichla song sunao');
      expect(res2, isNotNull);
      expect(methodCalls.any((call) => call.method == 'previous'), isTrue);
    });

    test('Parses resume / play command', () async {
      methodCalls.clear();
      final res = await aiService.handleMediaIntent('resume');
      expect(res, isNotNull);
      expect(res!.message, contains('Resumed'));
      expect(methodCalls.any((call) => call.method == 'play'), isTrue);
    });

    test('Parses seek / fast forward commands with time offsets', () async {
      methodCalls.clear();
      final res = await aiService.handleMediaIntent('seek to 45 seconds');
      expect(res, isNotNull);
      expect(res!.message, contains('45 seconds'));
      final seekCall =
          methodCalls.firstWhere((call) => call.method == 'seekTo');
      expect(seekCall.arguments['positionMs'], equals(45000));
    });

    test('Handles play query with active session', () async {
      methodCalls.clear();
      NowPlayingService.instance.nowPlaying.value = NowPlaying(
        packageName: 'com.spotify.music',
        title: 'Current Song',
        artist: 'Artist',
        album: 'Album',
        isPlaying: true,
        positionMs: 1000,
        durationMs: 100000,
        updatedAt: DateTime.now(),
      );

      final res = await aiService.handleMediaIntent('play blinding lights');
      expect(res, isNotNull);
      expect(res!.message, contains('blinding lights'));
      final searchCall =
          methodCalls.firstWhere((call) => call.method == 'playFromSearch');
      expect(searchCall.arguments['query'], equals('blinding lights'));
    });

    test('Handles play query without active session gracefully', () async {
      methodCalls.clear();
      NowPlayingService.instance.nowPlaying.value = null;

      final res = await aiService.handleMediaIntent('play kesariya');
      expect(res, isNotNull);
      expect(res!.message, contains('No active music session detected'));
    });
  });
}
