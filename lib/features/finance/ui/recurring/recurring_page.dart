import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/recurring/mark_paid_dialog.dart';
import 'package:habit_tracker/features/finance/ui/recurring/recurring_edit_sheet.dart';

class RecurringPage extends StatefulWidget {
  const RecurringPage({super.key});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage>
    with SingleTickerProviderStateMixin {
  final FinanceController _controller = FinanceController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // P6-1: Post any due auto-post recurring items on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.postRecurringDue();
      _controller.scheduleRecurringReminders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(RecurringRule rule) async {
    final newStatus = rule.status == 'active' ? 'paused' : 'active';
    final updated = RecurringRule(
      id: rule.id,
      name: rule.name,
      kind: rule.kind,
      amount: rule.amount,
      amountIsVariable: rule.amountIsVariable,
      categoryId: rule.categoryId,
      accountId: rule.accountId,
      toAccountId: rule.toAccountId,
      frequency: rule.frequency,
      interval: rule.interval,
      anchorDate: rule.anchorDate,
      dayOfMonth: rule.dayOfMonth,
      startDate: rule.startDate,
      endDate: rule.endDate,
      autoPost: rule.autoPost,
      reminderDaysBefore: rule.reminderDaysBefore,
      status: newStatus,
      folio: rule.folio,
      notes: rule.notes,
      createdAt: rule.createdAt,
    );
    await _controller.updateRecurringRule(updated);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final allRules = _controller.allRecurringRules;
        final monthlyTotal = _controller.getMonthlyRecurringTotal();
        final dueItems = _controller.getUnpostedDueItems();
        final detectedSubs = _controller.getDetectedSubscriptions();

        final bills = allRules.where((r) => r.kind == 'bill').toList();
        final subs = allRules.where((r) => r.kind == 'subscription').toList();
        final sipsAndEmis =
            allRules.where((r) => r.kind == 'sip' || r.kind == 'emi').toList();

        return Scaffold(
          backgroundColor: BentoTheme.background,
          appBar: AppBar(
            backgroundColor: BentoTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              color: BentoTheme.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Bills & Subscriptions',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monthly Total Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: BentoTheme.surface,
                          borderRadius: ExpressiveTokens.borderL,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MONTHLY RECURRING COMMITMENTS',
                                  style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  FormatUtils.formatMoney(monthlyTotal),
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    BentoTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${allRules.where((r) => r.status == 'active').length} Active Rules',
                                style: TextStyle(
                                  color: BentoTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Due Items Banner (P6-1)
                      if (dueItems.isNotEmpty) ...[
                        _buildDueItemsBanner(dueItems),
                        const SizedBox(height: 16),
                      ],

                      // Detected Subscriptions (P6-4)
                      if (detectedSubs.isNotEmpty) ...[
                        _buildDetectedSubscriptionsBanner(detectedSubs),
                        const SizedBox(height: 16),
                      ],

                      // TabBar
                      Container(
                        decoration: BoxDecoration(
                          color: BentoTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: BentoTheme.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.black,
                          unselectedLabelColor: BentoTheme.textSecondary,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                          unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'All'),
                            Tab(text: 'Bills'),
                            Tab(text: 'Subscriptions'),
                            Tab(text: 'SIP & EMI'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesList(allRules),
                _buildRulesList(bills),
                _buildRulesList(subs),
                _buildRulesList(sipsAndEmis),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              RecurringEditSheet.show(context, controller: _controller);
            },
            backgroundColor: BentoTheme.accent,
            foregroundColor: Colors.black,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Add Recurring',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDueItemsBanner(List<DueItem> dueItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.warning.withValues(alpha: 0.12),
        borderRadius: ExpressiveTokens.borderL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle,
                  color: BentoTheme.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'ACTION REQUIRED: DUE BILLS',
                style: TextStyle(
                  color: BentoTheme.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${dueItems.length} Due',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...dueItems.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.rule.name,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Due: ${DateFormat('dd MMM').format(item.dueDate)} • ${FormatUtils.formatMoney(item.estimatedAmount)}',
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      MarkPaidDialog.show(context,
                          controller: _controller, item: item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Paid',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetectedSubscriptionsBanner(
      List<DetectedSubscription> detectedSubs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'DETECTED SUBSCRIPTIONS',
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We spotted recurring charges in your history. Track them to predict bills and get reminders:',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...detectedSubs.map((sub) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BentoTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sub.rawMerchant,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${FormatUtils.formatMoney(sub.latestAmount)} / ${sub.frequency}',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${sub.occurrenceCount} occurrences (~${sub.cycleDays} days)',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                      if (sub.hasPriceChange) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Price change',
                            style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      if (sub.isPossiblyCancelled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Possibly cancelled',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _controller.dismissSubscriptionSuggestion(
                              sub.normalizedMerchant);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Dismiss',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          RecurringEditSheet.show(
                            context,
                            controller: _controller,
                            initialKind: 'subscription',
                            initialName: sub.rawMerchant,
                            initialAmount: sub.latestAmount,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BentoTheme.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: const Size(60, 30),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Track',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRulesList(List<RecurringRule> rules) {
    if (rules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.repeat,
                  size: 40, color: BentoTheme.textSecondary),
              const SizedBox(height: 14),
              Text(
                'No Recurring Items',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add bills, subscriptions, SIPs, and loan EMIs to receive reminders and forecast cashflow.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: rules.length,
      itemBuilder: (context, idx) {
        final rule = rules[idx];
        return _buildRuleCard(rule);
      },
    );
  }

  Widget _buildRuleCard(RecurringRule rule) {
    final cat = rule.categoryId != null
        ? _controller.storage.categoryBox.get(rule.categoryId!)
        : null;
    final isPaused = rule.status == 'paused';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            RecurringEditSheet.show(
              context,
              controller: _controller,
              existingRule: rule,
            );
          },
          borderRadius: ExpressiveTokens.borderM,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(cat?.colorValue ?? 0xFF00E5FF)
                      .withValues(alpha: 0.2),
                  child: Icon(
                    rule.kind == 'subscription'
                        ? LucideIcons.tv
                        : (rule.kind == 'sip'
                            ? LucideIcons.trendingUp
                            : LucideIcons.receipt),
                    size: 14,
                    color: Color(cat?.colorValue ?? 0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              rule.name,
                              style: TextStyle(
                                color: isPaused
                                    ? Colors.white38
                                    : BentoTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPaused) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PAUSED',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rule.frequency.toUpperCase()} • Day ${rule.dayOfMonth ?? rule.startDate.day} • ${rule.autoPost ? 'Auto-posted' : 'Manual confirm'}',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${rule.amountIsVariable ? '~' : ''}${FormatUtils.formatMoney(rule.amount)}',
                      style: TextStyle(
                        color:
                            isPaused ? Colors.white38 : BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPaused ? LucideIcons.play : LucideIcons.pause,
                        size: 14,
                        color: Colors.white60,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleStatus(rule),
                      tooltip: isPaused ? 'Resume' : 'Pause',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
