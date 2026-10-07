import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:habit_tracker/models/quote.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/content/quotes.dart';

class MysteriousQuoteCard extends StatefulWidget {
  const MysteriousQuoteCard({super.key});

  @override
  State<MysteriousQuoteCard> createState() => _MysteriousQuoteCardState();
}

class _MysteriousQuoteCardState extends State<MysteriousQuoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _tiltAnimation;
  late Quote _todaysQuote;

  final List<Quote> mysteryQuotes = curatedQuotes;

  @override
  void initState() {
    super.initState();
    _todaysQuote = mysteryQuotes[math.Random().nextInt(mysteryQuotes.length)];

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _tiltAnimation = Tween<double>(begin: 0.1, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_tiltAnimation.value),
            child: _buildCardContent(),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: BentoContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 30),
            const SizedBox(height: 16),
            Text(
              '"${_todaysQuote.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              "-   ${_todaysQuote.author.toUpperCase()}   -",
              style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
