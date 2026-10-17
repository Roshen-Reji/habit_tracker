import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/glass_tab_bar.dart';
import 'package:habit_tracker/features/finance/ui/categories/categories_page.dart';
import 'package:habit_tracker/features/finance/ui/calendar/finance_calendar_page.dart';
import 'package:habit_tracker/features/finance/ui/cashflow/cash_flow_page.dart';
import 'package:habit_tracker/features/finance/ui/debt/debt_page.dart';
import 'package:habit_tracker/features/finance/ui/insights/insights_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/reports/reports_page.dart';
import 'package:habit_tracker/features/finance/ui/split/split_groups_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/finance_privacy_data_page.dart';
import 'package:habit_tracker/features/finance/ui/budget/budget_tab.dart';
import 'package:habit_tracker/features/finance/ui/goals/goals_tab.dart';
import '../accounts/balance_review_dialog.dart';
import '../motion/frame_timing_logger.dart';
import '../motion/motion_scope.dart';
import '../motion/motion_tokens.dart';
import '../motion/press_scale.dart';
import '../today/today_tab.dart';
import '../activity/activity_tab.dart';
import '../plans/plans_tab.dart';
import '../accounts/accounts_tab.dart';
import '../widgets/quick_add_sheet.dart';

/// Unified Money v2 Shell supporting 4 tabs, lazy preservation, smooth transitions,
/// and complete backward-compatible deep linking.
class MoneyShell extends StatefulWidget {
  final int initialTab;
  final String? deepLink;

  const MoneyShell({
    super.key,
    this.initialTab = 0,
    this.deepLink,
  });

  @override
  State<MoneyShell> createState() => _MoneyShellState();
}

class _MoneyShellState extends State<MoneyShell>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  final Set<int> _loadedTabs = <int>{};
  final PageStorageBucket _bucket = PageStorageBucket();

  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final List<GlassTabItem> _tabItems = const [
    GlassTabItem(
      icon: LucideIcons.calendar,
      label: 'Today',
      tooltip: 'Today snapshot & quick actions',
    ),
    GlassTabItem(
      icon: LucideIcons.arrowRightLeft,
      label: 'Activity',
      tooltip: 'Transactions & activity',
    ),
    GlassTabItem(
      icon: LucideIcons.calendarClock,
      label: 'Plans',
      tooltip: 'SIP, EMI, bills, and income plans',
    ),
    GlassTabItem(
      icon: LucideIcons.wallet,
      label: 'Accounts',
      tooltip: 'Accounts, funds, and loans',
    ),
  ];

  int _resolveTabFromDeepLink(String? link, int defaultIndex) {
    if (link == null) return defaultIndex;
    final lower = link.toLowerCase().trim();
    if (lower == 'overview' || lower == 'home' || lower == 'today') return 0;
    if (lower == 'transactions' || lower == 'txns' || lower == 'activity') {
      return 1;
    }
    if (lower == 'plans' ||
        lower == 'recurring' ||
        lower == 'bills' ||
        lower == 'subscriptions' ||
        lower == 'subs' ||
        lower == 'sip' ||
        lower == 'emi') {
      return 2;
    }
    if (lower == 'accounts' || lower == 'account' || lower == 'more') return 3;
    return defaultIndex;
  }

  @override
  void initState() {
    super.initState();
    final initial = _resolveTabFromDeepLink(widget.deepLink, widget.initialTab);
    _currentIndex = initial.clamp(0, _tabItems.length - 1);
    _loadedTabs.add(_currentIndex);

    FrameTimingLogger().startTracking('MoneyShell');

    _transitionController = AnimationController(
      vsync: this,
      duration: MoneyMotionTokens.tabSwitch,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: MoneyMotionTokens.enter,
    );

    _slideAnimation = Tween<double>(
      begin: MoneyMotionTokens.tabVerticalShiftPx,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: MoneyMotionTokens.enter,
    ));

    _transitionController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BalanceReviewDialog.showIfNeeded(context);
      _handleDeepLink(widget.deepLink);
    });
  }

  @override
  void didUpdateWidget(MoneyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deepLink != widget.deepLink && widget.deepLink != null) {
      _handleDeepLink(widget.deepLink);
    }
  }

  @override
  void dispose() {
    FrameTimingLogger().stopTracking();
    _transitionController.dispose();
    super.dispose();
  }

  void _selectTab(int newIndex) {
    if (newIndex == _currentIndex) return;

    setState(() {
      _currentIndex = newIndex;
      _loadedTabs.add(newIndex);
    });

    if (MotionScope.animationsDisabled(context)) {
      _transitionController.value = 1.0;
    } else {
      _transitionController.forward(from: 0.0);
    }
  }

  void _handleDeepLink(String? link) {
    if (link == null) return;
    final lower = link.toLowerCase().trim();

    if (lower == 'overview' || lower == 'home' || lower == 'today') {
      _selectTab(0);
    } else if (lower == 'transactions' ||
        lower == 'txns' ||
        lower == 'activity') {
      _selectTab(1);
    } else if (lower == 'plans' ||
        lower == 'recurring' ||
        lower == 'bills' ||
        lower == 'subscriptions' ||
        lower == 'subs' ||
        lower == 'sip' ||
        lower == 'emi') {
      _selectTab(2);
    } else if (lower == 'accounts' || lower == 'account' || lower == 'more') {
      _selectTab(3);
    } else if (lower == 'budget' || lower == 'budgets') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Budget')),
            body: const BudgetTab(),
          ),
        ),
      );
    } else if (lower == 'goals' || lower == 'goal') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Goals')),
            body: const GoalsTab(),
          ),
        ),
      );
    } else if (lower == 'categories') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CategoriesPage()),
      );
    } else if (lower == 'networth' || lower == 'net_worth') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NetWorthPage()),
      );
    } else if (lower == 'calendar') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FinanceCalendarPage()),
      );
    } else if (lower == 'debt' || lower == 'loans' || lower == 'cards') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DebtPage()),
      );
    } else if (lower == 'insights' || lower == 'alerts') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InsightsPage()),
      );
    } else if (lower == 'cashflow' || lower == 'cash_flow') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CashFlowPage()),
      );
    } else if (lower == 'reports' || lower == 'export') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReportsPage()),
      );
    } else if (lower == 'split' || lower == 'splits') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SplitGroupsPage()),
      );
    } else if (lower == 'privacy') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FinancePrivacyDataPage()),
      );
    }
  }

  void _openQuickAdd() {
    QuickAddSheet.show(context);
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return TodayTab(
          onQuickAdd: _openQuickAdd,
          onSelectTab: _selectTab,
        );
      case 1:
        return const ActivityTab();
      case 2:
        return const PlansTab();
      case 3:
        return const AccountsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: PageStorage(
        bucket: _bucket,
        child: Stack(
          children: [
            // Lazy stack preserving state and scroll position
            IndexedStack(
              index: _currentIndex,
              children: List.generate(_tabItems.length, (index) {
                if (!_loadedTabs.contains(index)) {
                  return const SizedBox.shrink();
                }

                final content = _buildTabContent(index);

                // Apply transition only to the currently active tab
                if (index == _currentIndex) {
                  return AnimatedBuilder(
                    animation: _transitionController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: child,
                        ),
                      );
                    },
                    child: content,
                  );
                }
                return content;
              }),
            ),

            // Floating Navigation Bar + Quick Add Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Row(
                children: [
                  Expanded(
                    child: GlassTabBar(
                      selectedIndex: _currentIndex,
                      items: _tabItems,
                      onItemSelected: _selectTab,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      right: 16.0,
                      bottom: 12.0 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: PressScale(
                      onTap: _openQuickAdd,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: BentoTheme.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: BentoTheme.accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.plus,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
