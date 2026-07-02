import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/features/diet/widgets/diet_dashboard_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DietChat extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const DietChat({super.key, this.onDataChanged});

  @override
  State<DietChat> createState() => _DietChatState();
}

class _DietChatState extends State<DietChat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await AiService.instance.processMessage(text, contextHint: 'diet');

    setState(() {
      _isLoading = false;
      _messages.add(_ChatMessage(
        text: response.message,
        isUser: false,
        actions: response.actions,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _messages.add(_ChatMessage(text: "📸 [Food photo sent]", isUser: true));
        _isLoading = true;
      });
      _scrollToBottom();

      // For now, ask AI to estimate based on description since we can't send images in basic Gemini text mode
      final response = await AiService.instance.processMessage(
        "I just took a photo of my food. Please ask me to describe what's in the photo so you can estimate the calories and macros.",
        contextHint: 'diet',
      );

      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(text: response.message, isUser: false));
      });
      _scrollToBottom();
    }
  }

  void _confirmAction(AiAction action, int messageIndex) {
    AiService.instance.executeAction(action);
    setState(() {
      action.isConfirmed = true;
    });
    widget.onDataChanged?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getConfirmationText(action)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getConfirmationText(AiAction action) {
    switch (action.type) {
      case 'food_entry':
        return '✓ Added ${action.payload['name']} to food log';
      case 'burn_entry':
        return '✓ Added ${action.payload['calories_burned']} kcal burn for ${action.payload['activity']}';
      default:
        return '✓ Action confirmed';
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    final accent = DietTheme.accent;

    return Column(
      children: [
        // Chat messages
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(accent)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return _buildLoadingBubble();
                    }
                    return _buildMessageBubble(_messages[index], index);
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: accent, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: "Log food, ask for report...",
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
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
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu_rounded, color: accent.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 16),
          Text(
            "Your AI Nutritionist",
            style: TextStyle(
              color: accent.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tell me what you ate, snap a photo,\nor ask for your daily report",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip("I had 2 eggs for breakfast", accent),
              _buildSuggestionChip("Show daily report", accent),
              _buildSuggestionChip("How's my nutrition?", accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, Color accent) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Text(text, style: TextStyle(color: accent, fontSize: 12)),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 60),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DietTheme.accent,
              ),
            ),
            const SizedBox(width: 8),
            const Text("Analyzing...", style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
      ).animate().fade(duration: 200.ms).slideX(begin: -0.1),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, int index) {
    final accent = DietTheme.accent;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: message.isUser ? 60 : 0,
          right: message.isUser ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? accent.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: message.isUser
                    ? Border.all(color: accent.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

            // Action cards
            if (message.actions != null)
              ...message.actions!.map((action) => _buildActionCard(action, index)),
          ],
        ),
      ),
    ).animate().fade(duration: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildActionCard(AiAction action, int messageIndex) {
    final accent = DietTheme.accent;
    final isFood = action.type == 'food_entry';
    final isBurn = action.type == 'burn_entry';

    if (!isFood && !isBurn) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: action.isConfirmed
              ? AppColors.success.withValues(alpha: 0.3)
              : accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFood ? Icons.restaurant : Icons.local_fire_department,
                color: isFood ? accent : AppColors.error,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFood
                      ? action.payload['name'] ?? 'Food'
                      : action.payload['activity'] ?? 'Exercise',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (action.isConfirmed)
                const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          if (isFood) ...[
            Text(
              "${action.payload['calories']?.toStringAsFixed(0) ?? '0'} kcal  •  P: ${action.payload['protein']?.toStringAsFixed(1) ?? '0'}g  C: ${action.payload['carbs']?.toStringAsFixed(1) ?? '0'}g  F: ${action.payload['fat']?.toStringAsFixed(1) ?? '0'}g",
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ] else ...[
            Text(
              "${action.payload['calories_burned']?.toStringAsFixed(0) ?? '0'} kcal burned  •  ${action.payload['duration_minutes'] ?? 0} min",
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
          if (!action.isConfirmed) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _messages[messageIndex].actions!.remove(action);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.3)),
                    ),
                    child: const Text("Skip", style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmAction(action, messageIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("Add", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  List<AiAction>? actions;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.actions,
  });
}
