/// Feature flags for Money OS (MVP 3).
/// Controls visibility of tabs and capabilities that land across release trains.
class MoneyFeature {
  /// Bottom nav tabs
  static bool isBudgetTabEnabled = true;
  static bool isGoalsTabEnabled = true;

  /// Sub-modules (More tab / Deep links)
  static bool isAccountsEnabled = true;
  static bool isNetWorthEnabled = true;
  static bool isRecurringEnabled = true; // Phase 6
  static bool isDebtEnabled = true; // Phase 7
  static bool isCashFlowEnabled = true; // Phase 8
  static bool isInsightsEnabled = true; // Phase 8
  static bool isReportsEnabled = true; // Phase 9
  static bool isImportEnabled = false; // Phase 10
  static bool isSplitSettleEnabled = false; // Phase 12
  static bool isPrivacyDataEnabled = true; // Phase 13 preview
}
