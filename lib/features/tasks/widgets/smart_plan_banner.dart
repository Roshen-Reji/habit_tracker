import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/widgets/task_action_pill.dart';

/// Single-line collapsible Morning Plan banner adhering to AGENTS.md Phase 3.
/// Default collapsed state is a single 48px row that never wraps.
class SmartPlanBanner extends StatefulWidget {
  final PlanProposalItem plan;
  final VoidCallback onPlanAccepted;
  final VoidCallback onRebalance;

  const SmartPlanBanner({
    super.key,
    required this.plan,
    required this.onPlanAccepted,
    required this.onRebalance,
  });

  @override
  State<SmartPlanBanner> createState() => _SmartPlanBannerState();
}

class _SmartPlanBannerState extends State<SmartPlanBanner> {
  bool _isExpanded = false;
  late List<ScheduledBlockItem> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = List.from(widget.plan.blocks);
  }

  @override
  void didUpdateWidget(covariant SmartPlanBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan) {
      _blocks = List.from(widget.plan.blocks);
    }
  }

  void _acceptBlock(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      final b = _blocks[index];
      _blocks[index] = ScheduledBlockItem(
        id: b.id,
        taskId: b.taskId,
        title: b.title,
        startAt: b.startAt,
        endAt: b.endAt,
        source: b.source,
        reason: b.reason,
        status: 'accepted',
      );
    });
  }

  void _rejectBlock(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _blocks.removeAt(index);
    });
  }

  void _approveAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _blocks = _blocks.map((b) {
        return ScheduledBlockItem(
          id: b.id,
          taskId: b.taskId,
          title: b.title,
          startAt: b.startAt,
          endAt: b.endAt,
          source: b.source,
          reason: b.reason,
          status: 'accepted',
        );
      }).toList();
    });
    widget.onPlanAccepted();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Morning Plan approved and scheduled'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    final pendingCount =
        _blocks.where((b) => b.status == 'proposed').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BentoTheme.divider),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sleek 48px Header Row (always single-row)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: BentoTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Morning Plan · ${_blocks.length} time blocks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TaskActionPill(
                      label: 'Rebalance',
                      icon: const Icon(LucideIcons.refreshCw, size: 11),
                      height: 30,
                      horizontalPadding: 10,
                      borderRadius: 10,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onTap: widget.onRebalance,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isExpanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 18,
                      color: BentoTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded body with proposed blocks & actions
            if (_isExpanded) ...[
              const Divider(height: 1, color: Color(0xFF262626)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  children: [
                    for (int i = 0; i < _blocks.length; i++)
                      _buildBlockTile(i, _blocks[i]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '$pendingCount pending approval',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (pendingCount > 0)
                      TaskActionPill(
                        label: 'Approve All',
                        icon: const Icon(LucideIcons.check, size: 12),
                        isPrimary: true,
                        height: 34,
                        horizontalPadding: 14,
                        borderRadius: 10,
                        onTap: _approveAll,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockTile(int index, ScheduledBlockItem block) {
    final startTimeStr =
        '${block.startAt.hour.toString().padLeft(2, '0')}:${block.startAt.minute.toString().padLeft(2, '0')}';
    final endTimeStr =
        '${block.endAt.hour.toString().padLeft(2, '0')}:${block.endAt.minute.toString().padLeft(2, '0')}';

    final isAccepted = block.status == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isAccepted
            ? BentoTheme.accent.withValues(alpha: 0.08)
            : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAccepted
              ? BentoTheme.accent.withValues(alpha: 0.4)
              : const Color(0xFF262626),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Text(
              '$startTimeStr–$endTimeStr',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (block.reason != null)
                  Text(
                    block.reason!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (!isAccepted) ...[
            GestureDetector(
              onTap: () => _acceptBlock(index),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: BentoTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.check,
                    size: 13, color: BentoTheme.accent),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _rejectBlock(index),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.x,
                    size: 13, color: BentoTheme.textSecondary),
              ),
            ),
          ] else ...[
            Icon(LucideIcons.checkCircle2,
                size: 16, color: BentoTheme.accent),
          ],
        ],
      ),
    );
  }
}
