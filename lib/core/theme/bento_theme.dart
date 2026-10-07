import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/widgets/depth_card.dart';
import 'package:habit_tracker/services/now_playing_service.dart';

/// Legacy BentoTheme adapter that delegates directly to [AppTokens] and [DepthCard].
///
/// Preserves existing callers while enforcing the calm, borderless MVP 5 design system.
class BentoTheme {
  // Base Background Color
  static Color get background {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    final tokens = isLight ? AppTokens.light : AppTokens.dark;
    Color base = tokens.background;
    bool dynamicBg =
        Hive.box('settings').get('dynamic_background', defaultValue: true);

    if (dynamicBg &&
        NowPlayingService.instance.currentDominantColor.value != null) {
      return Color.alphaBlend(
        NowPlayingService.instance.currentDominantColor.value!
            .withValues(alpha: isLight ? 0.05 : 0.1),
        base,
      );
    }
    return base;
  }

  // Cards and surfaces
  static Color get surface {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    final tokens = isLight ? AppTokens.light : AppTokens.dark;
    return tokens.surface;
  }

  static Color get surfaceElevated {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    final tokens = isLight ? AppTokens.light : AppTokens.dark;
    return tokens.surfaceRaised;
  }

  static Color get surfaceRaised => surfaceElevated;

  static Color get surfaceSunken {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    final tokens = isLight ? AppTokens.light : AppTokens.dark;
    return tokens.surfaceSunken;
  }

  static Color get cardBackground => surfaceElevated;

  /// Neutral accent per MVP 5 design system (equals textPrimary).
  static Color get accent {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    final tokens = isLight ? AppTokens.light : AppTokens.dark;
    return tokens.accent;
  }

  /// Dynamic media accent (album art) exposed strictly for music features.
  static Color get mediaAccent {
    if (NowPlayingService.instance.currentDominantColor.value != null) {
      return NowPlayingService.instance.currentDominantColor.value!;
    }
    return accent;
  }

  static Color get textPrimary {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? AppTokens.light.textPrimary : AppTokens.dark.textPrimary;
  }

  static Color get textSecondary {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight
        ? AppTokens.light.textSecondary
        : AppTokens.dark.textSecondary;
  }

  static Color get textMuted {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? AppTokens.light.textMuted : AppTokens.dark.textMuted;
  }

  static Color get positive {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? AppTokens.light.positive : AppTokens.dark.positive;
  }

  static Color get negative {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? AppTokens.light.negative : AppTokens.dark.negative;
  }

  static Color get warning {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? AppTokens.light.warning : AppTokens.dark.warning;
  }

  static Color get divider {
    bool isLight =
        Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? AppTokens.light.divider : AppTokens.dark.divider;
  }

  static Color get accentColor => accent;
}

/// Re-implemented BentoContainer delegating directly to [DepthCard] (e2, borderless).
class BentoContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? customColor;
  final double? width;
  final double? height;

  const BentoContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.customColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      elevation: DepthElevation.e2,
      radius: borderRadius,
      padding: padding,
      margin: margin,
      color: customColor,
      width: width,
      height: height,
      child: child,
    );
  }
}

class BentoButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const BentoButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      elevation: DepthElevation.e1,
      radius: borderRadius,
      padding: padding,
      margin: margin,
      color: color,
      onTap: onTap,
      child: child,
    );
  }
}

class BentoToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const BentoToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: DepthCard(
        elevation: DepthElevation.e1,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        radius: 20,
        width: 50,
        height: 28,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? BentoTheme.accent : Colors.white30,
            ),
          ),
        ),
      ),
    );
  }
}
