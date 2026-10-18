import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/content/quotes.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/models/quote.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    HapticFeedback.lightImpact();
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _quotes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quotes[_quoteIndex];
    const accent = TactileTokens.warmIvory;

    return HomeCardFrame(
      icon: LucideIcons.quote,
      title: 'Daily Wisdom',
      subtitle: 'Philosophical Telemetry',
      domain: HomeCardDomain.editorial,
      accentColor: accent,
      onTap: _nextQuote,
      trailing: GestureDetector(
        onTap: _nextQuote,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.refreshCw,
                size: 11,
                color: TactileTokens.warmIvory.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Text(
                'CYCLE',
                style: TextStyle(
                  color: TactileTokens.warmIvory.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“${quote.text}”',
                  style: TextStyle(
                    color: TactileTokens.warmIvory,
                    fontSize: widget.size == HomeCardSize.hero
                        ? 18
                        : (widget.size == HomeCardSize.large ? 15.5 : 14),
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '— ${quote.author}',
                    style: TextStyle(
                      color: TactileTokens.warmIvory.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.size == HomeCardSize.hero) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.sparkles,
                      size: 13, color: TactileTokens.warmIvory.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily Reflection · How does this insight apply to your disciplines today?',
                      style: TextStyle(
                        color: TactileTokens.warmIvory.withValues(alpha: 0.75),
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
