# Habit Tracker MVP 3: Finance ("Money OS") Spec for a Coding Agent

Written for Claude Opus working autonomously in the repo root (`Roshen-Reji/habit_tracker`). Code facts were read from `master` at commit `d2a5d15` (MVP 1). MVP 2 will have shifted some line numbers, so re-read a file before you edit it.

Markers:
- **VERIFY:** something I could not confirm. Check it in the code or the package docs before relying on it.
- **Default:** a planner decision the owner has not confirmed. Proceed with it and list it in your phase report.

---

## 1. Mission

Turn the finance section from "log income, log expense, see a pie chart" into a personal financial operating system that answers: *where is my money going, what can I safely spend, what do I need to pay, what am I saving toward, and am I getting healthier financially?*

The owner wants all 27 functions in §4. The order in §7 is deliberate. The research behind this list gives the same advice: **build the accounting model correctly first, then put intelligence on top.** A beautiful dashboard on a broken ledger is a pretty lie. Phases 1 to 3 are therefore not negotiable shortcuts.

Success means every task meets its **Done when** line, `flutter analyze` and `flutter test` pass with no new warnings, and a user upgrading from MVP 1 or MVP 2 keeps every transaction, vault, budget, goal and SIP, with an identical total balance immediately after migration.

---

## 2. Prerequisites and working agreement

**Prerequisites (from MVP 2, see `HABIT_TRACKER_MVP2_SPEC.md`)**: P0-2 `GeminiClient`, P0-3 SIP posting, P1-2 `AppNav`, P1-3 home card registry, and the M3E theme decision. If any is missing, stop and ask. MVP 3 generalises MVP 2's `SipService` and reuses `AppNav`, the card registry, `GeminiClient`, `local_auth` and the secure-key helper.

**Process**
- Integration branch `mvp3/integration`; one branch per phase (`mvp3/p1-core`, ...); one commit per task (`P4-3: rollover budgets`). Merge to `master` only at the release trains in §4. Keep the app compiling at every commit.
- Run `dart format .`, `flutter analyze`, `flutter test` after each task. Run `dart run build_runner build --delete-conflicting-outputs` after any `@HiveType` change.
- You probably have no device. Never claim that notifications, permissions, camera, OCR, biometrics or SMS work unless you ran them. List them under "Not verified" in your report and append them to `MANUAL_QA.md`.
- For third-party packages, run `flutter pub get` and read the package README and API in the pub cache before writing code. Do not write package calls from memory. Every new dependency is **VERIFY** for maintenance and Flutter-version compatibility; list additions in your report.

**Data safety**
- Never change an existing `typeId`, `@HiveField` index or box name. New fields on existing models use new indexes with `defaultValue`s (Hive returns null for missing fields; non-nullable fields need a `defaultValue`).
- MVP 2 uses typeIds 30-35. MVP 3 uses **40-59**.
- Never delete or overwrite user data automatically. Migrations are versioned, idempotent per step, preceded by an automatic backup (P1-0), and abort on error leaving v1 data intact.
- Legacy settings keys (`budgets`, `goals`, `planner`, `sip_ledger`) are left in place after migration and marked as migrated. Only the owner may authorise deleting them.

**Stop and ask before**: upgrading the Flutter SDK; adding permissions with Play Store implications beyond those named in §6; deleting user data; implementing anything listed in §8.

**Effort**: reason carefully on the ledger invariants, migrations, forecasting maths and encryption. Move quickly on UI boilerplate.

**Report after each phase** (short): what changed, how you verified it (commands and results), what you could not verify, defaults you applied, questions.

---

## 3. Repo facts (finance, read from `master`)

**UI**: `lib/features/finance/finance_page.dart` is one 2,955-line file. `FinanceDashboard` has five tabs (`overview`, `transactions`, `budget`, `planner`, `goals`), is reached from `TasksPage` via a `_currentView` string, and is where all finance UI, modals and charts live (`_CashFlowChart`, `_NetTrendChart`, `_CategoryDonutChart`, `_BudgetTile`, `_GoalTile`, ...). Finance reads boxes directly with `ValueListenableBuilder`s and recomputes the whole `FinanceSnapshot` on every build (`_buildSnapshot`, ~L283-352).

**Models** (`lib/models/finance_model.dart`): `Transaction` (typeId 10: `title, amount, category, date, mode, icon`) and `AssetVault` (typeId 11: `name, balance, bank, type, colorValue`). No ids, accounts, notes, tags, merchant, or links between them. `Goal` (typeId 1) is the *habit-mission* goal, not a finance goal; name finance goals `SavingsGoal` to avoid the clash.

**Settings shapes** (untyped maps in `Hive.box('finance_settings')`): `budgets: [{category, total, color}]`; `goals: [{name, target, saved, deadline(String), color}]`; `planner: {fixedExpenses: [{name, amount, due, category}], sips: [{name, amount, due, folio}]}`. MVP 2 adds `id`/`createdAt` to SIPs and `sip_ledger`.

**Sign and type conventions**: expenses are stored with a **negative** amount and `mode == 'expense'`; income is positive with `mode == 'income'`. `_isExpense(tx)` = `mode == 'expense' || amount < 0`. Aggregations use `abs()`. This settles MVP 2's P0-3 **VERIFY**: SIP debits are negative amounts with `mode: 'expense'`, `icon: 'expense'`.

**Balance maths**: `totalBalance = Σ vault.balance + Σ(all transactions, signed) + Σ goal['saved']`. Vault balances are static numbers; transactions are not linked to vaults; goal savings are additive to the total.

**Defects found (each is fixed by a named task)**
1. The transaction form's "Mode" field (payment method, e.g. UPI) is never saved; `mode` is overwritten with `type` (P2-2).
2. New transactions are always dated `DateTime.now()`; edits cannot change the date (P2-2).
3. `_AddVaultModal` saves `bank: type` (bank name is lost) (P3-1).
4. Transactions are listed per month with only an All/Income/Expense filter; no search (P2-5).
5. Money is formatted with 2 decimals, a `$` fallback symbol and western digit grouping (`FormatUtils`, reads `settings['currency_symbol']`) (P1-4).
6. Finance writes are scattered. `ai_service.dart` writes transactions in at least five places (~L425, ~L460, ~L1076, `_recordFinanceTransaction` ~L1156, `executeFinanceAction` ~L2388), and `_buildFinanceSummaryResponse` (~L1115) re-implements `_buildSnapshot`. Existing AI actions: `finance_transaction`, `finance_budget`, `finance_commitment`, `finance_sip`, `finance_goal`, applied after user confirmation (P1-6).
7. The AI references vaults of `type == 'SIP'`, but the vault type list is Savings, Current, UPI Wallet, Investment, Cash (P1-3 maps these).
8. No `uuid`, `csv`, `share_plus`, OCR, SMS, or `local_auth` dependency (MVP 2 adds `local_auth`/secure storage). Available: `fl_chart`, `intl`, `http`, `image_picker`, `file_picker`, `path_provider`, `permission_handler`, `flutter_local_notifications`. `NotificationService` only has `scheduleTaskReminder(Goal)` and `cancelReminder`.
9. Existing XP hooks: new vault +15, goal contribution +20. Keep them (call `GlobalXPService.addXP` from the same events).

---

## 4. Feature coverage and release trains

Every function from the owner's list maps to tasks below.

| # | Function | Tasks |
|---|---|---|
| 1 | Home dashboard (cockpit) | P8-7, P9-3 |
| 2 | Transaction system (types, splits, transfers) | P1-2, P2-2..P2-6 |
| 3 | Automatic transaction tracking | P10 (import, rules, AI categorisation; SMS optional; Account Aggregator gated, §8) |
| 4 | Budgeting: Simple, 50/30/20, Zero-based | P4-2 |
| 5 | Budget intelligence | P4-4 |
| 6 | Rollover budgets | P4-3 |
| 7 | Goals with planner | P5-1, P5-2 |
| 8 | Sinking funds | P5-3 |
| 9 | Bills and subscriptions | P6-1, P6-2, P6-3 |
| 10 | Subscription intelligence | P6-4 |
| 11 | Net worth | P3-2, P3-3 |
| 12 | Debt manager | P7-1 |
| 13 | Credit card management | P7-2 |
| 14 | Cash flow | P8-1 |
| 15 | Financial forecast | P8-2 |
| 16 | Safe to spend | P8-3 |
| 17 | Financial health score | P8-4 |
| 18 | AI financial insights | P8-5 |
| 19 | Natural-language finance | P11 |
| 20 | Search everything | P2-5, P11-1 |
| 21 | Reports | P9-1, P9-2 |
| 22 | Financial calendar | P6-5 |
| 23 | Receipts | P10-4 |
| 24 | Multiple accounts | P1-2, P3-1 |
| 25 | Family / shared finance | P12 (local split-and-settle; sync is §8) |
| 26 | Privacy mode | P13 |
| 27 | Feature hierarchy | this table + trains below |
| + | "What if?" | P8-6, P11-3 |
| + | "Money OS" navigation | P2-1 |

**Release trains** (merge to `master` and cut a build at each):
- **3.0 Foundation** (Tier S): Phases 1-6.
- **3.1 Intelligence** (Tier A): Phases 7-9.
- **3.2 Automation and AI** (Tier A/B): Phases 10-11.
- **3.3 Social and security**: Phases 12-13. Backup/export (P1-0) ships in 3.0 as the migration safety net.

---

## 5. Architecture

### 5.1 Layers
```
lib/features/finance/
  data/      FinanceStorage, FinanceRepository, FinanceController, migrations/, backup/
  models/    Account, Category, ... (Hive models; Transaction stays in lib/models/)
  engine/    pure Dart, no Flutter or Hive imports: balances, budgets, goals, recurring,
             forecast, safe_to_spend, health_score, insights, query, loan, subscriptions
  ui/        shell/, home/, transactions/, budget/, goals/, accounts/, bills/, reports/, widgets/
```
- **The repository is the only code that touches finance boxes.** UI, AI service, MVP 2 SIP code and notifications call it. `FinanceStorage` opens boxes by name (one place to change for encryption in P13-3).
- **Engines are pure functions over immutable inputs** (lists of models plus a `today` parameter) so they are unit-testable with fixtures and share one definition between UI and AI.
- **Numbers are computed by code. The LLM never calculates.** It translates language into structured queries/actions and may phrase results.
- `FinanceController` (a `ChangeNotifier`, or match the app's existing state approach, **VERIFY**) exposes memoised per-month indexes (`Map<'yyyy-MM', List<Transaction>>`), rebuilt incrementally on box change. Never recompute everything per frame like `_buildSnapshot` does today.
- Money: values stay `double` in storage for compatibility; every aggregate rounds to 2 dp via `Money.r2` (round half away from zero) so sums of 0.1 do not drift.

### 5.2 Transaction kinds and ledger rules

`Transaction.kind` (new). Legacy rows have `kind == null`; `effectiveKind` = `expense` or `income` from `mode`/sign. New kinds store `amount` as a positive magnitude; legacy expense/income keep the existing sign convention.

| kind | accountId | toAccountId | Effect on account(s) | Counts as income | Counts as spending |
|---|---|---|---|---|---|
| `expense` | payer | n/a | -amount (card: liability grows) | no | yes, by category |
| `income` | receiver | n/a | +amount | yes | no |
| `transfer` | from | to | -amount / +amount | no | no |
| `refund` | account refunded | n/a | +amount | no | negative spending in its category |
| `investment` | from | to (investment account) | -amount / +amount (asset) | no | no (shown as "Invested") |
| `debt_payment` | from | loan or card | -total / +principal part | no | interest part only (category "Interest & fees") |
| `adjustment` | account | n/a | ±amount | no | no (balance reconciliation) |
| `reimbursement` | receiver | n/a | +amount | no | no (settles an owed split line) |

Invariants (each needs tests):
- **I1** A transfer, investment, or the principal part of a debt payment never changes net worth. Expense, income, refund, interest and adjustment do, by exactly their amount.
- **I2** Net worth = Σ balances of accounts with `includeInNetWorth`, liabilities negative, plus unsettled receivables minus unsettled payables.
- **I3** Spending totals exclude transfer, investment, debt principal, adjustment, reimbursement and owed split lines; refunds subtract.
- **I4** Credit card purchases are expenses on the card account; paying the card is a transfer. Card spending is never income.
- **I5** Migration preserves the pre-migration total balance exactly.
- **I6** Every write goes through the repository, which validates (transfer needs two different accounts; split parts sum to the amount; refund/transfer amount > 0).

Accounts: `balance(account, asOf) = openingBalance + Σ effects of that account's transactions dated ≤ asOf` (and ≥ `openingDate`). Valued accounts (investment, gold, property, vehicle, FD, crypto, other asset) use the latest valuation ≤ `asOf`, falling back to cumulative invested amount until the first valuation.

### 5.3 Models, typeIds and boxes

| typeId | Class | Box | Key fields |
|---|---|---|---|
| 10 (existing) | `Transaction` | `finance_transactions` | existing 0-5 plus the additions below |
| 11 (existing) | `AssetVault` | `finance_vaults` | read-only after migration (source for accounts) |
| 40 | `Account` | `fin_accounts` | id, name, kind (`bank, cash, wallet, credit_card, loan, bnpl, investment, gold, property, vehicle, fd, crypto, other_asset, other_debt`), institution, openingBalance, openingDate, colorValue, archived, includeInNetWorth, spendable, creditLimit?, statementDay?, dueDay?, loan terms (principal?, annualRate?, emi?, tenureMonths?, startDate?) |
| 41 | `Category` | `fin_categories` | id, name, kind (expense/income), group (`needs, wants, savings, none`), iconKey, colorValue, parentId?, essential, archived, sortOrder |
| 42 | `CategoryRule` | `fin_rules` | id, pattern, matchType (`contains, exact, regex`), categoryId, priority, createdFromCorrection |
| 43 | `RecurringRule` | `fin_recurring` | id, name, kind (`bill, subscription, sip, emi, income, transfer, goal_contribution`), amount, amountIsVariable, categoryId?, accountId?, toAccountId?, frequency (`weekly, monthly, quarterly, yearly`), interval, anchorDate/dayOfMonth, startDate, endDate?, autoPost, reminderDaysBefore, status (`active, paused, ended`), folio?, notes, createdAt |
| 44 | `BudgetLine` | `fin_budget_lines` | id, categoryId?, bucketRef? (goalId for zero-based buckets), amount, rollover, essential, startMonth |
| 45 | `BudgetOverride` | `fin_budget_overrides` | lineId, monthKey, amount |
| 46 | `SavingsGoal` | `fin_goals` | id, name, kind (`goal, sinking_fund`), targetAmount, deadline?, dueDate?, accountId? (earmark), colorValue, priority, autoContribute, plannedMonthly?, linkedCategoryId?, archived |
| 47 | `GoalEntry` | `fin_goal_entries` | id, goalId, date, amount (±), note, sourceRef? |
| 48 | `Valuation` | `fin_valuations` | id, accountId, date, value, units?, unitPrice? |
| 49 | `SplitGroup` | `fin_split_groups` | id, name, kind (`trip, household, other`), members (names), createdAt |
| 50 | `SplitEntry` | `fin_split_entries` | id, groupId, date, title, amount, paidBy, shares (map name to amount), txId?, settled |

**`Transaction` additions** (new HiveFields, all nullable or defaulted): `6 id` (String; legacy rows backfilled `legacy-{key}`; new rows random), `7 kind`, `8 accountId`, `9 toAccountId`, `10 categoryId`, `11 merchant`, `12 paymentMethod` (`UPI, Card, Cash, NetBanking, Other`), `13 notes`, `14 tags` (List<String>), `15 splits` (JSON string: `[{categoryId, amount, note, isOwed, counterparty}]`, Σ = |amount|), `16 receiptPaths` (List<String>), `17 recurringRuleId`, `18 sourceRef` (idempotency key: `rec:{ruleId}:{yyyy-MM-dd}`, `import:{hash}`), `19 createdAt`, `20 goalId`, `21 interestAmount` (debt payments), `22 refundOfId`. Keep the legacy `category` string as a denormalised display name; `categoryId` is authoritative when present.

`finance_settings` keys: `fin_schema_version`, `fin_migrated_steps`, `budget_mode` (`simple | 50_30_20 | zero_based`), `budget_split` (default 50/30/20), `rollover_carry_negative` (default false), `expected_income` (optional manual), `fin_home_layout`, `dismissed_insights`, `dismissed_sub_suggestions`, `import_profiles`, `ai_finance_privacy`, `emergency_target_months` (default 6), `card_min_due_pct` (default 5), `utilization_alert_pct` (default 30).

### 5.4 Engine definitions

All functions take `today` explicitly. Month = local calendar month. `daysElapsed` counts today.

- **Effective budget with rollover**: `effective(line, m) = base(line, m) + carry(line, m)`; `base` = override for `m` else `line.amount`; `carry(line, m)` = 0 if rollover off or `m` ≤ `startMonth`, else `max(0, effective(line, m-1) - spent(line, m-1))`, or without the `max` when `rollover_carry_negative` is true.
- **Variable spend projection per category**: `projected_c = w·(spent_c / daysElapsed · daysInMonth) + (1-w)·avg3_c`, `w = daysElapsed / daysInMonth`, `avg3_c` = mean of the previous 3 full months (use pace only if no history). Remaining = `max(0, projected_c - spent_c)`. Excludes categories fully covered by an active recurring rule.
- **Obligations(from, to)**: Σ unposted occurrences of active non-income recurring rules in the window, excluding `transfer` rules that pay a card (those are counted as card dues).
- **Safe to spend** (horizon default: end of month): `S = liquid - O - G - P - C` where `liquid` = Σ balance of `spendable` bank/cash/wallet accounts; `O` = obligations in `(today, horizon]`; `G` = Σ goal/fund planned monthly contributions not yet contributed this month; `P` = Σ over `essential` budget lines of `max(0, effective - spent - unpostedRecurringInThatCategory)`; `C` = card statement balances falling due by the horizon. Show `max(0, S)`, a `shortfall = max(0, -S)` state, and `perDay = S / daysLeft`.
- **Month-end forecast** of liquid balance: `liquid + expectedIncomeRemaining - O - C - Σ remainingVariable`. Goal contributions are earmarks, not outflows, so they are excluded here. **Confidence**: High if ≥3 full months of history and CV of monthly variable spend < 0.25; Medium if ≥2 months; else Low.
- **Goal planner**: `monthsLeft = max(1, ceil(daysUntilDeadline / 30.4375))`; `requiredMonthly = max(0, target - saved) / monthsLeft`; `rate` = mean monthly contributions over the last 3 months; `shortfall = max(0, requiredMonthly - rate)`. **Trim suggestions**: greedy over non-essential categories by 3-month average descending, up to 20% per category, until the shortfall is covered; if it cannot be, report "insufficient" instead of inventing a number. Suggestions are proposals the user confirms.
- **Loan**: monthly rate `r = annual/12`; `emi = P·r·(1+r)^n / ((1+r)^n - 1)`; remaining months = `ceil(-ln(1 - r·P/emi) / ln(1+r))` (flag "never amortises" if `emi <= r·P`); extra-payment simulation iterates the schedule and reports months and interest saved.
- **Health score** (0-100, weighted mean of available components, weights renormalised when a component has no data): Budgeting 25 = `100·(1 - Σmax(0, spent - limit) / Σlimit)` for the last full month; Savings 25 = `100·clamp(savingsRate3m / 0.20, 0, 1)`; Debt 20 = mean of available parts (DTI ≤ 0.20 → 100, falling linearly to 0 at ≥ 0.50; card utilisation ≤ 0.30 → 100, falling to 0 at ≥ 0.90; no debt → 100); Emergency fund 20 = `100·clamp(liquid / avgMonthlyEssential3m / targetMonths, 0, 1)`; Consistency 10 = `100·clamp(1 - CV6m / 0.5, 0, 1)` (needs ≥3 months). Return components, the weakest one, and the next milestone `(floor(months)+1) · avgMonthlyEssential`. Weights live in constants.
- **What-if** `canAfford(amount)`: `projectedAfter = forecastMonthEnd - amount`; **Comfortable** if `projectedAfter ≥ emergencyBuffer` (1 month of essentials), **Tight** if `≥ 0`, else **Not now**, with `monthsToSave = ceil(deficit / avgMonthlySurplus3m)` when surplus > 0.
- **Subscription detection**: normalise merchant (lowercase, strip digits, UPI/ref tokens, domains); group; require ≥3 occurrences with intervals within ±3 days of 7, 14, 30, 91 or 365 days and amount variance ≤ 5% (≤ 15% flags "variable"). Price-change flag when the latest amount differs from the previous by > 5%; "possibly cancelled" when ≥2 expected cycles are missing. The app has no usage data, so **never claim a subscription is "unused"**.

---

## 6. Planner decisions (defaults; owner may override)

1. Finance becomes a full-screen **Money shell** (pushed route) with a five-item bottom nav: Home, Transactions, Budget, Goals, More. Calendar, Net worth, Insights, Accounts, Bills and subscriptions, Debt and cards, Reports, Split and settle, Privacy and data are reached from Home cards and More. (Five is the bottom-nav limit; the research doc lists eight sections.)
2. Default currency ₹ with Indian grouping (`en_IN`: ₹1,42,850), whole rupees on dashboards, 2 decimals in transaction detail, compact lakh/crore. An existing user's stored symbol is never overridden.
3. Migration: each vault becomes an account (type mapping: Savings/Current → `bank`, UPI Wallet → `wallet`, Cash → `cash`, Investment/SIP → `investment`); all existing transactions go to a new `Main` account (opening 0, dated from the epoch); migrated `goal['saved']` money becomes an account "Goal savings (migrated)" so the total is preserved (I5), with goals as earmarks against it.
4. Legacy `fixedExpenses` migrate as `autoPost = false` recurring rules (reminder-only, matching MVP 1, where they never posted). SIPs keep MVP 2's behaviour (`autoPost = true`).
5. Goals and sinking funds are **earmarks**, not moved cash. They reduce "safe to spend" but not account balances.
6. Rollover carries only positive leftovers (`rollover_carry_negative = false`).
7. Auto-capture priority: CSV import, then rules and AI categorisation, then an **optional, off-by-default, Android-only** on-device SMS parser. The Account Aggregator integration is gated (§8). All capture sits behind a `TransactionSource` interface.
8. Receipt OCR is on-device (ML Kit) by default; cloud OCR is not used.
9. AI privacy: only the user's question, the query schema, and computed aggregates (category and merchant names included) are sent to Gemini. Raw transaction lists and account identifiers are never sent. A Settings toggle shows exactly what is shared.
10. Shared finance is **local split-and-settle** (trips, households as labels). Multi-user sync needs a backend and is out of scope.
11. Investments are manual valuations. No live price feed in this MVP.
12. Business rules are tunable constants (`engine/constants.dart`): health-score weights, utilisation threshold 30%, minimum-due 5%, trim cap 20%, anomaly thresholds, emergency target 6 months.

---

## 7. Phases and tasks

### Phase 1: Accounting core (nothing user-visible except fixes and backup)

**P1-0 Backup and export (safety net, do first)**
- `FinanceBackupService.exportJson()` writes `backups/finance_YYYYMMDD_HHMMSS.json` (app documents) containing every finance box and the finance settings keys; `importJson(file, {dryRun})` restores with a diff summary. An automatic backup runs before every migration; keep the last 5. Settings gets "Export finance data" (share or save via `share_plus`/`file_picker`, **VERIFY**).
- Done when: a test round-trips export, wipe, import and compares equal.

**P1-1 `FinanceStorage`, `FinanceRepository`, `FinanceController`**
- Repository API (sketch): `addTransaction(TxDraft)`, `updateTransaction`, `deleteTransaction(id)` with in-session undo, `transfer(...)`, `refund(...)`, `postRecurring(rule, dueDate)`, CRUD for accounts, categories, rules, budget lines, goals and entries, recurring rules, valuations; plus a `Listenable changes`. It enforces I6 and awards the existing XP hooks. Boxes injectable for tests (`Hive.init` on a temp dir).
- Done when: unit tests cover validation failures and undo; no widget imports `Hive.box<Transaction>` after P1-6.

**P1-2 Models and adapters**
- Add the models in §5.3 and the `Transaction` fields; regenerate adapters; register adapters and open boxes in `main.dart` via `FinanceStorage`.
- Done when: a legacy-adapter fixture (bytes written by MVP 1's adapter) still reads under the new adapter, with new fields null/default.

**P1-3 Migration v1 → v2** (versioned by `fin_schema_version`; each step records itself in `fin_migrated_steps` and is idempotent)
1. Seed categories: the 10 existing names (Food, Shopping, Transport, Utilities, Health, Entertainment, OTT, Groceries, EMI, Other) plus Rent, Education, Travel, Subscriptions, Insurance, Gifts, Personal Care, Interest & fees, Reimbursement, and income categories (Income, Salary, Stipend, Freelance, Interest, Gift, Refund). Default groups: needs = Food, Groceries, Transport, Utilities, Health, EMI, Rent, Education, Insurance; wants = Shopping, Entertainment, OTT, Travel, Subscriptions, Gifts, Personal Care, Other. Essential = needs.
2. Backfill transactions: `id`, `categoryId` (match by name), `createdAt = date`, `paymentMethod` null.
3. Create accounts per §6.3 (vault `bank` field was overwritten by type, so use `institution = null`).
4. Set `accountId = acc_main` on every transaction without one.
5. Budgets → `BudgetLine` (rollover off, essential from the category's flag).
6. Goals → `SavingsGoal` + one opening `GoalEntry` for `saved`; parse the free-text `deadline` best-effort (null if unparseable and say so in the report).
7. `fixedExpenses` and `sips` → `RecurringRule` per §6.4. Read MVP 2's SIP idempotency marker (deterministic key or `sip_ledger`) and write the equivalent `sourceRef` on already-posted SIP transactions so no debit posts twice after migration. **VERIFY** how MVP 2 implemented it.
8. Verify I5 (old `vaultTotal + allTimeNet + goalsSaved` equals new Σ balances) and counts per box; on any exception roll back the step, keep v1 data, show a blocking error with Export and Retry.
- Done when: fixture tests (empty app, typical app, large app with 5k transactions, app with MVP 2 SIPs already posted) pass, including a second run that changes nothing.

**P1-4 Money and formatting**
- `Money.r2`; `FormatUtils.formatMoney(amount, {compact, decimals})` with `en_IN` grouping and lakh/crore compact form (**VERIFY** what `NumberFormat.compactCurrency(locale: 'en_IN')` produces). Default ₹ for new installs only.
- Done when: tests for 142850 → `₹1,42,850`, 280000 compact → `₹2.8L`, and the 0.1+0.2 rounding case.

**P1-5 Ledger engine** (`engine/ledger.dart`)
- Implement `balance`, `netWorth`, `spent`/`income` (with splits expanded, refunds netted), month indexes, receivables/payables from owed split lines.
- Done when: tests for I1-I4 (every kind), credit-card purchase then payment, split with an owed line, refund, valued-account fallback, and `balanceAsOf` history.

**P1-6 Route existing code through the repository** (no behaviour change)
- Replace every `txBox.add`, vault/settings read and `_buildFinanceSummaryResponse`/`_buildSipResponse` computation in `ai_service.dart`, MVP 2's `SipService`, and MVP 2's finance home card with repository/engine calls. `FinanceDashboard._buildSnapshot` becomes a thin adapter over the engine.
- Done when: `grep -rn "Hive.box<Transaction>\|finance_transactions\|finance_vaults\|finance_settings" lib` shows only `FinanceStorage` and migration code; overview totals are identical before and after on the large fixture.

### Phase 2: Money shell and Transactions v2

**P2-1 Money shell**
- Full-screen route with the five-item M3E nav (§6.1). Add `MoneyRoute` to `AppNav` so cards, the AI and notifications can deep-link (`budget`, `goals`, `calendar`, `networth`, `insights`, ...). Tabs for phases not yet landed are hidden by `MoneyFeature` flags. Move the entry points (Tasks finance toggle, home finance card) to the shell. Extract the reusable charts from `finance_page.dart` into `ui/widgets/charts/`. The old `FinanceDashboard` stays compiled but unreachable until P13-5 removes it.
- Done when: every previous finance entry point opens the shell; deep links route correctly (test).

**P2-2 Transaction sheet**
- One add/edit sheet: kind chips (all eight kinds; reimbursement appears only when owed lines exist), amount, account (and destination for transfer/investment/debt payment), category grid, **date and time picker defaulting to now** (fixes defect 2), merchant with autocomplete from history, **payment method that is persisted** (defect 1), notes, tags, "make recurring" (opens P6 flow once it lands), receipt button (hook for P10-4). Quick path: amount then category in ≤3 taps; "repeat last". Delete shows an undo snackbar.
- Done when: widget tests for each kind's validation; saved `paymentMethod` and `date` survive reload.

**P2-3 Split transactions**
- Split editor: lines of category + amount + note, or an **owed** line with a counterparty (the friend's share). Remaining amount indicator; cannot save unless Σ equals the total. Owed lines feed receivables (I2) and later P12.
- Done when: the ₹1,200 example (700 food, 300 entertainment, 200 owed) yields spending 1,000, receivable 200.

**P2-4 Kinds in the UI**: transfers, refunds (optionally linked to the original via `refundOfId`), investments, debt payments (principal/interest inputs; auto-split when a loan has terms, P7), adjustments, reimbursements. Retire `_isExpense` for all new code; every reader uses `effectiveKind`.

**P2-5 List, filters and global search**
- Day-grouped virtualised list (`SliverList`) with daily totals. Filters: kind, account, category, tag, amount range, has receipt, date range. **Search** with free text over title, merchant, notes, tags, category and amount (`500` matches within ±10%), plus operators `>2000`, `<500`, `merchant:`, `cat:`, `tag:`, `acct:`, `month:sep`, `year:2026`. In-memory normalised index, rebuilt incrementally.
- Done when: parser tests for each operator and combinations; 20k-transaction search under 100 ms (report timing if you can run it).

**P2-6 Bulk actions**: multi-select to delete or re-categorise (with undo); category management screen (add, rename, merge, archive, group assignment).

### Phase 3: Accounts and net worth

**P3-1 Accounts UI**: list grouped by asset/liability, add/edit with kind-specific fields (card limit and dates, loan terms), colour, archive, include in net worth, spendable. Fix defect 3 (`institution`). **Reconcile** action: enter the real balance, create an `adjustment` for the difference.
**P3-2 Net worth screen**: total, change vs last month, assets and liabilities lists, receivables/payables line, a 12-month history chart computed from `balanceAsOf` at month ends, composition donut.
**P3-3 Valued assets and holdings** (investment tracking): add valuation entries (value, or units × price); invested amount from `investment` transactions; show value, invested, gain/loss and %. No price feed.
**P3-4 Account detail**: transactions for the account, balance-over-time chart, card/loan summary.
- Done when: engine tests for history; I5 test remains green after UI creation of accounts.

### Phase 4: Budgeting

**P4-1 Budget engine** per §5.4 (`effective`, spent by line and group, group totals).
**P4-2 Budget screen with three modes** (mode stored in `budget_mode`; all modes use `BudgetLine`s):
- **Simple**: per-category limits.
- **50/30/20**: wizard sets expected income (from `expected_income`, else the average of the last 3 months, else income recurring rules) and the split (editable, default 50/30/20); shows actual vs target per group, where Savings actual = goal/fund contributions + investments.
- **Zero-based**: lines include category budgets and **buckets** (goals, sinking funds, investments, emergency fund); "left to assign" = expected income − Σ assignments; warn on ≠ 0, never block.
**P4-3 Rollover** per §5.4, with a per-line toggle and a global negative-carry setting.
**P4-4 Budget intelligence**: per line projected month end (§5.4), overspend amount, and "cut about ₹X/week to stay on budget" with `X = max(0, projected - budget) / (daysLeft / 7)`; status copy such as "spending faster than usual".
**P4-5 Alerts**: notify at 80% and 100% of a line and on projected overspend; at most one pace alert per day; dedupe keys in settings; global toggle. Extend `NotificationService` with a generic `schedule(id, when, title, body, payload)` on a `finance` channel (payload deep-links through `AppNav`).
- Done when: tests for the rollover vectors (Food ₹5,000, January spent ₹4,200 → February effective ₹5,800; February spent ₹6,000 → March effective ₹5,000 with negative carry off and ₹4,800 with it on), the three modes' arithmetic, and the projection formula.

### Phase 5: Goals and sinking funds

**P5-1 Goals**: CRUD for `SavingsGoal`; contributions and withdrawals as `GoalEntry`; earmark account; progress; keep the +20 XP on contribution; the old "update goal" action becomes "add contribution".
**P5-2 Goal planner**: given a target and deadline, show required monthly, current rate, shortfall, and **trim suggestions** (§5.4) with an Apply action that edits budget lines after confirmation.
**P5-3 Sinking funds**: templates (Insurance, College fees, Laptop replacement, Festival shopping, Travel, Medical, Vehicle maintenance, Gifts) with target and due date → monthly reserve `target / monthsLeft`; appears as a bucket in zero-based budgeting and reduces safe-to-spend via `G`. Spending in the linked category prompts "use fund?" (no silent withdrawals).
**P5-4 Auto-contribute**: when `autoContribute` is on, create the month's `GoalEntry` on first open of each month (idempotent via `sourceRef`).
- Done when: planner tests (₹60,000 in 6 months → ₹10,000/month; rate ₹6,500 → shortfall ₹3,500; trims never touch essential lines, never exceed 20%, and report "insufficient" when short).

### Phase 6: Recurring, bills, subscriptions, calendar

**P6-1 Recurring engine** (generalises MVP 2 `SipService`; MVP 2's class becomes a thin wrapper then is deleted)
- `occurrences(rule, from, to)` for weekly, monthly (due day clamped to month length), quarterly, yearly (Feb 29 → Feb 28 in non-leap years), every-N intervals. `runDue(now)` at boot and on resume: for `autoPost` rules post an `expense`/`income`/`transfer`/`investment`/`debt_payment` dated on the due date with `sourceRef = rec:{id}:{yyyy-MM-dd}`; for confirm-mode rules create "due items" the user taps **Paid** (posts dated to the due date or the chosen date). Variable amounts estimate from the average of the last 3 posted. Idempotent under kill/restart (same invariant as MVP 2).
- Done when: tests for month-end clamps, leap years, a three-month gap, double run, December rollover, paused/ended rules, and migrated SIPs not re-posting.
**P6-2 Bills and recurring UI**: grouped by kind, monthly total, add/edit/pause/skip-this-month, Mark paid, "make this transaction recurring" from P2-2.
**P6-3 Reminders**: notifications `reminderDaysBefore` days ahead (default 2) at 09:00 local, rescheduled on boot and every edit; payload deep-links to the item. **VERIFY** exact-alarm permission handling as in MVP 2's medicine task; reuse it.
**P6-4 Subscriptions**: detection suggestions per §5.4 (confirm creates a rule, dismiss stored in `dismissed_sub_suggestions`), monthly and yearly cost totals, price-change and possibly-cancelled flags.
- Done when: detection tests (4 monthly ₹649 charges → detected; 649, 649, 799 → price-change flag; irregular amounts → not detected).
**P6-5 Financial calendar**: month grid with dots by type (income, bills, subscriptions, goals, card due/statement, EMI); day sheet with items and totals. Custom grid (**VERIFY** whether a calendar package is already a dependency before adding one).
**P6-6 Release gate for train 3.0**: run all tests; migration dry run against an export of the owner's real data if provided; update `MANUAL_QA.md` and `APP_DOCUMENTATION.md`; stop and report.

### Phase 7: Debt and credit cards

**P7-1 Debt manager**: loan accounts with terms; amortisation schedule; outstanding, remaining months, total interest remaining, EMI; **extra-payment simulator** (months and interest saved); optional avalanche vs snowball comparison across several debts. EMI rules create `debt_payment` transactions with the principal/interest split from the schedule.
- Done when: tests with an independent vector (P = 100,000, 12% p.a., n = 12 → EMI 8,884.88 ±0.01, total interest ≈ 6,618.5) and property tests (extra payments never increase interest or months).
**P7-2 Credit card management**: cycle from `statementDay`/`dueDay`; statement balance, outstanding, available credit, utilisation, minimum due (`card_min_due_pct` of the statement balance, **VERIFY** the owner's card terms); alerts (statement tomorrow, due in N days, utilisation above threshold); "Pay card" creates a transfer (I4). Never treat card spending as income.
**P7-3 Other debts** (BNPL, personal loans without schedules): liability accounts with optional due reminders.
- Done when: tests for cycle boundaries, purchase-then-payment net worth, utilisation maths.

### Phase 8: Intelligence

**P8-1 Cash flow**: money in, money out, net, by category/merchant for the chosen period, plus the next-30-days projection (expected income, bills due, expected variable spending, remaining).
**P8-2 Forecast** (§5.4) with confidence and a plain-language line.
**P8-3 Safe to spend** (§5.4): hero number, breakdown (balance, bills, goals, planned, card dues), per-day figure, shortfall state.
**P8-4 Financial health score** (§5.4): components, weakest area, next milestone.
**P8-5 Insights engine**: deterministic generators, each producing `Insight {stableKey, severity, kind, params, deepLink}` rendered from templates: category up vs 3-month average (> +20% and > ₹500), the merchant/frequency driving it, budget pace warnings, bill collisions with low balance, goal behind schedule, subscription total, net-worth change, savings-rate change, unusually large transaction (> 3× category median and above a floor), suspected duplicate charge (same merchant and amount within 24 hours), emergency-fund status. Dismissal stored by `stableKey`; at most 5 shown on Home. Optional LLM rewording is off by default (P11-5).
**P8-6 What-if engine** (§5.4) with unit tests (comfortable, tight, not-now, and months-to-save).
**P8-7 Money Home cockpit**: cards built on the MVP 2 registry pattern with their own `fin_home_layout`: Net worth (with change), Safe to spend, Cash-flow summary, What's happening (insights), Upcoming (next 5), Goals (top 2), Budgets (top 3 at risk), Health score, What-if entry. Reorderable and hideable in finance settings.
- Done when: every engine function has fixture tests, including empty-history behaviour (no division by zero; "not enough data" states instead of invented numbers).

### Phase 9: Reports and main-home integration

**P9-1 Reports**: monthly (income, spending, saved, invested, net worth change), category, merchant, month-vs-month comparison, trends over 3, 6 and 12 months.
**P9-2 Export**: each report and the transaction list to CSV (via `csv`/`share_plus`, **VERIFY**). PDF export is out of scope.
**P9-3 Main-dashboard cards** (MVP 2 registry): Safe to spend, Net worth, Upcoming bills; each deep-links into the shell.
- Done when: report maths tested against fixtures (splits, refunds and transfers handled per I3).

### Phase 10: Capture

**P10-1 CSV import**: pick a file, auto-detect delimiter, map columns (date format, description, debit/credit or signed amount), save mapping profiles in `import_profiles`, preview, **dedupe** by hash of (date, amount, normalised description, account) as `sourceRef = import:{hash}`, suggest transfer pairs (same amount, opposite sign, different accounts, ≤2 days apart) instead of importing both as spending.
**P10-2 Categorisation rules**: merchant normalisation plus `CategoryRule` priority matching on import and entry. When the user recategorises, offer "Always categorise {merchant} as {category}" (creates a rule, optionally applies to past transactions).
**P10-3 AI categorisation (opt-in)**: batch uncategorised normalised merchant strings to Gemini through `GeminiClient`, receive category suggestions, present as rule suggestions to confirm. Send merchant strings only (§6.9). Cache results.
**P10-4 Receipts**: attach from camera or gallery (`image_picker`); copy to `receipts/{txId}/`; thumbnails; on-device OCR to pre-fill amount, merchant and date (ML Kit, **VERIFY** package and Android requirements); review before saving. Receipts are excluded from JSON export (note that in the UI).
**P10-5 Optional SMS parser** (Android, off by default, explicit permission screen): reads bank/UPI SMS locally, template-based regex for amount, direction, merchant, account tail; creates *suggestions*, never auto-posts; dedupes against imports. **VERIFY** Play Store SMS-permission policy (fine for a sideloaded personal build); implement via a Kotlin ContentResolver bridge or a maintained plugin, evaluating both.
**P10-6 `TransactionSource` interface** (`Future<List<TxDraft>> fetch(...)`) implemented by CSV and SMS; the Account Aggregator integration is **not** implemented (§8).
- Done when: tests for CSV parsing edge cases (quoted commas, DD/MM/YYYY, debit/credit columns), dedupe, rule priority, transfer-pair detection.

### Phase 11: Natural-language finance and AI

**P11-1 Query engine** (`engine/query.dart`): `FinanceQuery {metric: sum|count|avg|list|top, subject: spending|income|net|balance|networth, filters: {merchant, category, tag, account, amountMin/Max, period}, groupBy, compareTo}`; deterministic executor with tests ("spent on Swiggy last month", "expenses above ₹2,000 this year", "top 5 merchants").
**P11-2 Language to action/query**: extend the existing action protocol. Keep `finance_transaction`, `finance_budget`, `finance_goal`, `finance_commitment`, `finance_sip` (now routed through the repository, with payload extended for account, date, merchant, kind) and add `finance_transfer`, `finance_recurring`, `finance_query` (read-only; executed by P11-1, then phrased from the computed numbers) and `finance_whatif`. All writes keep the existing confirmation step. Keep the English/Hinglish local regex fast paths ("I spent 350 on dinner") but make them call the repository.
**P11-3 What-if via chat**: "Can I afford a ₹50,000 phone?" returns the P8-6 verdict with the numbers and a saving plan.
**P11-4 AI privacy controls**: a Settings page that shows what is shared (§6.9), with a switch to disable finance AI features entirely.
**P11-5 Optional insight rewording** through the LLM (off by default, same payload rules).
- Done when: golden tests for query parsing from sample LLM JSON; confirmation required for every write action; the LLM is never given raw transactions (test the outgoing payload builder).

### Phase 12: Split and settle (local)

**P12-1 Groups and entries**: `SplitGroup`/`SplitEntry` (payer, equal or custom shares); who owes whom, plus suggested settlements using the minimal-transactions algorithm; owed split lines from P2-3 appear as entries.
**P12-2 Settlements**: receiving money creates a `reimbursement` transaction (not income); paying someone creates an `expense` or `transfer` as appropriate; both mark the entries settled and update receivables/payables.
**P12-3 Trip mode**: per-person spend and total report for a group.
- Done when: settlement algorithm tests (3-person example, rounding to paise with the remainder assigned deterministically).

### Phase 13: Privacy, security, hardening

**P13-1 Privacy and data screen**: what is stored locally; permissions in use (notifications, camera, storage, SMS) with toggles and links to system settings; AI sharing explanation; export; delete.
**P13-2 App lock for Money**: `local_auth` with device-credential fallback (reuse MVP 2's journal lock service), timeout setting, lock on background; optional hide-from-recents screen.
**P13-3 At-rest encryption**: AES-encrypt all finance boxes via `FinanceStorage` using a key in secure storage (reuse MVP 2's key service). Migration is **copy, verify counts and checksums, switch, keep the old box as a backup** until the owner confirms through an explicit "Delete unencrypted backup" action. Back up first (P1-0). Abort and keep the old boxes on any mismatch.
**P13-4 Delete all finance data**: typed confirmation, offer export first, then wipe finance boxes, the receipts folder and finance settings, and reset `fin_schema_version`.
**P13-5 Remove legacy**: delete the unreachable `FinanceDashboard` and unused widgets; leave legacy settings keys untouched (§2).
**P13-6 Harden and document**: tests for the migration matrix (MVP 1 → 3, MVP 2 → 3), encryption round trip, performance on a 20k-transaction fixture; update `MANUAL_QA.md` (every device-only check: notifications, exact alarms, camera/OCR, SMS, biometrics, encryption upgrade over a real install) and `APP_DOCUMENTATION.md` (boxes, models, engines, AI actions, privacy).
- Done when: round-trip and failure-injection tests pass (kill during migration leaves usable v1 data).

---

## 8. Open questions for the owner

Proceed on the stated default for everything except item 1.

1. **Account Aggregator** (Fold-style bank sync): this needs registration as a regulated Financial Information User or a partnership with an aggregator (**VERIFY** current requirements and sandbox availability). Default: not implemented; CSV import, rules and optional SMS cover capture. Tell me if you have an AA partner.
2. **SMS parsing**: acceptable as an opt-in, off-by-default feature? (§6.7.)
3. **Household / family sync across devices** needs a backend. Default: local split-and-settle only.
4. Is migrating existing goal savings into a "Goal savings (migrated)" account acceptable (§6.3), or should that money be treated as already inside existing accounts?
5. Which release train should ship first if time is short? Default order: 3.0 → 3.1 → 3.2 → 3.3.

## 9. Out of scope

Tax planning, insurance tracking (a yearly premium recurring rule covers payments), FIRE and retirement calculators, portfolio analysis, property valuation tools, automated investment recommendations, live market prices, multi-currency, PDF reports, cloud sync, and any change to existing typeIds, field indexes or box names.
