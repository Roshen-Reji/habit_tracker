import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/finance/data/backup/finance_backup_service.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/ui/categories/categories_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/reminders_settings_page.dart';

class MoreTab extends StatelessWidget {
  final Function(String deepLink)? onNavigate;

  const MoreTab({super.key, this.onNavigate});

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final backup = await FinanceBackupService.exportJson();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Backup exported successfully (${backup.length} bytes)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = FinanceController();
    final accountsCount = controller.activeAccounts.length;
    final categoriesCount = controller.activeCategories.length;
    final txCount = controller.allTransactions.length;

    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Money OS',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$txCount transactions · $accountsCount accounts · $categoriesCount categories',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              _sectionHeader('MANAGE & CONFIGURE'),
              _tile(
                icon: LucideIcons.bellRing,
                title: 'Reminders & Alarms',
                subtitle: 'Schedules, notifications, styles and permissions',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RemindersSettingsPage(),
                    ),
                  );
                },
              ),
              _tile(
                icon: LucideIcons.tag,
                title: 'Categories',
                subtitle: '$categoriesCount categories (Needs, Wants, Savings)',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CategoriesPage()),
                  );
                },
              ),
              _tile(
                icon: LucideIcons.landmark,
                title: 'Accounts & Vaults',
                subtitle: '$accountsCount accounts active',
                onTap: () {
                  if (onNavigate != null) {
                    onNavigate!('accounts');
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsPage()),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              _sectionHeader('INTELLIGENCE & REPORTS'),
              _tile(
                icon: LucideIcons.lineChart,
                title: 'Net Worth History',
                subtitle: 'Assets, liabilities and 12-month trend',
                onTap: () {
                  if (onNavigate != null) {
                    onNavigate!('networth');
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NetWorthPage()),
                    );
                  }
                },
              ),
              _tile(
                icon: LucideIcons.calendarClock,
                title: 'Bills & Subscriptions',
                subtitle: 'Recurring payments, reminders and auto-debits',
                onTap: () {
                  if (onNavigate != null) onNavigate!('recurring');
                },
              ),
              _tile(
                icon: LucideIcons.calendar,
                title: 'Financial Calendar',
                subtitle: 'Schedule of bills, SIPs, due dates and cashflow',
                onTap: () {
                  if (onNavigate != null) onNavigate!('calendar');
                },
              ),
              _tile(
                icon: LucideIcons.creditCard,
                title: 'Debt & Credit Cards',
                subtitle: 'EMIs, statements and loan amortisation',
                onTap: () {
                  if (onNavigate != null) onNavigate!('debt');
                },
              ),
              _tile(
                icon: LucideIcons.sparkles,
                title: 'Financial Insights',
                subtitle: 'Spending spikes, pace warnings & anomalies',
                onTap: () {
                  if (onNavigate != null) onNavigate!('insights');
                },
              ),
              _tile(
                icon: LucideIcons.arrowRightLeft,
                title: 'Cash Flow Analysis',
                subtitle: 'Inflow, outflow & 30-day projection',
                onTap: () {
                  if (onNavigate != null) onNavigate!('cashflow');
                },
              ),
              _tile(
                icon: LucideIcons.fileSpreadsheet,
                title: 'Financial Reports',
                subtitle: 'Monthly cash flow, spending breakdown & CSV export',
                onTap: () {
                  if (onNavigate != null) onNavigate!('reports');
                },
              ),
              const SizedBox(height: 20),
              _sectionHeader('DATA & PRIVACY'),
              _tile(
                icon: LucideIcons.download,
                title: 'Export JSON Backup',
                subtitle:
                    'Create a full encrypted snapshot of all finance data',
                onTap: () => _exportBackup(context),
              ),
              _tile(
                icon: LucideIcons.shieldCheck,
                title: 'Privacy & Security',
                subtitle: 'On-device storage, biometric lock, zero telemetry',
                onTap: () {
                  if (onNavigate != null) onNavigate!('privacy');
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: BentoTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: BentoTheme.accent),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          trailing: Icon(LucideIcons.chevronRight,
              size: 16, color: BentoTheme.textSecondary),
          onTap: onTap,
        ),
      ),
    );
  }
}
