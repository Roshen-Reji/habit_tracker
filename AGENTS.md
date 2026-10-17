# AGENTS.md: Money rewrite ("Money v2")

Standing instructions for any coding agent (Antigravity, Gemini, Claude Code) working in `Roshen-Reji/habit_tracker`. Read this whole file before touching code. It overrides the Finance parts of `MVP_5.md` (Phases 1, 2 and 5 for Finance). `MVP_5.md` still governs the PDF reader, reminders, XP and non-Finance work.

Based on a read-only audit of `master` at `ef162ff`. Nothing was compiled or run. Markers:
- **VERIFY:** not confirmed. Check in code, package source or on a device first.
- **Default:** a planner decision the owner has not confirmed. Proceed and list it in your report.
- **OWNER:** needs the owner's answer. Never block on it.

---

## 1. Goal

The owner's words, cleaned up: Finance is messy and complex. SIP is not counted correctly. Money I spend does not get deducted. Rewrite Finance so every part is linked, works the first time, and is simple for the user. Make the Finance UI extremely smooth ("buttery").

**Success means** a person can open Money, add a spend in three taps, see every number on every screen change at once, undo it, and never wonder where the money went.

---

## 2. Why it is broken (confirmed in code)

| ID | Finding | Evidence |
|---|---|---|
| RC1 | **Spends are silently ignored.** `LedgerEngine.balance` skips every transaction dated before `account.openingDate`. New accounts default `openingDate` to `DateTime.now()` including the time of day, and entries carry a time of day too (`transaction_sheet.dart` combines the picked date with `_selectedTime`). So a backdated spend, or one logged at an earlier time today than the account was created, never reduces the balance. Migrated accounts use `DateTime(2020,1,1)`, so they behave differently from new ones. | `engine/ledger.dart` `balance()` loop; `ui/accounts/account_edit_sheet.dart` L61, L229; `data/migrations/finance_migrator.dart` L417, L445, L462 |
| RC2 | **One fact is stored three ways.** A transaction has a signed `amount`, a `mode` string and a `kind`. `addTransaction` derives the sign from `kind`; the ledger's default branch falls back to `mode` and the sign. Any path that sets them inconsistently changes the balance wrongly. | `data/finance_repository.dart` L95-135; `engine/ledger.dart` default branch |
| RC3 | **SIP is too indirect to be reliable.** A SIP is a `RecurringRule`, an `investment` transaction, optional valuation anchors and a runner that only runs at start and resume. "Deposited", "value" and "balance" are different numbers the user cannot see side by side. Past start dates back-charge silently (up to 60 instalments). | `data/finance_repository.dart` `postRecurringDue` (L567+); `engine/ledger.dart` valued-asset branch |
| RC4 | **Every screen computes its own numbers.** The ledger scans the whole transaction box per account, inside `build` methods. Safe to Spend is built from five inputs and is evaluated as of the first of the month on the Overview. Home cards and Overview can disagree. | `ui/overview/money_overview_tab.dart` L92-110; `data/finance_controller.dart` L833+ |
| RC5 | **Too much surface.** 5 tabs plus a More tab that leads to about 20 pages, feature flags, three names for scheduled money (recurring, SIP, EMI) and 136 `setState` calls in Finance UI. | `ui/shell/money_shell_page.dart`; `engine/money_feature.dart` |
| RC6 | **Coarse rebuilds and almost no motion.** `FinanceController` is a singleton `ChangeNotifier` that calls `notifyListeners()` for every mutation. Tabs live in an `IndexedStack`, so all five are built at once. Finance UI has 28 `SingleChildScrollView`, 13 `ListView(`/`shrinkWrap` uses and only 2 animated widgets in total. | `data/finance_controller.dart` L24, L45; counts via `grep` over `lib/features/finance/ui` |

Already fine (do not redo): Hive `typeId`s do not collide; `LoanEngine.splitPayment` exists; `FormatUtils` is the single money formatter; `FinanceBackupService` exists; the double `₹` call sites are gone.

---

## 3. Product model (what the user sees)

Keep it to four ideas. Everything else is derived.

1. **Accounts.** Exactly one is **Main**: the account that holds all the owner's money. Others are **Funds** (SIP and investments), **Loans** and **Cards**. Stored `kind` strings do not change; map them to these four groups in one place (`AccountGroup`).
2. **Entries.** The user can do three things: **Spent**, **Received**, **Moved** (from one account to another). Anything automatic produces the same entries.
3. **Plans.** One concept replaces recurring rules, SIP, EMI, bills and subscriptions in the UI. A Plan repeats an entry on a day each month: SIP (Main to Fund), EMI (Main to Loan), Bill (Main to outside), Income (outside to Main). Stored as the existing `RecurringRule`.
4. **Goals.** A goal is a view over a fund (or a manual pot). It never holds money of its own.

### Money laws (these must always be true)

- **L1 Immediate.** Spent X from A: A falls by X. Received X into A: A rises by X. Moved X from A to B: A falls by X, B rises by X. Nothing else changes. Every screen shows the new numbers in the same frame.
- **L2 No ignored entries.** `balance(A) = openingBalance + Σ effect of every entry on A dated up to now`. There is no opening-date cut-off. `openingDate` becomes informational only.
- **L3 One representation.** Internally an entry is `{kind, amountMinor (always positive), from, to}`. Sign and `mode` are derived for legacy storage in one function and are never read back by the ledger.
- **L4 Funds.** `Invested = openingBalance + Σ deposits`. `Value = latest value update + deposits made after it` (or `Invested` if the owner never updated the value). `Gain = Value − Invested`, shown only after a value update. The user sees Invested, Value and Gain together.
- **L5 Loans.** A move into a loan reduces outstanding by the principal part only. The interest part is recorded as an expense on Main. Use `LoanEngine.splitPayment`.
- **L6 Automation is idempotent.** Each Plan occurrence has the key `plan:{id}:{yyyy-MM-dd}`. It is never posted twice, never silently back-charged, and catches up on app start, resume and right after a Plan is saved. If Main cannot cover an automatic plan, nothing is posted, the plan shows "Needs funds", and one notification is sent. Manual **Spent** is always allowed (it records reality), with a gentle warning when it takes Main below zero.
- **L7 Free to spend** = Main balance − Plans still due before month end (not yet posted). Three lines: **Available**, **Coming up**, **Free to spend**. Tapping shows the list behind each. Never clamp silently; if negative, show "Short by ₹X" in a calm tone.
- **L8 Undo and edit.** Every add, edit and delete offers Undo for 5 seconds. Editing or deleting an old entry updates every balance.
- **L9 Single writer, single reader.** Only `MoneyService` writes entries. Only `MoneySnapshot` is read by screens. UI code never opens a Hive box and never computes a balance.

---

## 4. Architecture

New module `lib/features/money/`. The old `lib/features/finance/` keeps working on the same boxes until parity, then dead code is deleted in M8.

```
lib/features/money/
  core/        pure Dart, no Flutter and no Hive imports
    minor.dart            int minor units (paise); toMinor/fromMinor at the boundary
    entry.dart            Entry value type (L3)
    ledger.dart           balances, fund math, loan split (L1, L2, L4, L5)
    plan_engine.dart      occurrences, due list, idempotent keys (L6)
    free_to_spend.dart    (L7)
    snapshot.dart         immutable MoneySnapshot
  data/
    money_store.dart      thin adapters over the existing Hive boxes (no schema change)
    money_service.dart    the only writer: spend, receive, move, edit, delete, undo, plans
    plan_runner.dart      start, resume, after-save; per-plan try/catch; one summary notification
    balance_check.dart    one-time migration helper (section 6)
  state/
    money_state.dart      one ValueNotifier<MoneySnapshot>; selectors for slices
  ui/
    shell/ today/ activity/ plans/ accounts/ widgets/ motion/
```

Rules:
- Money in the engine is **integer minor units**. Hive keeps `double`; convert at the store boundary with `(x * 100).round()` and back. (Default)
- `MoneyState` keeps per-account running balances and updates only the accounts an entry touches. It does a full rebuild once after the first frame, and again after a restore or migration. Hive stays on the main isolate.
- `MoneySnapshot` contains: per-account balance, Main balance, Free to spend (with its three lines), month spent and received, funds (Invested, Value, Gain), upcoming plans (next 10), plans needing funds, recent entries.
- Make the old `FinanceRepository.addTransaction` and the old controller's mutation methods thin wrappers that call `MoneyService`, so no second writer exists.
- Keep `FormatUtils` as the only money formatter. Currency symbol stays ₹.
- Keep every existing route string and deep link (`overview`, `transactions`, `budget`, `goals`, `more`, `accounts`, `recurring`, `reports`, and the rest in `AppNav` and `money_shell_page.dart`). Map each to a new destination or to the retained legacy page.

---

## 5. Screens

Four tabs and one add button. Reuse the floating nav bar and `DepthCard` described in `MVP_5.md` section 5.1 to 5.4 (if they are not built yet, build them as specified there).

| Tab | Content |
|---|---|
| **Today** | Hero: Main balance (animated number). Under it: Coming up and Free to spend. A row of three buttons: Spent, Received, Moved. "Coming up" (next 5 plans). "Funds" strip (Invested, Value, Gain per fund). |
| **Activity** | Entries grouped by day with sticky headers, search, swipe to delete with Undo, tap to edit. |
| **Plans** | Segments: SIP, EMI, Bills, Income, Goals. Each row: name, From to To, amount, next date, status. One "Add plan" sheet asks: what kind, how much and which day, from where to where. A SIP cannot be saved without a destination fund; the sheet can create the fund inline. |
| **Accounts** | Main pinned on top, then Funds, Loans, Cards. Account page: balance, history, and for a Fund: Invested, Value, Gain and an **Update value** button (one field). A **More** list at the bottom opens the existing Budget, Reports, Cash flow, Net worth, Insights and Privacy pages unchanged. |

**Quick add (three taps):** open, type the amount on a large keypad, pick a category chip. Account defaults to Main, date is today, time is now. Everything else is under "More options". Save, balances animate, Undo appears.

Removed from the user's path: the budget tab, goals tab, feature flags, the three scheduled-money names, and the Safe to Spend multi-input breakdown (replaced by L7).

---

## 6. Data safety and migration

- Never change an existing `typeId`, `@HiveField` index or box name. Do not delete user rows automatically. No Hive access from a background isolate.
- New settings keys live in `finance_settings` with the prefix `money2_` (for example `money2_main_account_id`, default `acc_main`; `money2_enabled`).
- Take a JSON backup with `FinanceBackupService` before any migration. If the backup fails, abort and change nothing.
- **Balance check (L2 change).** Removing the opening-date cut-off can change displayed balances because entries that were ignored before will now count. On first launch of Money v2, compute for each account the old balance (old rule) and the new balance (L2). If they differ, show one screen: per account, old and new values and the entries that were ignored. Two buttons: **Use new balances** or **Keep today's balances** (the second sets `openingBalance = oldBalance − Σ effects of all entries`, so today's number stays the same and future entries behave correctly). Never silent.
- **Legacy duplicates.** One-time check for months where both `sip_{id}_{yyyy-MM}` and `rec:{id}:{yyyy-MM-dd}` exist, and for plain "SIP · name" expenses with no destination. Show a review sheet. Never act automatically.
- **Past start date.** When a plan starts in the past, ask: **Start from today** (default) or **Post missed** (list and total shown first, capped at 24). Never back-charge silently.
- Keep the old Finance shell behind a hidden debug toggle until M8 so the owner can compare numbers.

---

## 7. Motion and smoothness standard

**Targets** (measure in `--profile` on a real device; without a device write "not measured"):
- No sustained frame over the display budget (16.6 ms at 60 Hz, 8.3 ms at 120 Hz) while scrolling Activity, switching tabs, and opening and closing sheets.
- Today is visible within 300 ms of tapping the Money entry.
- Activity scrolls smoothly with 5,000 entries.

**Motion kit** (`ui/motion/`, one source for everything):
- Durations: instant 90 ms, quick 160 ms, standard 240 ms, emphasized 360 ms.
- Curves: enter `easeOutCubic`, move `fastOutSlowIn`, press and sheets use one spring (mass 1, stiffness 380, damping 30; tune on device).
- `AnimatedMoneyText`: counts from the old value to the new one in about 450 ms on change, tabular figures, no layout jump.
- `PressScale`: scale to 0.97 on tap-down, spring back on release. `HapticFeedback.selectionClick` on taps, `lightImpact` on a saved entry.
- `MotionScope.of(context)`: returns instant durations when `MediaQuery.disableAnimations` is true.

**Rules** (a reviewer can grep for these):
1. Animate **transform and opacity** only (`Transform`, `FadeTransition`, `SlideTransition`, `AnimatedScale`). Do not animate width, height or padding per frame in lists. `AnimatedSize` only in small isolated widgets.
2. No `BackdropFilter`, no `ImageFilter.blur` in Finance, except the single optional nav bar blur from `MVP_5.md`. No `Opacity` widget over complex subtrees (use `FadeTransition`). Avoid `ClipRRect` on scrolling content; use `DecoratedBox` radius.
3. Lists are `CustomScrollView` with `SliverList.builder` or `SliverAnimatedList`. No `ListView(` with children, no `shrinkWrap: true` inside scrollables, no `Column` in a `SingleChildScrollView` for anything that can grow.
4. Rows are `const` where possible and each row has a `RepaintBoundary`. Entrance stagger only for the first 8 rows, 30 ms apart, and only the first time the screen appears (keep a "seen" flag so rebuilds never replay it).
5. Insert and delete in Activity animate (240 ms size and fade). Undo reverses it.
6. Rebuilds are scoped: screens listen to **slices** of `MoneyState` through selectors; field edits live in small widgets; no screen-level `setState` for a single value change. Never pass `Hive.box(...).listenable()` without `keys:`.
7. Tabs are lazy and keep state (`PageStorageKey` for scroll). Tab change: fade plus 12 px vertical shift, 220 ms. Card to detail: `Hero` on the amount and the card. Sheets: draggable with the shared spring.
8. Progress bars (budget, goal, fund) animate only when the value changes (`TweenAnimationBuilder`, 500 ms). No repeating animations on any Finance screen.
9. Optimistic UI: update the snapshot first, write to Hive after, roll back and show a message if the write fails.
10. Do not disable Impeller. **VERIFY** the Flutter version and that Impeller is on for Android.
11. Add a debug and profile-only frame timing logger (`SchedulerBinding.addTimingsCallback`) that counts over-budget frames per route. It is not compiled into release builds.

**Look** (calm, minimal): cards have no border, two soft shadows and a faint top highlight; desaturated colours (sage for positive, muted coral for negative); the accent colour is used only for the selected nav item, primary buttons, progress fill and the one key number on a screen. Use `MVP_5.md` section 5.1 values as the starting point.

---

## 8. Work order

One milestone per branch (`money2/m0` ... `money2/m8`), one commit per task, the app compiles at every commit. After each task run `dart format .` and `flutter analyze`. After each milestone write a short report: what changed, what you ran, what you could not verify, defaults applied, questions.

**Testing note.** The owner's standing rule is "testing last". Exception for this rewrite (Default): the pure-Dart money laws in M1 get small unit tests as they are written, because they are the only proof the numbers are right. UI, widget and device tests stay in M8.

**M0. Baseline.** Run `flutter analyze` and `flutter test`; record results. Record the real `typeId`s. Write a debug-only screen (long-press the Overview title; `kDebugMode || kProfileMode` only) that, for a chosen account, lists every entry and valuation in date order with the running total and the reason any entry is skipped. Record profile-mode frame times for Overview, Transactions and tab switching (or "not measured").
*Done when:* the audit screen's final total equals the current `LedgerEngine.balance`, and RC1 is reproduced on it.

**M1. Core (pure Dart).** `minor.dart`, `entry.dart`, `ledger.dart`, `plan_engine.dart`, `free_to_spend.dart`, `snapshot.dart`. Unit tests for L1 to L7, including: backdated entries count; entries before account creation count; fund Invested, Value and Gain with and without a value update; loan principal and interest; plan occurrences on day 29 to 31; idempotent keys; "Needs funds"; Free to spend with plans due later this month.
*Done when:* all law tests pass with no Flutter or Hive import in `core/`.

**M2. Store, service, state.** `money_store.dart`, `money_service.dart` (spend, receive, move, edit, delete, undo, add, pause and end plan), `plan_runner.dart`, `money_state.dart`. Wrap the old repository's write methods (section 4). Start the runner after the first frame, on resume and after a plan is saved. Per-plan `try/catch`; one summary notification per run; log `$e`.
*Done when:* creating, editing and deleting an entry through any old or new path updates one snapshot and every balance; the runner never posts the same key twice.

**M3. Main account and balance check.** `money2_main_account_id`, picker in settings; the balance-check and duplicate-review screens from section 6.
*Done when:* a backup is written before any change, and "Keep today's balances" leaves every displayed balance unchanged.

**M4. UI foundation.** Motion kit, `DepthCard`, floating nav bar with stable destination ids, lazy shell, `AnimatedMoneyText`, `PressScale`, shared progress bar.
*Done when:* the shell switches tabs with the motion rules in section 7 and deep links open the right destination.

**M5. Today, quick add, Activity.** Build both screens and the add and edit sheet. Wire Undo.
*Done when:* the owner's spend scenario in section 9 passes by eye.

**M6. Plans and Accounts.** Plans tab, add-plan sheet (with inline fund creation and the past-start prompt), Accounts tab, fund page with Invested, Value, Gain and Update value, loan page with paid, outstanding and next due, "Needs funds" state.
*Done when:* the SIP and EMI scenarios in section 9 pass.

**M7. Link everything.** Home cards (`safe_to_spend_card`, `finance_card`, `net_worth_card`, `upcoming_bills_card`) and the AI context read `MoneySnapshot`. Map every old deep link. Keep the legacy pages reachable from Accounts > More and make sure they use the snapshot or the same boxes without a second writer.
*Done when:* Home and Money always show the same numbers; `grep` finds no screen computing a balance outside `core/`.

**M8. Smoothness pass, cleanup, QA.** Profile on a device and fix every over-budget frame (rules in section 7). Remove dead Finance code and the old shell once the owner approves. Update `APP_DOCUMENTATION.md` and `MANUAL_QA.md`. Add the widget tests from section 10.
*Done when:* section 9 passes on a device and the numbers in section 7 are recorded before and after.

---

## 9. Acceptance scenarios (the owner's real cases)

1. **Spend.** Spent ₹200 from Main: Main falls by ₹200 at once on Today, Activity and Accounts; Undo restores it.
2. **Backdated spend.** A spend dated yesterday, and one dated before the account was created, both reduce the balance.
3. **Edit and delete.** Changing an old entry from ₹200 to ₹250, or deleting it, updates every balance.
4. **SIP.** A ₹1,000 SIP on the 5th: on the 5th Main falls ₹1,000 and the fund's Invested rises ₹1,000, once. Reopening the app or killing and restarting posts nothing again. After Update value ₹2,300 and the next SIP, Value is ₹3,300, Invested is ₹3,000, Gain is ₹300.
5. **Past start.** A SIP with a start date three months ago asks first; "Start from today" posts nothing in the past.
6. **Needs funds.** Main has ₹500 and a ₹1,000 SIP is due: nothing posts, the plan shows "Needs funds", one notification is sent. After adding money, the next run posts it.
7. **EMI.** Outstanding falls by the principal part only; interest appears as an expense.
8. **Move.** Main to a savings account changes both and the total stays the same.
9. **Restart.** Kill and restart: every number is identical.
10. **Scale.** 5,000 entries: Activity scrolls within the frame budget; Today opens within 300 ms.
11. **Linked.** Home cards, Today, Accounts and the AI context show the same Main balance and Free to spend at all times.

---

## 10. Test plan (M8, plus the M1 law tests)

Widget tests: nav bar and deep links; `AnimatedMoneyText` reaches the final value and respects reduced motion; Activity insert and delete with Undo; add-plan sheet blocks a SIP without a destination; Needs funds state; balance-check screen both buttons. Static checks that must come back empty: `Hive.box` in `lib/features/money/ui`; `BackdropFilter` in Finance; `shrinkWrap: true` in Finance lists; `Border.all` on cards; `.listenable()` without `keys:` on `settings`; any balance arithmetic outside `core/`.

---

## 11. Rules of engagement for the agent

1. **Plan first.** Produce an implementation plan and wait for approval before changing code. After each milestone produce a short walkthrough.
2. **Edit in place.** Never write placeholder comments such as `// ... existing code ...` into source files. Several files are very large; use targeted edits and re-read a file right before editing it. Never rewrite a large file in one go.
3. **Quote before you edit.** Confirm each finding in section 2 against the real code before relying on it. If it differs, stop, say so, and adapt.
4. **Read the real APIs** (Hive, `flutter_local_notifications`, `fl_chart`, Flutter's `Hero`, `SliverAnimatedList`) in the pinned versions in `pubspec.lock`. Do not rely on memory.
5. **No mass replace** without printing and checking every match.
6. **Never claim** that something runs smoothly, notifies, or passes unless you ran it. If Flutter or a device is not available, say so and list the item under "Not verified".
7. **Stop and ask before:** upgrading Flutter or a major package, adding a package, changing the application id or signing, adding Android permissions, deleting user data, removing `lib/models/goals.dart`, changing any `typeId`, field index or box name.
8. **Keep what works.** Do not rename routes, deep-link strings, registry ids (for example the home card id `galaxy_watch`), settings keys or existing file paths unless a task says so.
9. **No fake data.** Empty states are real empty states with one clear action.