/// Pure monetary calculation and rounding utilities.
class Money {
  /// Rounds half away from zero to 2 decimal places.
  static double r2(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    final sign = value < 0 ? -1.0 : 1.0;
    final rounded = (value.abs() * 100.0).roundToDouble() / 100.0;
    return sign * rounded;
  }

  /// Safe double parsing from dynamic values.
  static double asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
