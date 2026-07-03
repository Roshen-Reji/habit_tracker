import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/services/music_manager.dart';

class BentoTheme {
  // Base Background Color
  static Color get background {
    bool isLight = Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    Color base = isLight ? const Color(0xFFF9F9F9) : const Color(0xFF000000);
    bool dynamicBg = Hive.box('settings').get('dynamic_background', defaultValue: true);
    
    if (dynamicBg && MusicManager().currentDominantColor.value != null) {
      return Color.alphaBlend(MusicManager().currentDominantColor.value!.withValues(alpha: 0.1), base);
    }
    return base;
  }

  // Cards and surfaces
  static Color get surface {
    bool isLight = Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    Color base = isLight ? const Color(0xFFFFFFFF) : const Color(0xFF141414);
    bool dynamicBg = Hive.box('settings').get('dynamic_background', defaultValue: true);
    
    if (dynamicBg && MusicManager().currentDominantColor.value != null) {
      return Color.alphaBlend(MusicManager().currentDominantColor.value!.withValues(alpha: 0.08), base);
    }
    return base;
  }

  // Accent Color - Dynamic or Strict Black/White default
  static Color get accent {
    bool dynamicBg = Hive.box('settings').get('dynamic_background', defaultValue: true);
    if (dynamicBg && MusicManager().currentDominantColor.value != null) {
      return MusicManager().currentDominantColor.value!;
    }
    bool isLight = Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  static Color get textPrimary {
    bool isLight = Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  static Color get textSecondary {
    bool isLight = Hive.box('settings').get('theme_mode', defaultValue: 'dark') == 'light';
    return isLight ? const Color(0xFF000000).withValues(alpha: 0.6) : const Color(0xFFFFFFFF).withValues(alpha: 0.6);
  }
}

// Replaces BentoContainer with a flat Bento-style container
class BentoContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isPressed;
  final Color? customColor;
  final double? width;
  final double? height;

  const BentoContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0, // Bento box soft rounded corners
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.isPressed = false,
    this.customColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = customColor ?? BentoTheme.surface;
    
    // For pressed state, just slightly darken or lighten (since we're flat)
    final displayColor = isPressed 
      ? baseColor.withValues(alpha: 0.8) 
      : baseColor;

    return AnimatedScale(
      scale: isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: displayColor,
          borderRadius: BorderRadius.circular(borderRadius),
          // Subtle border to differentiate cards against pure black
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.0),
        ),
        child: child,
      ),
    );
  }
}

class BentoButton extends StatefulWidget {
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
  State<BentoButton> createState() => _BentoButtonState();
}

class _BentoButtonState extends State<BentoButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: BentoContainer(
        isPressed: _isPressed,
        borderRadius: widget.borderRadius,
        padding: widget.padding,
        customColor: widget.color,
        margin: widget.margin,
        child: widget.child,
      ),
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
      child: BentoContainer(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 20,
        width: 50,
        height: 28,
        customColor: BentoTheme.surface, // Background of the track
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
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
