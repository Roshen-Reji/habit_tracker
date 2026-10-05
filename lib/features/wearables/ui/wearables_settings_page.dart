import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/wearables/data/sync_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';

class WearablesSettingsPage extends StatefulWidget {
  const WearablesSettingsPage({super.key});

  @override
  State<WearablesSettingsPage> createState() => _WearablesSettingsPageState();
}

class _WearablesSettingsPageState extends State<WearablesSettingsPage> {
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final source = SyncService.instance.getActiveSource();
    final perms = await source.checkPermissions();
    if (mounted) {
      setState(() {
        _permissions = perms;
      });
    }
  }

  Future<void> _triggerSync() async {
    final success = await SyncService.instance.sync(days: 7);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✓ Telemetry synced successfully' : 'Sync completed with warnings',
        ),
        backgroundColor: success ? AppColors.success : AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useMock = WearableSettings.useMockProvider;
    final lastSyncMs = WearableSettings.lastSyncMs;
    final lastSyncText = lastSyncMs != null
        ? DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(lastSyncMs))
        : 'Never';

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'WEARABLE INTEGRATION',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Device Card
          BentoContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            customColor: BentoTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BentoTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(LucideIcons.watch, color: BentoTheme.accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Samsung Galaxy Watch 7',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: useMock ? Colors.amber : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                useMock ? 'Simulator Active' : 'Samsung Health Connected',
                                style: TextStyle(
                                  color: useMock ? Colors.amber : AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'BioActive Sensor telemetry active: Sleep stages, Energy Score, and Samsung Health AGEs Index.',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAST SYNC',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastSyncText,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<SyncStatus>(
                      valueListenable: SyncService.instance.statusNotifier,
                      builder: (context, status, _) {
                        final isSyncing = status == SyncStatus.syncing;
                        return ElevatedButton.icon(
                          onPressed: isSyncing ? null : _triggerSync,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BentoTheme.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(LucideIcons.refreshCw, size: 16),
                          label: Text(
                            isSyncing ? 'SYNCING...' : 'SYNC NOW',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Provider & Testing Mode
          _buildSectionHeader('TELEMETRY SOURCE'),
          const SizedBox(height: 8),
          BentoContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            customColor: BentoTheme.surface,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Galaxy Watch 7 Simulator',
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Generates realistic BioActive sensor, sleep, workout & AGEs telemetry for testing.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                  value: useMock,
                  activeColor: BentoTheme.accent,
                  onChanged: (val) {
                    setState(() {
                      WearableSettings.useMockProvider = val;
                      SyncService.instance.resetSource();
                    });
                    _checkStatus();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Automation Settings
          _buildSectionHeader('INTEGRATION & AUTOMATION'),
          const SizedBox(height: 8),
          BentoContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 16,
            customColor: BentoTheme.surface,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Day Journal Auto-Log',
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Auto-log morning sleep score, Energy Score, and AGEs index into your daily journal.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                  value: WearableSettings.journalAutologEnabled,
                  activeColor: BentoTheme.accent,
                  onChanged: (val) => setState(() => WearableSettings.journalAutologEnabled = val),
                ),
                const Divider(color: Colors.white10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Auto-Sync on Resume',
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Fetch latest watch telemetry when opening or returning to the app.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                  value: WearableSettings.autoSyncOnResume,
                  activeColor: BentoTheme.accent,
                  onChanged: (val) => setState(() => WearableSettings.autoSyncOnResume = val),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Calorie Burn Reconciliation',
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Credit workouts to Diet log and reconcile total daily calorie expenditure.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(LucideIcons.checkCheck, color: AppColors.success, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Telemetry Checklist
          _buildSectionHeader('SUPPORTED TELEMETRY STREAMS'),
          const SizedBox(height: 8),
          BentoContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            customColor: BentoTheme.surface,
            child: Column(
              children: [
                _buildPermissionRow('Daily Activity (Steps & Total Burn)', _permissions['activity'] ?? true, LucideIcons.footprints),
                const Divider(color: Colors.white10),
                _buildPermissionRow('Sleep Sessions & Stages (REM/Deep)', _permissions['sleep'] ?? true, LucideIcons.moon),
                const Divider(color: Colors.white10),
                _buildPermissionRow('Exercise & Workout Sessions', _permissions['exercise'] ?? true, LucideIcons.dumbbell),
                const Divider(color: Colors.white10),
                _buildPermissionRow('Body Composition (BIA % & Muscle)', _permissions['body_composition'] ?? true, LucideIcons.scale),
                const Divider(color: Colors.white10),
                _buildPermissionRow('Daily Energy Score (0-100)', _permissions['energy_score'] ?? true, LucideIcons.zap),
                const Divider(color: Colors.white10),
                _buildPermissionRow('Samsung Health AGEs Index', _permissions['ages_index'] ?? true, LucideIcons.sparkles, highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Open Samsung Health Button
          OutlinedButton.icon(
            onPressed: () async {
              final source = SyncService.instance.getActiveSource();
              await source.openExternalApp();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: BentoTheme.textPrimary,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(LucideIcons.externalLink, size: 16),
            label: const Text('Open Samsung Health App', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: BentoTheme.textSecondary,
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPermissionRow(String title, bool active, IconData icon, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: highlight ? BentoTheme.accent : BentoTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: highlight ? BentoTheme.accent : BentoTheme.textPrimary,
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: active ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              active ? 'ACTIVE' : 'OFF',
              style: TextStyle(
                color: active ? AppColors.success : AppColors.error,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
