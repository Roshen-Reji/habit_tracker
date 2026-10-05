import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';

/// Glass Material 3 Expressive frame shared by cards in the home stack.
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
    final effectiveAccent = accentColor ?? BentoTheme.accent;
    final borderRadius = BorderRadius.circular(ExpressiveTokens.radiusCard);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final glassTop =
        BentoTheme.surface.withValues(alpha: isLight ? 0.95 : 0.88);
    final glassBottom =
        BentoTheme.surfaceElevated.withValues(alpha: isLight ? 0.90 : 0.80);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: effectiveAccent.withValues(alpha: 0.1),
        highlightColor: effectiveAccent.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // This decoration deliberately sits outside the clip below so
            // the soft shadow can extend beyond the glass panel.
            boxShadow: isFocused ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.30),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      glassTop,
                      glassBottom,
                    ],
                  ),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: borderColor,
                    width: 1.2,
                  ),
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
      ),
    );
  }
}
