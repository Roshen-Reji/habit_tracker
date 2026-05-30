import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FormatUtils {
  static String getCurrencySymbol() {
    final settings = Hive.box('settings');
    return settings.get('currency_symbol', defaultValue: '\$');
  }

  static String formatCurrency(double amount) {
    final symbol = getCurrencySymbol();
    final format = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return format.format(amount);
  }

  static String formatCompactCurrency(double amount) {
    final symbol = getCurrencySymbol();
    final format = NumberFormat.compactCurrency(symbol: symbol, decimalDigits: 1);
    return format.format(amount);
  }
}
