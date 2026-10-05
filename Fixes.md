# Habit Tracker MVP 4.1: Make the wearable layer real, finish MVP 4, harden

Spec for Claude Opus working autonomously in the repo root (`Roshen-Reji/habit_tracker`). Based on a read-only audit of `master` at commit `a69a0c2` ("Health Upgrade"), which added the MVP 4 code and `MVP_4.md`. Read `MVP_4.md` first; this file corrects and completes it. Where the two disagree, this file wins.

Nothing was compiled or run in the audit (no Flutter SDK, no device). Every finding below comes from reading code. Anything I did not read in depth is marked **VERIFY**: confirm it in the code before acting on it.

Markers:
- **VERIFY:** unconfirmed; check in code, SDK docs or on the device.
- **Default:** a planner decision the owner has not confirmed. Proceed with it and list it in your phase report.
- **OWNER:** needs the owner's answer. Stop at the gate, do the work that is not blocked, and ask.

---

## 1. Mission

MVP 4's code is in the repo, but the wearable data path is simulated. Do these in order:

1. **Stop fake data reaching real data, and clean up what already got in** (Phase 0). Ship this alone, first.
2. **Give the app a real data source** (Phase 1) and handle AGEs Index honestly (Phase 2).
3. **Finish the MVP 4 spec items that were never built or are wrong** (Phase 3), then harden (Phase 4).
4. **All testing, QA, docs and release last** (Phase 5), as in `MVP_4.md`.

**New rule for the whole repo: never fabricate health data.** No code path outside the debug-only mock source may generate, default or estimate a health value and show or store it as if the watch measured it. A missing value is `null` and the UI shows "—".

---

## 2. Audit findings

Severity: **C** critical (corrupts real data), **H** high (spec item broken or missing), **M** medium, **L** low.

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| C1 | C | **The "Samsung bridge" returns generated data.** `readDailyActivity`, `readSleep`, `readExercises`, `readBodyComposition`, `readEnergyScore`, `readAgesIndex` call `generateNative*` functions that compute values from the calendar date: sleep is always 23:15 to 06:45 on alternate days, weight is a constant 72.4 kg, steps and energy are formulas, and AGEs samples carry the note "Measured by Galaxy Watch 7 BioActive optical sensor". No Samsung SDK class is imported. `android/app/libs/` does not exist, so there is no AAR. `checkPermissions` returns `true` for every type whenever the Samsung Health package is installed, and `requestPermissions` only launches the Samsung Health app. | `android/app/src/main/kotlin/.../SamsungHealthBridge.kt` |
| C2 | C | **Sync is ungated and writes into core data.** `wear_enabled` is defined but never read anywhere. `app.dart` runs `SyncService.instance.sync(days: 7)` on every resume (`wear_auto_sync_on_resume` defaults true), and `getActiveSource()` falls back to `SamsungHealthSource` (the generator). Each sync writes generated rows to the `wear_*` boxes, adds burn entries to `diet_logs` (changing `netCalories`), appends journal lines such as "Slept 7h 30m (Score: …)", and calls `WakeService.logWake(source: 'samsung_health')` from the generated 06:45 sleep end, which evaluates the wake task and awards `wake_on_time` XP. The owner's real data may already contain all of this. | `lib/app.dart` L43-48, `sync_service.dart`, `wearable_settings.dart` |
| C3 | C | **AGEs Index cannot be read through the Samsung Health Data SDK.** The owner clarified "Age Index" means Samsung's AGEs index. The public Data SDK type list (developer.samsung.com/health/data/guide/features/data-types.html) has no AGEs entry. The only reference found is a Samsung forum thread where a partner app asks about `advanced_glycation_endproduct.raw` under Samsung's privileged, partner-only Health SDK. So every AGEs value in the app is invented (generator, fallback `45.0`, levels low/optimal/medium), and `HealthSummaryData.agesScore` feeds the health composite from that invented scale. | `generateNativeAgesSamples`, `samsung_health_source.dart`, `health_calculator.dart` |
| H1 | H | **Wake direction contradicts the headline scenario.** `WakeService` passes `direction: 'after'` (comment: "User confirmed after"), so `onTime = wakeMinutes >= targetMinutes - grace`. With target 05:00, "hey I woke up at 4" is **Missed ✕** and 06:00 is ✓. `MVP_4.md` §8.6 scenario 1 expects 04:00 against 05:00 to be ✓. | `wake_service.dart` L98-103, `wake_rules.dart` |
| H2 | H | **Wake streak never resets and edits drift.** `WakeRules.updateStreak` is called only on the on-time path (`wake_service.dart` ~L140) and never with `consecutiveMisses`, so the owner's rule "keep unless for a long time" is not implemented. A ✓→✕ edit does not undo that day's increment. `lastCompletedDate` is set to `DateTime.now()` rather than the log's own day. | `wake_service.dart`, `wake_rules.dart` |
| H3 | H | **XP wiring is unfinished.** Only `wake_on_time` goes through `XpLedger`. No `xp_rules`, `WearableXpService` or any of `steps_goal`, `sleep_goal`, `workout:{id}`, `energy_high`, `diet_deficit` exists. Diet-deficit XP still uses the direct flip logic (`GlobalXPService.addXP/subtractXP(20)`) in `DietDayLog`, which MVP_4 P5-2 said to move to the ledger. | `diet_models.dart` ~L143-164 |
| H4 | H | **Calorie reconciliation is inline in `SyncService`, not an engine.** De-dup requires a ±45 min match and an exact activity-name match (spec: ±30 min, or normalised name with duration within 25%). The `dailyList` argument is unused, so the owner's "total burned calories should be taken" is not implemented. No Undo, no target suggester. Good: `DietDayLog.totalBurned` already skips `supersededBy` entries. | `sync_service.dart` `_reconcileExerciseCalories` |
| H5 | H | **Mapper defects fabricate values.** `bodyWaterPct` is filled from `totalBodyWaterKg` (unit mismatch). `activeKcal` is invented as 35% of total kcal. Energy score falls back to `75`, AGEs to `45.0`, and the journal line shows `score ?? 80`. Exercise `totalKcal` and `activeKcal` are both mapped from one `calories` field. | `samsung_health_source.dart`, `sync_service.dart` `_autoLogToJournal` |
| H6 | H | **Spec items missing or dead.** (a) No `wear` AI intent and no `AiContext.buildWearContext` (`wear_ai_share` is never read, so nothing is sent to Gemini today, which is the safe state). (b) Metric tasks: `Goal` has `kind/metricKey/...` fields, but no sync-to-`currentValue` logic, completion rule or `AddTaskDialog` templates were found. (c) Settings `journal_autolog_kinds`, `wake_infer_from_sleep`, `wear_enabled` are never read. (d) Home has one `galaxy_watch` card instead of the spec's `activity`, `sleep`, `workouts`, `body` cards (**VERIFY** whether that was intended). (e) `HealthCalculator` branches to a separate 100-point model when sleep score or AGEs exist, instead of the §5.5 weights 25/20/15/20/20 with exact 35/35/30 fallback (**VERIFY**). | `ai_service.dart`, `ai_context.dart`, `goal.dart`, `health_calculator.dart`, `home_card.dart` |
| M1 | M | **`MVP_4.md` is corrupted in §8.5 to §8.7.** The text breaks into a fragment (". No log all day. On the next open…") and a dangling "5" where scenario 5 and the §8.7 heading should be. The owner's answers are typed inline in §9. | `MVP_4.md` |
| M2 | M | **Finance files were edited in a "Health Upgrade" commit** (21 files, +283/−237): named→positional arguments (`RecurringEngine.occurrences`), `goal.deadlineDate`→`goal.deadline`, `exportFinanceDataJson`→`exportJson`, a new `getEffectiveBudget`. Looks like API alignment, but `MVP_4.md` said no finance changes and nothing was run. **VERIFY** by running the 13 finance test files. | `git diff HEAD~1 -- lib/features/finance` |
| M3 | M | **Docs and version not updated.** `APP_DOCUMENTATION.md`, `MANUAL_QA.md` and `README.md` have no mention of wearables, the wake-up task or the day journal. `docs/WEARABLE_FIELD_MAP.md` does not exist. `pubspec.yaml` is still `1.0.0+1`. | repo root |
| M4 | M | **No tests for MVP 4.** `test/features/` has only finance. Expected under the "tests last" rule, but Phase 5 must now cover the whole of MVP 4, not only 4.1. | `test/` |
| L1 | L | Pre-existing, report only: duplicate typeIds 0/1/2 in the unreferenced `lib/models/goals.dart` (removal needs owner approval); release signed with the debug key; application id `com.example.habit_tracker`; `MANAGE_EXTERNAL_STORAGE` and `CAMERA` permissions. Fine for sideloading, blockers for Play Store. | |

**Looks right on reading (do not redo):** typeIds 60-68 do not collide with finance 40-50; `XpLedger` delta approach and `GlobalXPService.addXPForDate` exist; no `addXP(` call inside wearable or wake code; `minSdk = 29`; Samsung Health `<queries>` entry; `DietDayLog.totalBurned` skips superseded entries; `wear_ai_share` defaults off; wake parser, wake intent routing, `rolloverMissedDays` hooks in `main.dart` and `app.dart`; Day Journal repository.

---

## 3. Owner decisions

Do not block on these except where stated. Ask once, in the Phase 0 report.

| # | Question | Default if unanswered |
|---|---|---|
| Q1 | **Wake direction (gates W-1).** Today the code ticks a wake time **at or after** the target. With target 05:00: is 04:00 ✓ or ✕? Is 06:00 ✓ or ✕? (Your note said "if the time is more then it gets ticked", and the §9 answer was "after".) | Keep today's behaviour, but make the rule explicit and visible (W-1). Do not flip it without the answer. |
| Q2 | **Real data path.** Track A: Samsung Health Data SDK (needs you to download `samsung-health-data-api.aar`, enable Developer Mode in Samsung Health, and Samsung Health 6.30.2+; gives Energy Score and body composition). Track B: Android Health Connect (no AAR, no Developer Mode; Samsung Health writes steps, sleep, exercise, weight to it; **no Energy Score found**, body composition uncertain). Approving Track B approves its read-only Health Connect permissions (§P1-2). | Build Track B first (unblocked), Track A when the AAR is supplied. |
| Q3 | **AGEs Index.** Since the SDK does not expose it, is **manual entry** (you type the number Samsung Health shows) acceptable? What range and wording does Samsung Health show for it? | Manual entry, display-only, no thresholds, not in the composite or XP. |
| Q4 | **"Credit for exercise sessions but total burned calories should be taken."** Which do you mean? (a) each workout's burn uses the watch's *total* kcal for that session; (b) also show the day's total burned (resting + active) as information; (c) add the whole day's total burn to the calorie tracker (this double-counts if your calorie target already includes resting burn). | (a) and (b). Not (c). |
| Q5 | **Cleanup of the simulated data (P0-4).** Run automatically on next launch with a visible summary and a backup, or only when you tap a button? | Automatic with a confirm dialog and a backup. |

---

## 4. Working agreement

Everything in `MVP_4.md` §2 still applies (tests last, pure-Dart engines, repositories own Hive, no Hive off the UI isolate, never change an existing `typeId`/`@HiveField`/box name, versioned idempotent migrations preceded by a JSON backup, stop-and-ask list, phase reports). Additions:

- Branches `mvp4.1/p0-safety`, `mvp4.1/p1-source`, ... off `master`; one commit per task (`P0-1: gate sync`). Keep the app compiling at every commit. Run `dart format .` and `flutter analyze` after each task and record the warning count against the baseline in P0-0.
- **Phase 0 ships on its own** before any other phase starts.
- Never claim the Samsung bridge, Health Connect, permissions, sync or UI work unless you ran them on a device. Put them under "Not verified" in the phase report and in `MANUAL_QA.md`.
- Read the real API (pub cache, Samsung SDK reference, Health Connect docs) before writing SDK calls. Do not write SDK calls from memory.
- Mock data: only in debug builds, always tagged `sourceDevice = 'mock'`, always labelled "DEMO DATA" in the UI, and **never** flows into the calorie tracker, XP, journal, wake task, composite or AI.
- Report after each phase: what changed, what you ran, what you could not verify, defaults applied, questions.

---

## 5. Phases

### Phase 0: Safety stop (ship first, alone)

**P0-0 Baseline.** Run `flutter analyze` and `flutter test` on a clean checkout of `master` and record the results (including any failing finance tests; that settles M2). Grep the real typeIds in use.

**P0-1 Gate the sync.** `SyncService.sync()` returns immediately unless `WearableSettings.isEnabled` is true **and** the active source reports a real, granted state. Resume, start and timer triggers respect it and `wear_auto_sync_on_resume`. `wear_enabled` is set to true only after a successful real permission grant (or the debug mock toggle). Result: a fresh install and the owner's current install do nothing wearable-related until the owner connects a real source.

**P0-2 Remove every generator from the Kotlin bridge.** Delete all `generateNative*` functions and their callers. Until Phase 1 lands, every read method returns a typed error (`not_implemented`), `checkPermissions` returns all-false, and `requestPermissions` returns the real result. Add a CI-style check (Phase 5.5) that fails if `android/` contains hard-coded health values. Error codes: `not_installed`, `old_version`, `no_permission`, `access_control`, `policy_2003`, `not_implemented`, `unknown`.

**P0-3 Restrict the mock source.** `MockWearableSource` is selectable only when `kDebugMode`. Tag its rows `sourceDevice = 'mock'`. Downstream consumers (calorie reconciler, journal auto-log, wake inference, XP rules, composite, AI) skip `mock` rows. Show a "DEMO DATA" banner on every wearable surface while it is active. Remove `wear_use_mock_provider` from release builds.

**P0-4 Purge migration for simulated data.** Versioned (`wear_bridge_version`, set to 2 on completion), idempotent. Steps:
1. Back up affected boxes to `backups/mvp4_1_purge_<timestamp>.json` in the app documents directory. If the backup fails, abort and change nothing.
2. Show a dialog (Q5 default): "Remove N simulated watch records?" with Remove / Later. While "Later", all wearable surfaces stay hidden (they are already gated by P0-1).
3. On Remove:
   - `wear_daily`, `wear_sleep`, `wear_exercise`, `wear_body`, `wear_energy`, `wear_ages`: clear all rows. (The bridge never read a real value, so none are real.)
   - `diet_logs`: remove `CalorieBurnEntry` rows with `id` starting `burn_shealth_` or `externalId` starting `shealth_`; set `supersededBy = null` on any entry whose `supersededBy` starts with `shealth_` (this restores manual burns that the generator hid). Leave empty day logs alone.
   - Journal: remove auto-log events with `source == 'samsung_health'` through `JournalDayRepository.removeAutoLog`. Do not touch the owner's own text.
   - Wake: delete `WakeLog` rows with `source == 'samsung_health'`, their `TaskDayLog` rows, set `XpLedger.set(dayKey, 'wake_on_time', 0)` for each day (the ledger reverses the XP on that day's own date), then recompute the wake goal's `isCompleted` and `streakCount` from the remaining logs.
   - **VERIFY** whether any `WeightEntry` rows were written with a wearable source; if so, remove only those.
   - Settings: clear `wear_last_sync`, `wear_last_sync_ms`, `wear_change_tokens`; set `wear_enabled = false`.
4. Show a result summary ("Removed 30 sleep, 15 workouts, …"). Never silent. Never delete anything that does not match a rule above.

**P0-5 Repair `MVP_4.md`.** Fix the corrupted §8.5 to §8.7 headings and restore the missing structure from §5 and §8.6 where it can be reconstructed; mark any scenario text that cannot be recovered as "lost, see §5". Move the owner's inline §9 answers into a short "Owner answers" table so they stop being mixed into the questions.

**Done when:** a build with no connected source writes nothing to `wear_*`, `diet_logs`, journal, wake logs or XP; the Kotlin bridge contains no fabricated values; the purge removes only matching rows and is safe to run twice.

---

### Phase 1: A real data source (Q2 gates the track)

Both tracks implement the existing `WearableSource` interface. Engines and UI do not change between tracks. `wear_source` selects `samsung_sdk` or `health_connect`.

**P1-1 Status model end to end.** One status enum shared by Kotlin and Dart (Not set up, Platform missing, Update needed, Developer Mode needed, Permission needed, Connected, Error) driven by real checks. The Settings status chip and the home card's connect prompt read it. After two permission denials, stop asking and show guidance.

**P1-2 Track B: Health Connect source (Default first).** **Default:** Kotlin bridge over `androidx.health.connect:connect-client` on a new channel, following the `MediaSessionBridge` pattern (the project already needed Java 17 fixes for plugins, so avoid a new Flutter plugin unless it builds cleanly: **VERIFY**). Read-only permissions: steps, distance, active calories, total calories, sleep sessions with stages, exercise sessions, weight, body fat, heart rate. Add the Health Connect `<queries>` package and permission rationale activity the API requires. Historical reads are limited to 30 days before the first grant unless `READ_HEALTH_DATA_HISTORY` is requested (**VERIFY** current behaviour). Energy Score shows "Needs Samsung Data SDK". Body composition: **VERIFY on device** what Samsung writes.

**P1-3 Track A: Samsung Health Data SDK (when the AAR is supplied).** OWNER prerequisites: AAR placed in `android/app/libs/` (the Gradle `fileTree` line already exists), Samsung Health 6.30.2+, Developer Mode on, watch paired. Implement the bridge per `MVP_4.md` P4-1: `getStatus`, `requestPermissions(types)`, `readDaily`, `readSleep` (with stages via the associated-data API), `readExercises`, `readBodyComposition`, `readEnergyScore`, `readUserProfile`, `readChanges`. Off the main thread; map every SDK exception to the error codes in P0-2. The SDK does not support emulators. **No synthetic fallback, ever.**

**P1-4 Fix the mappers.** Pure functions from channel maps to models. Canonical units (kg, m, kcal, minutes). `bodyWaterPct` only from a percentage field or computed from water mass and weight with a stated formula. Distinct `activeKcal` and `totalKcal` for daily activity and for exercise. Remove every invented default (energy `75`, AGEs `45.0`, sleep score `80`, active kcal ×0.35): missing means `null` and the UI shows "—". The journal sleep line omits the score when absent.

**P1-5 Harden `SyncService`.** Keep single-flight. Per-type `try/catch` so one failing type leaves the others consistent. Minimum 10 minutes between resume syncs. Use change tokens where the source supports them; if a token is rejected, re-read the last 7 days (upserts are idempotent). Aggregate-only types re-aggregate the last 3 days plus today. Surface typed errors, never crash. Wire the dead settings: respect `journal_autolog_kinds` in `_autoLogToJournal`, and `wake_infer_from_sleep` plus the main-sleep rule (longest session ending before 14:00, naps excluded) in `_autoLogWakeFromSleep`. A chat or manual wake log always beats a watch inference, and an inferred line says "(from watch)".

**P1-6 `docs/WEARABLE_FIELD_MAP.md`.** Source field → model field → unit for each track, with every unconfirmed field marked.

**Done when:** with a real source connected on a device, values in `wear_*` match what Samsung Health shows, with no invented numbers; with no source, the app is fully usable and shows connect prompts.

---

### Phase 2: AGEs Index, honestly

**P2-1 Remove fabricated AGEs.** Delete generator output and fallbacks. `AgesSample` (typeId 65) stays; manual rows use `sourceDevice = 'manual'`.

**P2-2 Manual entry and trend (Q3 default).** A sheet to add a reading (value, date and time, optional free-text level exactly as Samsung Health shows it) and a `fl_chart` trend on the Fitness tab and the body/watch card. Edit and delete. No thresholds, colours or "improving" labels that imply a scale you have not verified. Optional: a confirm-first chat action `ages_log` ("my AGEs index is 1.8").

**P2-3 Composite and XP.** Remove `agesScore` from `HealthSummaryData` weighting and from XP until the owner supplies the scale. Display only.

**P2-4 Drop the fitness-age estimate.** The `MVP_4.md` §5.6 "Age Index" estimate was never built and is replaced by AGEs. Update docs; do not build it.

---

### Phase 3: Finish the MVP 4 spec

**P3-W Wake-up task.**
- **W-1 Direction (Q1).** Add an explicit rule to the task: store the direction (`by` = at or before target, `from` = at or after), show it in plain words on the task card and in the edit sheet ("Ticked if I wake at or before 05:00"). Keep current behaviour (`from`) until Q1 is answered. Remove the hard-coded `direction: 'after'`.
- **W-2 Streak.** Implement the owner's rule "keep unless for a long time": derive consecutive missed days from `TaskDayLog`; a single miss keeps the streak; reset only after N consecutive misses. **Default** N = 3 (matches the current helper; settings key `wake_streak_reset_after_misses`). Call it from both the log path and `rolloverMissedDays`.
- **W-3 Edits and dates.** A ✓→✕ edit undoes that day's streak increment; `lastCompletedDate` uses the log's own day, not `now`; logging yesterday's wake does not change today's state. Re-evaluate both directions through `XpLedger`.
- **W-4 Rollover.** Honour `wake_unlogged_policy` and `wake_miss_penalty_xp` (**VERIFY** current code); bound multi-day gaps at 60 days.

**P3-X XP and ledger (MVP_4 P5-2).** Add `engine/xp_rules.dart` with the §5.5 table as constants, `WearableXpService.reconcile(dayKey)` after each sync for the last 3 days plus today, and the 40 XP wearable daily cap. Move diet-deficit XP off the flip logic (`DietDayLog.addFood/addBurn/removeFood/removeBurn`) onto the ledger rule `diet_deficit`. Set `xp_ledger_start` to the migration day and never reconcile earlier days (their XP was already awarded). **VERIFY** the current flip behaviour before editing. Mock rows are excluded. Only the ledger awards wearable or wake XP; never call `addXP` from that code.

**P3-C Calorie tracker (MVP_4 P5-3, Q4 default).** Extract `engine/calorie_reconciler.dart` (pure) plus a thin writer. Burn credit modes per `wear_burn_credit_mode`, with the Q4 default: each workout becomes one `CalorieBurnEntry` (id `wear_{externalId}`, `source = wearable`) using the session's total kcal if present, else active. De-dup per spec (±30 min, or normalised name and duration within 25%), nothing deleted, "merged with watch workout" note with Undo, `supersededBy` cleared when the source row is deleted. Show the day's total burned as a read-only row. Imports never trigger flip XP. Add the suggest-only target banner (Accept / Dismiss) using the §5.5 Mifflin-St Jeor rule; it needs `profile_sex`, `profile_dob`, `profile_height_cm`.

**P3-H Health composite (MVP_4 P5-5).** Align `HealthCalculator` with §5.5: weights calories 25, medicine 20, missions 15, sleep 20, activity 20, renormalised over available components; with no wearable data it must reproduce the original 35/35/30 results exactly. Sleep and activity come from the day view, never from invented values. AGEs excluded (P2-3).

**P3-M Metric tasks (MVP_4 P5-7).** **VERIFY** nothing exists, then implement: sync updates `currentValue` for `kind == 'metric'` goals (`steps`, `active_minutes`, `sleep_minutes`, `workout_minutes`, `energy_score`); reaching the target completes the task directly, XP through ledger rule `metric:{goalId}`, never `Goal.complete()`; reversal when data is revised down; `AddTaskDialog` templates "10,000 steps", "30 active minutes", "Sleep 7 h", "Workout today"; the daily reset applies.

**P3-A AI (MVP_4 P5-9).** Add intent `wear`, answered locally from `WearableRepository.dayView(dayKey)` (create it if missing) and the engines: steps, sleep, workouts, energy, body, AGEs, "sync my watch" as an auto-execute `wear_sync` action. If data is missing the answer says so. `AiContext.buildWearContext()` returns one compact line (under 60 tokens), attached to Gemini calls only when `wear_ai_share` is on. Keep `wake` routing before the task-create check and the diet scan.

**P3-U Cards and Fitness tab.** **VERIFY** `galaxy_watch_card.dart` and `fitness_tab.dart`. Required behaviour: not-connected state with a "Connect" call to action, loading, empty and error states, "—" for missing values, DEMO banner for mock, no fabricated fallbacks. **Default:** keep the single `galaxy_watch` card plus the Fitness tab; add the spec's separate `activity`, `sleep`, `workouts`, `body` cards only if the owner asks. New cards append to existing layouts per the registry merge rule.

---

### Phase 4: Hardening and loose ends

**P4-1 Finance regression check (M2).** Run all finance tests. If red, fix the specific hunks or revert them; do not widen finance scope. List what the "Health Upgrade" commit changed in finance and why, in the report.

**P4-2 Dead and duplicate settings.** Every key in `WearableSettings` is either read somewhere or removed. Report the list.

**P4-3 Journal day model.** **VERIFY** auto-log writes work while the journal is locked, the `settings['journal_inbox']` fallback flushes, and the 60-second auto-lock and unlock gate still protect viewing.

**P4-4 Report only (L1).** Do not change typeIds, `lib/models/goals.dart`, signing, application id or permissions without the owner.

---

### Phase 5: Testing, QA, documentation, release (everything testing-related lives here)

Do not start before Phases 0 to 4 compile. Fix defects in the owning phase's files and re-run the affected tests.

**5.1 Infrastructure.** `FakeWearableSource` (scriptable data, errors, tokens), an injectable clock, a temp-directory Hive harness (copy `test/services/*`), `JournalService.setMockDependencies`. Fixtures hand-built to match `docs/WEARABLE_FIELD_MAP.md`. New tests under `test/features/wearables/`, `test/features/journal/`, `test/features/wakeup/`.

**5.2 Unit tests.**

| Area | Must cover |
|---|---|
| Purge migration | Removes only matching rows; manual burns lose `supersededBy` and count again; wake XP reversed on the event's date; streak recomputed; backup file exists; backup failure aborts with no change; second run is a no-op; "Later" leaves data untouched |
| Sync gate | Disabled, not granted, or error → zero writes to `wear_*`, `diet_logs`, journal, wake logs, XP; mock rows never reach core; per-type failure keeps others consistent; single-flight; resume interval |
| Mappers | Units; missing field → `null` (no defaults); naps; sleep crossing midnight lands on the wake day; body water; active vs total kcal |
| Wake rules | Both directions at the boundary (target 05:00: 04:59, 05:00, 05:01; with grace); edits both ways; unlogged policy; multi-day gap; task created after target time |
| Wake streak | Single miss keeps it; N consecutive misses reset it; ✓→✕ undoes the increment; back-dated log does not touch today |
| XP ledger and rules | Idempotent `set`; reversal; own-date writes; per-day clamp; 40 XP cap; each rule at its boundary; revised data lowers XP; no double award with the diet migration |
| Diet XP migration | Past days untouched; ledger starts on the migration day; toggling food in and out of deficit nets one award |
| Calorie reconciler | Each credit mode; upsert without duplicates; ±30 min and 25% thresholds; Undo; `totalBurned` excludes superseded; no flip XP; missing day log created; Q4 behaviour |
| Composite | Renormalisation; wearable off reproduces 35/35/30 exactly; AGEs excluded |
| Metric tasks | Threshold completion, reversal, daily reset |
| AGEs manual | Add, edit, delete, ordering, no derived labels |
| AI routing | `wake` routes before diet; regression table of existing diet, finance, task, vault, music phrases; `wear` answers local; context line attached only with `wear_ai_share`, under budget; missing data answered honestly |

**5.3 Widget tests.** Wake-up task card (pending, ✓, ✕, 7-day strip, rule text); wearable card and Fitness tab (not connected, loading, empty, connected, error, DEMO banner); Settings status chips; purge dialog; burn list watch icon and merge note with Undo; AGEs sheet.

**5.4 Integration tests (fake source, no device).** Sync → burn entries → ledger XP → composite → journal lines in one pass; re-sync produces no duplicates; disconnect leaves every screen usable.

**5.5 Static checks.** `dart format .` clean; `flutter analyze` no new warnings versus P0-0; the whole existing suite (including finance phases 1 to 13) green. Searches that must come back empty: `generateNative` and hard-coded health literals under `android/`; `addXP(` inside `features/wearables` and wake code; Hive box access outside the repositories; any Hive access reachable from a background isolate; `?? 75`, `?? 45.0`, `?? 80` style defaults on health values.

**5.6 Device QA (owner, real Galaxy Watch 7; add to `MANUAL_QA.md`).**
1. Fresh state, no source: no wearable rows anywhere, cards show Connect.
2. After the purge: yesterday's fake entries gone, manual burns count again, wake XP reversed, summary matched what you saw.
3. Connect the real source: steps and sleep match Samsung Health; a re-sync adds nothing.
4. Run a 30-minute workout: one burn entry, a manual "ran 30 min" merged under it with Undo, XP once.
5. Wake task: target 05:00, say "woke up at 4" and "woke up at 5:40"; result follows the Q1 rule shown on the card; edits ✓↔✕ move XP and streak correctly; one missed day keeps the streak.
6. Disconnect or revoke permission: app stays usable, nothing crashes.
7. AGEs: add a reading by hand, see it in the trend.

**5.7 Documentation.** `APP_DOCUMENTATION.md` (boxes, models, engines, channels, XP rule table, wake rules, settings keys, data-source tracks, cards), `docs/WEARABLE_FIELD_MAP.md`, `MANUAL_QA.md`, `README.md`.

**5.8 Release.** Bump `pubspec.yaml` version. Record that the build is debug-signed and, for Track A, relies on Samsung Developer Mode. Rollback note: purge backup JSON, `.bak_mvp4` journal copy, `wear_enabled = false`. Final report in the usual format with three explicit lists: verified by tests, verified only by reading code, needs the device.

---

## 6. Out of scope

Everything in `MVP_4.md` §10, plus: building the fitness-age estimate, anything that needs Samsung's partner-only SDK, writing data back to Samsung Health or Health Connect, finance feature changes, signing or application-id changes, removing `lib/models/goals.dart`.