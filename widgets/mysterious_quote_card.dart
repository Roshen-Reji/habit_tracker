import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:habit_tracker/models/quote.dart';

class MysteriousQuoteCard extends StatefulWidget {
  const MysteriousQuoteCard({super.key});

  @override
  State<MysteriousQuoteCard> createState() => _MysteriousQuoteCardState();
}

class _MysteriousQuoteCardState extends State<MysteriousQuoteCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _tiltAnimation;
  late Quote _todaysQuote;

  // Mock Data
  final List<Quote> mysteryQuotes = [
    Quote("We are what we repeatedly do.", "Aristotle"),
    Quote("The cosmos is within us.", "Carl Sagan"),
    Quote("He who has a why to live can bear almost any how.", "Nietzsche"),
    Quote("Man is sometimes extraordinarily, passionately, in love with suffering...", "Fyodor Dostoevsky"),
    Quote("Taking a new step, uttering a new word, is what people fear most.", "Fyodor Dostoevsky"),
    Quote("If you want to overcome the whole world, overcome yourself.", "Fyodor Dostoevsky"),
    Quote("Life isn’t about finding yourself. Life is about creating yourself.", "George Bernard Shaw"),
    Quote("Doubt kills more dreams than failure ever will.", "Suzy Kassem")

  ];

  @override
  void initState() {
    super.initState();
    _todaysQuote = mysteryQuotes[math.Random().nextInt(mysteryQuotes.length)];

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFF2E004F).withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.purpleAccent.withOpacity(0.1), blurRadius: 15, spreadRadius: -5)
          ]
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, color: Colors.tealAccent.withOpacity(0.7), size: 30),
          const SizedBox(height: 16),
          Text(
            '"${_todaysQuote.text}"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Text(
            "-   ${_todaysQuote.author.toUpperCase()}   -",
            style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}