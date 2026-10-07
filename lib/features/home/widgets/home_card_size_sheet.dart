import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/depth_card.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/screens/home_layout_settings_page.dart';

/// Bottom sheet allowing quick card size changes on long-press (MVP 5 P8-1).
class HomeCardSizeSheet extends StatelessWidget {
  final HomeCardSpec spec;

  const HomeCardSizeSheet({
    super.key,
    required this.spec,
  });

  static Future<void> show(BuildContext context, HomeCardSpec spec) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HomeCardSizeSheet(spec: spec),
    );
  }

  String _sizeDescription(HomeCardSize size) {
    switch (size) {
      case HomeCardSize.compact:
        return 'Standard minimal card height';
      case HomeCardSize.large:
        return 'Expanded detail and insights';
      case HomeCardSize.hero:
        return 'Full-focus hero presentation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box('settings');
    final currentSize = HomeCardRegistry.getCardSize(settingsBox, spec.id);
    final supportedSizes = spec.supportedSizes;

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusHero),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: BentoTheme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Icon(spec.icon, size: 20, color: BentoTheme.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.title,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.slidersHorizontal,
                    size: 18, color: BentoTheme.textSecondary),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeLayoutSettingsPage(),
                    ),
                  );
                },
                tooltip: 'Layout Settings',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SELECT CARD SIZE',
            style: AppTokens.label(color: BentoTheme.textMuted),
          ),
          const SizedBox(height: 12),

          // Size choices
          ...HomeCardSize.values.map((size) {
            final isSupported = supportedSizes.contains(size);
            final isSelected = currentSize == size;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DepthCard(
                elevation: isSelected ? DepthElevation.e2 : DepthElevation.e1,
                radius: AppTokens.radiusCard,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isSelected
                    ? BentoTheme.accent.withValues(alpha: 0.12)
                    : (isSupported
                        ? BentoTheme.surface
                        : BentoTheme.surfaceSunken.withValues(alpha: 0.5)),
                onTap: isSupported
                    ? () async {
                        HapticFeedback.selectionClick();
                        await HomeCardRegistry.setCardSize(
                            settingsBox, spec.id, size);
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? LucideIcons.checkCircle2
                          : (isSupported
                              ? LucideIcons.circle
                              : LucideIcons.circleSlash),
                      size: 18,
                      color: isSelected
                          ? BentoTheme.accent
                          : (isSupported
                              ? BentoTheme.textSecondary
                              : BentoTheme.textMuted.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            size.name.toUpperCase(),
                            style: TextStyle(
                              color: isSupported
                                  ? (isSelected
                                      ? BentoTheme.textPrimary
                                      : BentoTheme.textSecondary)
                                  : BentoTheme.textMuted.withValues(alpha: 0.5),
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSupported
                                ? _sizeDescription(size)
                                : 'Not available for this card',
                            style: TextStyle(
                              color: BentoTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BentoTheme.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
