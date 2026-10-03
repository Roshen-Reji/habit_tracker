import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';

/// Standard Material 3 Expressive frame for all home cards in the wallet stack.
class HomeCardFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsetsGeometry contentPadding;

  const HomeCardFrame({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
    this.onTap,
    this.accentColor,
    this.contentPadding = const EdgeInsets.fromLTRB(18, 14, 18, 18),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? BentoTheme.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
        splashColor: effectiveAccent.withValues(alpha: 0.1),
        highlightColor: effectiveAccent.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Peek header strip
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: effectiveAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 16,
                      color: effectiveAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
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
        ),
      ),
    );
  }
}
