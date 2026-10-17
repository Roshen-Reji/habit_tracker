import 'minor.dart';

/// The internal kind of an entry according to the Money v2 product model.
enum EntryKind {
  spent,
  received,
  moved,
  adjustment,
}

/// Legacy representation tuple for persisting into existing Hive storage.
class LegacyStorageRepresentation {
  final double amount;
  final String mode;
  final String kind;

  const LegacyStorageRepresentation({
    required this.amount,
    required this.mode,
    required this.kind,
  });
}

/// Immutable Money v2 Entry.
///
/// Implements Law L3:
/// "Internally an entry is {kind, amountMinor (always positive), from, to}.
/// Sign and mode are derived for legacy storage in one function and are never read back by the ledger."
class Entry {
  final String id;
  final EntryKind kind;
  final int amountMinor; // Always strictly positive integer paise
  final String? fromAccountId;
  final String? toAccountId;
  final DateTime date;
  final String title;
  final String category;
  final String? categoryId;
  final String? notes;
  final String? sourceRef;
  final DateTime createdAt;
  final int? interestMinor; // Applicable for debt/EMI payments
  final String? icon;

  Entry({
    required this.id,
    required this.kind,
    required this.amountMinor,
    this.fromAccountId,
    this.toAccountId,
    required this.date,
    required this.title,
    required this.category,
    this.categoryId,
    this.notes,
    this.sourceRef,
    DateTime? createdAt,
    this.interestMinor,
    this.icon,
  })  : assert(amountMinor >= 0, 'amountMinor must be non-negative'),
        createdAt = createdAt ?? DateTime.now();

  /// Derives legacy storage values (signed amount, mode string, kind string)
  /// purely for backward compatibility when writing to legacy Hive boxes.
  /// The Money v2 ledger never reads these derived fields back.
  LegacyStorageRepresentation toLegacyStorage() {
    final doubleAmount = Minor.fromMinor(amountMinor);
    switch (kind) {
      case EntryKind.spent:
        return LegacyStorageRepresentation(
          amount: -doubleAmount,
          mode: 'Expense',
          kind: 'expense',
        );
      case EntryKind.received:
        return LegacyStorageRepresentation(
          amount: doubleAmount,
          mode: 'Income',
          kind: 'income',
        );
      case EntryKind.moved:
        return LegacyStorageRepresentation(
          amount: doubleAmount,
          mode: 'Transfer',
          kind: 'transfer',
        );
      case EntryKind.adjustment:
        return LegacyStorageRepresentation(
          amount: doubleAmount,
          mode: 'Adjustment',
          kind: 'adjustment',
        );
    }
  }

  /// Reconstitutes a Money v2 Entry from a stored record.
  /// Resolves ambiguous legacy fields deterministically into an Entry.
  static Entry fromRaw({
    required String id,
    required double rawAmount,
    required String rawMode,
    String? rawKind,
    String? accountId,
    String? toAccountId,
    required DateTime date,
    required String title,
    required String category,
    String? categoryId,
    String? notes,
    String? sourceRef,
    DateTime? createdAt,
    double? rawInterest,
    String? icon,
  }) {
    final absPaise = Minor.toMinor(rawAmount.abs());
    final effectiveKindStr = (rawKind != null && rawKind.isNotEmpty)
        ? rawKind.toLowerCase()
        : ((rawMode.toLowerCase() == 'expense' || rawAmount < 0)
            ? 'expense'
            : 'income');

    EntryKind kind;
    String? fromId = accountId;
    String? toId = toAccountId;

    switch (effectiveKindStr) {
      case 'expense':
        kind = EntryKind.spent;
        fromId = accountId;
        toId = null;
        break;
      case 'income':
      case 'refund':
      case 'reimbursement':
        kind = EntryKind.received;
        fromId = null;
        toId = accountId;
        break;
      case 'transfer':
      case 'investment':
      case 'sip':
      case 'emi':
      case 'debt_payment':
        kind = EntryKind.moved;
        fromId = accountId;
        toId = toAccountId;
        break;
      case 'adjustment':
        kind = EntryKind.adjustment;
        break;
      default:
        if (rawMode.toLowerCase() == 'expense' || rawAmount < 0) {
          kind = EntryKind.spent;
          fromId = accountId;
          toId = null;
        } else {
          kind = EntryKind.received;
          fromId = null;
          toId = accountId;
        }
    }

    return Entry(
      id: id,
      kind: kind,
      amountMinor: absPaise,
      fromAccountId: fromId,
      toAccountId: toId,
      date: date,
      title: title,
      category: category,
      categoryId: categoryId,
      notes: notes,
      sourceRef: sourceRef,
      createdAt: createdAt,
      interestMinor: rawInterest != null ? Minor.toMinor(rawInterest) : null,
      icon: icon,
    );
  }

  Entry copyWith({
    String? id,
    EntryKind? kind,
    int? amountMinor,
    String? fromAccountId,
    String? toAccountId,
    DateTime? date,
    String? title,
    String? category,
    String? categoryId,
    String? notes,
    String? sourceRef,
    DateTime? createdAt,
    int? interestMinor,
    String? icon,
  }) {
    return Entry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amountMinor: amountMinor ?? this.amountMinor,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      date: date ?? this.date,
      title: title ?? this.title,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      sourceRef: sourceRef ?? this.sourceRef,
      createdAt: createdAt ?? this.createdAt,
      interestMinor: interestMinor ?? this.interestMinor,
      icon: icon ?? this.icon,
    );
  }
}
