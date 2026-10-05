# Habit Tracker MVP 4: Samsung Wearable Integration, Daily Wake-Up Task, Day Journal

Spec for Claude Opus working autonomously in the repo root (`Roshen-Reji/habit_tracker`). Code facts were read from `master` at commit `64338a3` (the MVP 2 merge). **MVP 3 is not on GitHub** (the remote has only `master` and `Dev`), so I have not seen it. This plan stays out of the finance files, and the typeIds below start at 60 to stay clear of the 40-59 block the MVP 3 spec reserved. Before registering any adapter, grep the real typeIds in use.

Markers:
- **VERIFY:** something I could not confirm. Check it in the code, the SDK reference or on the device before relying on it.
- **Default:** a planner decision the owner has not confirmed. Proceed with it and list it in your phase report.

Nothing here was compiled or run (no Flutter SDK, no device). Every "fact" is from reading code or Samsung and Android documentation.

---

## 1. Mission

Three connected deliverables. Ship them in this order: B, A, C, because B and A need no Samsung setup and give the owner something usable early.

**B. Day Journal.** Journal becomes one document per day, and the journal page is a timeline of day sections. Each day section holds the owner's own text plus an **auto-log** block that the chat and the watch write into (wake-up time, sleep summary, workouts, steps).

**A. Daily wake-up task.** A new daily task type with a settable target wake time. The owner tells the chat "hey I woke up at 4"; the app records the time, writes it into that day's journal, and evaluates the task: on time = ticked, late = crossed. The AI can create the task, and the owner can create and edit it by hand.

**C. Samsung wearable integration** (Galaxy Watch 7 via Samsung Health). Walks and steps, exercise sessions, sleep (stages and score), body composition, energy score and the rest of what Samsung exposes, normalised into local models and wired into the calorie tracker, XP and scores, the health summary, tasks, the journal, the AI and the home cards, plus a new **Age Index**.

**One data spine.** Samsung data goes `bridge → normalised local models → pure engines → every surface`. No screen, task or AI handler reads Samsung directly.

---

## 2. Working agreement

**Testing comes last (owner's instruction).** Phases 0 to 7 contain no test tasks. After each task run only `dart format .` and `flutter analyze` so the build stays green. All unit, widget, migration and device testing, plus docs and release, is **Phase 8**. Do not skip it. To keep Phase 8 cheap, put all logic in pure Dart (no Flutter or Hive imports, clock and sources injected) and keep Hive access in thin repositories.

**Process**
- Integration branch `mvp4/integration`; one branch per phase (`mvp4/p1-foundation`, ...); one commit per task (`P4-2: sync service`). Keep the app compiling at every commit.
- Run `dart run build_runner build --delete-conflicting-outputs` after any `@HiveType` change.
- You probably have no device. Never claim that the Samsung bridge, permissions, sync, notifications or UI behave correctly unless you ran them. Put such items under "Not verified" in your phase report and add them to `MANUAL_QA.md` (Phase 8).
- For third-party packages and the Samsung SDK, read the real API (pub cache, the SDK's API reference and sample) before writing calls. Do not write SDK calls from memory.

**Data safety**
- Never change an existing `typeId`, `@HiveField` index or box name. New fields on existing models use new indexes with defaults.
- In use today (MVP 2): typeIds 0, 1, 2, 4, 10, 11, 20-23, 30-35. MVP 4 uses **60-79**.
- **Hive is not multi-isolate safe.** Never open or write Hive boxes from a background isolate or a native worker. Background work may only write to a native inbox file; the UI isolate ingests it (§7 P7-2).
- Migrations are versioned, idempotent, preceded by a JSON backup of the affected boxes, and abort on error leaving existing data intact. Never delete or overwrite user rows automatically.

**Stop and ask before**: upgrading the Flutter SDK; changing the application id or release signing; deleting any user data (including the unreferenced duplicate `lib/models/goals.dart`); adding permissions beyond those named in §4; implementing anything in §10.

**Report after each phase** (short): what changed, what you ran (`analyze` results), what you could not verify, defaults applied, questions.

---

## 3. Baseline: what exists (read from `64338a3`)

**Chat and AI** (`lib/data/services/ai_service.dart`, ~2,700 lines; `ai_context.dart`; `lib/features/home/home_chat.dart`; `widgets/chat_message_bubble.dart`)
- Pipeline in `processMessage`: `detectIntent(message)` returns `vault | finance | tasks | diet | music | general`. Music is handled locally, then `_handleLocally` (a regex engine per intent) runs, and only if that returns null does it call Gemini through `GeminiClient` with a minimal context line (`AiContext.buildDietContext/FinanceContext/TaskContext`).
- Actions are `AiAction {type, payload, isConfirmed}`. `executeAction` switches on `food_entry`, `burn_entry`, `task_create`, `finance_*`. The chat bubble shows Confirm/Reject for each unconfirmed action (`_confirmAction` in `home_chat.dart` ~L181). The system prompt lists action types in `AiContext.buildSystemPrompt()`.
- There is no wake-up, sleep, journal or wearable intent. Intent order today is vault, finance, task-create or task-status, then the diet and finance keyword scans, so the new wake intent must sit before the task-create check and the diet scan.

**Tasks** (`lib/data/models/goal.dart`, typeId 1; `task_reset_service.dart`; `lib/features/tasks/`)
- The live `Goal` model is `lib/data/models/goal.dart`. `lib/models/goals.dart` is an older duplicate (also typeId 1) that nothing imports; leave it alone.
- `GoalType {today, daily, weekly, monthly}`, `GoalCategory {health, productivity, learning, fitness, hobby}`. Fields 0-16 include `isCompleted`, `progress`, `targetValue`, `currentValue`, `unit`, `streakCount`, `lastCompletedDate`, `reminderTime`, `endDate`, `lastReset`. `xpValue` = 5 (daily), 20 (weekly), 50 (monthly). `complete()` adds XP once, increments the streak once per day, stamps `lastCompletedDate`.
- **There is no "missed" state and no per-day history.** `TaskResetService.checkAndResetTasks()` (boot and resume) resets a completed goal when `lastCompletedDate` is not today. In the files I read, nothing resets `streakCount` on a missed day (**VERIFY**). The card shows a strikethrough on completion (`task_card.dart` ~L92).
- Notifications: `NotificationService.scheduleTaskReminder(Goal)`, `scheduleMedicineReminder`, `showInstantNotification`, `cancelReminder`.

**XP and scores**
- `GlobalXPService`: `addXP`, `subtractXP`, writes `settings['global_xp']` and `xp_history[today]`. **`_recordDailyXP` always writes to today**, never to an event's own date, and clamps each day at 0. `ScoreService` sums `xp_history` for week/month/year and deltas (read-only). `RankService` computes rank from goals (completions and streaks), not from `global_xp`.
- `DietDayLog.addFood/addBurn/removeFood` award or remove 20 XP when the day *flips* into or out of deficit; `removeBurn` does not revert. Repeated changes can farm or drift XP. Any automatic burn import would trigger this churn, so the plan moves that XP to an idempotent ledger (P5-2).

**Calorie tracker** (`lib/data/models/diet_models.dart`)
- `DietDayLog` (typeId 23, one per `dateKey`) holds `entries`, `burnEntries`, `targetCalories` (default 2000, from `settings['daily_calorie_target']`). `netCalories = eaten - burned`, `deficit = target - net`. `CalorieBurnEntry` (typeId 22: id, activity, caloriesBurned, durationMinutes, timestamp) has no source or external-id field. The existing semantic: burn means *exercise* calories, not BMR.

**Health** (`lib/data/models/health_models.dart`, `lib/data/services/health_calculator.dart`, `lib/features/health/health_page.dart`)
- `WeightEntry` (typeId 32: `date` 'yyyy-MM-dd', `kg`, `note`). `HealthSummaryData.compositeScore` = calories 35 + medicine 35 + health missions 30. `HealthPage` has two tabs (Medicine | Weight) switched by `_selectedTab`.
- There is no user profile (age, height, sex) anywhere in the app, and **no "age index" concept**. The Age Index in §5.6 is new and is my interpretation (§9, question 1).

**Journal** (`lib/data/services/journal_service.dart`, `lib/features/journal/*`, `JournalEntry` typeId 33)
- Fields: `id`, `title`, `bodyDelta` (Quill JSON), `createdAt`, `updatedAt`, `pinned`, `tags`. Stored in an AES-encrypted box `journals`, key in secure storage. `isUnlocked` gates the *UI* (biometric or device credential, 60 s auto-lock). The box opens lazily through `openEncryptedBox()`, and **`saveEntry` needs no authentication**, so chat and sync code can append without unlocking.
- Existing entries are many per day.

**Android** (`android/app/`)
- `MainActivity : FlutterFragmentActivity`; `MediaSessionBridge.kt` is the pattern to copy (MethodChannel + EventChannel registered in `configureFlutterEngine`). Java 17, `compileSdk = 36`, **`minSdk = flutter.minSdkVersion`**, release build signed with the debug key, application id `com.example.habit_tracker`. The manifest has no Samsung Health `<queries>` entry.

**Dependencies present**: `hive`, `hive_flutter`, `fl_chart`, `intl`, `http`, `flutter_local_notifications`, `timezone`, `permission_handler`, `local_auth`, `flutter_secure_storage`, `flutter_quill`, `flutter_animate`, `material_3_expressive`. Not present: any health plugin, `workmanager`, `uuid`. Existing tests live under `test/`.

---

## 4. Samsung data access: findings and decision

**Path of the data.** Galaxy Watch 7 → Galaxy Wearable app (device management only) → **Samsung Health on the phone** → third-party apps. The Wearable app does not expose health data; Samsung Health is the only door.

**Two official doors**

| | Samsung Health Data SDK (primary) | Android Health Connect (fallback) |
|---|---|---|
| Source | Samsung Health's own data store | Data Samsung Health chooses to write to it |
| Energy score | Yes (`EnergyScoreType`, read and read-changes) | Not found in any source I read |
| Body composition | Yes (read, read-changes) | Reports conflict on whether Samsung writes it (**VERIFY on device**) |
| Sleep | Yes: sleep sessions with stages and `SLEEP_SCORE`, goal | Sessions and stages |
| Exercise | Yes, includes `vo2Max` | Yes |
| Steps, activity | Aggregate-only (`Steps`, `Activity summary`, goals) | Raw records |
| Also available | Heart rate, blood oxygen, skin temperature, floors climbed, water intake, nutrition, blood pressure and glucose, user profile (gender, date of birth, height, weight) | Overlaps |
| History | No 30-day limit documented | 30 days before first grant unless `READ_HEALTH_DATA_HISTORY`; change tokens expire after 30 days |
| Access | Developer Mode for development; **distribution to others needs a partner registration** (package name + SHA-256) | Standard Android permissions |

**Samsung Health Data SDK facts** (developer.samsung.com, release note v1.1.0 dated 12 Mar 2026): needs Samsung Health 6.30.2+, Android 10+ (API 29), Java 17+; **does not support emulators**; Android only; wellness data, not for diagnosis. An unregistered app is rejected with error `2003` unless **Developer Mode (Samsung Health Data SDK)** is enabled in Samsung Health. Each data point carries its source device (`DeviceManager`), so watch and phone can be told apart. `readChanges` returns new, updated and deleted points for incremental sync. Permissions are requested with `HealthDataStore.requestPermissions(..., activity)`; after a few denials stop asking and show guidance instead. Errors to handle: `PLATFORM_NOT_INSTALLED`, `OLD_VERSION_PLATFORM` (`ResolvablePlatformException.resolve(activity)`), `ERR_NO_USER_PERMISSION`, `ERROR_ACCESS_CONTROL`.

**What Samsung does not expose** (not in the SDK's type list): the watch's stress score, antioxidant index, vascular load, bedtime guidance, mindfulness, and heart-rate variability. The plan does not integrate them. Irregular-rhythm and sleep-apnea notifications exist in the SDK; they are medical-adjacent and left out (§10).

**Decision (Default).** Build on the **Samsung Health Data SDK** through a Kotlin bridge (same pattern as `MediaSessionBridge`), behind a Dart `WearableSource` interface so a Health Connect source can be added later (P7-1) without touching engines or UI. Personal sideloaded use runs under Developer Mode. This is acceptable for a personal app but fragile: Samsung describes Developer Mode as for testing. If you ever distribute the app, a partner registration and a real release keystore are required (§10).

**Owner prerequisites** (cannot be automated; do not proceed with the bridge until confirmed): (1) download the SDK from Samsung's developer site (the release note says it ships `samsung-health-data-api.aar`; **VERIFY** whether a Maven coordinate exists, and whether a Samsung developer account is needed to download); (2) update Samsung Health to 6.30.2 or newer; (3) turn on Developer Mode (Samsung Health Data SDK) following Samsung's guide; (4) the watch is paired and syncing to Samsung Health.

---

## 5. Architecture and data model

### 5.1 Layout
```
lib/features/wearables/
  data/      wearable_source.dart (interface), samsung_health_source.dart (channel client),
             health_connect_source.dart (P7-1), sync_service.dart, wearable_repository.dart
  engine/    pure Dart: day_aggregator, calorie_reconciler, xp_rules, composite, age_index,
             target_suggester, wake_parser, wake_rules, journal_autolog
  ui/        cards, pages, settings section
lib/features/journal/        day model, day timeline page, day editor changes
android/app/src/main/kotlin/com/example/habit_tracker/SamsungHealthBridge.kt
```
- Repositories are the only code that touch Hive boxes for the new data. Engines take immutable inputs plus an explicit `now`.
- **Numbers are computed by code, never by the LLM.** The AI turns language into actions and phrases results.

### 5.2 New models (typeIds 60-79)

| typeId | Class | Box (key) | Fields |
|---|---|---|---|
| 60 | `DailyActivity` | `wear_daily` (`yyyy-MM-dd`) | steps, distanceM, activeKcal, totalKcal?, activeMinutes, floors, restingHr?, avgHr?, spo2Avg?, stepGoal?, activeKcalGoal?, activeTimeGoal?, sourceNote, syncedAt |
| 61 | `SleepSession` | `wear_sleep` (`externalId`) | dayKey (wake day), start, end, durationMin, awakeMin, lightMin, deepMin, remMin, score?, efficiency?, isNap, sourceDevice, deleted |
| 62 | `ExerciseSession` | `wear_exercise` (`externalId`) | dayKey, type, title, start, end, durationMin, activeKcal?, totalKcal?, avgHr?, maxHr?, distanceM?, vo2Max?, sourceDevice, linkedBurnId?, deleted |
| 63 | `BodyCompSample` | `wear_body` (`externalId`) | timestamp, weightKg?, bodyFatPct?, bodyFatMassKg?, skeletalMuscleMassKg?, bodyWaterPct?, bmrKcal?, bmi?, sourceDevice, deleted |
| 64 | `EnergyScoreDay` | `wear_energy` (`yyyy-MM-dd`) | score, extraJson (any further fields the SDK returns, kept for forward compatibility) |
| 66 | `TaskDayLog` | `task_day_logs` (`goalId\|yyyy-MM-dd`) | status (`pending, done, missed, neutral`), value?, valueText?, loggedAt, source (`manual, chat, ai, sleep_infer, rollover, wearable`), note |
| 67 | `WakeLog` | `wake_logs` (`yyyy-MM-dd`) | wakeAt, source, sleepSessionId?, targetMinutesAtLog, onTime, editedAt, undoOf? |
| 68 | `XpLedgerEntry` | `xp_ledger` (`yyyy-MM-dd\|ruleId`) | amount, updatedAt |

All field lists marked with `?` are best-effort until you read the SDK API reference: **VERIFY exact property names and units** (for example how `ActivitySummary` reports active versus total calories, and which unit body composition masses use). Store canonical SI units (kg, m, kcal, minutes).

### 5.3 Changes to existing models (new HiveField indexes only)

| Model (typeId) | Add | Purpose |
|---|---|---|
| `Goal` (1) | 17 `kind` String? (`null`=standard, `wakeup`, `metric`), 18 `targetMinutes` int? (wake target, minutes after midnight), 19 `metricKey` String?, 20 `metricOp` String? (`>=`/`<=`), 21 `graceMinutes` int? | Wake-up task and data-driven tasks |
| `CalorieBurnEntry` (22) | 5 `source` String? (`manual, ai, wearable`), 6 `externalId` String?, 7 `supersededBy` String? | Imported burns, de-duplication |
| `WeightEntry` (32) | 3 `source` String?, 4 `externalId` String? | Samsung weigh-ins |
| `JournalEntry` (33) | 7 `dayKey` String?, 8 `autoLogJson` String?, 9 `mergedInto` String? | One doc per day, auto-log, optional merge |

Update `DietDayLog.totalBurned` to skip entries with `supersededBy != null`. Everything else on those models is unchanged.

### 5.4 Settings keys (in the existing `settings` box)
`wear_enabled`, `wear_source` (`samsung_sdk` | `health_connect`), `wear_last_sync`, `wear_change_tokens` (map per data type), `wear_backfill_days` (default 30), `wear_burn_credit_mode` (`workouts_only` default, `all_active`, `off`), `wear_ai_share` (default false), `wear_debug_dump` (default false), `step_goal_default` (8000), `sleep_goal_minutes_default` (420), `active_minutes_goal_default` (30), `wake_target_minutes_default` (null until the owner sets one), `wake_grace_minutes` (0), `wake_unlogged_policy` (`missed` default | `neutral`), `wake_miss_penalty_xp` (0), `wake_infer_from_sleep` (true), `journal_autolog_enabled` (true), `journal_autolog_kinds` (wake, sleep, workout, steps), `profile_sex`, `profile_dob`, `profile_height_cm` (filled from Samsung's user profile when readable, else by hand), `age_index_enabled` (true).

### 5.5 Engine rules

**Wake time parsing** (`wake_parser.dart`, pure). Input: message text, `now`. Output: `WakeParse {wakeAt, confidence, needsClarification?, question?}`.

| Message | Result |
|---|---|
| "hey i woke up at 4" | today 04:00 |
| "woke up at 4:30", "got up at 5 am", "up since 6" | today 04:30 / 05:00 / 06:00 |
| "woke up at 7 pm" / "at 16:00" | explicit meridiem and 24h win |
| "just woke up", "i'm up" | `now` |
| "woke up 10 minutes ago" | `now - 10 min` |
| "woke up at 4 yesterday" | yesterday 04:00 |
| "subah 4 baje utha" | today 04:00 (keep the Hinglish patterns used elsewhere) |
| "woke up at 12" | clarify: 12 AM or 12 PM |
| a computed time later than `now`, or "tomorrow" | clarify once ("Did you mean yesterday?"); "tomorrow" is declined with a short explanation |

Rules: with no meridiem, hours 1-11 mean AM unless the message contains pm/evening/afternoon/night; hours 12 and 0 are ambiguous; never invent a date silently; one clarifying question at most.

**Wake evaluation** (`wake_rules.dart`, pure). `onTime = wakeAt.timeOfDay <= targetMinutes + graceMinutes`. On time: log `done`, mark the goal completed for the day with streak increment once per day. Late: log `missed`, goal stays incomplete, **streak resets to 0 for `kind == wakeup`** (Default). Editing a log re-evaluates in both directions (XP is reversible, see the ledger). A day with no log at rollover becomes `missed` (or `neutral` if `wake_unlogged_policy == neutral`); a day on which the task did not exist before its target time is `neutral`. Source priority: manual edit > chat/AI > sleep inference > none.

**XP ledger** (`XpLedger`). `set(dayKey, ruleId, amount)` stores the entry and applies only the delta `amount - previous` through a new `GlobalXPService.addXPForDate(date, delta)` (writes `xp_history[date]`, not today). Because it is idempotent and recomputed on every sync, revised data corrects XP instead of adding to it. **Never call `addXP` directly from wearable or wake-up code.**

**Wearable XP rules** (Default; constants in `engine/xp_rules.dart`, owner-tunable):

| ruleId | Trigger | XP |
|---|---|---|
| `steps_goal` | steps ≥ goal (Samsung step goal, else `step_goal_default`) | +10 |
| `steps_stretch` | steps ≥ 1.5 × goal | +5 |
| `active_time_goal` | active minutes ≥ goal | +5 |
| `workout:{id}` | each exercise session ≥ 20 min, max 3 per day | +8 |
| `sleep_goal` | main sleep ≥ sleep goal − 15 min | +8 |
| `sleep_quality` | Samsung sleep score ≥ 80 | +4 |
| `energy_high` | energy score ≥ 80 | +3 |
| `wake_on_time` | wake-up task done | +5 |
| `diet_deficit` | migrated from the old flip logic | +20 |

A daily cap of 40 XP applies to the wearable rules only. No penalties by default.

**Calorie reconciliation** (`calorie_reconciler.dart`).
- `workouts_only`: one `CalorieBurnEntry` per `ExerciseSession`, id `wear_{externalId}`, `source = wearable`, kcal = session active kcal if present, else total. `all_active`: additionally one `wear_daily_{dayKey}` entry "Daily movement" = `max(0, dayActiveKcal − Σ session kcal)`. `off`: none. Entries are upserted by id, so repeated syncs never duplicate and never trigger flip-XP.
- De-duplication: a manual or AI burn entry on the same day is `supersededBy` a wearable entry when its timestamp falls within ±30 min of the session, or the normalised activity matches and durations differ by ≤ 25 %. Nothing is deleted; the UI shows "merged with watch workout" with Undo.
- **Target suggestion** (suggest only, never change `daily_calorie_target` silently): BMR from the latest body-composition BMR (≤ 30 days old), else Mifflin-St Jeor from the profile (10·kg + 6.25·cm − 5·age, +5 male or −161 female); activity factor from the 14-day average steps (<5k 1.2, 5-8k 1.375, 8-12k 1.55, >12k 1.725). Present as a wellness estimate.

**Health composite** (`composite.dart`). Weighted sum of available components, renormalised to 100: calories 25, medicine 20, missions 15, sleep 20, activity 20. Sleep = min(1, duration / goal) blended with score when present; activity = min(1, steps / goal). With the wearable off or empty, only the original three components remain and the weights fall back to 35/35/30.

### 5.6 Age Index (new, my interpretation; **VERIFY with the owner**)
A **fitness-age estimate**: chronological age plus the sum of component adjustments in years, clamped to ±10. It is a heuristic wellness indicator, not a medical or biological-age measurement, and the UI must say so. It needs sex and date of birth (Samsung profile or manual) and at least 3 components with at least 14 days of data each; otherwise show "Not enough data".

| Component (window) | Bands → adjustment (years) |
|---|---|
| Resting heart rate (30-day median) | ≤55 → −2.0; 56-60 → −1.0; 61-70 → 0; 71-80 → +1.0; >80 → +2.0 |
| Steps (30-day average) | ≥12k → −1.5; 8-12k → −0.5; 5-8k → +0.5; <5k → +1.5 |
| Sleep (30-day average and wake-time consistency) | 7-9 h and wake-time SD ≤ 45 min → −1.0; otherwise 0; <6 h → +1.5; SD > 90 min → +0.5 more |
| Body fat % (latest 30 days, sex and age band) | inside the healthy band → −1.0; above → +1.0 to +2.5; below → 0 |
| VO2 max (latest, if any) | ≥75th percentile for age and sex → −3.0; 50-75 → −1.0; 25-50 → +0.5; <25 → +2.0 |
| Skeletal muscle mass index (latest) | good → −1.0; low → +1.0 |

The bands above are placeholders chosen for transparency, not clinical thresholds. Keep them in one constants file, show each component's contribution on the Age Index screen, and **VERIFY the percentile tables** before presenting numbers as meaningful. Optional (Default off): +25 XP once a month when the index improves by at least 0.5 years.

### 5.7 Integration matrix (every datum must land where listed)

| Datum | Calorie tracker | XP / score | Health composite | Tasks | Journal auto-log | AI | Cards / pages |
|---|---|---|---|---|---|---|---|
| Steps, active time | `all_active` mode, target suggester | `steps_*`, `active_time_goal` | activity | metric tasks | end-of-day steps line | local answers | Activity card |
| Exercise sessions | one burn entry each, de-dup | `workout:{id}` | activity | "Workout today" metric task | one line per workout | local answers | Workouts card |
| Sleep | none | `sleep_*` | sleep | "Sleep 7 h" metric task; wake inference | sleep summary line | local answers | Sleep card |
| Wake time (chat/manual/inferred) | none | `wake_on_time` | missions | wake-up task | wake line | action + answers | Sleep card, task card |
| Body composition, weight | BMR for target suggester | none | none | none | none | local answers | Body card, Weight tab |
| Energy score | none | `energy_high` | none | none | none | local answers | Sleep and Energy card |
| Age Index | none | optional monthly XP | none | none | none | local answers | Body card, Health page |

---

## 6. Planner decisions (defaults; owner may override)

1. **Wake rule.** On time means the logged wake time is **at or before** the target (plus grace, default 0). Your note said "if the time is more then it gets ticked"; I read that as "earlier than the target".
2. **Chat wake-up logging runs automatically** with an Undo chip, because you asked for it to be added automatically. Creating or changing the task through the AI still asks for confirmation, as the existing actions do.
3. **A missed day breaks the wake-up streak** (reset to 0), and a day with no log at rollover counts as missed (crossed), editable afterwards. Both are settings (`wake_unlogged_policy`, streak behaviour in `WakeService`). No XP penalty by default.
4. **One journal per day.** The journal page is a timeline of day sections. Existing multiple-per-day entries are grouped under their day, never merged or deleted automatically.
5. **Auto-log** (wake-up, sleep, workouts, steps, energy) is written into the day's journal without unlocking, because the key is in secure storage. Viewing still needs authentication.
6. **Burn credit mode is `workouts_only`.** Only exercise sessions become burn entries. Counting all watch-measured active calories would double-count activity your calorie target probably already assumes. Suggestions to change the target are offered, never applied silently.
7. **Samsung Health Data SDK is primary** (Developer Mode, personal use). Health Connect is an optional fallback (P7-1).
8. **Wearable data stays on the device.** The AI receives wearable numbers only when `wear_ai_share` is on (default off); chat questions like "how did I sleep?" are answered locally.
9. **Foreground sync** (start, resume, manual, 15-minute timer while open). Background sync is optional (P7-2) because Hive must not be touched off the UI isolate.
10. **`minSdk` becomes 29** (Samsung SDK requirement). Record it in your report.
11. **XP values** in §5.5 are starting numbers (a daily mission is worth 5 XP), all in one constants file.

---

## 7. Phases and tasks

Each task lists the files and the behaviour that must exist when it is done. There are no test tasks here; all testing is Phase 8.

### Phase 0: Prerequisites and discovery

**P0-1 Owner setup and baseline.** Confirm the four owner prerequisites in §4 (SDK AAR, Samsung Health version, Developer Mode, paired watch). Run `flutter analyze` on a clean checkout and record the warning count; Phase 8 compares against it. Grep the real typeIds in use and confirm 60-79 are free.

**P0-2 Android build setup.** Raise `minSdk` to 29. Add the SDK AAR under `android/app/libs/` and reference it from `android/app/build.gradle.kts`; add any coroutine dependency the SDK requires (**VERIFY** from its docs). Add a `<queries>` entry for Samsung Health's package (`com.sec.android.app.shealth`, **VERIFY** the name and whether it is required). Keep release minification off as it is today; if you ever enable it, add the SDK's Proguard rules.

**P0-3 Data discovery spike (debug only).** Add a `dump(days)` method to the bridge (P4-1 skeleton is enough) that writes raw SDK data for every type in §4 to `wear_debug_dump.json`, guarded by `wear_debug_dump`. When a device is available, run it once; strip identifiers and commit a sample to `test/fixtures/samsung/`. Write `docs/WEARABLE_FIELD_MAP.md` resolving every **VERIFY** in §5.2 (property names, units, active versus total calories, energy score fields, ids, device types). Without a device, write the map from the SDK API reference and mark every unconfirmed field.

### Phase 1: Foundations

**P1-1 Models and adapters.** Add the models in §5.2 and the field additions in §5.3; run build_runner; register adapters and open the plain boxes in `main.dart`. The `journals` box stays lazily opened through `JournalService`.

**P1-2 Repositories.** `WearableRepository`, `TaskDayLogRepository`, `WakeLogRepository`: upsert by key, soft-delete via the `deleted` flag, `ValueListenable` change streams. They are the only code that touches the new boxes.

**P1-3 XP ledger.** Add `GlobalXPService.addXPForDate(DateTime, int)` (updates `xp_history[date]`, preserving the per-day clamp) and `XpLedger.set(dayKey, ruleId, amount)` applying deltas only (§5.5). Do not change existing `addXP` callers yet.

**P1-4 Settings.** `WearableSettings` helper exposing the §5.4 keys with defaults.

**P1-5 Journal migration v1.** Copy the `journals` Hive file to a `.bak_mvp4` sibling, then backfill `dayKey` on legacy entries from `createdAt`. If the encrypted box cannot be opened, skip and retry next launch.

### Phase 2: Day Journal (feature B)

**P2-1 `JournalDayRepository`.** Wraps `JournalService`. `getOrCreateDay(dayKey)` (id `day_{yyyy-MM-dd}`, title = formatted date, empty Quill body). `appendAutoLog(dayKey, AutoLogEvent{key, ts, kind, text, source, params})` upserts by `key` into `autoLogJson`; it opens the encrypted box without authentication, runs through a single-writer queue, and on any failure stores the event in `settings['journal_inbox']` and flushes it on the next successful open so nothing is lost. `removeAutoLog`, `legacyEntriesFor(dayKey)`.

**P2-2 Day timeline page.** Replace the journal list with a timeline: sticky date headers, newest first, **today always present** even when empty. Each section shows its auto-log lines as compact icon chips, the first lines of the owner's text, and an "Earlier entries (n)" group for legacy entries of that day. Search across days, a calendar jump, and the existing unlock gate and 60-second auto-lock.

**P2-3 Day editor.** Opens the day document for a date. Shows the auto-log block above the Quill editor (read-only; swipe a line to remove it; removing does not touch the source data). Autosave behaves as today. There is no "new journal" for a day that already has one; the button opens today's.

**P2-4 Optional merge.** "Merge this day's entries" appends legacy bodies under dated sub-headings into the day document and sets `mergedInto` on the originals (hidden, not deleted), with Undo. Never automatic.

**P2-5 Journal home card.** Create opens today's document; View keeps the authentication flow and lands on the timeline. Show how many auto-log lines today has.

### Phase 3: Wake-up task (feature A)

**P3-1 `WakeService`.** Pure rules in `engine/wake_rules.dart` (§5.5) plus a thin service: `createWakeupTask(targetMinutes, grace)` (enforces a single wake-up task; a second request edits the target), `logWake(wakeAt, source)`, `editWake`, `undo`, `evaluate`, `rolloverMissedDays(now)`. Set `isCompleted`, `lastCompletedDate` and the streak directly for `kind == wakeup`; **do not call `Goal.complete()`**, because its XP is not reversible. Award `wake_on_time` through the ledger.

**P3-2 Rollover hooks.** Call `rolloverMissedDays` beside `TaskResetService.checkAndResetTasks()` in `main.dart` and in `app.dart`'s resume handler. Handle gaps of several days (bounded at 60).

**P3-3 Chat.** Add intent `wake` to `detectIntent` after the vault and finance checks and **before** the task-create check and the diet keyword scan ("make me a wake up task" must not be taken as a generic task, and "woke up" must not fall into diet). `_handleWakeLocally` uses the parser (§5.5) and returns an `AiResponse` with `AiAction('wakeup_log', {wake_at, source: 'chat'})`. Add `autoExecute` to `AiAction` (default false). `home_chat.dart` runs auto-actions immediately and renders an **Undo** chip that calls `WakeService.undo`. Add `wakeup_task_create`, `wakeup_target_set` and `journal_note` (adds an auto-log line of kind `note`) as normal confirm-first actions. Responses:
- With a task: "Logged 04:00, on time (target 05:00). Added to today's journal."
- Late: "Logged 05:40, 40 min after your 05:00 target. Marked missed."
- Without a task: "Logged 04:00 in today's journal. Want a daily wake-up task?" with a Create action.
Extend `buildSystemPrompt()` and `executeAction` for the Gemini path; the same parser validates `wake_at` (reject future times).

**P3-4 Task creation.** `AddTaskDialog` gets a "Wake-up" template (target time picker, grace). Settings gets the wake-up defaults (§5.4).

**P3-5 Task card for `kind == wakeup`.** Shows the target and today's logged time, ✓ when done, ✕ when missed, a dash while pending, and a 7-day strip. Tapping opens a sheet to edit today's wake time, change the target, and see the last 30 days.

**P3-6 Journal hook.** Every log, edit and undo upserts or removes the auto-log line keyed `wake`: "Woke up 04:00 · target 05:00 · on time ✓ · via chat".

### Phase 4: Samsung bridge and sync (feature C, data layer)

**P4-1 `SamsungHealthBridge.kt`.** Copy `MediaSessionBridge`'s structure: a MethodChannel `habit/samsung_health` registered in `MainActivity.configureFlutterEngine`. Methods: `getStatus`, `requestPermissions(types)`, `readDaily(start, end)` (steps, activity summary, goals, heart-rate aggregates), `readSleep(from, to)` (with stages via the associated-data API), `readExercises`, `readBodyComposition`, `readEnergyScore`, `readUserProfile`, `readChanges(type, token?)`, `dump(days)`. All calls run off the main thread; every SDK exception is mapped to a stable error code (`not_installed`, `old_version`, `no_permission`, `access_control`, `policy_2003`, `unknown`); return plain maps with epoch milliseconds.

**P4-2 Dart source and mappers.** `WearableSource` interface and `SamsungHealthSource`. Mappers are pure functions from channel maps to the §5.2 models, tolerant of missing fields, converting to canonical units.

**P4-3 `SyncService`.** Single-flight. Triggers: app start, resume (minimum 10 minutes apart), manual, after a permission grant, a 15-minute foreground timer. First run backfills `wear_backfill_days`. Per type, use `readChanges` with the stored token to upsert or soft-delete by `externalId`; if a token is rejected, re-read the last 7 days (upserts are idempotent). Aggregate-only types (steps, activity) re-aggregate the last 3 days plus today every sync. Sleep belongs to the wake day, exercise to its start day. After ingest, emit one `WearableChanged` notification and call the reconcilers (Phase 5). Surface typed errors, never crash the UI.

**P4-4 Settings: Wearables section.** Status chip (Not set up / Developer Mode needed / Permission needed / Connected), setup guide (the §4 prerequisites), Connect, Sync now, last sync and counts, per-type toggles, backfill days, burn credit mode, AI-sharing toggle, debug dump. Stop requesting permissions after two denials and show guidance instead.

**P4-5 Profile.** Read Samsung's user profile (sex, date of birth, height, weight) into `profile_*` only where empty; allow manual entry. Never send it to the AI.

### Phase 5: Core integration (feature C, wiring)

**P5-1 Day read model.** `WearableRepository.dayView(dayKey)` returns one object combining activity, main sleep and naps, exercises, energy score, latest body composition, wake log and XP ledger entries. Every surface reads this, not raw boxes.

**P5-2 XP.** Implement `XpRules.evaluate(dayView, settings)` and `WearableXpService.reconcile(dayKey)`; call it after each sync for the last 3 days plus today. Move the existing diet-deficit XP to the ledger (`diet_deficit`): replace the flip logic in `DietDayLog.addFood/addBurn/removeFood/removeBurn` with a call to `DietXp.reconcile(dayKey)`. Start the ledger at the migration day and never reconcile earlier days (their XP was already awarded). Apply the 40 XP wearable cap.

**P5-3 Calorie tracker.** `CalorieReconciler` upserts burn entries per §5.5 (creating the `DietDayLog` for a missing day with the target from settings), applies `supersededBy` for duplicates, and `DietDayLog.totalBurned` skips superseded entries. UI: a watch icon on wearable entries in the burn list and dashboard, a "Steps and active kcal (watch)" row in the day summary, a "merged with watch workout" note with Undo, and the target-suggestion banner (Accept / Dismiss).

**P5-4 Weight and body composition.** Store `BodyCompSample`s. Write or update the day's `WeightEntry` (source `wearable`) only when there is no manual entry that day (manual wins). The Weight tab gets a composition panel (fat %, skeletal muscle, water, BMR) with trends.

**P5-5 Health composite.** Update `HealthSummaryData` and `HealthCalculator` per §5.5 with optional parameters so existing callers still compile.

**P5-6 Wake inference from sleep.** After a sleep sync, if `wake_infer_from_sleep` is on and the wake day has no chat/manual log, create a `WakeLog(source: sleep_infer)` from the main sleep session's end (the longest session ending before 14:00; naps excluded), evaluate the task provisionally, and mark the journal line "(from watch)". A later chat or manual log overrides it.

**P5-7 Metric tasks.** `Goal.kind = metric` with `metricKey` in `steps, active_minutes, sleep_minutes, workout_minutes, energy_score`. Sync updates `currentValue`; reaching the target completes the task directly (XP through the ledger rule `metric:{goalId}`, not `Goal.complete()`). Templates in `AddTaskDialog`: "10,000 steps", "30 active minutes", "Sleep 7 h", "Workout today". The existing daily reset applies.

**P5-8 Journal auto-log from the watch.** Upsert by key: `sleep` (summary), `workout:{id}` (one per session), `steps` (updated through the day), `energy`. Respect `journal_autolog_kinds`.

**P5-9 AI.** New intent `wear`, answered locally from `dayView` and the engines: steps, sleep, walks, workouts, energy score, body composition and trend, Age Index, "sync my watch" (an auto-execute `wear_sync` action). `AiContext.buildWearContext()` returns one compact line (under 60 tokens) and is attached to Gemini calls only when `wear_ai_share` is on.

### Phase 6: Cards, Fitness pages, Age Index

**P6-1 Home cards.** Register in `HomeCardRegistry.registerDefaults()`: `activity` (steps ring against the goal, active kcal and minutes), `sleep` (last night's duration, score and stage bar; wake time ✓/✕; energy score; wake-up streak), `workouts` (latest three plus today's total), `body` (weight, fat %, muscle, Age Index chip). Use `HomeCardFrame` and the M3E tokens. Not-connected state shows a "Connect Samsung Health" call to action. New cards append to the end of existing layouts per the registry's merge rule.

**P6-2 Fitness tab.** Third tab on `HealthPage` (0 Medicine, 1 Weight, 2 Fitness) with sections: Activity (7- and 30-day steps, active minutes), Workouts (list and detail), Sleep (stage chart, 14-day duration and score, wake-time consistency), Body (composition trends), Energy (score trend), Age Index. Charts with `fl_chart`.

**P6-3 Age Index.** Engine and screen per §5.6: component contributions, confidence, disclaimer, monthly trend, "needs profile" prompts, the optional monthly XP rule (off by default).

**P6-4 XP breakdown.** A "Where did my XP come from?" sheet from the score cards, grouped by rule from the ledger. `ScoreService` itself is unchanged.

**P6-5 Health notices.** Optional notification when Samsung Health permission is lost or sync has failed for 24 hours (`showInstantNotification`).

### Phase 7: Optional hardening (only if time; each is gated)

**P7-1 Health Connect source.** A second `WearableSource` for devices without the Samsung SDK path: steps, sleep, exercise, weight and body fat where Samsung writes them. Respect the 30-day history limit and request background-read access only if needed. **VERIFY** whether to use the Flutter `health` package or a second Kotlin bridge.

**P7-2 Background inbox.** A native WorkManager periodic worker (15-minute minimum) that reads the SDK and writes raw JSON to a native `wear_inbox/` folder; the UI isolate ingests it on start and resume. The worker never touches Hive. Default off.

**P7-3 Encrypt wearable boxes at rest** using the journal's key pattern. Default off.

**P7-4 Remove the unreferenced duplicate `lib/models/goals.dart`** (needs owner approval).

---

## 8. Phase 8: Testing, QA, documentation and release

Everything testing-related lives here, as requested. Do not start before Phases 1 to 6 compile. Fix defects you find in the owning phase's files and re-run the affected tests.

### 8.1 Test infrastructure
- `test/fixtures/samsung/*.json` from the P0-3 dump (sanitised), or hand-built fixtures matching `docs/WEARABLE_FIELD_MAP.md`.
- `FakeWearableSource` (scriptable responses, errors, change tokens), an injectable clock, and a temp-directory Hive harness. Copy the pattern in the existing `test/services/*` tests. Use `JournalService.setMockDependencies` for secure storage and `local_auth`.
- Put new tests under `test/features/wearables/`, `test/features/journal/`, `test/features/wakeup/`.

### 8.2 Unit tests

| Area | Cases to cover |
|---|---|
| Wake parser | At least 40 utterances: English, Hinglish, "at 4", "4:30", "5 am", "7 pm", "16:00", "just woke up", "10 minutes ago", "yesterday", "12" (clarify), a future time (clarify once), no meridiem for hours 1-11, messages containing pm/evening/night, and non-wake sentences that must not match |
| Wake evaluation | Target 05:00, grace 0: 04:59 ✓, 05:00 ✓, 05:01 ✕; grace 10: 05:10 ✓, 05:11 ✕. Edit ✕→✓ and ✓→✕ (XP ±5 exactly once, streak consistent), undo, same-day double log, task created after the target time (neutral day), multi-day rollover gap, `neutral` versus `missed` policy |
| XP ledger | `set` twice = one award; lowering to 0 reverses it; writes to the event's own date; per-day clamp; wearable cap of 40; ledger never double-awards with the diet migration |
| XP rules | Each rule at its boundary (steps at goal and at 1.5×, workout at 19 vs 20 min, 4th workout of the day, sleep goal − 15 min, score 79 vs 80, energy 79 vs 80); revised data lowers XP on the next reconcile |
| Calorie reconciler | Each burn credit mode; upsert by id with no duplicates; `supersededBy` at the ±30 min and ±25 % thresholds; Undo; `totalBurned` excludes superseded; no flip-XP from imports; day log created for a missing day |
| Diet XP migration | Existing days untouched; ledger starts at the migration day; toggling food in and out of deficit nets to one award |
| Target suggester | Mifflin-St Jeor: male 80 kg, 180 cm, 30 y = 1780 kcal; female 65 kg, 165 cm, 28 y = 1380.25 kcal; ×1.55 for a 10k-step average; body-comp BMR preferred when ≤ 30 days old |
| Composite | Renormalisation with missing components; wearable off reproduces the old 35/35/30 results exactly |
| Age Index | Every band edge for each component; the minimum-data gate (3 components, 14 days); clamp at ±10; missing sex or date of birth |
| Mappers | Fixtures to models; missing fields; unit conversion; naps; sleep crossing midnight lands on the wake day |
| Sync service | Backfill; incremental tokens; rejected token falls back to a 7-day re-read; deletions soft-delete and unlink the burn entry; partial failure leaves consistent data; single-flight; every error code maps to a status |
| Journal day repository | Upsert by key; write while locked; inbox fallback and flush; day id stability; legacy grouping by `dayKey`; merge and Undo; encrypted round trip |
| Metric tasks | Completion at the threshold, reversal when data is revised down, daily reset |
| AI routing | `wake` routes before the diet keywords; a regression table of existing diet, finance, task, vault and music phrases that must still route as before; `autoExecute` and Undo; local wearable answers; the context line is attached only when `wear_ai_share` is on and is under the token budget |
| Migrations | MVP 2 data to MVP 4 (idempotent; backup file exists; kill-mid-way leaves usable data); `journals` backfill of `dayKey` |

### 8.3 Widget tests
Wake-up task card (pending, ✓, ✕, 7-day strip); chat bubble with an auto-executed action and its Undo chip; journal timeline (today present when empty, sticky headers, auto-log chips, grouped legacy entries); each wearable card in empty, connected and error states; Settings status chips; diet burn list watch icon and merge note.

### 8.4 Integration tests (fake source, no device)
Sync → burn entries → ledger XP → composite → journal lines in one pass; re-sync produces no duplicates; killing the process between steps leaves consistent data; disconnecting the source leaves every screen usable.

### 8.5 Static checks
`dart format .` clean; `flutter analyze` has no new warnings versus the P0-1 baseline; searches that must come back empty: `addXP(` inside `features/wearables` and the wake-up code, Hive box access outside the repositories, any Hive access reachable from a background isolate.
. No log all day. On the next open, yesterday shows ✕ (policy `missed`).
6. The watch's sleep ends at 04:12 and there is no chat log. The task is provisionally ✓ with "(from watch)". Then "woke up at 4:40" overrides it.
7. Run 30 minutes on the watch. One burn entry appears; a manual "ran 30 min" logged earlier is merged under it; +8 XP once; a re-sync adds nothing.
8. Steps reach 11,000 with an 8,000 goal: +10 and +5 XP once each. If a later sync revises steps to 7,500, that XP is removed.
9. Open Journal (authenticate). Today's section shows the wake, sleep and workout lines plus your text; old days with several MVP 2 entries are grouped.
10. With the watch connected the health composite includes sleep and activity; with it disconnected the composite equals the old value. Age Index shows "Not enough data" until 14 days exist.
11. Disconnect or revoke permissions. The app stays fully usable, the cards show the connect prompt, and nothing crashes.

### 8.6 End-to-end acceptance scenarios
1. Target 05:00. Say "hey i woke up at 4". The task shows ✓, +5 XP once, the streak increments, today's journal section gains a wake line, and an Undo chip appears.
2. Say "woke up at 5:40". The task shows ✕, the streak resets to 0, there is no XP, and the journal line updates.
3. Edit 5:40 to 4:50 in the task sheet. ✕ becomes ✓, +5 XP exactly once, and the journal line is replaced.
4. Say "woke up at 12". One clarifying question appears. Say "woke up at 3 tomorrow morning". No log is written and the reply explains why.
5
### 8.8 Documentation
Update `APP_DOCUMENTATION.md` (boxes, models, engines, channels, the XP rule table, wake rules, settings keys, new cards), finish `docs/WEARABLE_FIELD_MAP.md`, extend `MANUAL_QA.md`.

### 8.9 Release
Bump the version. Record that the build is debug-signed and relies on Samsung Developer Mode. Write a rollback note: Hive backups, the `.bak_mvp4` journal copy, and `wear_enabled = false`. Final report in the usual format, with an explicit list of what was verified by tests, what only by reading code, and what needs the device.

---

## 9. Open questions for the owner

Proceed on the stated default for each, except where marked.

1. **Age Index.** There is no such concept in the app and it is not a Samsung metric. I defined it as a fitness-age estimate (§5.6). Is that what you meant, or did you mean something else (for example Samsung's body-age style figures, or a plain "days since start" counter)? *(Needs your confirmation.)* it is samsumng AGEs ibdex
2. **Wake rule.** On or before the target is ✓. Your sentence said "more"; please confirm the direction.after
3. **No log on a day.** Crossed (default) or neutral? crossed
4. **Streak.** Resets on a missed wake-up (default). Keep, or never reset?keep unless for a lomg time
5. **Calorie credit.** Exercise sessions only (default), or all watch-measured active calories?credit for excersie sessions but total burned calories should be taken 
6. **Developer Mode** is acceptable for your personal build, and you will provide the SDK download. *(Blocks Phase 4.)* maybe
7. **`minSdk` 29** is acceptable (§6.10).
8. **AI and health data.** Keep wearable numbers out of Gemini requests by default? yes but have the option to send if we need it
9. **MVP 3.** Push it to GitHub so a later pass can verify typeIds and shared files against it.

## 10. Out of scope

iOS or HealthKit; a Wear OS companion app; writing data back to Samsung Health; ECG, blood pressure, blood glucose, irregular-rhythm and sleep-apnea data; exercise GPS routes; Samsung's stress score, antioxidant index, vascular load, bedtime guidance and heart-rate variability (not exposed by the SDK); other brands (Garmin, Fitbit, Apple); cloud sync; Samsung partner registration, a release keystore and Play Store distribution; any change to the finance module (MVP 3); changing existing typeIds, field indexes or box names.