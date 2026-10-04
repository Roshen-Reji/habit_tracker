import 'package:hive/hive.dart';

part 'account.g.dart';

@HiveType(typeId: 40)
class Account extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Kind: bank, cash, wallet, credit_card, loan, bnpl, investment, gold, property, vehicle, fd, crypto, other_asset, other_debt
  @HiveField(2)
  String kind;

  @HiveField(3)
  String? institution;

  @HiveField(4)
  double openingBalance;

  @HiveField(5)
  DateTime openingDate;

  @HiveField(6)
  int colorValue;

  @HiveField(7)
  bool archived;

  @HiveField(8)
  bool includeInNetWorth;

  @HiveField(9)
  bool spendable;

  @HiveField(10)
  double? creditLimit;

  @HiveField(11)
  int? statementDay;

  @HiveField(12)
  int? dueDay;

  @HiveField(13)
  double? principal;

  @HiveField(14)
  double? annualRate;

  @HiveField(15)
  double? emi;

  @HiveField(16)
  int? tenureMonths;

  @HiveField(17)
  DateTime? startDate;

  Account({
    required this.id,
    required this.name,
    required this.kind,
    this.institution,
    required this.openingBalance,
    required this.openingDate,
    required this.colorValue,
    this.archived = false,
    this.includeInNetWorth = true,
    this.spendable = true,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
    this.principal,
    this.annualRate,
    this.emi,
    this.tenureMonths,
    this.startDate,
  });

  bool get isLiability =>
      kind == 'credit_card' ||
      kind == 'loan' ||
      kind == 'bnpl' ||
      kind == 'other_debt';

  bool get isValuedAsset =>
      kind == 'investment' ||
      kind == 'gold' ||
      kind == 'property' ||
      kind == 'vehicle' ||
      kind == 'fd' ||
      kind == 'crypto' ||
      kind == 'other_asset';

  bool get isCreditCard => kind == 'credit_card';
  bool get isLoan => kind == 'loan';
}
