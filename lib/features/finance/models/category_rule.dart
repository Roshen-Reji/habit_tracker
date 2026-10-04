import 'package:hive/hive.dart';

part 'category_rule.g.dart';

@HiveType(typeId: 42)
class CategoryRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pattern;

  /// matchType: 'contains', 'exact', 'regex'
  @HiveField(2)
  String matchType;

  @HiveField(3)
  String categoryId;

  @HiveField(4)
  int priority;

  @HiveField(5)
  bool createdFromCorrection;

  CategoryRule({
    required this.id,
    required this.pattern,
    required this.matchType,
    required this.categoryId,
    this.priority = 0,
    this.createdFromCorrection = false,
  });

  bool matches(String text) {
    final query = text.toLowerCase();
    final p = pattern.toLowerCase();
    switch (matchType) {
      case 'exact':
        return query == p;
      case 'regex':
        try {
          return RegExp(pattern, caseSensitive: false).hasMatch(text);
        } catch (_) {
          return false;
        }
      case 'contains':
      default:
        return query.contains(p);
    }
  }
}
