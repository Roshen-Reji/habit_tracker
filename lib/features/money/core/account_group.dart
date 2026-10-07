import 'minor.dart';

/// The four product model account groups visible to the user.
enum AccountGroup {
  main,
  funds,
  loans,
  cards,
}

/// Helper to classify accounts into one of the four groups.
class AccountClassifier {
  AccountClassifier._();

  /// Maps a stored legacy kind string and main account ID into an [AccountGroup].
  static AccountGroup classify({
    required String accountId,
    required String mainAccountId,
    required String rawKind,
  }) {
    if (accountId == mainAccountId) {
      return AccountGroup.main;
    }

    final k = rawKind.toLowerCase().trim();
    if (k == 'investment' ||
        k == 'mutual_fund' ||
        k == 'stocks' ||
        k == 'gold' ||
        k == 'crypto' ||
        k == 'property' ||
        k == 'fund' ||
        k == 'sip') {
      return AccountGroup.funds;
    }

    if (k == 'loan' ||
        k == 'mortgage' ||
        k == 'emi' ||
        k == 'debt' ||
        k == 'liability') {
      return AccountGroup.loans;
    }

    if (k == 'credit' || k == 'credit_card' || k == 'card') {
      return AccountGroup.cards;
    }

    // Default liquid accounts fall back to Main or secondary liquid
    return AccountGroup.main;
  }
}

/// Pure Dart representation of an account used within the Money core engine.
class CoreAccount {
  final String id;
  final String name;
  final AccountGroup group;
  final String rawKind;
  final int openingBalanceMinor;
  final DateTime openingDate;
  final double? annualRatePct;
  final int? emiMinor;
  final int? tenureMonths;
  final int colorValue;
  final bool archived;

  const CoreAccount({
    required this.id,
    required this.name,
    required this.group,
    required this.rawKind,
    required this.openingBalanceMinor,
    required this.openingDate,
    this.annualRatePct,
    this.emiMinor,
    this.tenureMonths,
    this.colorValue = 0xFF1E88E5,
    this.archived = false,
  });

  bool get isMain => group == AccountGroup.main;
  bool get isFund => group == AccountGroup.funds;
  bool get isLoan => group == AccountGroup.loans;
  bool get isCard => group == AccountGroup.cards;

  /// Whether this account tracks asset valuations (Fund)
  bool get isValuedAsset => group == AccountGroup.funds;

  /// Factory from raw storage parameters
  factory CoreAccount.fromRaw({
    required String id,
    required String name,
    required String rawKind,
    required double openingBalance,
    required DateTime openingDate,
    required String mainAccountId,
    double? annualRate,
    double? emi,
    int? tenureMonths,
    int? colorValue,
    bool? archived,
  }) {
    final group = AccountClassifier.classify(
      accountId: id,
      mainAccountId: mainAccountId,
      rawKind: rawKind,
    );

    return CoreAccount(
      id: id,
      name: name,
      group: group,
      rawKind: rawKind,
      openingBalanceMinor: Minor.toMinor(openingBalance),
      openingDate: openingDate,
      annualRatePct: annualRate,
      emiMinor: emi != null ? Minor.toMinor(emi) : null,
      tenureMonths: tenureMonths,
      colorValue: colorValue ?? 0xFF1E88E5,
      archived: archived ?? false,
    );
  }
}
