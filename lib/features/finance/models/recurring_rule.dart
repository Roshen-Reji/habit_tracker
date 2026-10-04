import 'package:hive/hive.dart';

part 'recurring_rule.g.dart';

@HiveType(typeId: 43)
class RecurringRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// kind: 'bill', 'subscription', 'sip', 'emi', 'income', 'transfer', 'goal_contribution'
  @HiveField(2)
  String kind;

  @HiveField(3)
  double amount;

  @HiveField(4)
  bool amountIsVariable;

  @HiveField(5)
  String? categoryId;

  @HiveField(6)
  String? accountId;

  @HiveField(7)
  String? toAccountId;

  /// frequency: 'weekly', 'monthly', 'quarterly', 'yearly'
  @HiveField(8)
  String frequency;

  @HiveField(9)
  int interval;

  @HiveField(10)
  DateTime? anchorDate;

  @HiveField(11)
  int? dayOfMonth;

  @HiveField(12)
  DateTime startDate;

  @HiveField(13)
  DateTime? endDate;

  @HiveField(14)
  bool autoPost;

  @HiveField(15)
  int reminderDaysBefore;

  /// status: 'active', 'paused', 'ended'
  @HiveField(16)
  String status;

  @HiveField(17)
  String? folio;

  @HiveField(18)
  String? notes;

  @HiveField(19)
  DateTime createdAt;

  RecurringRule({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    this.amountIsVariable = false,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    required this.frequency,
    this.interval = 1,
    this.anchorDate,
    this.dayOfMonth,
    required this.startDate,
    this.endDate,
    this.autoPost = false,
    this.reminderDaysBefore = 2,
    this.status = 'active',
    this.folio,
    this.notes,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isEnded => status == 'ended';
  bool get isSip => kind == 'sip';
  bool get isSubscription => kind == 'subscription';
  bool get isBill => kind == 'bill';
  bool get isEmi => kind == 'emi';
}
