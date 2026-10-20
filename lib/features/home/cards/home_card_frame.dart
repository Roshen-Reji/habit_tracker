import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';

/// The 6 domain visual personalities defined in AGENTS.md Phase 3.
enum HomeCardDomain {
  telemetry,  // Executive Telemetry Module (Rank badge, tabular score, sparkline)
  ledger,     // Banknote / Ledger Grid Motif (Dot-grid/micro-ruled, safe-to-spend gauge)
  biometrics, // Biometric Instrument Cluster (Dot-matrix accents, concentric ring meter)
  tactical,   // Tactical Checklist (Satisfying strikethrough sweep, snap checkbox)
  audio,      // Hardware Audio Deck (Equalizer bars, vinyl disk, transport controls)
  editorial,  // Editorial Warmth (Paper-grain, bookmark ribbon, blister-pack pills)
}

/// Bespoke frame that gives distinct character to each domain card in the home stack.
class HomeCardFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? accentColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isFocused;
  final HomeCardDomain domain;
  final String? subtitle;
  final Widget? statusBadge;
  final bool isAlabaster;

  const HomeCardFrame({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.accentColor,
    this.contentPadding = const EdgeInsets.all(18.0),
    this.isFocused = true,
    this.domain = HomeCardDomain.telemetry,
    this.subtitle,
    this.statusBadge,
    this.isAlabaster = false,
  });

  Color _resolveDomainColor() {
    if (accentColor != null) return accentColor!;
    switch (domain) {
      case HomeCardDomain.telemetry:
        return TactileTokens.vermilion;
      case HomeCardDomain.ledger:
        return TactileTokens.financePositive;
      case HomeCardDomain.biometrics:
        return TactileTokens.telemetryCyan;
      case HomeCardDomain.tactical:
        return TactileTokens.acidLime;
      case HomeCardDomain.audio:
        return BentoTheme.mediaAccent;
      case HomeCardDomain.editorial:
        return TactileTokens.warmIvory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainColor = AppColors.resolveAccent(context, _resolveDomainColor());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(28.0);

    final BoxDecoration decoration;
    final Color textPrimary;
    final Color textMuted;

    if (isAlabaster) {
      decoration = BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
      textPrimary = const Color(0xFF111417);
      textMuted = const Color(0xFF64748B);
    } else if (isDark) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262A30), Color(0xFF1C1F24)],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withOpacity(0.09),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );
      textPrimary = const Color(0xFFF3F6F9);
      textMuted = const Color(0xFF8B949E);
    } else {
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
      textPrimary = const Color(0xFF111417);
      textMuted = const Color(0xFF64748B);
    }

    Widget content = Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Domain Background Motif
          if (!isAlabaster) ...[
            if (domain == HomeCardDomain.ledger)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LedgerGridPainter(
                        gridColor: domainColor.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                ),
              )
            else if (domain == HomeCardDomain.biometrics)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BiometricPulsePainter(
                        accentColor: domainColor.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                ),
              )
            else if (domain == HomeCardDomain.tactical)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _TacticalGridPainter(
                        accentColor: domainColor.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                ),
              )
            else if (domain == HomeCardDomain.editorial)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _EditorialPaperPainter(
                        lineColor: domainColor.withValues(alpha: 0.025),
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // Main Card Content
          Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Domain-Specific Header Strip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Domain Indicator Pip or Icon
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: domainColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: domainColor.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 14,
                        color: domainColor,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title with Tight Grotesk Tracking (-0.5)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (statusBadge != null) ...[
                      statusBadge!,
                      const SizedBox(width: 8),
                    ],

                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null || onLongPress != null) {
      content = PressScale.card(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: content,
      );
    }

    return RepaintBoundary(child: content);
  }
}

/// Banknote / Ledger fine dot-grid motif painter for finance cards
class _LedgerGridPainter extends CustomPainter {
  final Color gridColor;

  const _LedgerGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const spacing = 16.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedgerGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

/// Biometric subtle telemetry line motif
class _BiometricPulsePainter extends CustomPainter {
  final Color accentColor;

  const _BiometricPulsePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const step = 20.0;
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BiometricPulsePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

/// Tactical cross-hatch micro-ruled motif
class _TacticalGridPainter extends CustomPainter {
  final Color accentColor;

  const _TacticalGridPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const step = 24.0;
    // Angled 45-deg tactical telemetry corner lines
    for (double i = 0; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - 40, 40),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalGridPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

/// Editorial notebook subtle ruled lines
class _EditorialPaperPainter extends CustomPainter {
  final Color lineColor;

  const _EditorialPaperPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const step = 26.0;
    for (double y = 48.0; y < size.height; y += step) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EditorialPaperPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

