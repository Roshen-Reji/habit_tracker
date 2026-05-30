import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'finance_model.g.dart';

@HiveType(typeId: 10)
class Transaction extends HiveObject {
  @HiveField(0) String title;
  @HiveField(1) double amount;
  @HiveField(2) String category;
  @HiveField(3) DateTime date;
  @HiveField(4) String mode;
  @HiveField(5) String icon;

  Transaction({required this.title, required this.amount, required this.category, required this.date, required this.mode, required this.icon});
}

@HiveType(typeId: 11)
class AssetVault extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) double balance;
  @HiveField(2) String bank;
  @HiveField(3) String type;
  @HiveField(4) int colorValue;

  AssetVault({required this.name, required this.balance, required this.bank, required this.type, required this.colorValue});
}
