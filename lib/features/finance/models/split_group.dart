import 'package:hive/hive.dart';

part 'split_group.g.dart';

@HiveType(typeId: 49)
class SplitGroup extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// kind: 'trip', 'household', 'other'
  @HiveField(2)
  String kind;

  @HiveField(3)
  List<String> members;

  @HiveField(4)
  DateTime createdAt;

  SplitGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.members,
    required this.createdAt,
  });
}
