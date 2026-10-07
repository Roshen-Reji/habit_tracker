import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/models/quote.dart';

import 'package:habit_tracker/core/content/quotes.dart';

class QuoteCard extends StatefulWidget {
  final HomeCardSize size;

  const QuoteCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  static const List<Quote> _quotes = curatedQuotes;

  late int _quoteIndex;

  @override
  void initState() {
    super.initState();
    _quoteIndex = math.Random().nextInt(_quotes.length);
  }

  void _nextQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _quotes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quotes[_quoteIndex];

    return HomeCardFrame(
      icon: LucideIcons.quote,
      title: 'Daily Wisdom',
      onTap: _nextQuote,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BentoTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.refreshCw,
              size: 11,
              color: BentoTheme.accent,
            ),
            const SizedBox(width: 4),
            Text(
              'Tap for next',
              style: TextStyle(
                color: BentoTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.text}"',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: widget.size == HomeCardSize.hero
                  ? 19
                  : (widget.size == HomeCardSize.large ? 17 : 15),
              height: widget.size == HomeCardSize.hero
                  ? 1.6
                  : (widget.size == HomeCardSize.large ? 1.5 : 1.4),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(
            height: widget.size == HomeCardSize.hero
                ? 18
                : (widget.size == HomeCardSize.large ? 14 : 8),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— ${quote.author}',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: widget.size == HomeCardSize.hero
                    ? 14
                    : (widget.size == HomeCardSize.large ? 13 : 12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.size == HomeCardSize.hero) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: BentoTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.sparkles,
                      size: 14, color: BentoTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily Reflection · How does this apply to your progress today?',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
