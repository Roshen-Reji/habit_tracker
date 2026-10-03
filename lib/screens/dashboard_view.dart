import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/widgets/wallet_card_stack.dart';
import 'package:habit_tracker/screens/settings_page.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'USER');

        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed Greeting Header and Settings Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            letterSpacing: 0.8,
                            color: BentoTheme.textPrimary,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .slideX(
                          begin: -0.1,
                          duration: 350.ms,
                          curve: Curves.easeOutQuad,
                        )
                        .fade(),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      ),
                      child: BentoContainer(
                        borderRadius: 12,
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          LucideIcons.settings,
                          color: BentoTheme.textPrimary,
                          size: 20,
                        ),
                      ),
                    ).animate().scale(
                          delay: 150.ms,
                          duration: 300.ms,
                          curve: Curves.easeOutBack,
                        ),
                  ],
                ),
              ),
              // Wallet Card Stack fills the rest of the dashboard
              const Expanded(
                child: WalletCardStack(),
              ),
            ],
          ),
        );
      },
    );
  }
}
