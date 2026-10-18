# AGENTS.md — Antigravity Master Implementation Plan (Tasks OS Overhaul, Navigation & Knowledge Vault Card)

## 0. Agent Operating Rules (Optimized for Gemini 3.8 Flash)
1. **Deterministic, Incremental Execution:** Execute phases in strict order (Phase 1 -> Phase 6). Do not skip files or leave `// TODO` placeholders.
2. **Offline-First Storage Strategy:** The existing project uses `Hive` and `SharedPreferences`. Implement all new Task, Academic, Habit, and Planner repositories using **Hive boxes** (with JSON/Map serialization so no `build_runner` codegen step is required to compile) and an operation log box (`sync_op_log_box`) for offline-first sync readiness.
3. **Zero Regressions:** Preserve all existing Finance engine math (`lib/features/finance/`, `lib/features/money/`), Health/Wearables logic, and Native Black & White theme support (`lib/core/theme/`).
4. **Performance & Layout Safety:**
   - Guard all `Hive.box(...)` calls with `Hive.isBoxOpen(...)`.
   - Ensure zero `RenderFlex` overflows by using `Expanded`/`Flexible` and `LayoutBuilder`.
   - Maintain `< 150ms` local search and `< 300ms` task completion animations with 5-second Undo snackbars.

---

## Phase 1: Navigation Bar Swap & Tasks Page De-Cluttering

### Target Files
- `lib/core/navigation/app_nav.dart`
- `lib/widgets/bottom_nav_bar.dart`
- `lib/screens/home_page.dart`
- `lib/screens/dashboard_view.dart`
- `lib/features/tasks/tasks_page.dart`
- `test/navigation/app_nav_test.dart`
- `test/widgets/bottom_nav_bar_test.dart`

### Implementation Requirements
1. **Replace `Settings` with `Finance` in Bottom Navigation (`app_nav.dart` & `bottom_nav_bar.dart`):**
   - Update the 5 main navigation destinations to:
     - Index `0`: `Home` (`Icons.home_rounded`)
     - Index `1`: `Health` (`Icons.favorite_rounded`)
     - Index `2`: `Diet` (`Icons.restaurant_rounded`)
     - Index `3`: `Tasks` (`Icons.check_circle_rounded`)
     - Index `4`: `Finance` (`Icons.account_balance_wallet_rounded`)
   - In `lib/screens/home_page.dart`, mount `FinancePage` (which wraps `MoneyShellPage` / `MoneyShell`) at Index `4` of the main page switcher instead of `SettingsPage`.
   - Add/verify a top-right `IconButton(icon: const Icon(Icons.settings_outlined))` in `DashboardView` / `HomePage` header that navigates to `SettingsPage` via `Navigator.of(context).push(...)` (or `AppNav.openSettings(context)`).
   - Keep the per-item `TextPainter` width check in `BottomNavBar` so any tab label that would cut off automatically renders icon-only.
2. **Remove Finance & Motivation/Knowledge Vault from `TasksPage`:**
   - Remove all references, buttons, banners, or sections linking to `FinancePage`, `MoneyShell`, `SpeechVaultPage`, or `ReaderLibraryPage` from `lib/features/tasks/tasks_page.dart`.

---

## Phase 2: Interactive Knowledge Vault Card on Home Page

### Target Files
- `lib/features/home/cards/knowledge_vault_card.dart` *(New File)*
- `lib/features/home/cards/home_card.dart`
- `lib/screens/dashboard_view.dart`
- `lib/screens/home_layout_settings_page.dart`
- `test/cards/home_card_registry_test.dart`

### Implementation Requirements
1. **Create `KnowledgeVaultCard` (`lib/features/home/cards/knowledge_vault_card.dart`):**
   - Build a stateful Bento card that integrates both `ReaderService` (PDF/Book library) and the Speech/Motivation Vault (`speech_box` / `notes` Hive box) directly on the card.
   - **Card Header:**
     - Title: `"Knowledge Vault"` with `Icons.auto_stories_rounded`.
     - Inline Segmented Pill Toggle: `Books` | `Speeches` (switches card body state without leaving the Home page).
     - Expand IconButton: Opens `ReaderLibraryPage` (when in `Books` mode) or `SpeechVaultPage` (when in `Speeches` mode).
   - **When in `Books` Mode (Inline Functions on Card):**
     - Load recent books via `ReaderService`.
     - Display the active/last-read book title, current page vs. total pages, percentage progress bar (`ProgressBarX`), and a primary **`Resume`** button that pushes `PdfReaderPage` directly at the saved page.
     - Provide an inline **`+ Import PDF`** button right on the card that calls `ReaderService` to pick & import a PDF and refreshes the card state immediately.
     - Show compact quick-switch chips for up to 2 other recent PDFs.
   - **When in `Speeches` Mode (Inline Functions on Card):**
     - Read saved items from the `speech_box` Hive box (with fallback starter quotes/speeches if empty).
     - Render the active speech/note title, category badge, and a 3-line scrollable/expandable preview.
     - Provide inline **`◀ Prev`** and **`Next ▶`** buttons to cycle through vault entries directly on the card, a **`Read Full`** modal sheet trigger, and an inline **`+ Add`** button that opens a quick bottom sheet to add a new speech/note directly from the Home screen.
2. **Register in Home Card Registry (`home_card.dart` & `dashboard_view.dart`):**
   - Register `'knowledge_vault'` in `HomeCardRegistry` / `HomeCard` definitions as enabled by default on the Home Dashboard.
   - Update `test/cards/home_card_registry_test.dart` to include and verify `'knowledge_vault'`.

---

## Phase 3: Tasks OS Data Models & Core Engines (Deterministic Logic)

### Target Files
- `lib/features/tasks/models/task_os_models.dart` *(New File)*
- `lib/features/tasks/data/task_os_repository.dart` *(New File)*
- `lib/features/tasks/engine/task_nl_parser.dart` *(New File)*
- `lib/features/tasks/engine/task_urgency_engine.dart` *(New File)*
- `lib/features/tasks/engine/smart_scheduler_engine.dart` *(New File)*
- `lib/features/tasks/engine/attendance_gpa_engine.dart` *(New File)*
- `lib/features/tasks/engine/rrule_recurrence_engine.dart` *(New File)*

### Implementation Requirements
1. **Unified Data Models (`task_os_models.dart`):**
   - Implement clean, immutable Dart classes with `toMap()` and `fromMap()` serialization (stored in Hive box `'task_os_box'` with tombstone `deletedAt`, `createdAt`, `updatedAt`, and `deviceId` fields):
     - `TaskItem`: `id`, `title`, `notes` (Markdown), `status` (`inbox`, `todo`, `doing`, `done`, `archived`), `priority` (`1` Urgent to `4` Low), `dueAt`, `hasDueTime`, `startAt` ("hide until"), `courseId`, `projectId`, `parentTaskId`, `subtasks` (`List<SubtaskItem>`), `tags` (`List<String>`), `estimateMin`, `actualMin`, `recurrenceRule` (RRULE string), `recurrenceMode` (`fixed`, `afterCompletion`), `reminderOffsetsMin` (`List<int>`), `weightage`, `maxMarks`, `scoreObtained`, `blockedByTaskIds`, `templateName`, `completedAt`, `deletedAt`.
     - `CourseItem`: `id`, `semesterId`, `name`, `code`, `colorHex`, `credits`, `instructor`, `room`, `requiredAttendancePct` (default `0.75`), `gradeScale` (`cgpa10`, `gpa4`, `percentage`), `gradeComponents` (`List<GradeComponentItem>`).
     - `TimetableSlotItem`: `id`, `courseId`, `dayOfWeek` (1-7), `startMinutes`, `endMinutes`, `room`, `weekPattern` (`every`, `weekA`, `weekB`), `batch`.
     - `ClassSessionLog`: `id`, `slotId`, `courseId`, `dateIso`, `status` (`scheduled`, `cancelled`, `extra`, `rescheduled`), `attendance` (`present`, `absent`, `unmarked`), `notes`.
     - `ExamItem` & `ExamTopicItem`: `id`, `courseId`, `title`, `examDate`, `venue`, `weightage`, `topics` (`id`, `title`, `confidence` `0..3`, `lastStudiedAt`, `nextReviewAt`).
     - `ScheduledBlockItem` & `PlanProposalItem`: `id`, `taskId`, `title`, `startAt`, `endAt`, `source` (`user`, `ai`), `reason`, `status` (`proposed`, `accepted`, `done`, `skipped`).
     - `FocusSessionLog`: `id`, `taskId`, `courseId`, `startAt`, `endAt`, `plannedMin`, `actualMin`, `interruptions`.
     - `ForgivingHabitItem`: `id`, `name`, `targetPerWeek`, `freezesLeft`, `restDays` (`List<int>`), `completedDatesIso` (`List<String>`), `frozenDatesIso` (`List<String>`).
     - `SchedulingRules`: `workStartHour` (default 8), `workEndHour` (default 22), `lightSundays` (true), `minBlockMin` (25), `maxContinuousMin` (90), `breakMin` (15), `deadlineBufferHours` (24), `autonomyLevel` (`manual`, `suggest`, `autoWithApproval`, `auto`).

2. **Live Natural-Language Parser (`task_nl_parser.dart` — `CAP-2`):**
   - Implement `ParsedTaskInput parseNaturalLanguageTask(String rawInput, DateTime now)`:
     - Extracts and strips tokens from `rawInput` while returning structured `ParsedChip` items (each chip has `id`, `type`, `label`, `rawToken`, `value`):
       - **Dates:** `today`, `tmr`/`tomorrow`, `mon`..`sun`, `next mon`..`next sun`, `in X days`, `end of month`, `DD oct`/`DD nov` etc.
       - **Times:** `5pm`, `5:30pm`, `17:30`, `noon`, `midnight`.
       - **Duration:** `~2h`, `~45m`, `for 45m`, `est 90min` -> `estimateMin`.
       - **Priority:** `!1`..`!4`, `!urgent`, `!high`, `!med`, `!low` -> `priority` (1..4).
       - **Course/Project:** `#([A-Za-z0-9_-]+)` -> `courseCode`.
       - **Tag:** `@([A-Za-z0-9_-]+)` -> `tags`.
       - **Recurrence:** `daily`, `every weekday`, `every mon`..`sun`, `every X weeks`, `after completion` -> `recurrenceRule` & `recurrenceMode`.
       - **Reminder:** `remind Xd before`, `remind Xm before`, `remind Xh before` -> `reminderOffsetsMin`.
     - If the user dismisses a chip in the UI, its `rawToken` is restored to the clean title.

3. **Rule-Based Urgency Ranking Engine (`task_urgency_engine.dart` — `PLAN-1`):**
   - Implement the exact urgency formula:
     ```dart
     double computeUrgency(TaskItem task, DateTime now) {
       // 40 * dueProximity + 25 * priorityWeight + 15 * weightageFactor + 10 * overdueFactor + 10 * effortPressure
     }
     ```
   - `dueProximity`: `1.0` if overdue or due today, decaying linearly toward `0.0` over 7 days (`168` hours).
   - `priorityWeight`: P1 = `1.0`, P2 = `0.66`, P3 = `0.33`, P4 = `0.0`.
   - `weightageFactor`: `(task.weightage ?? 0).clamp(0, 100) / 100.0`.
   - `overdueFactor`: `(daysOverdue.clamp(0, 7)) / 7.0`.
   - `effortPressure`: `((task.estimateMin ?? 30) / 60.0 / max(1.0, hoursUntilDue)).clamp(0.0, 1.0)`.
   - Sort descending; break ties by oldest `createdAt`. Top task is surfaced as **"Next Up"**.

4. **Deterministic Smart Scheduler & Exam Revision Engine (`smart_scheduler_engine.dart` — `PLAN-2..12`):**
   - **Free-Time & Morning Plan Generator (`generateDailyPlan`):**
     - Collect fixed events for the day (active `TimetableSlotItem` classes for current Week A/B + exams).
     - Compute free windows within `SchedulingRules` working hours.
     - Slice high-urgency open tasks into chunks between `minBlockMin` (`25m`) and `maxContinuousMin` (`90m`) with `breakMin` (`15m`) buffers.
     - Attach a deterministic explanation string to every `ScheduledBlockItem`: e.g., `"Due tomorrow · 2h estimated · fits your free slot 14:00–15:30"`.
     - Flag deadline conflicts if required effort exceeds available free slots before `dueAt - buffer`.
   - **Big-Task Backwards Breakdown (`proposeBackwardsMilestones` — `PLAN-7`):**
     - Given a task title, estimate, and due date, generate 4 editable milestone subtasks spaced backwards from `dueAt - buffer`.
   - **Exam Spaced-Repetition Planner (`generateExamRevisionSchedule` — `PLAN-8`):**
     - Schedules syllabus topics across available days before `examDate`, prioritizing lower-confidence topics (`confidence` 0 or 1) and spacing reviews at `1, 3, 7, 14` day intervals.
   - **Workload Heatmap (`computeWeeklyWorkload` — `PLAN-10`):**
     - Sums daily scheduled/due task `estimateMin` + class hours and classifies each day against user capacity (`safe`, `heavy`, `overloaded`), triggering an overload warning when capacity is exceeded or $\ge 3$ deadlines/exams fall in a 3-day window.

5. **Attendance & GPA Target Engine (`attendance_gpa_engine.dart` — `ACA-7`, `ACA-8`):**
   - **Attendance Math (`computeAttendanceStats`):**
     - Exclude `cancelled` sessions.
     - `total = present + absent + remaining`
     - `attendedPct = (present + absent) == 0 ? 1.0 : present / (present + absent)`
     - `maxMissable = max(0, (present + remaining - (req * total)).floor())`
     - Compute `mustAttendNext` if `attendedPct < req`, and `canNoLongerReachMin = (present + remaining) < (req * total)`.
   - **Grade & Target Calculator (`computeRequiredFinalScore`):**
     - Given completed `GradeComponentItem` marks/weights, final exam weightage, and target course grade, calculate the exact score/percentage required on the final exam, plus running Semester GPA / CGPA.

6. **Recurrence Engine (`rrule_recurrence_engine.dart` — `TSK-5`):**
   - Support `DAILY`, `WEEKLY` (with `BYDAY`), `MONTHLY`, custom intervals, and `recurrenceMode` (`fixed` schedule vs. `afterCompletion` where next due date = `completedAt + interval`).
   - Completing a recurring task immediately spawns only the next occurrence and logs the completed instance.

---

## Phase 4: Tasks Page UI Overhaul (`lib/features/tasks/`)

### Target Files
- `lib/features/tasks/tasks_page.dart`
- `lib/features/tasks/widgets/quick_add_nl_bar.dart` *(New File)*
- `lib/features/tasks/widgets/academic_hub_view.dart` *(New File)*
- `lib/features/tasks/widgets/smart_plan_banner.dart` *(New File)*
- `lib/features/tasks/widgets/focus_timer_sheet.dart` *(New File)*
- `lib/features/tasks/widgets/task_detail_sheet.dart` *(New File)*
- `lib/features/tasks/widgets/weekly_review_shutdown_sheet.dart` *(New File)*

### Implementation Requirements
1. **Top Bar & 5-View Switcher in `TasksPage` (`tasks_page.dart`):**
   - **Header Row:**
     - Title: `"TASKS"` with active streak/XP badge.
     - Instant Search Field toggle (`< 150ms` local filter across titles, notes, tags, courses) + Filter Chips (`Course`, `Priority`, `Tag`, `Overdue`).
     - Action buttons for **Autonomy Dial** (`Manual | Suggest | Approval | Auto`), **Shutdown Ritual / Weekly Review**, and **Import/Export** (CSV / Markdown / iCal).
   - **Primary View Tabs:**
     1. `Today` (`VIEW-1` + `VIEW-6` List/Timeline toggle)
     2. `Upcoming` (`VIEW-2` + `PLAN-10` 7-day Workload Heatmap & Overload Warning banner)
     3. `Inbox` (`VIEW-3` Unsorted captures + Bulk Multi-Select toolbar `TSK-8`)
     4. `Academic` (`M5` Courses, Week A/B Timetable, Attendance Tracker, Exams & Spaced Revision, GPA Target Calculator)
     5. `Board` (`VIEW-7` Kanban columns: `Inbox`, `To Do`, `Doing`, `Done` + `Archive/Trash` 30-day restore `TSK-13`)
   - **Reliability Health Check Banner (`REM-9`):**
     - If notification permissions are disabled, show a dismissible high-contrast banner at the top guiding the user to enable exact alarms/notifications.

2. **Today View Experience:**
   - **Pinned "Next Up" Hero Card (`PLAN-1`):** Highlights the #1 urgency-ranked task with its urgency breakdown, `"Why is this here?"` explanation, **`▶ Just 5 Min`** button (`FOC-5`), and **`⏱ Focus`** button (`FOC-1`).
   - **AI Morning Plan Card (`PLAN-3..6`, `PLAN-9`):** Shows proposed time blocks in free gaps between classes with individual `Accept` / `Reject` actions, `Approve All`, and a 1-tap **`Rebalance My Day`** button (shows before/after diff).
   - **List vs. Visual Day Timeline Toggle (`VIEW-6`):** Switches between grouped task cards (`Overdue`, `Today's Classes`, `Due Today`) and a vertical 08:00–22:00 timeline showing classes, scheduled task blocks, breaks, and a live current-time indicator line.
   - **Forgiving Habits Strip (`HAB-1`, `HAB-2`):** Compact horizontal row of daily/weekly habits showing current streak, available Streak Freezes (`❄️`), and 1-tap completion or freeze usage.

3. **Persistent Quick-Add Bar & Brain-Dump Sheets (`quick_add_nl_bar.dart`):**
   - Docked at the bottom of `TasksPage` (and accessible via a `+` button).
   - Live token chips (`CAP-2`) appear as the user types; tapping a chip edits or removes it (restoring text to the title).
   - Rapid-fire mode (`CAP-1`): pressing `Enter` / `Submit` saves the task immediately and keeps focus in the text field for the next entry.
   - **Voice Brain-Dump (`CAP-4`) & Syllabus/Photo Capture (`CAP-6/7`):** Tapping the mic or camera/PDF icon opens a structured review modal where multi-task extractions are shown with confidence badges (`High` / `Needs Review`) and must be confirmed (`Add Selected` / `Add All`) before saving.

4. **Task Detail & Big-Task Breakdown Sheet (`task_detail_sheet.dart`):**
   - Edits all `TaskItem` fields, 1-level reorderable subtasks (`TSK-2`), RRULE recurrence (`TSK-5`), multiple reminders (`REM-1`) with snooze (`10m`, `1h`, `Tonight`, `Tomorrow`), dependencies (`blockedBy`), Markdown notes (`NOTE-1`), and attachments (`NOTE-2`).
   - Includes a **`⚡ Break Down Big Task`** button (`PLAN-7`) that generates backwards-scheduled milestones for review before inserting them as subtasks.

---

## Phase 5: Unit & Widget Tests

### Target Files
- `test/features/tasks/task_os_engines_test.dart` *(New File)*
- `test/navigation/app_nav_test.dart`
- `test/widgets/bottom_nav_bar_test.dart`
- `test/cards/home_card_registry_test.dart`

### Implementation Requirements
1. Write comprehensive unit tests in `test/features/tasks/task_os_engines_test.dart` covering:
   - **Natural Language Parser (`CAP-2`):** Verify `"DBMS record fri 5pm #DBMS !high ~2h @lab"` parses title `"DBMS record"`, Friday 17:00 due date, course `"DBMS"`, priority `2` (High), `estimateMin: 120`, and tag `"lab"`.
   - **Attendance Math (`ACA-7`):** Verify `present: 30, absent: 6, remaining: 20, req: 0.75` yields `total: 56` and `maxMissable: 8`, plus the unreachable-minimum warning case.
   - **Urgency Ranking (`PLAN-1`):** Verify overdue high-weightage tasks rank above low-priority distant tasks.
   - **Recurrence (`TSK-5`):** Verify both `"fixed"` and `"afterCompletion"` next-instance date calculation.
   - **Smart Scheduler (`PLAN-3`):** Verify free-slot detection around fixed classes and deterministic chunk placement.
2. Update `test/navigation/app_nav_test.dart`, `test/widgets/bottom_nav_bar_test.dart`, and `test/cards/home_card_registry_test.dart` to reflect the `Finance` tab replacing `Settings` in the bottom nav bar and the new `'knowledge_vault'` Home card.