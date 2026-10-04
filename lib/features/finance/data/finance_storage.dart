import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Single source of truth for opening and accessing all finance Hive boxes and adapters.
class FinanceStorage {
  static final FinanceStorage _instance = FinanceStorage._internal();
  factory FinanceStorage() => _instance;
  FinanceStorage._internal();

  Box<Transaction>? _txBox;
  Box<AssetVault>? _vaultBox;
  Box? _settingsBox;
  Box<Account>? _accountBox;
  Box<Category>? _categoryBox;
  Box<CategoryRule>? _ruleBox;
  Box<RecurringRule>? _recurringBox;
  Box<BudgetLine>? _budgetLineBox;
  Box<BudgetOverride>? _budgetOverrideBox;
  Box<SavingsGoal>? _goalBox;
  Box<GoalEntry>? _goalEntryBox;
  Box<Valuation>? _valuationBox;
  Box<SplitGroup>? _splitGroupBox;
  Box<SplitEntry>? _splitEntryBox;

  /// Registers all finance adapters if not already registered.
  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(10))
      Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(11))
      Hive.registerAdapter(AssetVaultAdapter());
    if (!Hive.isAdapterRegistered(40)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(41)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(42))
      Hive.registerAdapter(CategoryRuleAdapter());
    if (!Hive.isAdapterRegistered(43))
      Hive.registerAdapter(RecurringRuleAdapter());
    if (!Hive.isAdapterRegistered(44))
      Hive.registerAdapter(BudgetLineAdapter());
    if (!Hive.isAdapterRegistered(45))
      Hive.registerAdapter(BudgetOverrideAdapter());
    if (!Hive.isAdapterRegistered(46))
      Hive.registerAdapter(SavingsGoalAdapter());
    if (!Hive.isAdapterRegistered(47)) Hive.registerAdapter(GoalEntryAdapter());
    if (!Hive.isAdapterRegistered(48)) Hive.registerAdapter(ValuationAdapter());
    if (!Hive.isAdapterRegistered(49))
      Hive.registerAdapter(SplitGroupAdapter());
    if (!Hive.isAdapterRegistered(50))
      Hive.registerAdapter(SplitEntryAdapter());
  }

  /// Opens all boxes required for the finance system.
  Future<void> init() async {
    registerAdapters();

    _txBox ??= await Hive.openBox<Transaction>('finance_transactions');
    _vaultBox ??= await Hive.openBox<AssetVault>('finance_vaults');
    _settingsBox ??= await Hive.openBox('finance_settings');
    _accountBox ??= await Hive.openBox<Account>('fin_accounts');
    _categoryBox ??= await Hive.openBox<Category>('fin_categories');
    _ruleBox ??= await Hive.openBox<CategoryRule>('fin_rules');
    _recurringBox ??= await Hive.openBox<RecurringRule>('fin_recurring');
    _budgetLineBox ??= await Hive.openBox<BudgetLine>('fin_budget_lines');
    _budgetOverrideBox ??=
        await Hive.openBox<BudgetOverride>('fin_budget_overrides');
    _goalBox ??= await Hive.openBox<SavingsGoal>('fin_goals');
    _goalEntryBox ??= await Hive.openBox<GoalEntry>('fin_goal_entries');
    _valuationBox ??= await Hive.openBox<Valuation>('fin_valuations');
    _splitGroupBox ??= await Hive.openBox<SplitGroup>('fin_split_groups');
    _splitEntryBox ??= await Hive.openBox<SplitEntry>('fin_split_entries');
  }

  /// Testing helper to inject pre-opened boxes.
  void injectForTesting({
    Box<Transaction>? txBox,
    Box<AssetVault>? vaultBox,
    Box? settingsBox,
    Box<Account>? accountBox,
    Box<Category>? categoryBox,
    Box<CategoryRule>? ruleBox,
    Box<RecurringRule>? recurringBox,
    Box<BudgetLine>? budgetLineBox,
    Box<BudgetOverride>? budgetOverrideBox,
    Box<SavingsGoal>? goalBox,
    Box<GoalEntry>? goalEntryBox,
    Box<Valuation>? valuationBox,
    Box<SplitGroup>? splitGroupBox,
    Box<SplitEntry>? splitEntryBox,
  }) {
    if (txBox != null) _txBox = txBox;
    if (vaultBox != null) _vaultBox = vaultBox;
    if (settingsBox != null) _settingsBox = settingsBox;
    if (accountBox != null) _accountBox = accountBox;
    if (categoryBox != null) _categoryBox = categoryBox;
    if (ruleBox != null) _ruleBox = ruleBox;
    if (recurringBox != null) _recurringBox = recurringBox;
    if (budgetLineBox != null) _budgetLineBox = budgetLineBox;
    if (budgetOverrideBox != null) _budgetOverrideBox = budgetOverrideBox;
    if (goalBox != null) _goalBox = goalBox;
    if (goalEntryBox != null) _goalEntryBox = goalEntryBox;
    if (valuationBox != null) _valuationBox = valuationBox;
    if (splitGroupBox != null) _splitGroupBox = splitGroupBox;
    if (splitEntryBox != null) _splitEntryBox = splitEntryBox;
  }

  Box<Transaction> get transactionBox =>
      _txBox ?? Hive.box<Transaction>('finance_transactions');

  Box<AssetVault> get vaultBox =>
      _vaultBox ?? Hive.box<AssetVault>('finance_vaults');

  Box get settingsBox => _settingsBox ?? Hive.box('finance_settings');

  Box<Account> get accountBox =>
      _accountBox ?? Hive.box<Account>('fin_accounts');

  Box<Category> get categoryBox =>
      _categoryBox ?? Hive.box<Category>('fin_categories');

  Box<CategoryRule> get ruleBox =>
      _ruleBox ?? Hive.box<CategoryRule>('fin_rules');

  Box<RecurringRule> get recurringBox =>
      _recurringBox ?? Hive.box<RecurringRule>('fin_recurring');

  Box<BudgetLine> get budgetLineBox =>
      _budgetLineBox ?? Hive.box<BudgetLine>('fin_budget_lines');

  Box<BudgetOverride> get budgetOverrideBox =>
      _budgetOverrideBox ?? Hive.box<BudgetOverride>('fin_budget_overrides');

  Box<SavingsGoal> get goalBox =>
      _goalBox ?? Hive.box<SavingsGoal>('fin_goals');

  Box<GoalEntry> get goalEntryBox =>
      _goalEntryBox ?? Hive.box<GoalEntry>('fin_goal_entries');

  Box<Valuation> get valuationBox =>
      _valuationBox ?? Hive.box<Valuation>('fin_valuations');

  Box<SplitGroup> get splitGroupBox =>
      _splitGroupBox ?? Hive.box<SplitGroup>('fin_split_groups');

  Box<SplitEntry> get splitEntryBox =>
      _splitEntryBox ?? Hive.box<SplitEntry>('fin_split_entries');

  Future<void> clearAll() async {
    await transactionBox.clear();
    await vaultBox.clear();
    await accountBox.clear();
    await categoryBox.clear();
    await ruleBox.clear();
    await recurringBox.clear();
    await budgetLineBox.clear();
    await budgetOverrideBox.clear();
    await goalBox.clear();
    await goalEntryBox.clear();
    await valuationBox.clear();
    await splitGroupBox.clear();
    await splitEntryBox.clear();
    await settingsBox.clear();
  }
}
