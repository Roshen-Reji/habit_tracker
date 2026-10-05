# Habit Tracker MVP 4.2: Money that adds up, real Health data, buttery UI

Spec for Claude Opus working autonomously in the repo root (`Roshen-Reji/habit_tracker`). Based on a read-only audit of `master` at commit `a69a0c2`. If `MVP_4_1.md` is in the repo, this file replaces its Phase 1 and Phase 2 (the Samsung SDK and AGEs tracks) and keeps its safety ideas, which are repeated here in Phase 0 so this file stands alone.

Nothing was compiled or run in the audit (no Flutter SDK, no device). Every finding comes from reading code. Markers:
- **VERIFY:** not confirmed. Check it in the code, the package source or on the device before relying on it.
- **Default:** a planner decision the owner has not confirmed. Proceed with it and list it in your phase report.
- **OWNER:** needs the owner's answer.

---

## 1. Mission

The owner reported four problems. All four are confirmed in the code.

1. **SIPs and EMIs do not accumulate.** A fund account (for example "Flexi Cap Fund", SIP ₹1,000 a month) should receive ₹1,000 every month, automatically, with the same amount leaving the main account. Loan EMIs should work the same way. The owner also wants a way to add the account's current balance, and ₹ appears twice in places.
2. **Watch data sync is a placeholder.** It reports "synced" but reads no real Health data.
3. **The Health tab is wrong.** Remove all "Samsung Galaxy" data and branding and use plain Health data.
4. **The UI is laggy.** The owner wants it smooth, fresh and buttery.

Order of work: Phase 0 (safety, ship alone), then Money, Health data, Health tab, Smoothness, then Phase 5 (all testing, docs, release).

**Rule for the whole repo: never fabricate health data.** A missing value is `null` and the UI shows "—".

---

## 2. Audit findings

Severity: **C** critical (wrong or corrupted data), **H** high (feature does not work), **M** medium, **L** low.

### 2.1 Money (SIP, EMI, balances, ₹)

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| M1 | C | **Recurring rules only post when the Recurring page is opened.** `postRecurringDue()` is called from exactly one place, `initState` of `recurring_page.dart` (L31). Nothing calls it at app start, on resume or on a schedule. So "every month, automatically" does not happen unless the owner visits that page. EMI rules default to `autoPost = false`, so they only appear as "due" items that need Mark Paid. | `recurring_page.dart` L31, `finance_repository.dart` `postRecurringDue`, `recurring_edit_sheet.dart` L115 |
| M2 | C | **A fund's balance ignores contributions made after its latest valuation.** `LedgerEngine.balance` returns the latest `Valuation.value` for any valued asset (`investment`, `gold`, `fd`, `crypto`, ...) as soon as one exists on or before the date, and skips all transactions. So once the owner uses "Log New Valuation" (today the only way to enter a current balance on an account), every later SIP leaves the displayed balance unchanged. Net worth and balance history inherit this. | `engine/ledger.dart` L8-27 |
| M3 | C | **Two SIP systems run together and can double-debit.** The legacy `SipService.runDue()` still runs at boot (`main.dart` L92) and on every resume (`app.dart` L45). It reads the old `finance_settings['planner']['sips']` and posts a plain **expense** ("SIP · name", key `sip_{id}_{yyyy-MM}`) with no destination account. The MVP 3 migrator copied the same SIPs into `RecurringRule(kind: 'sip', autoPost: true)`, which post as `investment` transactions with source ref `rec:{id}:{yyyy-MM-dd}`. The two keys differ, so the same SIP can be debited twice, and the legacy debit never reaches a fund account. **VERIFY** with a fixture that has one migrated SIP. | `data/services/sip_service.dart`, `data/migrations/finance_migrator.dart` L578-600 |
| M4 | H | **A SIP or EMI may have no destination.** `toAccountId` is optional, and `postRecurringDue` defaults the source to `acc_main` and passes `rule.toAccountId` as is. With no destination the money leaves the main account and no fund or loan account receives it. **VERIFY** whether `recurring_edit_sheet.dart` forces a destination for kinds `sip` and `emi`. | `finance_repository.dart` `postRecurringDue` |
| M5 | H | **EMI posts the whole instalment as principal.** `postRecurringDue` builds the `debt_payment` without `interestAmount`. `LedgerEngine.balance` then treats `amount − 0` as principal repaid, so the loan balance falls too fast and interest is never recorded as an expense. `Account` already has `principal`, `annualRate`, `emi`, `tenureMonths`, `startDate`, and `engine/loan_engine.dart` exists, but the posting path does not use it. **VERIFY** the loan engine's schedule function. | `finance_repository.dart`, `engine/ledger.dart` L84 |
| M6 | H | **No quick way to add a current balance.** The account sheet has only "Opening Balance". The detail page has "Log New Valuation", which is a units and price form. | `account_edit_sheet.dart`, `valuation_history_sheet.dart` |
| M7 | H | **Double rupee symbol.** `FormatUtils.formatMoney`, `formatCurrency` and `formatCompactCurrency` already include the currency symbol (default ₹), but **42 call sites in 9 files** prepend a literal `₹`, giving "₹₹1,000.00": `cash_flow_page.dart`, `csv_import_page.dart`, `sms_import_sheet.dart`, `money_overview_tab.dart`, `reports_page.dart`, `split_group_detail_page.dart`, `split_groups_page.dart`, `what_if_sheet.dart`, `upcoming_bills_card.dart`. | `grep -rnE "₹\$\{FormatUtils\.format"` |
| M8 | M | **Mixed currency symbols.** `FormatUtils.getCurrencySymbol()` defaults to ₹, but the home `finance_card.dart` formats with a hard-coded `$` and `settings_page.dart` (L268) defaults `currency_symbol` to `$`. | `finance_card.dart` L28, `settings_page.dart` L268 |
| M9 | M | **The home finance card and the AI still read legacy finance data.** `finance_card.dart` uses the old `FinanceCalculator` and `planner` SIPs; `ai_service.dart` (L1419-1421) reads `planner`. Neither sees the new accounts or recurring rules. | `finance_card.dart`, `ai_service.dart` |
| M10 | M | **Posting is quadratic.** `postRecurringDue` and `getUnpostedDueItems` call `transactionBox.values.any(...)` for every rule and date. | `finance_repository.dart` |

### 2.2 Health data

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| H1 | C | **The "Samsung bridge" generates fake data.** `readDailyActivity`, `readSleep`, `readExercises`, `readBodyComposition`, `readEnergyScore` and `readAgesIndex` return values computed from the calendar date (sleep is always 23:15 to 06:45, weight is always 72.4 kg, AGEs samples are labelled as measured by a watch sensor). No Samsung SDK class is imported and there is no AAR. `checkPermissions` says "granted" for everything whenever Samsung Health is installed, and `requestPermissions` only opens the Samsung Health app. This is why sync "does nothing real". | `SamsungHealthBridge.kt` |
| H2 | C | **Sync is ungated and writes fake data into core data.** `wear_enabled` is never read. `app.dart` syncs on every resume (`wear_auto_sync_on_resume` defaults to true). Each sync writes generated rows, adds fake burn entries to `diet_logs`, adds fake sleep and workout lines to the journal, and calls `WakeService.logWake` from the fake 06:45 sleep end, which evaluates the wake task and awards XP. The owner's real data may already contain these. | `app.dart` L43-48, `sync_service.dart` |
| H3 | H | **Mapper defects invent values.** Active kcal is guessed as 35% of total, energy score falls back to 75, AGEs to 45.0, journal sleep score to 80, and `bodyWaterPct` is filled from a water mass in kg. | `samsung_health_source.dart`, `sync_service.dart` |
| H4 | H | **Samsung-only data cannot come from Health data.** Energy Score and the AGEs Index are Samsung-specific, and Android Health Connect has no such types (**VERIFY** against the package's type list). Per the owner, they are removed rather than replaced. | |
| H5 | M | **Sync is slow and un-batched.** One `await` per record upsert on the UI isolate. | `sync_service.dart` |

### 2.3 Health tab and smoothness

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| U1 | H | **Health tab.** The third tab is labelled `GALAXY WATCH`, three equal `Expanded` buttons with 12 px letter-spaced labels and an icon (likely to clip on narrow phones). Tab content is swapped with a ternary, so every switch rebuilds the 846-line `FitnessTab` and loses scroll position. Samsung and Galaxy branding is spread over `fitness_tab.dart`, `wearables_settings_page.dart`, `galaxy_watch_card.dart`, `settings_page.dart` and `health_calculator.dart`. | `health_page.dart` L58-86 |
| U2 | C | **Home stack paints several blurs per frame.** Per visible card: an `ImageFiltered` blur, an `Opacity`, a perspective `Transform`, a `HomeCardFrame` with its own `BackdropFilter(sigma 18)` and two large `BoxShadow`s (blur 26 and 24). On top, one full-screen `BackdropFilter` "lens" (sigma 9 to 13) over the star field, rebuilt on every scroll tick. Blur inside blur over a changing backdrop forces offscreen layers every frame. 17 `BackdropFilter`/`ImageFilter.blur` uses exist in 7 files. | `wallet_card_stack.dart` L177, L324; `home_card_frame.dart` L53-71 |
| U3 | C | **Every scroll tick rebuilds all cards.** `AnimatedBuilder(animation: _scrollController)` rebuilds the full list of cards (up to 19 registered), each with its own Hive listeners and calculations, instead of only updating their transforms. | `wallet_card_stack.dart` |
| U4 | H | **The star background repaints constantly.** `StarBackground` runs a 4-second repeating controller and also listens to the scroll controller, repainting 50 stars one by one every frame behind the blurs. | `widgets/star_background.dart` |
| U5 | H | **Whole-app rebuilds.** `app.dart` wraps `MaterialApp` (and both `ThemeData` objects) in `ValueListenableBuilder(Hive.box('settings').listenable())`, plus another builder on `NowPlayingService.currentDominantColor`. Any write to `settings` (sync timestamps, layout, XP, calorie target) or any song change rebuilds the whole app. Across the app there are 49 `.listenable()` uses and none pass `keys:`. | `app.dart` L56-110 |
| U6 | H | **Slow start.** `main()` awaits about 25 steps in sequence before `runApp`, including the finance migrator, the encrypted journal box, the legacy SIP run, notification init and medicine reminders. | `main.dart` |
| U7 | M | **Non-lazy lists.** 38 `SingleChildScrollView`, 14 `ListView(` (non-builder), 6 `shrinkWrap: true`, and only 4 `RepaintBoundary` in the whole app. **VERIFY** which screens hold long lists (transactions, journal timeline, fitness tab). | |
| U8 | M | **Continuous animations** in `speech_vault_page`, `tasks_page`, `home_chat` and `wobbly_slider` (`repeat`), plus 28 `flutter_animate` uses. **VERIFY** they pause off-screen. | |
| U9 | M | **Derived data recomputed in `build`.** The ledger scans all transactions once per account; the legacy finance card recomputes on every transaction change. | `engine/ledger.dart`, `finance_card.dart` |

**Looks right on reading (do not redo):** typeIds 60-68 and finance 40-50 do not collide; `RecurringRule` already has `accountId`, `toAccountId` and `kind` (`sip`, `emi`), so no schema change is needed for SIP and EMI links; the `XpLedger` delta approach exists; `DietDayLog.totalBurned` skips superseded entries; `FlutterFragmentActivity` is in use; `minSdk = 29`.

---

## 3. Owner decisions

Do not block on these. Ask once, in the Phase 0 report.

| # | Question | Default if unanswered |
|---|---|---|
| Q1 | **Past start date.** When a SIP or EMI is created with a start date in the past, post the missed instalments or start from today? | Ask in the sheet, preselected "start from today" (never back-charge silently, as MVP 2 decided). |
| Q2 | **Old SIP debits.** Past debits titled "SIP · name" are plain expenses that never reached the fund. Convert them to transfers into the matching fund? | Show a preview list and let the owner confirm each. Never automatic. |
| Q3 | **Third tab name.** | `HEALTH DATA` with the heart-pulse icon. |
| Q4 | **Home depth-of-field.** The blur on cards behind the focused one is the biggest cost. OK to replace it with scale, fade and a dark overlay while keeping the glass look through gradient and border? | Yes. |
| Q5 | **"2₹".** Read as a doubled symbol ("₹₹"). If you meant something else (for example a literal ₹2 amount), send a screenshot. | Doubled symbol. |
| Q6 | **Energy Score and AGEs.** Removed from the UI and purged, since all existing values were fabricated and Health data cannot supply them. | Yes, with a backup. |

---

## 4. Working agreement

- **Testing last (owner's standing instruction).** Phases 0 to 4 have no test tasks. After each task run only `dart format .` and `flutter analyze`. All tests, device QA, docs and release are Phase 5. Keep logic in pure Dart so Phase 5 is cheap.
- Branches `mvp4.2/p0-safety`, `mvp4.2/p1-money`, ...; one commit per task; the app compiles at every commit. Run `dart run build_runner build --delete-conflicting-outputs` after any `@HiveType` change (none are expected).
- **Data safety.** Never change an existing `typeId`, `@HiveField` index or box name. Keep adapters registered for models that are no longer used (`EnergyScoreDay` 64, `AgesSample` 65) so existing boxes still open. Migrations are versioned, idempotent, preceded by a JSON backup, and abort on error. Never delete user rows automatically. No Hive access from a background isolate.
- **Never claim** that Health Connect, permissions, sync, notifications or frame rate work unless you ran them on a device. List them under "Not verified" in the phase report and add them to `MANUAL_QA.md`.
- Read the real API (pub cache source for packages, Health Connect docs) before writing calls.
- **Stop and ask before:** upgrading Flutter, changing the application id or signing, deleting user data, adding Android permissions beyond those in P2-2, removing `lib/models/goals.dart`.
- Phase report (short): what changed, what you ran, what you could not verify, defaults applied, questions.

---

## 5. Phases

### Phase 0: Safety stop (ship first, alone)

**P0-0 Baseline.** Run `flutter analyze` and `flutter test` on a clean checkout and record the results. Record the real typeIds in use. **Performance baseline:** on a device, in `--profile` mode, record cold-start time to first frame, and frame build/raster p90 and p99 while (a) scrolling the home stack for 10 seconds, (b) switching Health tabs, (c) scrolling the Transactions list. If there is no device, write "not measured" and continue.

**P0-1 Gate the sync.** `SyncService.sync()` returns immediately unless `wear_enabled` is true and the active source reports a real, granted state. Start, resume and timer triggers respect it. `wear_enabled` becomes true only after a successful real permission grant. Result: nothing wearable runs until the owner connects the real source.

**P0-2 Remove every generator.** Delete all `generateNative*` functions and the whole Samsung bridge path (`SamsungHealthBridge.kt`, its registration and unregistration in `MainActivity.kt`, `samsung_health_source.dart`). Delete `MockWearableSource` from `lib/` (move a fake into `test/` in Phase 5). Remove the "Simulator" toggle and `wear_use_mock_provider`. Until Phase 2 lands, the source is a stub that returns "not connected".

**P0-3 Stop the legacy SIP run.** Remove the calls to `SipService.runDue()` in `main.dart` and `app.dart`. Keep the legacy `planner` data in place (never delete it). Keep `SipService.migrateSips` and `getNextDebitDate` only until P1-7 removes their last callers.

**P0-4 Purge the simulated data** (versioned, idempotent, `wear_bridge_version = 2`):
1. Back up the affected boxes to `backups/mvp4_2_purge_<timestamp>.json` in the app documents directory. If the backup fails, abort and change nothing.
2. Show a dialog "Remove N simulated watch records?" with Remove or Later. While on Later, wearable surfaces stay hidden (they are already gated by P0-1).
3. On Remove:
   - Clear `wear_daily`, `wear_sleep`, `wear_exercise`, `wear_body`, `wear_energy`, `wear_ages`.
   - In `diet_logs`, remove `CalorieBurnEntry` rows whose `id` starts with `burn_shealth_` or whose `externalId` starts with `shealth_`; clear `supersededBy` on any entry whose value starts with `shealth_` (this restores manual burns the generator hid).
   - Remove journal auto-log events with `source == 'samsung_health'` through `JournalDayRepository.removeAutoLog`. Never touch the owner's own text.
   - Delete `WakeLog` rows with `source == 'samsung_health'` and their `TaskDayLog` rows, set `XpLedger.set(dayKey, 'wake_on_time', 0)` for each affected day (the ledger reverses XP on that day's own date), then recompute the wake goal's `isCompleted` and `streakCount` from the remaining logs.
   - **VERIFY** whether any `WeightEntry` was written with a wearable source; remove only those.
   - Clear `wear_last_sync`, `wear_last_sync_ms`, `wear_change_tokens`; set `wear_enabled = false`.
4. Show a result summary. Never silent. Delete nothing that does not match a rule above.

**Done when:** a build with no connected source writes nothing to `wear_*`, `diet_logs`, journal, wake logs or XP; the legacy SIP run is gone; the purge only removes matching rows and is safe to run twice.

---

### Phase 1: Money that accumulates

**Design (no schema change).** A SIP or EMI is a `RecurringRule` whose `toAccountId` is the fund or loan account and whose `accountId` is the paying account (default `acc_main`). The account's screen finds its rules with `rules.where((r) => r.toAccountId == account.id)`.

**P1-1 Fix the balance of valued accounts (M2).** In `LedgerEngine.balance`, for a valued asset with a valuation on or before the cutoff, return `latestValuation.value + Σ flows dated after the valuation's day`, where flows use the same `transfer` and `investment` rules as today for both the source and destination side. With no valuation the behaviour is unchanged (opening balance plus flows). Treat a valuation as end-of-day: flows dated on the valuation's day are assumed included (Default; document it). Apply the same rule in `accountBalanceHistory` and net worth. `investedAmount` stays as is (opening plus net inflows). The detail page shows **Invested**, **Current value** and **Gain/Loss = current − invested**.

**P1-2 Auto-post at the right times (M1, M10).** Add `RecurringRunner.run(now)` that calls `postRecurringDue` for every active `autoPost` rule. Call it at app start (after boxes open, off the first-frame path), on resume, and right after any rule is created, edited or resumed. Build the set of existing `sourceRef`s once per run instead of scanning per rule and date. Post only occurrences dated on or before today. Catch up at most 60 months per rule per run. Run at most once per calendar day unless a rule changed (`recurring_last_run` in `finance_settings`). Clamp days 29 to 31 to the month's last day (**VERIFY** `RecurringEngine.occurrences` already does). Show a notification on each post: "SIP ₹1,000 debited: Main → Flexi Cap Fund" (use `NotificationService.showInstantNotification`). Post even if the source balance is too low (real SIPs debit regardless) and add "balance low" to the notification (Default).

**P1-3 SIP and EMI sections in the account UI.**
- Creating or editing an account of kind `investment`, `gold`, `fd`, `crypto` or `other_asset`: add a **Monthly SIP** section with a switch, amount, day of month, "Pay from" (default main), and start date. Saving creates or updates the linked rule: `kind 'sip'`, `toAccountId = this account`, `autoPost = true`, `frequency 'monthly'`. Past start date follows Q1.
- Creating or editing a `loan`: an **EMI** section prefilled from `account.emi`, plus day of month and "Pay from". Linked rule: `kind 'emi'`, `autoPost = true`, `toAccountId = this loan`.
- Account detail shows the linked rules with Pause, Resume, Edit and Stop, a "next instalment" line, and a short cumulative history ("12 instalments, ₹12,000 invested"). For loans: paid n of N, principal paid, interest paid, outstanding, next due date, estimated payoff date.
- `recurring_edit_sheet.dart`: for kinds `sip` and `emi`, require a destination account (M4).

**P1-4 Add the current balance (M6).** Add **Update current value** on the account detail page for valued assets: one amount field, date defaulting to today, optional units and price under "More". It creates a `Valuation`. In the create sheet for valued assets, show **Invested so far** (stored as `openingBalance`) and **Current value** (if different, create a `Valuation` dated today). For plain bank, cash and wallet accounts keep the existing reconcile dialog and label it "Set current balance".

**P1-5 EMI interest split (M5).** When posting a rule of kind `emi` linked to a loan with `principal`, `annualRate` and `tenureMonths`, compute that month's interest and principal from the loan engine (**VERIFY** the schedule API) and set `interestAmount`. Interest is recorded as a debt-interest expense, principal reduces the liability. Stop posting and set the rule `ended` when the schedule completes or the outstanding reaches zero. If loan fields are missing, post as today and show "Add rate and tenure for the interest split".

**P1-6 Rupee fixes (M7, M8).**
- Remove the literal `₹` in front of every `FormatUtils.formatMoney`, `formatCurrency` and `formatCompactCurrency` call (the 42 sites in M7). Where a sign is needed, build it as `${v >= 0 ? '+' : '-'}${FormatUtils.formatMoney(v.abs())}`. Add `FormatUtils.signed(double)` for this.
- **VERIFY** the other literal `₹` uses in `ai_service.dart`, `query.dart`, `insights_engine.dart`, `what_if_engine.dart`, `account_edit_sheet.dart`, `transaction_sheet.dart`, `goal_edit_sheet.dart` and `upcoming_bills_card.dart`: they are fine only if they are not followed by a formatter that already adds the symbol.
- One source of truth: every amount goes through `FormatUtils`. Default `currency_symbol` is ₹ everywhere (fix `settings_page.dart` L268 and the `$` in `finance_card.dart`).

**P1-7 Retire the legacy finance reads (M9).** Rewire `FinanceCard` to the new `FinanceController` (month income, spend, net, and the next SIP or EMI from the recurring rules) using `FormatUtils`. Rewire the planner read in `ai_service.dart` (L1419-1421) to recurring rules. After this, remove the last callers of `SipService`.

**P1-8 Duplicate and legacy-debit review (Q2).** One-time, versioned check. Find (a) months where both `sip_{id}_{yyyy-MM}` and `rec:{id}:{yyyy-MM-dd}` exist for the same SIP, and (b) legacy "SIP · name" expenses with no destination. Show a review sheet with a preview: **Remove duplicates** (backup first) and **Convert to transfer into <fund>** per item. Never act automatically.

**Done when:** an account "Flexi Cap Fund" with a ₹1,000 SIP on the 5th shows +₹1,000 invested on the 5th of each month, the main account shows −₹1,000, nothing is debited twice, and entering a current value of ₹2,300 followed by the next SIP shows ₹3,300 and a gain of ₹300 once the invested total is ₹3,000.

---

### Phase 2: Real Health data (Android Health Connect)

**Decision.** Replace the Samsung path with one real source: **Android Health Connect**, the system store that Samsung Health and other apps write into. Samsung Health must be set to share data to Health Connect (in-app guide in P2-5; the menu path varies by version, **VERIFY**). No Samsung SDK file, no Developer Mode, no partner registration. Health Connect is built in on Android 14 and later; older versions need the Health Connect app from Google Play (the package can open the install page, **VERIFY**).

**P2-1 Package.** Add the Flutter `health` package (current stable 13.x at the time of writing; pin an exact version). Read its source in the pub cache first: the exact type names, the permission request flow, how `uuid` and `sourceId` are exposed, and whether it requires a newer `compileSdk`, Kotlin or Gradle than the project uses. If it conflicts with the Java 17 and Gradle setup already in `android/`, stop and report; the fallback is a small Kotlin bridge over `androidx.health.connect:connect-client` on a new channel following the `MediaSessionBridge` pattern, behind the same Dart interface.

**P2-2 Android setup.** `AndroidManifest.xml`: add read-only Health Connect permissions for steps, distance, active calories, total calories, sleep, exercise, heart rate, resting heart rate, weight, body fat, and `READ_HEALTH_DATA_HISTORY` only if a backfill beyond 30 days is wanted (**VERIFY** how far back Health Connect lets an app read without it). Add the Health Connect `<queries>` package entry and the permission-rationale activity or alias that Health Connect requires on each Android version (**VERIFY** against the package README). Do not add any other permission. Keep `FlutterFragmentActivity` (needed for the permission contract).

**P2-3 `HealthConnectSource`** implements the existing `WearableSource` interface (remove `fetchEnergyScores` and `fetchAgesSamples` from the interface and from `SyncService`). Mapping, in canonical units (kg, m, kcal, minutes):
- **Steps and distance** from the plugin's aggregate call per day, not by summing raw records (Health Connect de-duplicates overlapping sources in aggregates).
- **Active and total calories** per day, as separate fields. Never derive one from the other.
- **Sleep sessions** with stages; the day is the local date of the session's end; naps flagged; stage minutes from the stage records.
- **Exercise sessions** with type, title, start, end, duration, calories where present, average and max heart rate where present, distance where present.
- **Heart rate and resting heart rate**: daily resting value, daily average where available.
- **Weight and body fat** samples.
- A missing field is `null`. No defaults. Keep each record's source app (`dataOrigin`) in `sourceDevice` as plain text for Diagnostics only.
- External id = the record's `uuid` (**VERIFY** it is exposed), so upserts are idempotent.

**P2-4 `SyncService` rewrite.** Single-flight. Triggers: app start, resume (at least 10 minutes apart), manual, and after a permission grant. First run backfills `wear_backfill_days` (default 30); later runs re-read the last 3 days plus today. Per data type `try/catch`, so one failing type never blocks the others. Batch writes with `putAll` per box instead of one `await` per record. No work on the first-frame path; run after the UI is up. Status model, shown honestly in the UI: Not available, Needs update or install, Needs permission, Connected with no data yet, Connected, Error (with a readable reason). **"Synced" is shown only when records were actually read**, and the message includes counts ("Read 7 days: 52,310 steps, 6 sleep sessions, 3 workouts").

**P2-5 Settings: Health Data** (rewrite `wearables_settings_page.dart`; rename the entry in `settings_page.dart`). Status chip, **Connect** (request permissions), **Open Health Connect settings**, Sync now, last sync, per-type toggles, backfill days, workout calorie credit mode, an AI-sharing toggle (default off), and a **Diagnostics** screen showing, for the last sync, the record count per type with first and last timestamps and the source apps seen. A short setup guide: install or update Health Connect, turn on sharing from the phone's health app, grant permissions here. Remove every "Samsung", "Galaxy", "Simulator" and "BioActive" string.

**P2-6 Wire real data into the app** (each reads one `dayView(dayKey)` from `WearableRepository`, never raw boxes):
- **Calorie tracker.** Each workout becomes one `CalorieBurnEntry` (`id = health_{externalId}`, `source = 'health_connect'`), using the session's calories. De-duplicate against manual entries (same day, start within 30 minutes, or similar name and duration within 25%; mark `supersededBy`, never delete; show "merged with workout" with Undo). The day's total burned (resting plus active) is shown as a read-only row and is not added to the target (Default). Imports never trigger the old flip-XP. Put this logic in a pure `calorie_reconciler.dart`.
- **Wake-up task.** If `wake_infer_from_sleep` is on and there is no chat or manual log for the day, create an inferred wake log from the main sleep session's end (the longest session ending before 14:00; naps excluded), marked "(from Health data)". A chat or manual log always wins. Read `wake_infer_from_sleep` and `journal_autolog_kinds`, which are defined today but never read.
- **Journal auto-log.** Sleep summary, one line per workout, steps, written without unlocking and respecting `journal_autolog_kinds`. Omit the sleep score when absent.
- **Health composite.** Align `HealthCalculator` with weights calories 25, medicine 20, missions 15, sleep 20, activity 20, renormalised over the components that have data. With no Health data it must reproduce the old 35/35/30 results exactly. Remove the AGEs and "sleep score" branches that depend on Samsung-only fields.
- **XP.** Use ledger rules only (`steps_goal`, `steps_stretch`, `active_time_goal`, `workout:{id}`, `sleep_goal`), never `addXP` from this code; 40 XP daily cap on these rules. Keep the diet-deficit flip logic as it is for now.
- **Weight.** Write a `WeightEntry` (source `health_connect`) for a day only when no manual entry exists that day (manual wins). **VERIFY** `WeightEntry` has `source` and `externalId`.
- **AI.** Add a local `wear` intent answering steps, sleep, workouts, weight and heart rate from `dayView`, saying so plainly when data is missing. `AiContext.buildWearContext()` returns one compact line, attached to Gemini calls only when the AI-sharing toggle is on. Keep the `wake` intent routing ahead of the task-create check and the diet scan.
- **Metric tasks.** **VERIFY** whether `Goal.kind == 'metric'` has any logic (the fields exist). If not, implement: sync updates `currentValue` for `steps`, `active_minutes`, `sleep_minutes`, `workout_minutes`; reaching the target completes the task through the ledger rule `metric:{goalId}`, not `Goal.complete()`.

**Done when:** on a phone with Health Connect and Samsung Health sharing enabled, the Diagnostics screen's record counts and the Health tab's numbers match what Samsung Health shows for the same days; a re-sync adds nothing; with Health Connect missing or permission denied the app stays fully usable and says what to do.

---

### Phase 3: Health tab and Samsung cleanup

**P3-1 Tab bar (U1).** Replace the hand-built row in `health_page.dart` with a `TabBar` and `TabBarView` (or a segmented control with a `PageView`), three tabs: `MEDICINE`, `WEIGHT`, `HEALTH DATA` (Q3). Labels never clip (`FittedBox` or a shorter label on narrow widths), swipe between tabs, each tab keeps its state and scroll position (`AutomaticKeepAliveClientMixin`), the `initialTab` argument keeps its meaning (0, 1, 2).

**P3-2 Health Data tab** (rename `FitnessTab` content; keep the file path to keep the diff small). Sections, each shown only when it has data: **Today** (steps ring against `step_goal_default`, active calories, distance, active minutes), **Sleep** (last night's duration and stage bar, 7-day chart, wake-time consistency), **Workouts** (list and detail), **Heart** (resting heart rate trend), **Body** (weight and body fat trend). States: not connected (Connect call to action), loading (skeleton without shimmer), connected with no data (one explanation line), error. "—" for missing values. Build lists lazily (slivers or `ListView.builder`), precompute chart series in the repository (not in `build`), wrap each chart in a `RepaintBoundary`.

**P3-3 Remove Samsung and Galaxy data.** Delete the AGEs Index card, the Energy Score UI and every "Galaxy Watch 7", "Samsung Health", "BioActive Sensor" string and icon in `fitness_tab.dart`, `galaxy_watch_card.dart`, `wearables_settings_page.dart`, `settings_page.dart` and `health_calculator.dart` comments. Keep the home card's registry **id** `galaxy_watch` (saved home layouts reference it) but change its title to "Activity" and its content to Health data. Do not remove the `EnergyScoreDay` and `AgesSample` adapters (data safety).

**Done when:** `grep -rniE "galaxy|samsung|bioactive|ages index"` over `lib/` and `android/app/src/main/AndroidManifest.xml` returns nothing except the retained adapter files, the home-card id, and the unrelated `SamsungVideoAssistant` class in `speech_vault_page.dart` (leave that one; report it).

---

### Phase 4: Smoothness ("so smooth, so fresh, buttery")

Targets, measured in profile mode on a device: no sustained frame over the display's frame budget (16.6 ms at 60 Hz, 8.3 ms at 120 Hz) while scrolling the home stack, switching Health tabs and scrolling Transactions; cold start to first frame under 1.5 seconds. Record before and after in the report. Without a device, apply the changes and report "not measured".

**P4-1 Home stack, the biggest win (U2, U3).** Keep the look, drop the per-frame blur:
1. Remove the per-card `ImageFiltered` blur and the full-screen "lens" `BackdropFilter` (Q4). For cards behind the focused one, use scale, fade (via `FadeTransition` or a colour overlay, not an `Opacity` widget) and a dark overlay.
2. In `HomeCardFrame`, replace the `BackdropFilter(sigma 18)` with a pre-composed translucent gradient plus the existing hairline border. Replace the two large shadows with one cheap shadow, applied only to the focused card.
3. Replace the `AnimatedBuilder` that rebuilds all cards on every scroll tick with a `Flow` (a `FlowDelegate` with `repaint: _scrollController`) or an equivalent that updates transforms in paint only, so card widgets are built once.
4. Build only the cards within three positions of the focus; give the rest a `SizedBox.shrink()`.
5. Keep a `RepaintBoundary` directly under each transform so card contents are not re-rasterised while the transform moves.

**P4-2 Star background (U4).** Paint all stars with one batched `drawPoints` or `drawRawPoints` call, reduce to about 24 stars, drop the scroll listener in favour of a transform on a cached layer, and pause the ticker when the home route is covered, the app is paused, or the system reduce-motion setting is on.

**P4-3 Scope rebuilds (U5).** Pass `keys:` to every `box.listenable()` (49 sites; at minimum `app.dart`, `wallet_card_stack.dart`, every home card). The `MaterialApp` listens only to `theme_mode` (and the accent if it is a setting). Build both `ThemeData` objects once per mode and accent, not on every rebuild. Move the `NowPlayingService.currentDominantColor` builder down to the widgets that use it (mini player, now-playing card) instead of wrapping `MaterialApp`.

**P4-4 Data work off the hot path (U9, M10).** Compute the finance summary once per change (memoise on the controller's `_notify`), not per `build`. Compute all account balances in a single pass over the transactions grouped by account instead of one full scan per account. Keep heavy jobs (backfill, catch-up posting) off the first-frame path and batch Hive writes with `putAll`.

**P4-5 Startup (U6).** Open only what the first frame needs (settings, goals, the boxes the home cards read). Open independent boxes with `Future.wait`. Run the finance migrator, journal box, wake rollover, recurring runner, notification init and medicine reminder reschedule after the first frame (`addPostFrameCallback` or `unawaited`). Cheap version-flag checks stay in front of any migration. **VERIFY** ordering dependencies (adapters before boxes; the migrator before finance screens).

**P4-6 Lists and screens (U7, U8).** Convert long `Column` + `SingleChildScrollView` screens to slivers or `ListView.builder` (Transactions, Journal timeline, Health Data tab, Accounts, Recurring). Remove `shrinkWrap: true` inside scrollables where an item count can be large. Add `const` constructors and `RepaintBoundary` around list items and charts. Pause repeating animations when off-screen. Replace `Opacity` with `FadeTransition` or `AnimatedOpacity`.

**P4-7 Motion polish.** One motion token set (durations 160 to 320 ms, `Curves.easeOutCubic` for entrances, `Curves.fastOutSlowIn` for moves) in `expressive_tokens.dart`. A consistent page transition for every route through `PageTransitionsTheme` (**VERIFY** what `core/utils/page_transitions.dart` already does and reuse it). Respect `disableAnimations`. Keep haptics to taps on primary controls only.

**P4-8 Optional: high refresh rate.** If the device runs a lower rate than it supports, evaluate `flutter_displaymode` to request the highest mode. Stop and ask before adding the dependency.

**P4-9 Jank probe (debug and profile only).** A `SchedulerBinding.addTimingsCallback` logger that counts frames over budget per route. Not shipped in release builds.

---

## 6. Phase 5: Testing, QA, documentation and release

Everything testing-related lives here. Do not start before Phases 0 to 4 compile.

**5.1 Infrastructure.** `FakeHealthSource` (scriptable data, errors) under `test/`, an injectable clock, a temp-directory Hive harness (copy the pattern in `test/services/*`). Fixtures built by hand from the field map written in 5.7.

**5.2 Unit tests.**

| Area | Must cover |
|---|---|
| Valued-account balance | No valuation (opening plus flows); valuation then later SIP (anchor plus flows); same-day flows; two valuations; flows before the valuation ignored; history and net worth consistent |
| SIP and EMI posting | Monthly post on the due day; idempotent re-run; day 31 in short months; catch-up cap of 60; past start date per Q1; paused and ended rules; destination required; no double debit with legacy data; source and destination both change |
| EMI split | Interest and principal from the schedule; final instalment; ends at zero; missing loan fields |
| Currency | No formatter output contains two symbols; signed formatting; default symbol ₹; a repo-wide search for a literal `₹` directly before `FormatUtils.format` is empty |
| Legacy review | Duplicate detection; convert-to-transfer; nothing automatic; backup written |
| Purge | Only matching rows removed; manual burns restored; wake XP reversed on the event's date; second run is a no-op; backup failure aborts |
| Sync | Gate (disabled, no permission, error: zero writes); per-type failure isolation; single-flight; idempotent upserts; batch writes; "synced" only when records were read |
| Mappers | Units; missing field gives `null`; naps; sleep crossing midnight lands on the wake day; steps from aggregates; active versus total calories |
| Calorie reconciler | Credit mode; no duplicates; 30 minute and 25% de-duplication with Undo; `totalBurned` excludes superseded; no flip-XP |
| Composite | Renormalisation; no Health data reproduces 35/35/30 exactly |
| Wake inference | Main sleep rule; manual or chat log beats inference; setting off |
| Metric tasks, XP rules | Boundaries, reversal when data is revised down, 40 XP cap |

**5.3 Widget tests.** Health page tabs (labels do not clip at 320 dp width, swipe, state kept); Health Data tab in all states; Settings status chips; account sheet SIP and EMI sections; Update current value; purge and review dialogs; home stack builds only nearby cards.

**5.4 Integration (fake source, no device).** Create fund account with SIP, advance the clock three months, check balances, notifications and net worth. Sync, burn entries, XP, composite and journal in one pass; re-sync adds nothing.

**5.5 Static checks.** `dart format .`; `flutter analyze` no new warnings against P0-0; the existing suite (including finance phases 1 to 13) green. Searches that must come back empty: `generateNative`; `SamsungHealth` outside the retained adapters; `?? 75`, `?? 45.0`, `?? 80` on health values; `addXP(` in wearable and wake code; `.listenable()` with no `keys:` on the `settings` box; `BackdropFilter` inside `home_card_frame.dart`.

**5.6 Device QA (owner; add to `MANUAL_QA.md`).**
1. No Health Connect permission: no health rows anywhere, cards show Connect.
2. After the purge: yesterday's fake entries are gone and manual burns count again.
3. Grant permission: steps and sleep match the phone's health app; a re-sync adds nothing; Diagnostics shows real counts and source apps.
4. Run a 30 minute workout: one burn entry, an earlier manual "ran 30 min" merged with Undo.
5. Create "Flexi Cap Fund" with a ₹1,000 SIP on a day close to today (or use the debug clock): main goes down by ₹1,000 and the fund goes up by ₹1,000 once; reopening the app does not post again.
6. Enter a current value, then wait for or simulate the next SIP: the value rises by the SIP amount.
7. Create a loan with an EMI: outstanding falls by the principal part only.
8. No amount shows two ₹ symbols, and no screen shows `$`.
9. Home scroll, Health tabs and Transactions scroll feel smooth, and cold start feels fast. Record numbers or a screen recording.

**5.7 Documentation and release.** `APP_DOCUMENTATION.md` (recurring runner, valued-account balance rule, Health Connect source, sync states, settings keys, Health Data tab, performance rules: no `BackdropFilter` on repeated or animated surfaces, `keys:` on listenables), `docs/HEALTH_FIELD_MAP.md` (Health Connect field, model field, unit, with every unconfirmed field marked), `MANUAL_QA.md`, `README.md`. Bump `pubspec.yaml`. Rollback note: the purge backup JSON, the review-sheet backup, and `wear_enabled = false`. Final report in the usual format with three lists: verified by tests, verified only by reading code, needs the device.

---

## 7. Out of scope

Samsung Health Data SDK, AGEs Index, Energy Score, Samsung partner registration, writing data back to Health Connect, background sync, iOS and HealthKit, any change to existing typeIds, field indexes or box names, signing or application-id changes, removing `lib/models/goals.dart`, and the wake-up task issues listed in `MVP_4_1.md` (wake direction and streak), which are tracked there.1. SIP and EMI not accumulating (four causes)

Auto-posting only happens when you open the Recurring page. Nothing posts SIPs or EMIs at app start, on resume or on a schedule. EMI rules also default to manual confirm.
Fund balances ignore later contributions. Once any value has been logged on an investment account, the balance is just that latest value and every SIP after it is ignored. So "add current balance" actually stops the account growing.
The old SIP system still runs beside the new one. It posts plain expenses with no destination account, and can double-debit a SIP that was migrated to the new system.
EMIs count entirely as principal. No interest split is recorded, so the loan balance drops too fast.

The plan makes the fund account the destination of its SIP rule. Each month the SIP posts automatically (main account down, fund up). There's a quick "Update current value" button, and a one-time review to remove duplicate or old SIP debits, with a backup first and nothing automatic.

2. Double ₹
FormatUtils already adds the symbol, but 42 places in 9 files add another ₹ in front. The home finance card also hard-codes $. I read "2₹" as this doubled symbol; if you meant something else, send a screenshot.

3. Watch sync
The bridge never calls Samsung. It generates fake steps, sleep, weight and AGEs from the calendar date, and sync writes them into your calorie tracker, journal, wake task and XP. The plan stops that, removes the fake data (with a backup and a confirm dialog), and reads real data through Android Health Connect instead. Samsung Health has to be set to share into Health Connect for the watch data to arrive; the plan includes an in-app guide for that. Energy Score and AGEs are removed, since Health Connect doesn't provide them.

4. Health tab and lag

The tab: the third tab becomes HEALTH DATA with proper swipeable tabs that keep their state, and all Samsung and Galaxy text is removed.
The main lag cause: the home card stack paints several blurs and shadows per card on every frame, and rebuilds all cards on every scroll tick. The animated star background also repaints constantly behind the blurs.
Whole-app rebuilds: any write to settings rebuilds the entire app, because no listener filters by key.
Slow start: about 25 awaited steps run before the first screen.
Fixes: swap the blurs for scale, fade and gradient glass, move to paint-only card transforms, scope the listeners, and defer startup work. The agent is also asked to measure frame times before and after if it has a device.

Please answer (defaults are in the file):

For a SIP or EMI with a past start date, should it post the missed months, or start from today?
Is it okay to drop the depth-of-field blur on the home cards? It's the biggest speed cost, and the glass look stays.
Is HEALTH DATA the right name for the third tab?