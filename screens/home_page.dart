import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/goals.dart';
import 'package:habit_tracker/widgets/mysterious_quote_card.dart';
import 'package:habit_tracker/widgets/mysterious_momentum_graph.dart';
import 'package:habit_tracker/widgets/star_background.dart';
import 'package:habit_tracker/screens/goals_page.dart';
import 'package:habit_tracker/screens/music_library_page.dart';
import 'package:habit_tracker/screens/speech_vault_page.dart';
import 'package:habit_tracker/widgets/mini_player_bar.dart';
import 'package:habit_tracker/screens/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final Box _settingsBox = Hive.box('settings'); //

  final List<Widget> _pages = [
    const DashboardView(),
    const GoalsPage(),
    const SpeechVaultPage(),
    const MusicLibraryPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Logic to identify user on first run
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_settingsBox.get('username') == null) {
        _showOnboardingDialog();
      }
    });
  }

  void _showOnboardingDialog() {
    final TextEditingController _nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), 
            side: const BorderSide(color: Colors.tealAccent)
          ),
          title: const Text("Welcome", style: TextStyle(color: Colors.tealAccent, letterSpacing: 2)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("enter your name", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Enter Name...",
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  _settingsBox.put('username', _nameController.text.toUpperCase());
                  Navigator.pop(context);
                  setState(() {}); 
                }
              },
              child: const Text("ENGAGE", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.mediumImpact(); //
      setState(() {
        _selectedIndex = index;
      });
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _pages[_selectedIndex],
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildAppleNavigationStack(),
          ),
          const GlobalFloatingPlayer(),
        ],
      ),
    );
  }

Widget _buildAppleNavigationStack() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45), 
          child: Container(
            decoration: BoxDecoration(
              // CHANGE OPACITY HERE: Lowered from 0.7 to 0.35 for more transparency
              color: const Color(0xFF1C1C1E).withOpacity(0.35),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.15), // Slightly increased border opacity so it doesn't get lost
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAppleTab(Icons.dashboard_rounded, "HOME", 0),
                      _buildAppleTab(Icons.check_circle_rounded, "GOALS", 1),
                      _buildAppleTab(Icons.auto_awesome_motion_rounded, "VAULT", 2),
                      _buildAppleTab(Icons.music_note_rounded, "AUDIO", 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildAppleTab(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.4),
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'COMMANDER');

        return StarBackground( //
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("WELCOME,\n$name",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.tealAccent, width: 2)),
                            child: const CircleAvatar(backgroundColor: Colors.black, radius: 20, child: Icon(Icons.settings, color: Colors.tealAccent, size: 20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const MysteriousQuoteCard(), //
                  const SizedBox(height: 10),
                  const MysteriousMomentumGraph(), //
                  const SizedBox(height: 20),
                  _buildSectionHeader("Tasks"),
                  _buildDailyMissionsList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.radar, color: Colors.tealAccent, size: 16),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: Colors.tealAccent.withOpacity(0.8), letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDailyMissionsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Goal>('mission_box_v3').listenable(),
      builder: (context, Box<Goal> box, _) {
        final dailyGoals = box.values.where((g) => g.type == GoalType.daily).toList();
        if (dailyGoals.isEmpty) return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("NO ACTIVE MISSIONS", style: TextStyle(color: Colors.grey))));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: dailyGoals.length > 3 ? 3 : dailyGoals.length,
          itemBuilder: (context, index) => _buildGoalTile(dailyGoals[index]),
        );
      },
    );
  }

  Widget _buildGoalTile(Goal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.6), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: ListTile(
        onTap: () { 
          goal.isCompleted = !goal.isCompleted; 
          goal.save(); //
        },
        leading: Icon(goal.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: Colors.tealAccent),
        title: Text(goal.title, style: TextStyle(color: goal.isCompleted ? Colors.grey : Colors.white, decoration: goal.isCompleted ? TextDecoration.lineThrough : null)),
      ),
    );
  }
}