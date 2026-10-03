# Habit Tracker MVP 2: Implementation Spec for a Coding Agent

Written for Claude Opus working autonomously in the repo root (`Roshen-Reji/habit_tracker`, branch `master`). The code facts below were read from the repo on 3 Oct 2026. Line numbers are approximate; re-read a file before you edit it.

Markers used in this file:
- **VERIFY:** something I could not confirm. Check it in the code or the package docs before relying on it.
- **Default:** a planner decision the owner has not confirmed. Proceed with it, and list it in your phase report so the owner can override it.

---

## 1. Mission

Ship MVP 2 of **Commander Habit Tracker** (Flutter 3.x, Dart 3.x, Hive, offline-first):

1. Three small fixes: thinner nav bar, a working Gemini model chain, SIPs debited on their due day.
2. A Material 3 Expressive redesign, with a wallet-style scrolling card stack as the home screen.
3. A music rewrite: remove the in-app player, add a controller for whatever app is playing.
4. New cards and features: Journal (locked), Brainstorm, Reader (PDF), Medicine, Weight, Health summary, score cards.

Success means every task below meets its **Done when** line, `flutter analyze` and `flutter test` pass with no new warnings, and a user upgrading from MVP 1 keeps all existing data.

---

## 2. Working agreement

**Process**
- Work phase by phase in the order in §6. Phase 3 (music) is independent of Phases 2, 4 and 5 and may run in parallel. Phase 2 needs Phase 1.
- One branch per phase (`mvp2/p0-fixes`, `mvp2/p1-foundation`, ...), one commit per task, message format `P0-3: post SIPs on due day`.
- Keep the app compiling at every commit. Where a task replaces something (music, nav), add the new path first, switch over, then delete the old one.
- Keep edits local. `finance_page.dart` (~2,950 lines) and `ai_service.dart` (~2,750 lines) are large. Put new logic in new files and touch the big files only at the seams named below.

**Verification**
- After each task run `dart format .`, `flutter analyze`, `flutter test`. After any change to a `@HiveType` model run `dart run build_runner build --delete-conflicting-outputs`.
- You likely have no device. Do not claim UI, notifications, biometrics, storage permissions or media-session behaviour work unless you ran them. List them under "Not verified" in your report and add them to `MANUAL_QA.md` (Phase 6).
- For third-party packages, run `flutter pub get`, then read the package's README, example and public API in the pub cache before writing code. Do not write package calls from memory.

**Data safety (Hive)**
- Never change an existing `typeId` or an existing `@HiveField` index. Add new fields with new indexes and nullable or defaulted values.
- New models use typeIds from **30** upward (existing: 0, 1, 2, 4, 10, 11, 20-23). Register adapters in `main.dart` next to the existing ones.
- Migrations must be idempotent and must never delete or reset an existing box. Back up the relevant box content to a JSON string in memory before rewriting it and abort the migration on any exception.
- Writing new keys into existing untyped boxes (`settings`, `finance_settings`) is fine; do not rename existing keys.

**Stop and ask the owner before**
- Upgrading the Flutter SDK.
- Any new Android permission with Play Store implications, other than the all-files access already covered by default in §5.9 (flag that one in your report).
- Deleting user data of any kind.
- Anything in §7 where you cannot proceed on the stated default.

**Effort**
- Reason carefully on: SIP date logic, Hive migrations, notification scheduling, encrypted storage, the media-session bridge.
- Move quickly on mechanical work: import swaps, deletions, renames, boilerplate dialogs.

**Report at the end of each phase** (short): what changed, how you verified it (commands and results), what you could not verify, defaults you applied, questions for the owner.

---

## 3. Repo facts (read from `master`)

**Shell and navigation**
- `lib/screens/home_page.dart`: `_selectedIndex` plus `_pages = [DashboardView, TasksPage, DietPage, MusicLibraryPage]`. A `Stack` holds `StarBackground`, `BottomNavBar`, `GlobalFloatingPlayer`, `HomeChatFAB`. `extendBody: true`.
- `lib/widgets/bottom_nav_bar.dart`: margin `fromLTRB(16,0,16,24)`, padding `16`, tab height `60`, icon size `26`, four tabs (home, target, utensils, music). About 92px tall.
- `lib/features/tasks/tasks_page.dart`: a private `_currentView` string (`'missions' | 'finance' | 'vault'`) swaps in `FinanceDashboard` or `SpeechVaultPage`. `TaskAnalyticsPage` is pushed from here (~L118). Finance and Speech Vault are not tabs.

**Dashboard**
- `lib/screens/dashboard_view.dart`: a `SingleChildScrollView` column with greeting header and settings button, `MysteriousQuoteCard`, `MysteriousMomentumGraph`, `_buildDietSummaryCard()`, then up to 3 daily missions. Bottom padding is 180.
- `lib/widgets/mysterious_momentum_graph.dart`: listens to `Hive.box('xp_history')`, uses `GlobalXPService.getPast7DaysXP()`, dot matrix of 10 dots per day, 1 dot = 10 XP, 150px high.

**Finance**
- `lib/features/finance/finance_page.dart`. Settings in `Hive.box('finance_settings')`. Key `planner` holds `{fixedExpenses: [], sips: []}`.
  - SIP map: `{name, amount: double, due: int (default 5), folio}`. No `id`, no `createdAt`.
  - SIP created ~L2547-2570, deleted by list index ~L499-503, legacy planner migration ~L158-180.
  - Snapshot ~L305-360: `totalBalance = vaultTotal + allTimeNet + goalsSaved`; PLAN view uses `sipTotal` (~L683, ~L893-905).
- `lib/models/finance_model.dart`: `Transaction` (typeId 10: title, amount, category, date, mode, icon; no id or notes field) and `AssetVault` (typeId 11).
- Nothing ever posts SIPs; they are projections only.

**AI**
- `lib/data/services/ai_service.dart`:
  - Gemini call ~L2120-2200. `modelCandidates = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash']`. The loop breaks only on 200, 401 or 403. On a 404 or 429 it falls through, so the surfaced error and logged model are those of the last attempt (1.5). The request uses `system_instruction`, `responseMimeType: 'application/json'`, `http.post` directly, and a 2-message history cap.
  - Two `MusicManager().setPlaylist(...)` call sites (~L2550, ~L2584). Local regex NLP handles music intents in English and Hinglish.

**Music (to be replaced)**
- `lib/services/music_manager.dart` (singleton on `just_audio`, publishes `currentDominantColor` via `palette_generator`), `lib/features/music/*`, `lib/services/lyrics_service.dart`, `lib/widgets/local_music_manager.dart`, `lib/widgets/mini_player_bar.dart`, `lib/models/song_model.dart`, `test_query_songs.dart` at the repo root.
- Files that import music code and need edits: `app.dart`, `main.dart` (`JustAudioBackground.init`), `core/theme/bento_theme.dart`, `features/home/home_chat.dart`, `data/services/ai_service.dart`, `widgets/mini_player_bar.dart`.

**Other**
- `main.dart` registers adapters and opens boxes: `mission_box_v4`, `settings`, `speech_vault`, `finance_transactions`, `finance_vaults`, `finance_settings`, `diet_logs`, `xp_history`.
- Two theme files exist: `lib/theme/app_theme.dart` and `lib/core/theme/app_theme.dart`. `app.dart` also builds its own `ColorScheme`.
- `lib/data/services/notification_service.dart` uses `flutter_local_notifications` + `timezone`.
- `pubspec.lock` SDK constraints: Dart >=3.12, Flutter >=3.44.
- Not present: medicine, weight, journal, brainstorm, PDF reading. No `local_auth`, `flutter_quill`, `pdfrx`, `flutter_secure_storage` dependency yet.

---

## 4. Requirements (owner's intent)

**Small fixes**
- Nav bar is too thick; reduce its size, especially height.
- Gemini API is not working and appears to be on 1.5; fix it.
- SIPs are deducted from the balance on their designated day.

**Redesign**
- Adopt Google's Material 3 Expressive.
- Momentum Signal Graph: smaller compact form showing only the days with completed work; expands to the full graph on tap.
- Home is a wallet-holder-style stack of cards that scroll up and down, revealing other cards, with animation on scroll.
- Card order and visibility are editable from Settings.
- Every card navigates to its tab or screen on tap.
- Cards: Finance Summary, Calorie Summary, Medicine Reminder, Health Summary, Weight Journey, a score card (week, month, year), a score-difference card (day vs previous week and month), Music control panel.
- **Journal** card with two options. *Create* opens a new tab with standard note-taking features. *View* asks for pattern, PIN or fingerprint, then shows all journals to read or edit.
- **Brainstorm** card: add ideas (title + description); buttons Add and View all.
- **Reader** card: folders are added in Settings; PDFs from those folders show as covers on the card, 3 at a time, plus View all. The PDF reader is simple, easy, creative and functional.

**Music**
- Remove the Music tab entirely. Keep only the music control panel (card), the mini player and the expanded controls. Remove everything else music-related.
- The panel detects the music currently playing and has typical player controls.
- The AI can still change songs.

---

## 5. Planner decisions (defaults; owner may override)

1. SIPs post as an expense that reduces the balance; no credit to an investment vault.
2. Existing SIPs are not back-charged: on migration their `createdAt` is "now".
3. Journal lock uses the device credential (PIN, pattern, password or biometric) through `local_auth`, not a custom in-app pattern.
4. Lyrics are removed along with the music tab.
5. "Difference in scores" means today vs yesterday, this week vs last week, this month vs last month.
6. Health Summary is a composite: latest weight, net calories vs target, medicine taken/total today, health-category missions completed today.
7. Medicine, Weight and Health live on a new pushed `HealthPage` (not a bottom-nav tab). Bottom nav becomes three tabs: Home, Tasks, Diet.
8. Existing dashboard content (quote, daily missions) is wrapped as cards in the same registry so ordering and visibility work uniformly. Greeting header and settings button stay fixed above the stack.
9. Reader folder access uses all-files access (personal sideloaded app). Play Store distribution would need a different approach (SAF).
10. Music detection and control are Android-only. On other platforms the music card is hidden.
11. A day counts as "completed work" in the compact momentum view when its XP is greater than 0. Diet XP (±20) also lands in `xp_history`, so this is an approximation; mention it in your report.

---

## 6. Phases and tasks

### Phase 0: Small fixes (ship first)

**P0-1 Nav bar height**
- Files: `lib/widgets/bottom_nav_bar.dart`, `lib/screens/home_page.dart`, `lib/widgets/mini_player_bar.dart` (`GlobalFloatingPlayer`), `lib/features/home/home_chat.dart` (`HomeChatFAB`), bottom paddings in pages (dashboard uses 180).
- Do: padding 16 → vertical 8 / horizontal 12; tab height 60 → 46; icon 26 → 22; bottom margin 24 → 12; keep the 16 horizontal margin. Target about 62px excluding the system inset. Then re-anchor the floating player and FAB and trim page bottom paddings so there is no dead space and no overlap. **VERIFY:** how the floating player and FAB compute their offsets.
- Done when: a widget test confirms the nav is about 62px tall; no overlap between nav, mini player, FAB and the last list item at 360x640 and 412x915; the selected-tab animation is unchanged.

**P0-2 Gemini client**
- Files: new `lib/data/services/gemini_client.dart`; `ai_service.dart` (call it at ~L2150); `settings_page.dart`.
- Do:
  1. Move transport, model resolution and error mapping into `GeminiClient` with an injectable `http.Client`. Keep `AiService`'s public API, the `system_instruction` field, `responseMimeType: 'application/json'` and the history cap unchanged.
  2. Model resolution order: `settings['gemini_model']` (owner override) → models from the ListModels endpoint filtered to those supporting `generateContent` and in the flash family, newest first, cached in `settings` with a timestamp (24h) → a short built-in fallback list.
  3. **VERIFY the model IDs.** A secondary source (Oct 2026) says `gemini-2.0-flash` is shut down and names `gemini-3.6-flash` and `gemini-3.8-flash`; Google's own deprecation table lists 2.0 and 2.5 flash for retirement. Confirm current IDs at `https://ai.google.dev/gemini-api/docs/models` and `/deprecations`. Do not hardcode IDs from this file. **VERIFY** whether the API key should go in the `x-goog-api-key` header instead of the query string (preferred, keeps it out of logs).
  4. Status handling: 404 → next model. 429 → back off once (honour `Retry-After` if present), then next model. 400 → stop and surface the body. 401/403 → stop with key guidance (keep the `activeApiKeySource` wording).
  5. Log `status model truncated-body` per attempt via `debugPrint`. Surface the first non-404 error to the user, not the last.
  6. Settings: model-override field and a **Test connection** button (minimal request; shows model used and status).
  7. Update `APP_DOCUMENTATION.md` §5.6 (fallback chain text).
- Done when: unit tests with `MockClient` cover 404 → next model, 429 → backoff, 403 → stop, success path, and ListModels failure → fallback list. Manual (owner, real key): Test connection succeeds.

**P0-3 SIP debits**
- Files: new `lib/data/services/sip_service.dart`; `finance_page.dart` (add dialog ~L2547, delete ~L499, PLAN view ~L880-950, snapshot ~L305-360); `main.dart`; notification service.
- Do:
  1. `SipService.runDue({DateTime? now})` returns the number of debits posted. Inject the clock for tests.
  2. One-time idempotent migration: give every existing SIP a stable `id` and `createdAt = now` (so nothing is back-charged). New SIPs get both at creation. Deleting a SIP also removes its ledger entry.
  3. Rule: for each SIP, for each calendar month from the later of `createdAt`'s month and the month after `sip_ledger[id]`, through the current month, compute `dueDate = DateTime(y, m, min(due, daysInMonth))`. Post when `dueDate >= createdAt` (date part) and `dueDate <= today`.
  4. Post an expense `Transaction`: title `SIP · {name}`, category from the existing list (add "Investment" if absent), `date = dueDate` (not now). **VERIFY** how existing code encodes expense vs income in `mode` and the sign of `amount`, and how `allTimeNet` is computed, by reading how expenses are created and summed. Follow that convention exactly.
  5. Invariant: a SIP/month pair never produces two transactions, and a crash mid-run never silently loses one. Suggested approach: a deterministic key `sip_{id}_{yyyy-MM}` with `box.put`. **VERIFY** that no code reads or deletes transactions by integer index or `keyAt`; if it does, post then record in the ledger with a pre-check for an existing matching transaction instead.
  6. Ledger: `finance_settings['sip_ledger'] = {id: 'yyyy-MM'}`.
  7. Run at boot (after boxes open, before `runApp`) and on app resume. **VERIFY** whether the resume hook exists: the docs say `TaskResetService` runs on resume but `main.dart` only calls it at boot. If no `WidgetsBindingObserver` exists, add one in `app.dart`.
  8. Send a local notification per posted debit via the existing `NotificationService`. PLAN tab shows "next debit: {date}" per SIP.
  9. Fix the double count: PLAN's projected disposable income must subtract only SIPs not yet posted this month. Fixed commitments are unchanged.
- Examples the tests must cover:
  - `due = 31` in Feb 2027 → posts on Feb 28. `due = 30` in Feb 2028 → Feb 29.
  - SIP created 2026-10-15 with `due = 5` → first debit 2026-11-05.
  - App not opened for 3 months → 3 transactions, each dated on its own due date.
  - `runDue` twice on the same day → no duplicates.
  - December → January rollover.
- Done when: the tests above pass; Overview balance drops by the SIP amount once on the due date.

### Phase 1: Foundation (before any new UI)

**P1-1 Material 3 Expressive spike (decision gate)**
- Branch `mvp2/p1-m3e-spike`. Check `flutter --version` against the package's constraints after adding `material_3_expressive`. Do not upgrade the SDK without asking.
- The package is community-maintained (not Google's) and reportedly requires `package:material_ui/material_ui.dart` imports instead of `package:flutter/material.dart`, with minimum Flutter versions that vary by release. **VERIFY** all of this from the package's own README and `pubspec.yaml`.
- Do: run the import swap as a scripted codemod across `lib/`, build, and check that `fl_chart`, `youtube_player_flutter` and the other plugins still compile and pick up the theme.
- Gate report: number of files changed, build result, incompatible plugins, recommendation. Proceed on your own only if the build is green and no SDK upgrade is needed. Otherwise stop and ask.
- Fallback if the gate fails: stock Material 3 (`useMaterial3: true`) plus `lib/core/theme/expressive_tokens.dart` (large corner radii, spring-style motion, shape morphs via `flutter_animate`), same visual language.
- Also: merge the two `app_theme.dart` files into `lib/core/theme/`, and keep the dark Bento base (see §7 on Material You).
- Done when: the app builds and launches on the new theme root; Settings is restyled as the pilot screen.

**P1-2 Navigation plumbing**
- New `AppNav` (`ChangeNotifier` or `ValueNotifier`) with `tab` and `tasksSubview` (`missions | finance | vault`). `HomePage._selectedIndex` and `TasksPage._currentView` read and write through it. Expose `AppNav.goTo(tab, {sub})`.
- Done when: a test calling `goTo(tasks, sub: finance)` from the dashboard ends on the finance sub-view.

**P1-3 Card registry**
- `lib/features/home/cards/home_card.dart`: `HomeCardSpec {id, title, icon, compactBuilder, onTap, defaultOrder}` and a registry list. Layout persists in `settings['home_layout']` as a list of `{id, visible}`. Loading merges: stored order filtered to known ids, then new ids appended, unknown ids dropped.
- Done when: unit tests cover the merge (fresh install, new card added, card removed).

### Phase 2: Wallet-stack home

**P2-1 Stack behaviour**
- Replace the `SingleChildScrollView` in `dashboard_view.dart` with a `CustomScrollView`. Cards overlap like a wallet: each shows a peek strip, and as you scroll, earlier cards scale down slightly, dim, and tuck under the next. Drive scale, elevation and opacity from scroll offset.
- Performance: wrap each card in `RepaintBoundary`; confine per-frame rebuilds to the transform layer; keep Hive `ValueListenableBuilder`s inside card bodies, not above the scroll view.
- Done when: smooth scroll with 12 cards in profile mode (report frame timings if you can run it; otherwise list as not verified).

**P2-2 Momentum card**
- Compact: a 7-day strip showing only days that count as completed work (default 11). Tap expands in place (container transform) to the existing dot-matrix graph; tap again collapses.

**P2-3 Card catalog**

| id | Shows | Data source | Tap goes to |
|---|---|---|---|
| `momentum` | 7-day strip, expands to graph | `GlobalXPService.getPast7DaysXP()` | expands in place |
| `finance` | month net, balance, next SIP debit | finance snapshot logic (extract a pure function from the state class, ~L305-360) | Tasks tab → finance |
| `calories` | net / target, macros | `diet_logs` (logic from `_buildDietSummaryCard`) | Diet tab |
| `medicine` | next dose, taken/total today | `medicines`, `medicine_logs` | HealthPage → medicine |
| `health` | composite summary | see §5.6 | HealthPage |
| `weight` | latest weight, sparkline | `weight_entries` | HealthPage → weight |
| `score` | week / month / year XP | `xp_history` | `TaskAnalyticsPage` |
| `score_delta` | today vs yesterday, week vs last week, month vs last month | `xp_history` | `TaskAnalyticsPage` |
| `music` | now playing + controls | `NowPlayingService` (Phase 3) | expanded player sheet |
| `journal` | Create / View | n/a | Create → editor; View → auth → list |
| `brainstorm` | latest ideas, Add, View all | `ideas` | Brainstorm page |
| `reader` | 3 covers, View all | reader library | Library page |
| `quote`, `missions` | existing content wrapped as cards | existing | existing |

- **VERIFY:** whether `GlobalXPService` / `xp_history` keeps data beyond 7 days. If it prunes, stop pruning (do not delete history) so week, month and year totals work; the box is keyed `yyyy-MM-dd`.
- Cards for features not built yet (`medicine`, `weight`, `health`, `music`, `journal`, `brainstorm`, `reader`) ship in their own phases; register them then.

**P2-4 Settings layout editor**
- `ReorderableListView` with a visibility switch per card, writing `settings['home_layout']`. Add a "Reset layout" action.
- Done when: reordering and hiding persist across restarts; a newly registered card appears at the end for existing users.

### Phase 3: Music (independent track)

Order inside this phase matters: add the new path (P3-1 to P3-3), confirm it compiles and works, then delete the old one (P3-4).

**P3-1 `MediaSessionBridge` (Android, Kotlin) + `NowPlayingService` (Dart)**
- Kotlin: a `NotificationListenerService` subclass, a MethodChannel `habit/media_control` and an EventChannel `habit/now_playing`. Use `MediaSessionManager.getActiveSessions(listenerComponent)`, an `OnActiveSessionsChangedListener`, and a `MediaController.Callback`. Emit `{package, title, artist, album, artwork bytes, isPlaying, positionMs, durationMs, speed, updatedAt}`.
- Commands: `play`, `pause`, `next`, `previous`, `seekTo`, `stop`, `playFromSearch(query)` (best effort), `openApp`.
- Manifest: declare the service with `android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"`, the `android.service.notification.NotificationListenerService` intent filter, and the correct `exported` value. **VERIFY** current Android requirements.
- Dart: `lib/services/now_playing_service.dart` exposing `ValueNotifier<NowPlaying?>`, `hasAccess()`, `openAccessSettings()` (system notification-listener settings) and `send(MediaCommand)`. Interpolate progress locally from position + timestamp + speed; do not poll.
- Access is a manual user toggle in system settings. The card must show an "Enable access" state when it is missing.
- Plugins exist (`flutter_media_controller`, `nowplaying`, `media_notification_service`) but are young. Spend a short time reading their source. Use one only if it supports seek, artwork and exposes the session package and is maintained; otherwise write the bridge (**Default**).

**P3-2 UI**
- Card (artwork, title/artist, play/pause, previous/next, progress), global mini player (visible whenever a session exists), expanded bottom sheet (artwork, seek using the existing `WobblySlider`, play/pause, previous/next). Show shuffle/repeat only if the session exposes them; omit otherwise.
- Dominant colour: keep `palette_generator`, feed it the session artwork, and replace the `MusicManager().currentDominantColor` hookups in `bento_theme.dart` and `app.dart`.

**P3-3 AI**
- Replace the two `MusicManager().setPlaylist` sites in `ai_service.dart` and the local music intents with `NowPlayingService.send`. Pause, resume, next, previous and seek map directly. "play X" uses `playFromSearch` on the active session; if no session is active or the app does not support it, say so plainly in the reply. Keep the Hinglish patterns.

**P3-4 Removal (after P3-1 to P3-3 work)**
- Delete: `features/music/*`, `services/music_manager.dart`, `services/lyrics_service.dart`, `widgets/local_music_manager.dart`, `models/song_model.dart`, `features/music/widgets/procedural_artwork.dart`, and `test_query_songs.dart` at the repo root.
- Remove deps `just_audio`, `just_audio_background`, `on_audio_query`. Keep `palette_generator`. Confirm with `grep` that nothing else imports them first.
- Clean `main.dart` (`JustAudioBackground.init`), the manifest's foreground-service and audio-service entries, the music-folder picker and `music_folders` usage in Settings (leave the stored key untouched), audio permission requests that nothing else needs (Reader needs all-files access, see Phase 5), `home_page._pages` and `BottomNavBar` (three tabs; fix index mapping).
- Done when: `grep -ri "just_audio\|on_audio_query\|MusicManager" lib` is empty; analyze is clean; the app launches with three tabs. Manual (not verifiable without a device): with Spotify or YouTube Music playing, the card shows the track and controls work; AI "pause music" works.

### Phase 4: Health cards

**New data (typeIds 30+; register adapters and open boxes in `main.dart`)**

| typeId | Class | Box | Fields |
|---|---|---|---|
| 30 | `Medicine` | `medicines` | id, name, doseLabel, timesMinutes (List<int>), weekdays (List<int> 1-7, empty = daily), startDate, endDate?, notes, active |
| 31 | `MedicineLog` | `medicine_logs` | id, medicineId, scheduledAt, status (taken / skipped / snoozed), loggedAt |
| 32 | `WeightEntry` | `weight_entries` | date (key `yyyy-MM-dd`), kg, note |
| 33 | `JournalEntry` | `journals` (AES) | id, title, bodyDelta (JSON string), createdAt, updatedAt, pinned, tags |
| 34 | `Idea` | `ideas` | id, title, description, createdAt, updatedAt |
| 35 | `BookProgress` | `reader_progress` | key (hash of path), lastPage, totalPages, bookmarks (List<int>), lastOpened |

Settings keys: `home_layout`, `gemini_model`, `weight_start`, `weight_goal`, `weight_unit`, `reader_folders` (List<String>), `journal_lock_timeout_s`.

**P4-1 Medicine**
- `lib/features/health/health_page.dart` with a Medicine | Weight switch. Add/edit dialog with times, weekdays, start/end.
- Schedule notifications through the existing `NotificationService` with stable ids derived from medicine id + slot; reschedule on boot and on every edit. Actions: Taken and Snooze (10 min). **VERIFY** the `flutter_local_notifications` background-action requirements (top-level `@pragma('vm:entry-point')` handler; Hive must be initialised inside it).
- Exact alarms on Android 12+: **VERIFY** the manifest and the permission flow. If denied, fall back to inexact scheduling and show a visible banner on the card.
- Card shows next dose and today's taken/total.

**P4-2 Weight**
- Add entry, start/goal, kg unit. `fl_chart` sparkline on the card and a full chart on `HealthPage`.

**P4-3 Health summary**
- Composite from §5.6. Pure function over existing boxes, unit-tested.

Done when: models round-trip through Hive in tests; notification scheduling logic (next occurrence calculation) is unit-tested; delivery on a device is listed as not verified.

### Phase 5: Journal, Brainstorm, Reader

**P5-1 Journal**
- Editor: `flutter_quill` (formatting, lists, checklists, search, pin, autosave). **VERIFY** its setup requirements (localization delegates, current API) from the README.
- Create opens the editor without authentication. View requires `local_auth` with device-credential fallback (not biometric-only). **VERIFY** the package's Android requirements (for example the activity base class and manifest permissions).
- Storage: a Hive box encrypted with `HiveAesCipher`; the 32-byte key is generated once and stored in `flutter_secure_storage`. The lock must protect the data, not only the screen.
- Re-lock when the app backgrounds or after `journal_lock_timeout_s` (default 60).
- Done when: unit tests cover encrypted round-trip and key reuse across a simulated restart; auth flow listed as not verified.

**P5-2 Brainstorm**
- Card shows the latest few ideas with Add and View all. View all: list, search, edit, delete (with confirmation).

**P5-3 Reader**
- Settings: add and remove folders (`file_picker` directory picker), stored in `reader_folders`. Request all-files access on first use (**Default**; flag it in your report).
- Library service lists `*.pdf` recursively (cap depth and count; do it off the UI isolate). Cover = first page rendered with `pdfrx` (**VERIFY** current API), cached on disk keyed by path + mtime, generated lazily.
- Card: 3 covers plus View all. Library page: grid, search, sort by recently opened.
- Reader screen: continuous scroll, page slider, last-page resume (`reader_progress`), bookmarks, night mode (dim or invert). Keep it simple and expressive in the M3E style; no feature beyond that list.
- Done when: unit tests cover folder scan and the cover cache key; rendering listed as not verified.

### Phase 6: Harden and document

- Unit tests as specified above. Add a test for `home_layout` migration and one for media-command parsing in the AI path.
- Create `MANUAL_QA.md` listing every device-only check: nav layout on small and large screens, Gemini Test connection, SIP debit on a due day, notification-listener access flow, now-playing detection with Spotify and YouTube Music, medicine notification actions and exact-alarm denial, journal lock flow, all-files permission and PDF covers.
- Update `APP_DOCUMENTATION.md`: directory tree, Hive boxes table, music section, AI fallback chain, new features.
- Take a Hive data backup procedure note for upgrade testing (copy the app's Hive directory before running the new build over an MVP 1 install).

---

## 7. Open questions for the owner

Proceed on the stated default for everything except the first item, and report which defaults you applied.

1. Flutter SDK: is upgrading acceptable if M3E needs a newer version? (Blocking for P1-1 only if the gate fails.)
2. Keep the dark Bento base, or add Material You dynamic colour? Default: keep Bento.
3. Should existing SIPs post this month's debit if their due day has already passed? Default: no (§5.2).
4. Is all-files access acceptable for the Reader? Default: yes (§5.9).

## 8. Out of scope

- Cloud sync or accounts; iOS music control; lyrics; features not listed in §4.
- Refactoring `finance_page.dart` or `ai_service.dart` beyond the seams named here.
- Changing existing Hive typeIds, field indexes or box names.
