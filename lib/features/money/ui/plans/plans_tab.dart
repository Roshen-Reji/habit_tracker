import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../../core/minor.dart';
import '../../core/plan_engine.dart';
import '../../core/snapshot.dart';
import '../../data/money_service.dart';
import '../../data/plan_runner.dart';
import '../../state/money_state.dart';
import '../motion/press_scale.dart';
import 'add_plan_sheet.dart';

/// The Plans Tab: Segments (All, SIP, EMI, Bills, Income), automated plan list,
/// "Needs funds" badges, and plan actions.
class PlansTab extends StatefulWidget {
  const PlansTab({super.key});

  @override
  State<PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<PlansTab> {
  int _selectedSegmentIndex = 0; // 0: All, 1: SIP, 2: EMI, 3: Bills, 4: Income
  final List<String> _segments = const ['All', 'SIP', 'EMI', 'Bills', 'Income'];

  void _openAddPlan(BuildContext context) {
    PlanKind initialKind = PlanKind.sip;
    if (_selectedSegmentIndex == 2) initialKind = PlanKind.emi;
    if (_selectedSegmentIndex == 3) initialKind = PlanKind.bill;
    if (_selectedSegmentIndex == 4) initialKind = PlanKind.income;

    AddPlanSheet.show(context, initialKind: initialKind);
  }

  void _showPlanOptions(BuildContext context, CorePlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.title,
                style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Every ${plan.dayOfMonth} of month • ${Minor.format(plan.amountMinor)}',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Run Now
              ListTile(
                leading: Icon(LucideIcons.play, color: BentoTheme.positive),
                title: Text('Run Occurrence Now',
                    style: TextStyle(color: BentoTheme.textPrimary)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await PlanRunner().runDuePlans();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Executed due plans for "${plan.title}"')),
                    );
                  }
                },
              ),
              // Pause or Resume
              ListTile(
                leading: Icon(
                    plan.isPaused
                        ? LucideIcons.playCircle
                        : LucideIcons.pauseCircle,
                    color: BentoTheme.accent),
                title: Text(plan.isPaused ? 'Resume Plan' : 'Pause Plan',
                    style: TextStyle(color: BentoTheme.textPrimary)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  if (plan.isPaused) {
                    await MoneyService().resumePlan(plan.id);
                  } else {
                    await MoneyService().pausePlan(plan.id);
                  }
                },
              ),
              // Delete Plan
              ListTile(
                leading: Icon(LucideIcons.trash2, color: BentoTheme.negative),
                title: Text('Delete Plan',
                    style: TextStyle(color: BentoTheme.negative)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await MoneyService().endPlan(plan.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted plan "${plan.title}"')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const PageStorageKey<String>('money_tab_plans'),
      child: ValueListenableBuilder<MoneySnapshot>(
        valueListenable: MoneyState(),
        builder: (context, snapshot, _) {
          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom + 90.0;

          final allPlans = MoneyState().plans;
          final filteredPlans = allPlans.where((p) {
            if (_selectedSegmentIndex == 1) return p.kind == PlanKind.sip;
            if (_selectedSegmentIndex == 2) return p.kind == PlanKind.emi;
            if (_selectedSegmentIndex == 3) return p.kind == PlanKind.bill;
            if (_selectedSegmentIndex == 4) return p.kind == PlanKind.income;
            return true;
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // Header Sliver
              SliverPadding(
                padding: EdgeInsets.only(
                    top: topPadding + 16, left: 20, right: 20, bottom: 12),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AUTOMATION',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Plans',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        PressScale(
                          onTap: () => _openAddPlan(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: BentoTheme.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.plus,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add Plan',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Segment Chips
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _segments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final isSelected = _selectedSegmentIndex == idx;
                          return PressScale(
                            onTap: () =>
                                setState(() => _selectedSegmentIndex = idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? BentoTheme.accent
                                    : BentoTheme.surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _segments[idx],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : BentoTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Plan List or Empty State
              if (filteredPlans.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.calendarClock,
                            size: 48, color: BentoTheme.textMuted),
                        const SizedBox(height: 12),
                        Text('No plans configured',
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: BentoTheme.surface),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Create a Plan'),
                          onPressed: () => _openAddPlan(context),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final plan = filteredPlans[idx];
                        final needsFunds = snapshot.plansNeedingFunds
                            .any((occ) => occ.plan.id == plan.id);
                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPlanCard(context, plan, needsFunds),
                          ),
                        );
                      },
                      childCount: filteredPlans.length,
                    ),
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

  Widget _buildPlanCard(BuildContext context, CorePlan plan, bool needsFunds) {
    final state = MoneyState();
    final fromName = plan.fromAccountId != null
        ? state.accounts
            .firstWhere((a) => a.id == plan.fromAccountId,
                orElse: () => state.accounts.first)
            .name
        : 'External';
    final toName = plan.toAccountId != null
        ? state.accounts
            .firstWhere((a) => a.id == plan.toAccountId,
                orElse: () => state.accounts.first)
            .name
        : 'External';

    final IconData icon;
    final Color iconColor;
    final String kindLabel;
    switch (plan.kind) {
      case PlanKind.sip:
        icon = LucideIcons.repeat;
        iconColor = BentoTheme.positive;
        kindLabel = 'SIP';
        break;
      case PlanKind.emi:
        icon = LucideIcons.creditCard;
        iconColor = BentoTheme.negative;
        kindLabel = 'EMI';
        break;
      case PlanKind.bill:
        icon = LucideIcons.zap;
        iconColor = BentoTheme.warning;
        kindLabel = 'Bill';
        break;
      case PlanKind.income:
        icon = LucideIcons.arrowDownLeft;
        iconColor = BentoTheme.positive;
        kindLabel = 'Income';
        break;
    }

    return InkWell(
      onTap: () => _showPlanOptions(context, plan),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.title,
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BentoTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              kindLabel,
                              style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fromName → $toName',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  Minor.format(plan.amountMinor),
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Repeats every ${plan.dayOfMonth}th of month',
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                ),
                if (needsFunds)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BentoTheme.negative.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Needs funds',
                      style: TextStyle(
                          color: BentoTheme.negative,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                else if (plan.isPaused)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BentoTheme.textMuted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Paused',
                      style: TextStyle(
                          color: BentoTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Text(
                    'Active',
                    style: TextStyle(
                        color: BentoTheme.positive,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
