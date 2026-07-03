import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/services/music_manager.dart';
import 'app_colors.dart';

class NeuTheme {
  // Theme Mode
  static ThemeMode get currentMode {
    final modeStr = Hive.box('settings').get('theme_mode', defaultValue: 'dark');
    return modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
  }
  
  static bool get isDark => currentMode == ThemeMode.dark;

  // Base Background Color
  static Color get background {
    Color base = isDark ? const Color(0xFF222831) : const Color(0xFFF9F7F7);
    bool dynamicBg = Hive.box('settings').get('dynamic_background', defaultValue: true);
    
    if (dynamicBg && MusicManager().currentDominantColor.value != null) {
      return Color.alphaBlend(MusicManager().currentDominantColor.value!.withValues(alpha: 0.18), base);
    }
    return base;
  }

  static RadialGradient? get backgroundGradient {
    bool dynamicBg = Hive.box('settings').get('dynamic_background', defaultValue: true);
    if (dynamicBg && MusicManager().currentDominantColor.value != null) {
      return RadialGradient(
        center: Alignment.topRight,
        colors: [
          MusicManager().currentDominantColor.value!.withValues(alpha: 0.25),
          Colors.transparent
        ],
        radius: 1.5,
      );
    }
    return null;
  }
  
  static Color get surface {
    return isDark ? const Color(0xFF393E46) : const Color(0xFFDBE2EF);
  }

  // Accent Color (Music adaptive)
  static Color get accent {
    bool dynamicBg = Hive.box('settings').get('dynamic_background', defaultValue: true);
    if (dynamicBg && MusicManager().currentDominantColor.value != null) {
      return MusicManager().currentDominantColor.value!;
    }
    return isDark ? const Color(0xFF00ADB5) : const Color(0xFF3F72AF);
  }

  static Color get textPrimary => isDark ? const Color(0xFFEEEEEE) : const Color(0xFF112D4E);
  static Color get textSecondary => isDark ? const Color(0xFFEEEEEE).withValues(alpha: 0.7) : const Color(0xFF112D4E).withValues(alpha: 0.6);

  // Neumorphic Shadows (Apple-like matte finish)
  static List<BoxShadow> get shadows {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(4, 4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.05),
          offset: const Offset(-4, -4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFF3F72AF).withValues(alpha: 0.2),
          offset: const Offset(4, 4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        const BoxShadow(
          color: Colors.white,
          offset: Offset(-4, -4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    }
  }

  static List<BoxShadow> get innerShadows {
    // Note: True inner shadows in Flutter require custom painting or packages.
    // For a debossed look, we typically invert the gradient or use a darker base.
    // We'll simulate a debossed state by removing outer shadows and slightly darkening the background.
    return [];
  }
}

class NeuContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isPressed;
  final Color? customColor;
  final double? width;
  final double? height;

  const NeuContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.isPressed = false,
    this.customColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = customColor ?? NeuTheme.background;
    final displayColor = isPressed 
      ? (NeuTheme.isDark ? baseColor.withValues(alpha: 0.8) : baseColor.withValues(alpha: 0.95)) 
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
          boxShadow: isPressed ? [] : NeuTheme.shadows,
          border: isPressed 
              ? Border.all(color: NeuTheme.isDark ? Colors.black26 : Colors.black12, width: 1.5)
              : Border.all(color: Colors.white.withValues(alpha: NeuTheme.isDark ? 0.05 : 0.3), width: 1.0),
        ),
        child: child,
      ),
    );
  }
}

class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const NeuButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.color,
    this.margin,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
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
      child: NeuContainer(
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

class NeuToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const NeuToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { 
        onChanged(!value);
      },
      child: NeuContainer(
        isPressed: !value, // Press inwards when off
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 20,
        width: 50,
        height: 28,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: 1.0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? NeuTheme.accent : (NeuTheme.isDark ? Colors.white30 : Colors.black26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
