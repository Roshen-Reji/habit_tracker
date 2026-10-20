import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/widgets/wallet_card_stack.dart';
import 'package:habit_tracker/features/home/widgets/expandable_cluster_modal.dart';

class DashboardView extends StatefulWidget {
  final ScrollController? scrollController;

  const DashboardView({
    super.key,
    this.scrollController,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _hasAnimatedEntrance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hasAnimatedEntrance = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (!Hive.isBoxOpen('settings')) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['username']),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'USER');

        Widget greetingCol = Column(
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
        );

        Widget settingsBtn = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            AppNav.openSettings(context);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: Center(
              child: BentoContainer(
                borderRadius: 12,
                padding: const EdgeInsets.all(10),
                child: Icon(
                  LucideIcons.settings,
                  color: BentoTheme.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        );

        if (!_hasAnimatedEntrance && !reduceMotion) {
          greetingCol = greetingCol
              .animate()
              .slideX(
                begin: -0.1,
                duration: 350.ms,
                curve: Curves.easeOutQuad,
              )
              .fade();
          settingsBtn = settingsBtn.animate().scale(
                delay: 150.ms,
                duration: 300.ms,
                curve: Curves.easeOutBack,
              );
        }

        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed Greeting Header and Settings Button
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation:
                      widget.scrollController ?? const AlwaysStoppedAnimation(0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        greetingCol,
                        settingsBtn,
                      ],
                    ),
                  ),
                  builder: (context, child) {
                    if (reduceMotion ||
                        widget.scrollController == null ||
                        !widget.scrollController!.hasClients) {
                      return child!;
                    }

                    final offset =
                        widget.scrollController!.offset.clamp(0.0, 1600.0);
                    return Transform.translate(
                      offset: Offset(0, -offset * 0.045),
                      child: Opacity(
                        opacity: 1.0 - ((offset / 1600.0) * 0.10),
                        child: child,
                      ),
                    );
                  },
                ),
              ),

              // Compact 2-Column Bento Cluster Grid (Resting State)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  height: 156,
                  child: Row(
                    children: const [
                      Expanded(
                        child: CompactMetricTile(),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SmartClusterFolderTile(),
                      ),
                    ],
                  ),
                ),
              ),

              // Wallet Card Stack fills the rest of the dashboard
              Expanded(
                child: WalletCardStack(controller: widget.scrollController),
              ),
            ],
          ),
        );
      },
    );
  }
}
