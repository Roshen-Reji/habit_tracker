import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';

class FormatUtils {
  static String getCurrencySymbol() {
    if (!Hive.isBoxOpen('settings')) return '₹';
    final settings = Hive.box('settings');
    return settings.get('currency_symbol', defaultValue: '₹');
  }

  static String formatCurrency(double amount) {
    return formatMoney(amount, decimals: 2);
  }

  static String formatCompactCurrency(double amount) {
    return formatMoney(amount, compact: true);
  }

  /// Formats money with Indian number grouping (en_IN) and optional compact Lakh/Crore formatting.
  static String formatMoney(
    double amount, {
    bool compact = false,
    int? decimals,
    String? customSymbol,
  }) {
    final symbol = customSymbol ?? getCurrencySymbol();
    final isNegative = amount < 0;
    final absAmount = Money.r2(amount.abs());

    if (compact) {
      final String formatted;
      if (absAmount >= 10000000) {
        final cr = absAmount / 10000000;
        formatted = '${_stripTrailingZero(cr.toStringAsFixed(1))}Cr';
      } else if (absAmount >= 100000) {
        final l = absAmount / 100000;
        formatted = '${_stripTrailingZero(l.toStringAsFixed(1))}L';
      } else if (absAmount >= 1000) {
        final k = absAmount / 1000;
        formatted = '${_stripTrailingZero(k.toStringAsFixed(1))}K';
      } else {
        formatted = absAmount.toStringAsFixed(decimals ?? 0);
      }
      return '${isNegative ? '-' : ''}$symbol$formatted';
    }

    final dec = decimals ?? 2;
    try {
      final formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: symbol,
        decimalDigits: dec,
      );
      return formatter.format(isNegative ? -absAmount : absAmount);
    } catch (_) {
      // Fallback manual Indian grouping
      final parts = absAmount.toStringAsFixed(dec).split('.');
      final intPart = _formatIndianInt(parts[0]);
      final decimalPart = dec > 0 && parts.length > 1 ? '.${parts[1]}' : '';
      return '${isNegative ? '-' : ''}$symbol$intPart$decimalPart';
    }
  }

  static String _stripTrailingZero(String numStr) {
    if (numStr.endsWith('.0')) {
      return numStr.substring(0, numStr.length - 2);
    }
    return numStr;
  }

  static String _formatIndianInt(String digits) {
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(rest[i]);
    }
    buffer.write(',');
    buffer.write(lastThree);
    return buffer.toString();
  }
}
