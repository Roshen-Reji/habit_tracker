import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../../core/entry.dart';
import '../../core/minor.dart';
import '../../core/snapshot.dart';
import '../../data/money_service.dart';
import '../../state/money_state.dart';
import '../motion/motion_tokens.dart';
import '../widgets/money_category_icon.dart';
import '../widgets/quick_add_sheet.dart';

/// Group of transactions occurring on the same calendar date.
class DayGroup {
  final DateTime date;
  final List<Entry> entries;
  final int netMinor;

  const DayGroup({
    required this.date,
    required this.entries,
    required this.netMinor,
  });
}

/// The Activity Tab: Searchable, daily-grouped transaction stream with swipe-to-delete,
/// 5-second Undo, tap-to-edit, and Section 7 performance motion.
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static bool _hasSeenEntranceAnimation = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DayGroup> _groupEntries(List<Entry> entries) {
    final filtered = _searchQuery.isEmpty
        ? entries
        : entries.where((e) {
            final titleMatch = e.title.toLowerCase().contains(_searchQuery);
            final catMatch = e.category.toLowerCase().contains(_searchQuery);
            final noteMatch =
                e.notes?.toLowerCase().contains(_searchQuery) ?? false;
            return titleMatch || catMatch || noteMatch;
          }).toList();

    if (filtered.isEmpty) return const [];

    final Map<String, List<Entry>> groups = {};
    for (final e in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      groups.putIfAbsent(key, () => []).add(e);
    }

    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((key) {
      final dayEntries = groups[key]!;
      int net = 0;
      for (final e in dayEntries) {
        if (e.kind == EntryKind.received) {
          net += e.amountMinor;
        } else if (e.kind == EntryKind.spent) {
          net -= e.amountMinor;
        }
      }
      return DayGroup(
        date: dayEntries.first.date,
        entries: dayEntries,
        netMinor: net,
      );
    }).toList();
  }

  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == today.subtract(const Duration(days: 1)))
      return 'Yesterday';
    return DateFormat('EEE, dd MMM yyyy').format(date);
  }

  Future<void> _handleDelete(Entry entry) async {
    final service = MoneyService();
    await service.deleteEntry(entry.id);

    if (!mounted) return;
    final undo = service.lastUndoAction;
    if (undo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${entry.title}"'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await service.undo();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const PageStorageKey<String>('money_tab_activity'),
      child: ValueListenableBuilder<MoneySnapshot>(
        valueListenable: MoneyState(),
        builder: (context, snapshot, _) {
          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom + 90.0;
          final dayGroups = _groupEntries(snapshot.recentEntries);

          // Mark entrance as seen after first build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _hasSeenEntranceAnimation = true;
          });

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Search Header Sliver
              SliverPadding(
                padding: EdgeInsets.only(
                  top: topPadding + 16,
                  left: 20,
                  right: 20,
                  bottom: 12,
                ),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVITY',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Transactions',
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Search Field
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search transactions...',
                            hintStyle: TextStyle(
                                color: BentoTheme.textMuted, fontSize: 13),
                            prefixIcon: Icon(LucideIcons.search,
                                size: 18, color: BentoTheme.textSecondary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(LucideIcons.x,
                                        size: 16,
                                        color: BentoTheme.textSecondary),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: BentoTheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(
                              color: BentoTheme.textPrimary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Empty State
              if (dayGroups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.inbox,
                            size: 48, color: BentoTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No transactions yet'
                              : 'No matching transactions',
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Groups of Daily Entries
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, groupIdx) {
                      final group = dayGroups[groupIdx];
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sticky Day Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDayHeader(group.date),
                                    style: TextStyle(
                                      color: BentoTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    group.netMinor >= 0
                                        ? '+${Minor.format(group.netMinor)}'
                                        : Minor.format(group.netMinor),
                                    style: TextStyle(
                                      color: group.netMinor >= 0
                                          ? BentoTheme.positive
                                          : BentoTheme.negative,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Card containing entries for the day
                              Container(
                                decoration: BoxDecoration(
                                  color: BentoTheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  children: List.generate(group.entries.length,
                                      (entryIdx) {
                                    final entry = group.entries[entryIdx];
                                    final isFirst = entryIdx == 0;
                                    final isLast =
                                        entryIdx == group.entries.length - 1;
                                    final globalIndex =
                                        groupIdx * 10 + entryIdx;

                                    Widget item = _buildEntryRow(
                                      context: context,
                                      entry: entry,
                                      isFirst: isFirst,
                                      isLast: isLast,
                                    );

                                    // Entrance stagger for first 8 rows (Rule 4)
                                    if (!_hasSeenEntranceAnimation &&
                                        globalIndex <
                                            MoneyMotionTokens.maxStaggerCount) {
                                      final delay =
                                          MoneyMotionTokens.staggerInterval *
                                              globalIndex;
                                      item = TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration:
                                            MoneyMotionTokens.standard + delay,
                                        curve: MoneyMotionTokens.enter,
                                        builder: (context, val, child) {
                                          return FadeTransition(
                                            opacity:
                                                AlwaysStoppedAnimation(val),
                                            child: Transform.translate(
                                              offset: Offset(0, 10 * (1 - val)),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: item,
                                      );
                                    }

                                    return item;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: dayGroups.length,
                  ),
                ),

              // Bottom Padding
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPadding),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEntryRow({
    required BuildContext context,
    required Entry entry,
    required bool isFirst,
    required bool isLast,
  }) {
    final isSpent = entry.kind == EntryKind.spent;
    final isReceived = entry.kind == EntryKind.received;
    final color = isSpent
        ? BentoTheme.negative
        : (isReceived ? BentoTheme.positive : BentoTheme.accent);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: BentoTheme.negative,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(18) : Radius.zero,
            bottom: isLast ? const Radius.circular(18) : Radius.zero,
          ),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => _handleDelete(entry),
      child: Column(
        children: [
          InkWell(
            onTap: () => QuickAddSheet.show(context, editEntry: entry),
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(18) : Radius.zero,
              bottom: isLast ? const Radius.circular(18) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      MoneyCategoryIcon.getIcon(entry.icon ?? entry.category),
                      size: 16,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              entry.category,
                              style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11),
                            ),
                            if (entry.notes != null &&
                                entry.notes!.isNotEmpty &&
                                entry.notes != entry.title) ...[
                              Text(' • ',
                                  style: TextStyle(
                                      color: BentoTheme.textMuted,
                                      fontSize: 11)),
                              Expanded(
                                child: Text(
                                  entry.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: BentoTheme.textMuted,
                                      fontSize: 11),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isSpent ? '-' : (isReceived ? '+' : '')}${Minor.format(entry.amountMinor)}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm a').format(entry.date),
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 52,
              endIndent: 16,
              color: BentoTheme.divider.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}
