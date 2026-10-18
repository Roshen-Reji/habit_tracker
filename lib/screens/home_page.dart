import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/features/finance/finance_page.dart';
import 'package:habit_tracker/screens/dashboard_view.dart';
import 'package:habit_tracker/features/tasks/tasks_page.dart';
import 'package:habit_tracker/features/diet/diet_page.dart';
import 'package:habit_tracker/features/home/home_chat.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/widgets/bottom_nav_bar.dart';
import 'package:habit_tracker/data/services/permission_service.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = AppNav.instance.currentTab;
  Box? get _settingsBox =>
      Hive.isBoxOpen('settings') ? Hive.box('settings') : null;
  final ScrollController _dashboardScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AppNav.instance.addListener(_onNavChanged);
    // Logic to identify user on first run
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionService.checkAndRequestPermissions(context);
      final box = _settingsBox;
      if (box != null && box.get('username') == null && mounted) {
        _showOnboardingDialog();
      }
    });
  }

  @override
  void dispose() {
    AppNav.instance.removeListener(_onNavChanged);
    _dashboardScrollController.dispose();
    super.dispose();
  }

  void _onNavChanged() {
    if (mounted && _selectedIndex != AppNav.instance.currentTab) {
      setState(() {
        _selectedIndex = AppNav.instance.currentTab;
      });
    }
  }

  void _showOnboardingDialog() {
    final TextEditingController _nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: TactileTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: TactileTokens.specularBorder, width: 1.0),
          ),
          title: const Text(
            "Welcome",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "enter your name",
                style: TextStyle(color: TactileTokens.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Enter Name...",
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white)),
                ),
              ),
            ],
          ),
          actions: [
            TactileButton(
              size: TactileButtonSize.small,
              variant: TactileButtonVariant.primary,
              label: "ENGAGE",
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  _settingsBox?.put(
                      'username', _nameController.text.toUpperCase());
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      AppNav.instance.setTab(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardView(scrollController: _dashboardScrollController),
      const HealthPage(),
      const DietPage(),
      const TasksPage(),
      const FinancePage(),
    ];

    final clampedIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey(clampedIndex),
              child: pages[clampedIndex],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(
              selectedIndex: clampedIndex,
              onItemTapped: _onItemTapped,
            ),
          ),
          if (clampedIndex != 3) const HomeChatFAB(),
        ],
      ),
    );
  }
}
