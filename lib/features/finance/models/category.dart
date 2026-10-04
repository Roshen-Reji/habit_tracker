import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 41)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// kind: 'expense' or 'income'
  @HiveField(2)
  String kind;

  /// group: 'needs', 'wants', 'savings', 'none'
  @HiveField(3)
  String group;

  @HiveField(4)
  String iconKey;

  @HiveField(5)
  int colorValue;

  @HiveField(6)
  String? parentId;

  @HiveField(7)
  bool essential;

  @HiveField(8)
  bool archived;

  @HiveField(9)
  int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.group,
    required this.iconKey,
    required this.colorValue,
    this.parentId,
    this.essential = false,
    this.archived = false,
    this.sortOrder = 0,
  });

  bool get isExpense => kind == 'expense';
  bool get isIncome => kind == 'income';
}
