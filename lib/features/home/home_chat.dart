import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/services/music_manager.dart';
import 'package:habit_tracker/features/home/widgets/chat_message_bubble.dart';
import 'package:habit_tracker/features/diet/widgets/diet_dashboard_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeChatFAB extends StatefulWidget {
  const HomeChatFAB({super.key});

  @override
  State<HomeChatFAB> createState() => _HomeChatFABState();
}

class _HomeChatFABState extends State<HomeChatFAB> with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  void _toggleChat() {
    HapticFeedback.mediumImpact();
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _ChatBottomSheet(),
      ).then((_) {
        if (mounted) setState(() => _isOpen = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = NeuTheme.accent;

    return Positioned(
      bottom: 100,
      right: 16,
      child: GestureDetector(
        onTap: _toggleChat,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.sparkles,
            color: Colors.black,
            size: 26,
          ),
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(reverse: true),
      ).shimmer(
        delay: 2000.ms,
        duration: 1500.ms,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}

class _ChatBottomSheet extends StatefulWidget {
  const _ChatBottomSheet();

  @override
  State<_ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<_ChatBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Cached local songs for music search
  List<SongModel> _localSongs = [];

  @override
  void initState() {
    super.initState();
    _loadLocalSongs();
  }

  Future<void> _loadLocalSongs() async {
    // Try to get songs from MusicManager if available
    final manager = MusicManager();
    if (manager.currentPlaylist != null && manager.currentPlaylist!.isNotEmpty) {
      _localSongs = manager.currentPlaylist!;
    } else {
      // Try to query directly
      try {
        final audioQuery = audio_query.OnAudioQuery();
        final songs = await audioQuery.querySongs(
          sortType: audio_query.SongSortType.TITLE,
          uriType: audio_query.UriType.EXTERNAL,
        );
        _localSongs = songs.map((s) => SongModel(
          id: s.id.toString(),
          title: s.title,
          artist: s.artist ?? 'Unknown Artist',
          album: s.album ?? 'Unknown Album',
          artworkUrl: '',
          audioUrl: s.uri ?? '',
          source: SongSource.local,
        )).toList();
      } catch (e) {
        // Music library unavailable
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await AiService.instance.processMessage(text);

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        actions: response.actions,
      ));
    });
    _scrollToBottom();

    // Auto-execute music play actions (no confirmation needed for playing music)
    for (var action in response.actions) {
      if (action.type == 'music_play') {
        final matched = AiService.instance.executeMusicAction(action, _localSongs);
        if (matched != null) {
          setState(() {
            action.isConfirmed = true;
            _messages.add(ChatMessage(
              text: "🎵 Now playing: ${matched.title} by ${matched.artist}",
              isUser: false,
            ));
          });
          _scrollToBottom();
        }
      }
    }
  }

  void _confirmAction(AiAction action) {
    AiService.instance.executeAction(action, availableSongs: _localSongs);
    setState(() {
      action.isConfirmed = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getConfirmText(action)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _rejectAction(AiAction action) {
    setState(() {
      for (var msg in _messages) {
        msg.actions?.remove(action);
      }
    });
  }

  String _getConfirmText(AiAction action) {
    switch (action.type) {
      case 'food_entry':
        return '✓ Added ${action.payload['name']} to food log';
      case 'burn_entry':
        return '✓ Logged ${action.payload['calories_burned']} kcal burn';
      case 'task_create':
        return '✓ Created mission: ${action.payload['title']}';
      case 'music_play':
        return '🎵 Playing: ${action.payload['search_query']}';
      default:
        return '✓ Done';
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = NeuTheme.accent;
    final height = MediaQuery.of(context).size.height * 0.75;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(LucideIcons.sparkles, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "COMMANDER AI",
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(LucideIcons.x, color: AppColors.textTertiary, size: 20),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.glassBorder, height: 1),

              // Messages
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(accent)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return _buildLoadingIndicator(accent);
                          }
                          return ChatMessageBubble(
                            message: _messages[index],
                            onConfirmAction: _confirmAction,
                            onRejectAction: _rejectAction,
                          );
                        },
                      ),
              ),

              // Input
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: accent.withValues(alpha: 0.1))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: "Ask anything — diet, tasks, finance, music...",
                            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _sendMessage(_controller.text),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.send, color: Colors.black, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color accent) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.sparkles, color: accent.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 16),
              Text(
                "Your Super AI Assistant",
                style: TextStyle(
                  color: accent.withValues(alpha: 0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "I can handle diet, tasks, finance,\nmusic, and more!",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestion("🍽️ I had rice and chicken", accent),
                  _buildSuggestion("✅ Today I'll study 3 hours", accent),
                  _buildSuggestion("💰 How are my expenses?", accent),
                  _buildSuggestion("🎵 Play something", accent),
                  _buildSuggestion("🎯 Am I on track?", accent),
                  _buildSuggestion("🏃 Burned 200 kcal running", accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestion(String text, Color accent) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Text(
          text,
          style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color accent) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
            const SizedBox(width: 10),
            const Text(
              "Thinking...",
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      ).animate().fade(duration: 200.ms),
    );
  }
}
