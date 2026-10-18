import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/features/tasks/engine/smart_scheduler_engine.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

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
        content: Text('AI Morning Plan approved and scheduled'),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: BentoTheme.accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.sparkles,
                      size: 16, color: BentoTheme.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Morning Plan (PLAN-3)',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_blocks.length} blocks tailored around your class timetable',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rebalance button
                TactileButton(
                  onPressed: widget.onRebalance,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BentoTheme.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.refreshCw,
                            size: 11, color: BentoTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Rebalance',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: BentoTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _isExpanded = !_isExpanded);
                  },
                ),
              ],
            ),
          ),
          // Sliced proposed blocks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (int i = 0; i < (_isExpanded ? _blocks.length : math.min(2, _blocks.length)); i++) ...[
                  _buildBlockTile(i, _blocks[i]),
                ],
              ],
            ),
          ),
          // Bottom action row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              children: [
                if (!_isExpanded && _blocks.length > 2)
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = true),
                    child: Text(
                      '+${_blocks.length - 2} more blocks',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                if (pendingCount > 0) ...[
                  TactileButton(
                    onPressed: _approveAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: BentoTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.check, size: 12, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'Approve All',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAccepted
            ? BentoTheme.accent.withValues(alpha: 0.08)
            : BentoTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAccepted
              ? BentoTheme.accent.withValues(alpha: 0.4)
              : BentoTheme.divider,
        ),
      ),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BentoTheme.divider),
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
                    fontWeight: FontWeight.bold,
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
          // Accept / reject actions
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
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
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
