import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/widgets/depth_card.dart';
import 'package:habit_tracker/services/now_playing_service.dart';

/// Legacy BentoTheme adapter that delegates directly to [AppTheme], [AppTokens], and [DepthCard].
///
/// Preserves existing callers while enforcing Native Black & White and selectable color schemes.
class BentoTheme {
  static bool get _isLight {
    if (!Hive.isBoxOpen('settings')) return false;
    return Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
  }

  static bool get isLight => _isLight;
  static bool get isDark => !_isLight;

  // Base Background Color (Pure native background without dynamic album art tint per AGENTS.md Task 2)
  static Color get background {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightBackground : p.darkBackground;
  }

  // Cards and surfaces
  static Color get surface {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightSurface : p.darkSurface;
  }

  static Color get surfaceElevated {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightSurfaceElevated : p.darkSurfaceElevated;
  }

  static Color get surfaceRaised => surfaceElevated;

  static Color get surfaceSunken {
    return _isLight ? const Color(0xFFECECF0) : const Color(0xFF000000);
  }

  static Color get cardBackground => surfaceElevated;

  /// Preset primary accent color
  static Color get accent {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightPrimary : p.darkPrimary;
  }

  /// Dynamic media accent (album art) exposed strictly for music features.
  static Color get mediaAccent {
    if (NowPlayingService.instance.currentDominantColor.value != null) {
      return NowPlayingService.instance.currentDominantColor.value!;
    }
    return accent;
  }

  static Color get textPrimary {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightTextPrimary : p.darkTextPrimary;
  }

  static Color get textSecondary {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightTextSecondary : p.darkTextSecondary;
  }

  static Color get textMuted {
    return _isLight ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
  }

  static Color get positive => const Color(0xFF10B981);
  static Color get negative => const Color(0xFFF43F5E);
  static Color get warning => const Color(0xFFF59E0B);

  static Color get divider {
    final p = AppTheme.currentPreset.palette;
    return _isLight ? p.lightBorder : p.darkBorder;
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
