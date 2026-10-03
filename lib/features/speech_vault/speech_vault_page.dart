import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:habit_tracker/models/speech_model.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SpeechVaultPage extends StatefulWidget {
  const SpeechVaultPage({super.key});

  @override
  State<SpeechVaultPage> createState() => _SpeechVaultPageState();
}

class _SpeechVaultPageState extends State<SpeechVaultPage> {
  late Box<SpeechModel> vaultBox;

  @override
  void initState() {
    super.initState();
    vaultBox = Hive.box<SpeechModel>('speech_vault');
    if (vaultBox.isEmpty) {
      _loadInitialIntelligence();
    }
  }

  void _loadInitialIntelligence() {
    final List<SpeechModel> initialSpeeches = [
      SpeechModel(
          id: 's1',
          title: 'The Psychology of Self-Motivation',
          speaker: 'Scott Geller',
          youtubeVideoId: '7sxpKhIbr0E',
          thumbnailUrl: 'https://img.youtube.com/vi/7sxpKhIbr0E/hqdefault.jpg',
          durationLabel: '15:20'),
    ];
    for (var s in initialSpeeches) vaultBox.add(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("K N O W L E D G E   V A U L T",
            style: TextStyle(letterSpacing: 2, fontSize: 16)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.link, color: AppColors.primary),
            onPressed: () => _showAddVideoDialog(context),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: vaultBox.listenable(),
        builder: (context, Box<SpeechModel> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.ghost, size: 48, color: Colors.white24)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(
                          begin: -8,
                          end: 8,
                          duration: 2.seconds,
                          curve: Curves.easeInOut),
                  const SizedBox(height: 16),
                  const Text("Vault is empty. Add a video link.",
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: box.length,
            itemBuilder: (context, index) =>
                _buildIntelligenceCard(context, box.getAt(index)!)
                    .animate()
                    .fade(duration: 400.ms, delay: (50 * index).ms)
                    .slideY(
                        begin: 0.1,
                        duration: 400.ms,
                        delay: (50 * index).ms,
                        curve: Curves.easeOutBack),
          );
        },
      ),
    );
  }

  void _showAddVideoDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Add new Video",
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: "Paste YouTube Link",
              hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              final videoId = YoutubePlayer.convertUrlToId(controller.text);
              if (videoId != null) {
                vaultBox.add(SpeechModel(
                  id: videoId,
                  title: "Recovered Intelligence",
                  speaker: "External Source",
                  youtubeVideoId: videoId,
                  thumbnailUrl:
                      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  durationLabel: '??:??',
                ));
                Navigator.pop(context);
              }
            },
            child:
                const Text("Add", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceCard(BuildContext context, SpeechModel speech) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SamsungVideoAssistant(speech: speech))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.4),
              gradient: AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15)),
                        child: Image.network(speech.thumbnailUrl,
                            fit: BoxFit.cover, width: double.infinity))),
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(speech.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0)
                      .copyWith(bottom: 12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.mic,
                          color: AppTheme.textSecondary, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(speech.speaker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10))),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SamsungVideoAssistant extends StatefulWidget {
  final SpeechModel speech;
  const SamsungVideoAssistant({super.key, required this.speech});

  @override
  State<SamsungVideoAssistant> createState() => _SamsungVideoAssistantState();
}

class _SamsungVideoAssistantState extends State<SamsungVideoAssistant> {
  late YoutubePlayerController _controller;

  bool _isLocked = false;
  bool _showControls = true;
  bool _isLandscape = false;
  Timer? _hideTimer;

  // --- Gesture State Variables ---
  Duration _startPosition = Duration.zero;
  Duration _seekTarget = Duration.zero;
  bool _isSeeking = false;
  double _panStartX = 0;
  double _panStartY = 0;
  int _currentVolume = 100;
  bool _isVolumeSwipe = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.speech.youtubeVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        hideControls: true,
        disableDragSeek: true, // We handle the seeking natively now
      ),
    );
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isSeeking && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      _showControls = true;
    });
    _startHideTimer();
  }

  void _toggleRotation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    // Always force portrait mode when leaving the player
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _format(Duration d) {
    return "${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Raw Video Player
          Center(
            child: YoutubePlayer(
              controller: _controller,
              progressIndicatorColor: AppColors.primary,
            ),
          ),

          // 2. Full-Screen Transparent Gesture Interceptor
          GestureDetector(
            onTap: _toggleControls,
            onPanStart: (details) {
              if (_isLocked) return;
              _panStartX = details.globalPosition.dx;
              _panStartY = details.globalPosition.dy;
              _startPosition = _controller.value.position;
              _isSeeking = false;
              _isVolumeSwipe = false;
            },
            onPanUpdate: (details) {
              if (_isLocked) return;

              final dx = details.globalPosition.dx - _panStartX;
              final dy = details.globalPosition.dy - _panStartY;

              // Lock into an axis (Horizontal vs Vertical) based on initial movement
              if (!_isSeeking && !_isVolumeSwipe) {
                if (dx.abs() > dy.abs() && dx.abs() > 10) {
                  _isSeeking = true;
                } else if (dy.abs() > dx.abs() && dy.abs() > 10) {
                  _isVolumeSwipe = true;
                }
              }

              // Handle Seeking (Left/Right)
              if (_isSeeking) {
                setState(() {
                  _showControls = true;
                  int secondsOffset = (dx / 5)
                      .round(); // Ratio: 5 pixels dragged = 1 second scrubbed
                  _seekTarget =
                      _startPosition + Duration(seconds: secondsOffset);
                  if (_seekTarget < Duration.zero) _seekTarget = Duration.zero;
                  if (_controller.metadata.duration.inMilliseconds > 0 &&
                      _seekTarget > _controller.metadata.duration) {
                    _seekTarget = _controller.metadata.duration;
                  }
                });
              }
              // Handle Volume (Up/Down)
              else if (_isVolumeSwipe) {
                setState(() {
                  _showControls = true;
                  // Subtracting dy because dragging "Up" gives a negative pixel delta
                  _currentVolume = (_currentVolume - (details.delta.dy))
                      .clamp(0, 100)
                      .toInt();
                  _controller.setVolume(_currentVolume);
                });
              }
            },
            onPanEnd: (details) {
              if (_isLocked) return;
              if (_isSeeking) {
                _controller.seekTo(
                    _seekTarget); // Execute the network seek only once you lift your finger
              }
              setState(() {
                _isSeeking = false;
                _isVolumeSwipe = false;
              });
              _startHideTimer();
            },
            child: Container(color: Colors.transparent),
          ),

          // 3. UI Overlays (Glassmorphism Controls)
          if (_isLocked && _showControls)
            Positioned(
              top: 50,
              left: 20,
              child: _buildGlassButton(LucideIcons.lock, _toggleLock,
                  color: AppColors.primary),
            ),

          if (!_isLocked && _showControls) ...[
            // Top Utility Bar
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassButton(
                      LucideIcons.x, () => Navigator.pop(context)),
                  Row(
                    children: [
                      _buildGlassButton(LucideIcons.unlock, _toggleLock),
                      const SizedBox(width: 16),
                      _buildGlassButton(
                          LucideIcons.smartphone, _toggleRotation),
                    ],
                  )
                ],
              ),
            ),

            // Giant Seeking Indicator (Center)
            if (_isSeeking)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24)),
                  child: Text(
                    "${_format(_seekTarget)} / ${_format(_controller.metadata.duration)}",
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                ),
              ),

            // Giant Volume Indicator (Center)
            if (_isVolumeSwipe)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _currentVolume == 0
                              ? LucideIcons.volumeX
                              : LucideIcons.volume2,
                          color: AppColors.primary,
                          size: 36),
                      const SizedBox(width: 12),
                      Text(
                        "$_currentVolume%",
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Minimalist Bottom Playback Controls
            if (!_isSeeking && !_isVolumeSwipe)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.rotateCcw,
                          color: Colors.white, size: 40),
                      onPressed: () {
                        _controller.seekTo(_controller.value.position -
                            const Duration(seconds: 10));
                        _startHideTimer();
                      },
                    ),
                    const SizedBox(width: 50),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                        _startHideTimer();
                      },
                      child: Icon(
                        _controller.value.isPlaying
                            ? LucideIcons.pauseCircle
                            : LucideIcons.playCircle,
                        color: AppColors.primary,
                        size: 70,
                      ),
                    ),
                    const SizedBox(width: 50),
                    IconButton(
                      icon: const Icon(LucideIcons.rotateCw,
                          color: Colors.white, size: 40),
                      onPressed: () {
                        _controller.seekTo(_controller.value.position +
                            const Duration(seconds: 10));
                        _startHideTimer();
                      },
                    ),
                  ],
                ),
              ),
          ]
        ],
      ),
    );
  }

  // Helper method for the beautiful glass UI buttons
  Widget _buildGlassButton(IconData icon, VoidCallback onTap,
      {Color color = Colors.white}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}
