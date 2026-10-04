import 'package:hive/hive.dart';

part 'valuation.g.dart';

@HiveType(typeId: 48)
class Valuation extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String accountId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  double value;

  @HiveField(4)
  double? units;

  @HiveField(5)
  double? unitPrice;

  Valuation({
    required this.id,
    required this.accountId,
    required this.date,
    required this.value,
    this.units,
    this.unitPrice,
  });
}
