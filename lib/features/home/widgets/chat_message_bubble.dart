import 'dart:typed_data';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/data/services/ai_service.dart';
import 'package:habit_tracker/features/diet/widgets/diet_dashboard_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Represents a single chat message in the home chat
class ChatMessage {
  final String text;
  final bool isUser;
  final List<AiAction>? actions;
  final DateTime timestamp;
  final Uint8List? imageBytes;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.actions,
    this.imageBytes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// A chat message bubble with action cards
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(AiAction)? onConfirmAction;
  final Function(AiAction)? onRejectAction;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onConfirmAction,
    this.onRejectAction,
  });

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10,
          left: isUser ? 50 : 0,
          right: isUser ? 0 : 50,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Main bubble
            BentoContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 18,
              customColor: isUser
                  ? accent.withValues(alpha: 0.2)
                  : BentoTheme.background,
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, color: accent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "AI ASSISTANT",
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        message.imageBytes!,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Action cards
            if (message.actions != null && message.actions!.isNotEmpty)
              ...message.actions!.map((action) => _ActionConfirmCard(
                    action: action,
                    onConfirm: () => onConfirmAction?.call(action),
                    onReject: () => onRejectAction?.call(action),
                  )),
          ],
        ),
      ),
    ).animate().fade(duration: 250.ms).slideY(begin: 0.05);
  }
}

/// Action confirmation card for pending actions
class _ActionConfirmCard extends StatelessWidget {
  final AiAction action;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const _ActionConfirmCard({
    required this.action,
    this.onConfirm,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final accent = BentoTheme.accent;

    return BentoContainer(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      customColor: action.isConfirmed
          ? AppColors.success.withValues(alpha: 0.1)
          : BentoTheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(accent),
          const SizedBox(height: 8),
          _buildContent(),
          if (!action.isConfirmed) ...[
            const SizedBox(height: 10),
            _buildActions(accent),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    IconData icon;
    String label;
    Color color;

    switch (action.type) {
      case 'food_entry':
        icon = LucideIcons.utensils;
        label = 'FOOD ENTRY';
        color = accent;
        break;
      case 'burn_entry':
        icon = LucideIcons.flame;
        label = 'CALORIE BURN';
        color = AppColors.error;
        break;
      case 'task_create':
        icon = LucideIcons.checkCircle;
        label = 'NEW MISSION';
        color = AppColors.success;
        break;
      case 'music_play':
        icon = LucideIcons.music;
        label = 'PLAY SONG';
        color = const Color(0xFFE040FB);
        break;
      case 'play_vault_video':
        icon = LucideIcons.video;
        label = 'PLAY VAULT VIDEO';
        color = Colors.redAccent;
        break;
      case 'finance_transaction':
        icon = LucideIcons.receipt;
        label = 'FINANCE LOG';
        color = AppColors.warning;
        break;
      case 'finance_budget':
        icon = LucideIcons.pieChart;
        label = 'BUDGET';
        color = AppColors.primary;
        break;
      case 'finance_commitment':
        icon = LucideIcons.calendar;
        label = 'MONTHLY COMMITMENT';
        color = AppColors.warning;
        break;
      case 'finance_sip':
        icon = LucideIcons.lineChart;
        label = 'SIP';
        color = AppColors.primary;
        break;
      case 'finance_goal':
        icon = LucideIcons.flag;
        label = 'FINANCE GOAL';
        color = AppColors.success;
        break;
      default:
        icon = LucideIcons.info;
        label = 'ACTION';
        color = accent;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        if (action.isConfirmed)
          Row(
            children: [
              const Icon(LucideIcons.checkCircle2,
                  color: AppColors.success, size: 14),
              const SizedBox(width: 4),
              const Text("Done",
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
      ],
    );
  }

  Widget _buildContent() {
    switch (action.type) {
      case 'food_entry':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action.payload['name'] ?? 'Unknown Food',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildMiniStat("${_numStr(action.payload['calories'])} kcal",
                    AppColors.textPrimary),
                _buildMiniStat("P: ${_numStr(action.payload['protein'])}g",
                    MacroBreakdownBar.proteinColor),
                _buildMiniStat("C: ${_numStr(action.payload['carbs'])}g",
                    MacroBreakdownBar.carbsColor),
                _buildMiniStat("F: ${_numStr(action.payload['fat'])}g",
                    MacroBreakdownBar.fatColor),
              ],
            ),
          ],
        );

      case 'burn_entry':
        return Row(
          children: [
            Text(
              action.payload['activity'] ?? 'Exercise',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const Spacer(),
            Text(
              "-${_numStr(action.payload['calories_burned'])} kcal",
              style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            if (action.payload['duration_minutes'] != null &&
                action.payload['duration_minutes'] > 0) ...[
              const SizedBox(width: 8),
              Text(
                "${action.payload['duration_minutes']} min",
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ],
        );

      case 'task_create':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action.payload['title'] ?? 'Untitled',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTag(
                    (action.payload['type'] ?? 'today')
                        .toString()
                        .toUpperCase(),
                    AppColors.primary),
                const SizedBox(width: 6),
                _buildTag(
                    (action.payload['category'] ?? 'productivity')
                        .toString()
                        .toUpperCase(),
                    AppColors.warning),
                if (action.payload['end_date'] != null) ...[
                  const SizedBox(width: 6),
                  _buildTag("ENDS ${_dateLabel(action.payload['end_date'])}",
                      AppColors.error),
                ],
                const Spacer(),
                Text(
                  "Target: ${_numStr(action.payload['target_value'])} ${action.payload['unit'] ?? 'units'}",
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ],
        );

      case 'music_play':
        return Row(
          children: [
            const Icon(LucideIcons.playCircle,
                color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action.payload['search_query'] ?? 'Unknown Song',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ],
        );

      case 'play_vault_video':
        return Row(
          children: [
            const Icon(LucideIcons.video, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action.payload['query'] ?? 'Vault Video',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ],
        );

      case 'finance_transaction':
        final mode = (action.payload['mode'] ?? 'expense').toString();
        final amount = action.payload['amount'] ?? 0;
        final isIncome = mode.toLowerCase() == 'income';
        return Row(
          children: [
            Icon(
              isIncome ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              color: isIncome ? AppColors.success : AppColors.error,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action.payload['title'] ?? 'Transaction',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            Text(
              "${isIncome ? '+' : '-'}Rs $amount",
              style: TextStyle(
                color: isIncome ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        );

      case 'finance_budget':
        return _buildFinanceActionRow(
          icon: LucideIcons.pieChart,
          title: '${action.payload['category'] ?? 'Category'} budget',
          subtitle: 'Monthly limit',
          amount: action.payload['total'],
          color: AppColors.primary,
        );

      case 'finance_commitment':
        return _buildFinanceActionRow(
          icon: LucideIcons.calendar,
          title: action.payload['name'] ?? 'Commitment',
          subtitle:
              '${action.payload['category'] ?? 'Fixed'} - due day ${action.payload['date'] ?? 1}',
          amount: action.payload['amount'],
          color: AppColors.warning,
        );

      case 'finance_sip':
        return _buildFinanceActionRow(
          icon: LucideIcons.lineChart,
          title: action.payload['name'] ?? 'SIP',
          subtitle: 'Due day ${action.payload['due'] ?? 5}',
          amount: action.payload['amount'],
          color: AppColors.primary,
        );

      case 'finance_goal':
        return _buildFinanceActionRow(
          icon: LucideIcons.flag,
          title: action.payload['name'] ?? 'Finance goal',
          subtitle: 'Target amount',
          amount: action.payload['target'],
          color: AppColors.success,
        );

      default:
        return Text(
          action.payload.toString(),
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        );
    }
  }

  Widget _buildFinanceActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required dynamic amount,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          'Rs ${_numStr(amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onReject,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.textTertiary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.x, color: AppColors.textTertiary, size: 14),
                SizedBox(width: 4),
                Text("Reject",
                    style:
                        TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onConfirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.check, color: Colors.black, size: 14),
                const SizedBox(width: 4),
                const Text("Accept",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  String _numStr(dynamic value) {
    if (value == null) return '0';
    if (value is double)
      return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return value.toString();
  }

  String _dateLabel(dynamic value) {
    try {
      final date = DateTime.parse(value.toString());
      return '${date.day}/${date.month}';
    } catch (_) {
      return value.toString();
    }
  }
}
