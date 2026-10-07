import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import '../../core/account_group.dart';
import '../../core/entry.dart';
import '../../core/ledger.dart';
import '../../core/minor.dart';
import '../../core/plan_engine.dart';
import '../../core/snapshot.dart';
import '../../state/money_state.dart';
import '../motion/animated_money_text.dart';
import '../motion/press_scale.dart';
import '../widgets/money_category_icon.dart';
import '../widgets/money_depth_card.dart';
import '../widgets/quick_add_sheet.dart';

/// The Today Tab: Hero Main Balance, Free to Spend card, Quick Action row,
/// Coming Up plans, Funds strip, and recent activity preview.
class TodayTab extends StatelessWidget {
  final VoidCallback? onQuickAdd;
  final ValueChanged<int>? onSelectTab;

  const TodayTab({
    super.key,
    this.onQuickAdd,
    this.onSelectTab,
  });

  void _openSheet(BuildContext context, EntryKind kind) {
    QuickAddSheet.show(context, initialKind: kind);
  }

  void _showUpcomingPlansDialog(
      BuildContext context, List<PlanOccurrence> plans) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.calendarClock, color: BentoTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text('Coming up before month end',
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: plans.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No upcoming plans due this month.',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 13)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final occ = plans[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BentoTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  occ.plan.name,
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM').format(occ.dueDate),
                                  style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Minor.format(occ.plan.amountMinor),
                            style: TextStyle(
                              color: BentoTheme.negative,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const PageStorageKey<String>('money_tab_today'),
      child: ValueListenableBuilder<MoneySnapshot>(
        valueListenable: MoneyState(),
        builder: (context, snapshot, _) {
          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom + 90.0;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header / Hero Balance Sliver
              SliverPadding(
                padding: EdgeInsets.only(
                  top: topPadding + 16,
                  left: 20,
                  right: 20,
                  bottom: 12,
                ),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildHeroSection(context, snapshot),
                  ),
                ),
              ),

              // Quick Action Row (Spent, Received, Moved)
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildQuickActionRow(context),
                  ),
                ),
              ),

              // Free to Spend Card (Law L7)
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildFreeToSpendCard(context, snapshot),
                  ),
                ),
              ),

              // "Funds" Strip (Invested, Value, Gain per fund) (Law L4)
              if (snapshot.funds.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: _buildFundsHeader(context),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: _buildFundsStrip(context, snapshot.funds),
                    ),
                  ),
                ),
              ],

              // "Coming Up" Section (Next 5 plans)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildUpcomingHeader(context, snapshot),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildUpcomingPlansCard(context, snapshot),
                  ),
                ),
              ),

              // Recent Activity Preview
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildRecentHeader(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildRecentEntriesList(context, snapshot),
                  ),
                ),
              ),

              // Bottom Spacing for Floating Tab Bar
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPadding),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, MoneySnapshot snapshot) {
    final mainAccountName = MoneyState()
        .accounts
        .firstWhere(
          (a) => a.id == snapshot.mainAccountId,
          orElse: () => CoreAccount(
            id: 'acc_main',
            name: 'Main Account',
            group: AccountGroup.main,
            rawKind: 'checking',
            openingBalanceMinor: 0,
            openingDate: DateTime(2020),
          ),
        )
        .name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainAccountName.toUpperCase(),
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedMoneyText(
                  amountMinor: snapshot.mainBalanceMinor,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.wallet,
                color: BentoTheme.accent,
                size: 22,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            context,
            label: 'Spent',
            icon: LucideIcons.arrowUpRight,
            color: BentoTheme.negative,
            onTap: () => _openSheet(context, EntryKind.spent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            context,
            label: 'Received',
            icon: LucideIcons.arrowDownLeft,
            color: BentoTheme.positive,
            onTap: () => _openSheet(context, EntryKind.received),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            context,
            label: 'Moved',
            icon: LucideIcons.arrowLeftRight,
            color: BentoTheme.accent,
            onTap: () => _openSheet(context, EntryKind.moved),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeToSpendCard(BuildContext context, MoneySnapshot snapshot) {
    final fts = snapshot.freeToSpend;

    return MoneyDepthCard(
      onTap: () => _showUpcomingPlansDialog(context, snapshot.upcomingPlans),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FREE TO SPEND',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 16, color: BentoTheme.textMuted),
            ],
          ),
          const SizedBox(height: 12),

          // Three lines (Law L7)
          _buildFtsRow(
            'Available',
            FormatUtils.formatMoney(Minor.fromMinor(fts.availableMinor)),
            BentoTheme.textPrimary,
          ),
          const SizedBox(height: 6),
          _buildFtsRow(
            'Coming up',
            '-${FormatUtils.formatMoney(Minor.fromMinor(fts.comingUpMinor))}',
            BentoTheme.textSecondary,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fts.isShort ? 'Deficit' : 'Free to spend',
                style: TextStyle(
                  color: fts.isShort
                      ? BentoTheme.negative
                      : BentoTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                fts.isShort
                    ? 'Short by ${Minor.format(fts.shortByMinor)}'
                    : Minor.format(fts.freeToSpendMinor),
                style: TextStyle(
                  color:
                      fts.isShort ? BentoTheme.negative : BentoTheme.positive,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFtsRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFundsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Funds & Investments',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onSelectTab != null)
          GestureDetector(
            onTap: () => onSelectTab!(3),
            child: Text(
              'See all',
              style: TextStyle(
                color: BentoTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFundsStrip(BuildContext context, List<FundSummary> funds) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: funds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final f = funds[idx];
          final isPositive = f.gainMinor >= 0;

          return Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MoneyState()
                      .accounts
                      .firstWhere(
                        (a) => a.id == f.accountId,
                        orElse: () => CoreAccount(
                          id: f.accountId,
                          name: 'Fund',
                          group: AccountGroup.funds,
                          rawKind: 'mutual_fund',
                          openingBalanceMinor: 0,
                          openingDate: DateTime(2020),
                        ),
                      )
                      .name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invested',
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(Minor.format(f.investedMinor),
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Value',
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(Minor.format(f.valueMinor),
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gain',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 10)),
                    Text(
                      '${isPositive ? '+' : ''}${Minor.format(f.gainMinor)}',
                      style: TextStyle(
                        color: isPositive
                            ? BentoTheme.positive
                            : BentoTheme.negative,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingHeader(BuildContext context, MoneySnapshot snapshot) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Coming Up',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onSelectTab != null)
          GestureDetector(
            onTap: () => onSelectTab!(2),
            child: Text(
              'Plans',
              style: TextStyle(
                color: BentoTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingPlansCard(BuildContext context, MoneySnapshot snapshot) {
    final plans = snapshot.upcomingPlans.take(5).toList();
    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No plans due before month end',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: plans.length,
        separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: BentoTheme.divider.withValues(alpha: 0.4)),
        itemBuilder: (context, idx) {
          final occ = plans[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.calendarClock,
                      size: 16, color: BentoTheme.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        occ.plan.name,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM').format(occ.dueDate),
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (occ.needsFunds) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BentoTheme.negative.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Needs funds',
                      style: TextStyle(
                        color: BentoTheme.negative,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  Minor.format(occ.plan.amountMinor),
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onSelectTab != null)
          GestureDetector(
            onTap: () => onSelectTab!(1),
            child: Text(
              'See all',
              style: TextStyle(
                color: BentoTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentEntriesList(BuildContext context, MoneySnapshot snapshot) {
    final recent = snapshot.recentEntries.take(4).toList();
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No transactions logged yet',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: BentoTheme.divider.withValues(alpha: 0.4)),
        itemBuilder: (context, idx) {
          final entry = recent[idx];
          final isSpent = entry.kind == EntryKind.spent;
          final isReceived = entry.kind == EntryKind.received;
          final color = isSpent
              ? BentoTheme.negative
              : (isReceived ? BentoTheme.positive : BentoTheme.accent);

          return InkWell(
            onTap: () => QuickAddSheet.show(context, editEntry: entry),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
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
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(entry.date),
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isSpent ? '-' : (isReceived ? '+' : '')}${Minor.format(entry.amountMinor)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
