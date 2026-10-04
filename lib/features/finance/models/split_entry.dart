import 'package:hive/hive.dart';

part 'split_entry.g.dart';

@HiveType(typeId: 50)
class SplitEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String groupId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String title;

  @HiveField(4)
  double amount;

  @HiveField(5)
  String paidBy;

  /// Map of participant name -> their share of amount
  @HiveField(6)
  Map<String, double> shares;

  @HiveField(7)
  String? txId;

  @HiveField(8)
  bool settled;

  SplitEntry({
    required this.id,
    required this.groupId,
    required this.date,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.shares,
    this.txId,
    this.settled = false,
  });
}
