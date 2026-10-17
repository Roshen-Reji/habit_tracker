import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Helper mapping category icon keys and kinds to Lucide icons.
class MoneyCategoryIcon {
  MoneyCategoryIcon._();

  static IconData getIcon(String? iconKey, [String? kind]) {
    if (kind == 'income') return LucideIcons.arrowDownLeft;
    if (kind == 'transfer') return LucideIcons.arrowLeftRight;

    switch (iconKey?.toLowerCase()) {
      case 'utensils':
      case 'food':
      case 'dining':
        return LucideIcons.utensils;
      case 'shopping_basket':
      case 'groceries':
        return LucideIcons.shoppingBasket;
      case 'shopping_bag':
      case 'shopping':
        return LucideIcons.shoppingBag;
      case 'car':
      case 'transport':
      case 'travel':
        return LucideIcons.car;
      case 'zap':
      case 'bills':
      case 'utilities':
        return LucideIcons.zap;
      case 'activity':
      case 'health':
      case 'medical':
        return LucideIcons.activity;
      case 'home':
      case 'rent':
        return LucideIcons.home;
      case 'book':
      case 'education':
        return LucideIcons.book;
      case 'credit_card':
      case 'emi':
      case 'loan':
        return LucideIcons.creditCard;
      case 'tv':
      case 'entertainment':
      case 'subs':
      case 'subscriptions':
        return LucideIcons.tv;
      case 'gift':
        return LucideIcons.gift;
      case 'briefcase':
      case 'salary':
      case 'income':
        return LucideIcons.briefcase;
      case 'repeat':
      case 'sip':
      case 'investment':
        return LucideIcons.repeat;
      default:
        return LucideIcons.tag;
    }
  }
}
