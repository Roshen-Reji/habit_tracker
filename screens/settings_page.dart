import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/goals.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  // Rank Ladder
  final List<String> _ranks = [
    "RECRUIT", 
    "OPERATIVE", 
    "SPECIALIST", 
    "VETERAN", 
    "COMMANDER", 
    "LEGEND"
  ];

  /// Calculates Rank, Level, and the user's specific "Position" based on category focus
  Map<String, dynamic> _calculateServiceRecord(List<Goal> goals) {
    double totalXp = 0;
    Map<GoalCategory, int> categoryPoints = {};
    
    for (var goal in goals) {
      // Priority weighting for XP
      double weight = goal.type == GoalType.monthly ? 50.0 : (goal.type == GoalType.weekly ? 20.0 : 5.0);
      
      if (goal.isCompleted) {
        totalXp += weight;
        categoryPoints[goal.category] = (categoryPoints[goal.category] ?? 0) + weight.toInt();
      }
      totalXp += (goal.streakCount * (weight * 0.1)); 
    }

    // Determine "Position" (Specialization) based on max points in a category
    String position = "UNASSIGNED";
    if (categoryPoints.isNotEmpty) {
      final bestCategory = categoryPoints.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      switch (bestCategory) {
        case GoalCategory.learning: position = "LEAD RESEARCHER"; break;
        case GoalCategory.fitness: position = "TACTICAL ATHLETE"; break;
        case GoalCategory.productivity: position = "OPERATIONS CHIEF"; break;
        case GoalCategory.health: position = "BIO-SECURITY OFFICER"; break;
        case GoalCategory.hobby: position = "CREATIVE DIRECTOR"; break;
      }
    }

    int level = (totalXp / 100).floor();
    int rankIndex = level.clamp(0, _ranks.length - 1);
    double progressToNext = (totalXp % 100) / 100;

    return {
      "title": _ranks[rankIndex],
      "position": position,
      "level": level + 1,
      "progress": progressToNext,
      "xp": totalXp.toInt()
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Goal>('mission_box_v3').listenable(),
        builder: (context, Box<Goal> missionBox, _) {
          final goals = missionBox.values.toList();
          final record = _calculateServiceRecord(goals);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    children: [
                      _buildProfileSection(record),
                      const SizedBox(height: 32),
                      _buildSettingGroup("SYSTEM CONFIGURATION", [
                        _buildToggleTile(Icons.notifications_active, "Mission Alerts", _notificationsEnabled, (v) => setState(() => _notificationsEnabled = v)),
                      ]),
                      const SizedBox(height: 24),
                      _buildSettingGroup("DATA MANAGEMENT", [
                        _buildActionTile(Icons.delete_sweep, "Purge Mission Data", "Wipe progress and reset position", _confirmDataPurge, isDestructive: true),
                        _buildActionTile(Icons.refresh, "Reset Daily Streaks", "Keep rank, reset daily targets", _resetAllDailyGoals),
                      ]),
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
      backgroundColor: Colors.black,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: EdgeInsets.only(left: 20, bottom: 16),
        title: Text("S E T T I N G S", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      ),
    );
  }

  Widget _buildProfileSection(Map<String, dynamic> record) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'COMMANDER');

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 30, backgroundColor: Colors.tealAccent, child: Icon(Icons.person, size: 35, color: Colors.black)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(record['position'], style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        Text("RANK: ${record['title']} (LVL ${record['level']})", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _editUsername(settings)),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("EVOLUTION PROGRESS", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold)),
                      Text("${record['xp']} XP", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: record['progress'],
                      backgroundColor: Colors.white10,
                      color: Colors.tealAccent,
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
          child: Text(title, style: TextStyle(color: Colors.tealAccent.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(IconData icon, String title, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Switch.adaptive(value: value, activeColor: Colors.tealAccent, onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); }),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70, size: 22),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
    );
  }

  void _editUsername(Box box) {
    final controller = TextEditingController(text: box.get('username'));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Update Callsign", style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () { box.put('username', controller.text.toUpperCase()); Navigator.pop(context); }, child: const Text("Apply", style: TextStyle(color: Colors.tealAccent))),
        ],
      ),
    );
  }

  void _confirmDataPurge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("PURGE ALL DATA?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently delete missions and reset your service record.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abort")),
          TextButton(onPressed: () async { await Hive.box<Goal>('mission_box_v3').clear(); if (mounted) Navigator.pop(context); }, child: const Text("Confirm Purge", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _resetAllDailyGoals() {
    final box = Hive.box<Goal>('mission_box_v3');
    for (var goal in box.values) { if (goal.type == GoalType.daily) goal.reset(); }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Daily missions reset.")));
  }
}