/// Pure Dart utilities for integer minor units (paise).
///
/// 1 Rupee = 100 Paise.
/// All monetary arithmetic in the core engine MUST use 64-bit integer minor units
/// to avoid floating-point inaccuracy and rounding errors.
class Minor {
  Minor._();

  /// Converts a floating-point rupee amount to integer paise (minor units).
  ///
  /// Uses round-half-away-from-zero: `(amount * 100).round()`.
  static int toMinor(double amount) {
    if (amount.isNaN || amount.isInfinite) return 0;
    return (amount * 100.0).round();
  }

  /// Converts an integer minor unit (paise) back to floating-point rupees.
  static double fromMinor(int minor) {
    return minor / 100.0;
  }

  /// Absolute value of minor units.
  static int abs(int minor) => minor.abs();

  /// Formats integer minor units into standard Indian currency representation.
  /// Example: 100050 -> "₹1,000.50" or "1,000.50" without symbol.
  static String format(
    int minor, {
    String symbol = '₹',
    bool showDecimals = true,
    bool compact = false,
  }) {
    final isNegative = minor < 0;
    final absPaise = minor.abs();
    final rupees = absPaise ~/ 100;
    final paise = absPaise % 100;

    if (compact) {
      final doubleRupees = absPaise / 100.0;
      final prefix = isNegative ? '-' : '';
      if (doubleRupees >= 10000000) {
        final cr = doubleRupees / 10000000.0;
        return '$prefix$symbol${_trimDecimals(cr)}Cr';
      } else if (doubleRupees >= 100000) {
        final l = doubleRupees / 100000.0;
        return '$prefix$symbol${_trimDecimals(l)}L';
      } else if (doubleRupees >= 1000) {
        final k = doubleRupees / 1000.0;
        return '$prefix$symbol${_trimDecimals(k)}k';
      }
    }

    final formattedRupees = _formatIndianGrouping(rupees);
    final prefix = isNegative ? '-' : '';
    if (!showDecimals || paise == 0) {
      return '$prefix$symbol$formattedRupees';
    }
    final paiseStr = paise.toString().padLeft(2, '0');
    return '$prefix$symbol$formattedRupees.$paiseStr';
  }

  static String _trimDecimals(double val) {
    final fixed = val.toStringAsFixed(1);
    if (fixed.endsWith('.0')) {
      return fixed.substring(0, fixed.length - 2);
    }
    return fixed;
  }

  /// Formats an integer using Indian numbering format (e.g. 12,34,567).
  static String _formatIndianGrouping(int number) {
    final s = number.toString();
    if (s.length <= 3) return s;

    final lastThree = s.substring(s.length - 3);
    var remaining = s.substring(0, s.length - 3);

    final parts = <String>[];
    while (remaining.length > 2) {
      parts.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      parts.insert(0, remaining);
    }

    return '${parts.join(',')},$lastThree';
  }
}
