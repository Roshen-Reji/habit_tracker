import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/models/quote.dart';

class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  static final List<Quote> _quotes = [
    Quote('We are what we repeatedly do.', 'Aristotle'),
    Quote('The cosmos is within us.', 'Carl Sagan'),
    Quote('He who has a why to live can bear almost any how.', 'Nietzsche'),
    Quote(
      'Man is sometimes extraordinarily, passionately, in love with suffering...',
      'Fyodor Dostoevsky',
    ),
    Quote(
      'Taking a new step, uttering a new word, is what people fear most.',
      'Fyodor Dostoevsky',
    ),
    Quote(
      'If you want to overcome the whole world, overcome yourself.',
      'Fyodor Dostoevsky',
    ),
    Quote(
      'Life isn’t about finding yourself. Life is about creating yourself.',
      'George Bernard Shaw',
    ),
    Quote('Doubt kills more dreams than failure ever will.', 'Suzy Kassem'),
  ];

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
              fontSize: 15,
              height: 1.4,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— ${quote.author}',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
