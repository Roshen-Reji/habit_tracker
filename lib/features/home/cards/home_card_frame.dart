import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/depth_card.dart';

/// Calm, borderless frame shared by cards in the home stack (MVP 5 design system).
class HomeCardFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isFocused;

  const HomeCardFrame({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
    this.onTap,
    this.accentColor,
    this.contentPadding = const EdgeInsets.fromLTRB(18, 14, 18, 18),
    this.isFocused = true,
  });

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      elevation: isFocused ? DepthElevation.e2 : DepthElevation.e1,
      radius: AppTokens.radiusCard,
      padding: contentPadding,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header strip: plain 16-px muted glyph, 11-px caps label
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: BentoTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTokens.label(color: BentoTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
