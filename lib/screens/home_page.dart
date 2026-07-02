import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/screens/dashboard_view.dart';
import 'package:habit_tracker/features/tasks/tasks_page.dart';
import 'package:habit_tracker/features/music/music_library_page.dart';
import 'package:habit_tracker/features/diet/diet_page.dart';
import 'package:habit_tracker/screens/settings_page.dart';
import 'package:habit_tracker/features/music/music_player_page.dart';
import 'package:habit_tracker/features/home/home_chat.dart';
import 'package:habit_tracker/widgets/mini_player_bar.dart';
import 'package:habit_tracker/widgets/bottom_nav_bar.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/data/services/permission_service.dart';

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
    const TasksPage(),
    const DietPage(),
    const MusicLibraryPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Logic to identify user on first run
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionService.checkAndRequestPermissions(context);
      if (_settingsBox.get('username') == null && mounted) {
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
          AnimatedSwitcher(duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation), child: child)), child: SizedBox(key: ValueKey(_selectedIndex), child: _pages[_selectedIndex])),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped),
          ),
          const GlobalFloatingPlayer(),
          const HomeChatFAB(),
        ],
      ),
    );
  }
}

