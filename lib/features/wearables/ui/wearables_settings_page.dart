import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/wearables/data/sync_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
    final success = await SyncService.instance.sync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✓ Telemetry synced successfully' : 'Sync completed with warnings or no new data',
        ),
        backgroundColor: success ? AppColors.success : AppColors.warning,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final source = SyncService.instance.getActiveSource();
    final granted = await source.requestPermissions();
    if (granted) {
      setState(() {
        WearableSettings.isEnabled = true;
      });
    }
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['wear_last_sync_ms', 'wear_enabled']),
      builder: (context, box, _) {
        final isEnabled = WearableSettings.isEnabled;
        final lastSyncMs = WearableSettings.lastSyncMs;
        final lastSyncText = lastSyncMs != null && lastSyncMs > 0
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
              'HEALTH DATA',
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
                          child: Icon(LucideIcons.heartPulse, color: BentoTheme.accent, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Health Connect',
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
                                      color: isEnabled ? AppColors.success : AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEnabled ? 'Connected' : 'Not Connected',
                                    style: TextStyle(
                                      color: isEnabled ? AppColors.success : AppColors.warning,
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
                      'Sync steps, sleep, workouts, and body measurements securely from Health Connect.',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    if (!isEnabled) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BentoTheme.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Connect & Grant Permissions'),
                      ),
                    ],
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
                              onPressed: isSyncing || !isEnabled ? null : _triggerSync,
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

              // Setup Guide
              if (!isEnabled) ...[
                _buildSectionHeader('SETUP GUIDE'),
                const SizedBox(height: 8),
                BentoContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  customColor: BentoTheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSetupStep('1', 'Install or update Health Connect from the Google Play Store if it isn\'t built-in.'),
                      const SizedBox(height: 12),
                      _buildSetupStep('2', 'Open your watch\'s companion app (e.g., your health app) and turn on sharing to Health Connect.'),
                      const SizedBox(height: 12),
                      _buildSetupStep('3', 'Tap "Connect & Grant Permissions" above to allow this app to read your data.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

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
                        'Auto-log morning sleep score and workouts into your daily journal.',
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
                        'Fetch latest telemetry when opening or returning to the app.',
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

              // Diagnostics
              _buildSectionHeader('DIAGNOSTICS & SYNC LOGS'),
              const SizedBox(height: 8),
              BentoContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                customColor: BentoTheme.surface,
                child: Column(
                  children: [
                    _buildDiagnosticRow('Daily Activity', LucideIcons.footprints),
                    const Divider(color: Colors.white10),
                    _buildDiagnosticRow('Sleep Sessions', LucideIcons.moon),
                    const Divider(color: Colors.white10),
                    _buildDiagnosticRow('Exercise Sessions', LucideIcons.dumbbell),
                    const Divider(color: Colors.white10),
                    _buildDiagnosticRow('Body Composition', LucideIcons.scale),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSetupStep(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BentoTheme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(num, style: TextStyle(color: BentoTheme.accent, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13, height: 1.4)),
        ),
      ],
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

  Widget _buildDiagnosticRow(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: BentoTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'Check sync logs',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
