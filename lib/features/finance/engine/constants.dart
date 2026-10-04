/// Tunable constants and configuration for the Finance engine.
class FinanceConstants {
  static const double cardMinDuePct = 5.0;
  static const double utilizationAlertPct = 30.0;
  static const double trimCapPct = 20.0;
  static const int emergencyTargetMonths = 6;

  // Health score component weights (sum to 100)
  static const double healthWeightBudgeting = 25.0;
  static const double healthWeightSavings = 25.0;
  static const double healthWeightDebt = 20.0;
  static const double healthWeightEmergency = 20.0;
  static const double healthWeightConsistency = 10.0;

  // Default category IDs
  static const String catIncome = 'cat_income';
  static const String catSalary = 'cat_salary';
  static const String catFood = 'cat_food';
  static const String catShopping = 'cat_shopping';
  static const String catTransport = 'cat_transport';
  static const String catUtilities = 'cat_utilities';
  static const String catHealth = 'cat_health';
  static const String catEntertainment = 'cat_entertainment';
  static const String catOtt = 'cat_ott';
  static const String catGroceries = 'cat_groceries';
  static const String catEmi = 'cat_emi';
  static const String catOther = 'cat_other';
  static const String catRent = 'cat_rent';
  static const String catEducation = 'cat_education';
  static const String catTravel = 'cat_travel';
  static const String catSubscriptions = 'cat_subscriptions';
  static const String catInsurance = 'cat_insurance';
  static const String catGifts = 'cat_gifts';
  static const String catPersonalCare = 'cat_personal_care';
  static const String catInterestFees = 'cat_interest_fees';
  static const String catReimbursement = 'cat_reimbursement';

  // Main account ID for legacy / default transactions
  static const String defaultAccountId = 'acc_main';
  static const String migratedGoalsAccountId = 'acc_goals_migrated';
}
