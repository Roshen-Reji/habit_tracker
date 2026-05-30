import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/services/rank_service.dart';
import 'package:habit_tracker/data/models/user_rank.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
        builder: (context, Box<Goal> missionBox, _) {
          final goals = missionBox.values.toList();
          final record = RankService.calculateServiceRecord(goals);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    children: [
                      _buildProfileSection(record).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutBack).fade(),
                      const SizedBox(height: 32),
                      _buildSettingGroup("SYSTEM CONFIGURATION", [
                        _buildToggleTile(Icons.notifications_active, "Mission Alerts", _notificationsEnabled, (v) => setState(() => _notificationsEnabled = v)),
                        _buildCurrencyTile(),
                      ]).animate().slideY(begin: 0.1, duration: 400.ms, delay: 100.ms, curve: Curves.easeOutBack).fade(),
                      const SizedBox(height: 24),
                      _buildSettingGroup("DATA MANAGEMENT", [
                        _buildActionTile(Icons.delete_sweep, "Purge Mission Data", "Wipe progress and reset position", _confirmDataPurge, isDestructive: true),
                        _buildActionTile(Icons.refresh, "Reset Daily Streaks", "Keep rank, reset daily targets", _resetAllDailyGoals),
                      ]).animate().slideY(begin: 0.1, duration: 400.ms, delay: 200.ms, curve: Curves.easeOutBack).fade(),
                      const SizedBox(height: 120), 
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildAppBar() {
    return const SliverAppBar(
      expandedHeight: 100,
      backgroundColor: AppColors.background,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: EdgeInsets.only(left: 20, bottom: 16),
        title: Text("S E T T I N G S", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildProfileSection(UserRank record) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'COMMANDER');

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 30, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 35, color: Colors.black)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(record.position, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        Text("RANK: ${record.title} (LVL ${record.level})", style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 18), onPressed: () => _editUsername(settings)),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("EVOLUTION PROGRESS", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text("${record.totalXp} XP", style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: record.progressToNext,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: TextStyle(color: AppColors.primary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(IconData icon, String title, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      trailing: Switch.adaptive(value: value, activeColor: AppColors.primary, onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); }),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.textSecondary, size: 22),
      title: Text(title, style: TextStyle(color: isDestructive ? AppColors.error : AppColors.textPrimary, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
    );
  }

  Widget _buildCurrencyTile() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('finance_settings').listenable(),
      builder: (context, Box box, _) {
        String currentSymbol = box.get('currency_symbol', defaultValue: '₹');
        return ListTile(
          onTap: () { HapticFeedback.mediumImpact(); _editCurrency(box); },
          leading: const Icon(Icons.payments, color: AppColors.textSecondary, size: 22),
          title: const Text("Base Currency", style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          subtitle: Text("Currently: $currentSymbol", style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
        );
      }
    );
  }

  void _editCurrency(Box box) {
    final controller = TextEditingController(text: box.get('currency_symbol', defaultValue: '₹'));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Update Currency Symbol", style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () { box.put('currency_symbol', controller.text); Navigator.pop(context); }, child: const Text("Apply", style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  void _editUsername(Box box) {
    final controller = TextEditingController(text: box.get('username'));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Update Callsign", style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () { box.put('username', controller.text.toUpperCase()); Navigator.pop(context); }, child: const Text("Apply", style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  void _confirmDataPurge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("PURGE ALL DATA?", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently delete missions and reset your service record.", style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abort", style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () async { await Hive.box<Goal>('mission_box_v4').clear(); if (mounted) Navigator.pop(context); }, child: const Text("Confirm Purge", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }

  void _resetAllDailyGoals() {
    final box = Hive.box<Goal>('mission_box_v4');
    for (var goal in box.values) {
      if (goal.type == GoalType.daily || goal.type == GoalType.today) {
        goal.reset();
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Daily targets reset successfully."), backgroundColor: AppColors.primary));
  }
}
