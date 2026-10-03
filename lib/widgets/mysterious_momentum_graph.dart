import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';

class MysteriousMomentumGraph extends StatelessWidget {
  const MysteriousMomentumGraph({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('xp_history').listenable(),
      builder: (context, Box box, _) {
        List<int> xpHistory = GlobalXPService.getPast7DaysXP();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: BentoContainer(
            borderRadius: 20,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "M O M E N T U M   S I G N A L",
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.grain,
                        color: BentoTheme.textSecondary, size: 16),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height:
                      150, // Increased fixed height for the dot matrix to fix overflow
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      return _buildDotMatrixColumn(
                          xpHistory[index], index == 6);
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    DateTime date =
                        DateTime.now().subtract(Duration(days: 6 - index));
                    String label = index == 6
                        ? "NOW"
                        : DateFormat('EE').format(date).toUpperCase();
                    return Text(
                      label,
                      style: TextStyle(
                        color: index == 6
                            ? BentoTheme.textPrimary
                            : BentoTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotMatrixColumn(int xp, bool isToday) {
    // Let's say 1 dot = 10 XP, max 10 dots (100 XP)
    int filledDots = (xp / 10).round().clamp(0, 10);
    int totalDots = 10;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(totalDots, (index) {
        // Build from bottom up
        int invertedIndex = totalDots - 1 - index;
        bool isFilled = invertedIndex < filledDots;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (isToday ? BentoTheme.textPrimary : BentoTheme.textSecondary)
                : BentoTheme.textPrimary.withValues(alpha: 0.1),
          ),
        );
      }),
    );
  }
}
