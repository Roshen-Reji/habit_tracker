
# AGENT.md — Master Engineering & UI/UX Specification
**Target Agent:** Antigravity Agent (Powered by Gemini 3.8 Flash)
**Project:** `habit_tracker` (Flutter Cross-Platform Personal OS)
**Authority:** Chief Engineering & Google Material 3 Expressive UI/UX Architecture

---

## 0. STRICT ANTI-HALLUCINATION GUARDRAILS (READ FIRST)

1. **READ BEFORE WRITE:** Never guess the contents, class names, or method signatures of a file. Always read the target file from disk before applying edits.
2. **NO PHANTOM DEPENDENCIES:** Do NOT add new packages to `pubspec.yaml`. Use Flutter's built-in `flutter/physics.dart`, Material 3 `ColorScheme`, and existing packages already in `pubspec.yaml` (`hive`, `shared_preferences`, `fl_chart`, `google_generative_ai`, `file_picker`, `syncfusion_flutter_pdf`, etc.).
3. **HIVE BACKWARD COMPATIBILITY:** Never change existing `@HiveType(typeId: ...)` IDs or repurpose existing `@HiveField(n)` indices in `lib/data/models/*.dart` or `lib/features/*/models/*.dart`. When adding new fields to Hive models, append a new `@HiveField` index with a safe `defaultValue` and update the corresponding `.g.dart` file.
4. **PHASE GATING:** Execute the plan strictly in order (Phase 1 -> Phase 5). After each phase, run:
   ```bash
   flutter analyze
   flutter test

```

Do not proceed to the next phase until `flutter analyze` returns **0 errors**.

---

## 1. VERIFIED REPOSITORY FILE MAP

### Files to DELETE Immediately (Phase 2)

* `lib/features/diet/data/indian_regional_food_db.dart`
* `lib/features/diet/widgets/meal_planner_tab.dart`
* `lib/features/diet/widgets/grocery_pantry_tab.dart`

### Core Theme, Motion & Shared Widgets (`lib/core/` & `lib/widgets/`)

* `lib/core/theme/app_colors.dart`
* `lib/core/theme/app_theme.dart`
* `lib/core/theme/app_tokens.dart`
* `lib/core/theme/expressive_tokens.dart`
* `lib/core/theme/tactile_tokens.dart`
* `lib/core/theme/bento_theme.dart`
* `lib/core/theme/app_animations.dart`
* `lib/core/motion/motion_tokens.dart`
* `lib/core/motion/motion_scope.dart`
* `lib/core/motion/press_scale.dart`
* `lib/core/motion/spring_sheet.dart`
* `lib/core/motion/animated_metric_ticker.dart`
* `lib/core/motion/animated_strikethrough.dart`
* `lib/core/utils/page_transitions.dart`
* `lib/core/widgets/depth_card.dart`
* `lib/core/widgets/glass_tab_bar.dart`
* `lib/core/widgets/progress_bar_x.dart`
* `lib/core/widgets/tactile_button.dart`
* `lib/widgets/bottom_nav_bar.dart`
* `lib/widgets/star_background.dart`

### Diet Sector (`lib/features/diet/`)

* `lib/features/diet/diet_page.dart`
* `lib/features/diet/data/diet_repository.dart`
* `lib/features/diet/engine/nutrition_science_engine.dart`
* `lib/features/diet/engine/native_diet_ai_engine.dart`
* `lib/features/diet/models/diet_planner_models.dart`
* `lib/features/diet/widgets/diet_dashboard_widgets.dart`
* `lib/features/diet/widgets/diet_progress_tab.dart`
* `lib/features/diet/widgets/manual_food_input.dart`
* `lib/features/diet/widgets/nutrition_profile_sheet.dart`
* `lib/features/home/cards/calories_card.dart`
* `lib/data/models/diet_models.dart` & `lib/data/models/diet_models.g.dart`

### Tasks, Habits & Academics Sector (`lib/features/tasks/`)

* `lib/features/tasks/tasks_page.dart`
* `lib/features/tasks/task_analytics_page.dart`
* `lib/features/tasks/data/task_os_repository.dart`
* `lib/features/tasks/data/task_day_log_repository.dart`
* `lib/features/tasks/engine/rrule_recurrence_engine.dart`
* `lib/features/tasks/engine/task_nl_parser.dart`
* `lib/features/tasks/engine/native_task_ai_engine.dart`
* `lib/features/tasks/engine/attendance_gpa_engine.dart`
* `lib/features/tasks/engine/smart_scheduler_engine.dart`
* `lib/features/tasks/models/task_os_models.dart`
* `lib/features/tasks/models/task_day_log.dart`
* `lib/features/tasks/widgets/academic_hub_view.dart`
* `lib/features/tasks/widgets/add_task_dialog.dart`
* `lib/features/tasks/widgets/animated_task_os_tile.dart`
* `lib/features/tasks/widgets/quick_add_nl_bar.dart`
* `lib/features/tasks/widgets/sliding_workspace_pill_bar.dart`
* `lib/features/tasks/widgets/task_action_pill.dart`
* `lib/features/tasks/widgets/task_card.dart`
* `lib/features/tasks/widgets/task_detail_sheet.dart`
* `lib/data/services/task_reset_service.dart`

### Unified AI & Services (`lib/data/services/` & `lib/features/home/`)

* `lib/data/services/ai_service.dart`
* `lib/data/services/ai_context.dart`
* `lib/data/services/gemini_client.dart`
* `lib/data/services/reader_service.dart`
* `lib/features/home/home_chat.dart`
* `lib/features/home/widgets/chat_message_bubble.dart`

---

## 2. UI/UX SYSTEM: MATERIAL 3 EXPRESSIVE & ANTI-"AI SLOP" RULES

### 2.1 What Screams "AI Slop" (BANNED PATTERNS)

You must actively search for and remove every instance of the following across the codebase:

1. **Glassmorphism:** Remove all `BackdropFilter`, `ImageFilter.blur`, and translucent white/black containers (`Colors.white.withOpacity(0.05)`).
2. **AI Gradient Borders:** Remove all multi-color `LinearGradient` or `SweepGradient` borders (purple/cyan/pink glowing strokes) on cards, inputs, banners, and chat bubbles.
3. **Sparkle Icon Spam:** Remove `Icons.auto_awesome` (`✨`) from standard headers, buttons, and cards. Use clean, domain-specific Material Rounded icons (`Icons.restaurant_rounded`, `Icons.check_circle_rounded`, `Icons.school_rounded`, `Icons.account_balance_wallet_rounded`).
4. **Starfield Background:** Replace the particle painter inside `lib/widgets/star_background.dart` with a solid `ColoredBox(color: Theme.of(context).colorScheme.surface, child: child)`.
5. **Low-Contrast Ghost Buttons:** Never render text/icons with low alpha against dark backgrounds. Every interactive button must have a solid tonal container fill and high-contrast foreground label.

### 2.2 Material 3 Expressive Tonal Palette (`app_colors.dart` & `app_theme.dart`)

Use solid tonal surface elevation instead of opacity or shadows:

| Token | Dark Mode Hex | Light Mode Hex | Usage |
| --- | --- | --- | --- |
| `surface` | `#0E1113` | `#F7F9FC` | Scaffold background |
| `surfaceContainerLowest` | `#090B0D` | `#FFFFFF` | Deep inset wells |
| `surfaceContainerLow` | `#15191C` | `#F1F4F8` | Secondary section grouping |
| `surfaceContainer` | `#1B2024` | `#EBEEF3` | Standard cards (`DepthCard`) |
| `surfaceContainerHigh` | `#242A2F` | `#E3E7ED` | Elevated cards, bottom sheets, dialogs |
| `surfaceContainerHighest` | `#2F363C` | `#DCE1E8` | Input fields, unselected pills, icon buttons |
| `onSurface` | `#F1F4F7` | `#111417` | Primary headings, body text, metrics |
| `onSurfaceVariant` | `#A2ACB5` | `#444C54` | Subtitles, metadata (minimum 4.5:1 contrast) |
| `primary` | `#5CE1E6` | `#006874` | Primary CTAs, active indicators, key metrics |
| `onPrimary` | `#00363A` | `#FFFFFF` | Text/icons inside `primary` buttons |
| `primaryContainer` | `#004F54` | `#97F0FF` | Selected navigation pills, active filter chips |
| `onPrimaryContainer` | `#9DF4F8` | `#001F24` | Text/icons inside `primaryContainer` |
| `secondaryContainer` | `#324655` | `#CFE6F7` | Secondary action buttons (`TaskActionPill`) |
| `onSecondaryContainer` | `#CEE5F6` | `#0D1E2A` | Text/icons inside `secondaryContainer` |
| `tertiaryContainer` | `#5C3B1E` | `#FFDCC2` | Habit streaks & warm highlights |
| `onTertiaryContainer` | `#FFDCC2` | `#2E1500` | Text/icons inside `tertiaryContainer` |
| `outline` | `#454E56` | `#72787E` | Input field borders |
| `outlineVariant` | `#282F35` | `#C2C7CE` | 1px structural card borders & dividers |

### 2.3 OxygenOS 15 / One UI 7 Fluidity & Expressive Shape Morphing

Update `lib/core/motion/motion_tokens.dart`, `lib/core/motion/press_scale.dart`, and `lib/core/widgets/tactile_button.dart`:

1. **Interruptible Spring Physics:**
* **Touch/Press Spring:** `SpringDescription(mass: 1.0, stiffness: 420.0, damping: 28.0)`
* **Sheet/Spatial Spring:** `SpringDescription(mass: 1.0, stiffness: 300.0, damping: 26.0)`
* **Emphasized Curve (Non-Spring Fallback):** `Cubic(0.2, 0.0, 0.0, 1.0)`


2. **Expressive Shape Morphing:**
* Buttons, chips, and habit/task checkboxes morph their `BorderRadius` on interaction:
* **Resting / Unselected:** `BorderRadius.circular(28.0)` (Stadium Pill)
* **Pressed / Active / Checked:** `BorderRadius.circular(14.0)` (Expressive Squircle) over `200ms`.




3. **Grouped List Geometry:**
* When rendering stacked items (e.g., Meal Logs in a slot or Tasks in a list), use `24dp` outer corners for the first/last item and `6dp` inner corners for adjacent items, separated by `2dp` vertical gaps.



---

## 3. PHASE-BY-PHASE IMPLEMENTATION PLAN

### PHASE 1: Theme, Widgets & Motion Overhaul

1. **`lib/core/theme/app_colors.dart` & `lib/core/theme/app_theme.dart`:**
* Implement the Material 3 Expressive `ColorScheme` above.
* Define explicit `FilledButtonThemeData`, `OutlinedButtonThemeData`, `TextButtonThemeData`, `FloatingActionButtonThemeData`, and `InputDecorationTheme` so every button and input across the app has guaranteed high visibility.


2. **`lib/core/widgets/depth_card.dart`:**
* Remove `BackdropFilter` and glass gradients.
* Render a solid `AnimatedContainer` with `colorScheme.surfaceContainer`, `BorderRadius.circular(24)`, and `Border.all(color: colorScheme.outlineVariant, width: 1)`.


3. **`lib/core/widgets/glass_tab_bar.dart` & `lib/widgets/bottom_nav_bar.dart`:**
* Remove all blur effects.
* Use `colorScheme.surfaceContainerHigh` for the bar background and a spring-animated `colorScheme.primaryContainer` sliding pill indicator with `colorScheme.onPrimaryContainer` icons/text.


4. **`lib/core/widgets/tactile_button.dart` & `lib/core/motion/press_scale.dart`:**
* Ensure `TactileButton` defaults to `colorScheme.primary` fill and `colorScheme.onPrimary` bold text (`FontWeight.w700`), with spring scale (`0.96`) and radius morphing (`28dp` $\rightarrow$ `14dp`).



---

### PHASE 2: Diet Module Purge & High-Visibility Rebuild

1. **Delete Files:**
* Remove `lib/features/diet/data/indian_regional_food_db.dart`
* Remove `lib/features/diet/widgets/meal_planner_tab.dart`
* Remove `lib/features/diet/widgets/grocery_pantry_tab.dart`


2. **Clean `lib/features/diet/data/diet_repository.dart` & `lib/features/diet/models/diet_planner_models.dart`:**
* Strip all preloaded regional food lists, recipe generators, meal planners, and grocery/pantry state.
* Keep zero preloaded meal data. The database starts clean and stores only user-created foods and logs.
* Ensure `DietRepository` exposes reactive (`ValueNotifier` / `ChangeNotifier` or stream/callback) CRUD operations for:
* `NutritionProfile` (`weightKg`, `heightCm`, `age`, `gender`, `activityLevel`, `goal`, `targetCalories`, `targetProteinG`, `targetCarbsG`, `targetFatG`, `targetWaterMl`).
* `CustomFoodItem` (user's saved foods: `id`, `name`, `servingLabel`, `calories`, `proteinG`, `carbsG`, `fatG`).
* `MealLogEntry` (`id`, `dateKey`, `mealSlot` [`breakfast`, `lunch`, `dinner`, `snack`], `name`, `servings`, `calories`, `proteinG`, `carbsG`, `fatG`).




3. **Rebuild `lib/features/diet/widgets/nutrition_profile_sheet.dart` & `lib/features/diet/engine/nutrition_science_engine.dart`:**
* Make all inputs (`Weight`, `Height`, `Age`, `Activity Level`, `Goal: Cut / Maintain / Bulk`) high-contrast M3 `TextFormField`s and segmented pills.
* Add an **"Auto-Calculate from Body Metrics"** button alongside **direct manual editing** of `Daily Calories`, `Protein (g)`, `Carbs (g)`, and `Fats (g)`.
* Connect `NutritionProfile` directly to `diet_page.dart` and `lib/features/home/cards/calories_card.dart` so target progress bars and remaining calories update immediately on save.


4. **Rebuild `lib/features/diet/diet_page.dart` & `lib/features/diet/widgets/manual_food_input.dart`:**
* **Layout:** Clean 2-mode M3 view: **Today's Log** and **Progress & Targets**.
* **Today's Log:**
* Top **Macro Hero Card** (`surfaceContainerHigh`): Large tabular readout of `Consumed / Target kcal`, `Remaining kcal`, and 3 distinct tonal progress bars for `Protein`, `Carbs`, and `Fats`, plus an `Edit Targets` button (`secondaryContainer`).
* **Hydration Bar:** Quick `+250ml` / `+500ml` pill buttons.
* **4 Meal Slot Cards (`Breakfast`, `Lunch`, `Dinner`, `Snacks`):** Each displays its total calories, logged items (tap to edit, swipe to delete), and a high-contrast `+ Add Food` pill button.


* **Log Meal Sheet (`manual_food_input.dart`):**
* **Quick Entry Form:** Food Name, Calories (kcal), Protein (g), Carbs (g), Fats (g), Servings stepper, and a checkbox `"Save to My Foods"`.
* **My Saved Foods List:** Displays the user's own previously saved `CustomFoodItem`s for 1-tap logging or editing. No preloaded regional clutter.





---

### PHASE 3: Strict Tasks vs. Habits Separation & Button Visibility Fix

1. **Domain Separation (`lib/features/tasks/models/task_os_models.dart`, `lib/features/tasks/data/task_os_repository.dart`, `lib/data/services/task_reset_service.dart`):**
* **Tasks (`isHabit == false`):**
* Strictly **one-time** items bound to a single date (`scheduledDate` normalized to `YYYY-MM-DD`).
* Never have recurrence rules (`rrule = null`, `recurrenceFrequency = 'none'`).
* If a user creates a Task for today, it appears **only** on today's date (and in an optional "Overdue" section if left incomplete). It must **never** regenerate tomorrow.


* **Habits (`isHabit == true`):**
* Strictly **recurring** items with explicit frequency: `daily`, `weekly` (with `daysOfWeek: List<int>`), or `monthly` (with `dayOfMonth: int`).
* Managed by `rrule_recurrence_engine.dart` and daily state reset by `task_reset_service.dart`.
* Completion is recorded per date in `task_day_log_repository.dart` and increments `streak`.




2. **Tasks Page & Dialog UI Rebuild (`lib/features/tasks/tasks_page.dart`, `lib/features/tasks/widgets/add_task_dialog.dart`):**
* **Workspace Switcher (`sliding_workspace_pill_bar.dart`):** Clearly separate **`Tasks`** (One-Time, date-scoped), **`Habits`** (Recurring routines), and **`Academics`**.
* **`add_task_dialog.dart`:**
* Top M3 Segmented Toggle: **`One-Time Task`** | **`Recurring Habit`**.
* If **`One-Time Task`**: Show Title, Date (defaults to selected day), Optional Time, Priority. Hide all recurrence fields.
* If **`Recurring Habit`**: Show Title, Recurrence Selector (`Every Day`, `Weekly on [M T W T F S S]`, `Monthly on Day X`), Category, and Reminder Time.


* **Fix All Invisible Buttons (`add_task_dialog.dart`, `task_action_pill.dart`, `task_card.dart`, `animated_task_os_tile.dart`):**
* Primary "Create Task" / "Create Habit" CTA must use `FilledButton` (`backgroundColor: colorScheme.primary`, `foregroundColor: colorScheme.onPrimary`).
* Secondary pills (`TaskActionPill`, filter chips, date selectors) must use `colorScheme.secondaryContainer` background and `colorScheme.onSecondaryContainer` text/icons.





---

### PHASE 4: Context-Aware Digital Scanner & Smart Auto-Router

1. **Context-Filtered Extraction (`lib/features/tasks/widgets/academic_hub_view.dart`, `lib/data/services/reader_service.dart`, `lib/data/services/ai_service.dart`):**
* Add a **Smart Import / Digital Scanner** sheet accessible from both the Tasks/Academics hub and the global AI bar.
* Input controls:
1. **File/Image Picker** (PDF, image, or pasted text).
2. **Context Filter Input Field:** e.g., `"CS S3"` (persisted in user academic profile so the user doesn't have to retype it every time, but editable per scan).


* **Extraction Logic:**
* Extract raw text locally first via `ReaderService` when a PDF text layer is available.
* Parse rows/items and evaluate each against the user's Context Filter (e.g., `"CS S3"` matches Computer Science Semester 3 courses, slots, and lab batches; rejects other departments/semesters like `EC S3`, `ME S5`, etc.).
* Set `item.isRelevant = true` and `item.isSelected = true` **only** for matching items. Set `item.isSelected = false` for non-matching items, but keep them in the list so the user can manually check/uncheck any item.




2. **Interactive Selection & Automatic Sector Routing:**
* Show a high-contrast **Scan Review Sheet** before committing:
* Displays auto-detected document type badge:
* `TIMETABLE` $\rightarrow$ Routes automatically to **Academics $\rightarrow$ Timetable**.
* `SYLLABUS / COURSES` $\rightarrow$ Routes automatically to **Academics $\rightarrow$ Courses & Attendance**.
* `EXAM / ASSIGNMENT DATES` $\rightarrow$ Routes automatically to **Tasks (One-Time Tasks on specific dates)**.
* `EXPENSE / RECEIPT` $\rightarrow$ Routes automatically to **Finance $\rightarrow$ Transactions**.


* Filter toggles: `Selected Only (CS S3)` | `Show All Extracted Rows` | `Select All` | `Deselect All`.
* Every row has an interactive M3 `CheckboxListTile` and inline edit button so the user has 100% manual control before tapping **`Import Selected (N)`**.





---

### PHASE 5: Unified, Inter-Modular AI Agent (On-Device First + Token Optimization)

1. **Single Cross-Sector Orchestrator (`lib/data/services/ai_service.dart` & `lib/data/services/ai_context.dart`):**
* Deprecate isolated AI silos. `AiService` is the single brain connected to `DietRepository`, `FinanceController`/`FinanceRepository`, `TaskOsRepository`, `AcademicHub`, `WearableRepository`, and `JournalService`.


2. **Tier 1 — On-Device Deterministic Fast-Path (0 API Tokens):**
* Before making any network call to `GeminiClient`, pass user input through a local Dart intent router (`AiService.tryHandleOnDevice(input)`):
* **Diet Pattern:** `"log 400 cal oats 15g protein for breakfast"` or `"drank 500ml water"` $\rightarrow$ Executes directly on `DietRepository` (0 tokens).
* **Finance Pattern:** `"spent 120 onshawarma"` or `"paid 50 auto"` $\rightarrow$ Parses via `CaptureEngine` and logs to `FinanceRepository` (0 tokens).
* **Task Pattern:** `"add task finish OS record today"` $\rightarrow$ Parses via `TaskNlParser` as a One-Time Task (`isHabit: false`) for today (0 tokens).
* **Habit Pattern:** `"add habit code 1 hour every day"` $\rightarrow$ Parses via `TaskNlParser` as a Recurring Habit (`isHabit: true`, `daily`) (0 tokens).




3. **Tier 2 — Token-Optimized Gemini 3.8 Flash Call (`lib/data/services/gemini_client.dart`):**
* When the input requires complex reasoning, multi-action execution, or document scanning:
* **Intent-Scoped Delta Context (`ai_context.dart`):** Classify which sectors the prompt touches (`diet`, `finance`, `tasks`, `habits`, `academics`, `health`) using fast keyword/intent scoring on-device. Include **only** the relevant sectors in a minified JSON delta payload (e.g., `{"d":{"cal":1200,"tgt":2200,"p":80},"f":{"safe":450},"t":{"due":["OS Lab"]}}`). Never send full historical Hive dumps.
* **Unified Multi-Action Schema:** Instruct Gemini to respond with compact JSON:
```json
{
  "reply": "Logged your lunch, recorded ₹140 expense, and scheduled your OS revision task for tonight.",
  "actions": [
    {"sector": "diet", "op": "log_meal", "data": {"name": "Chicken Biryani", "cal": 650, "p": 32, "c": 75, "f": 22, "slot": "lunch"}},
    {"sector": "finance", "op": "add_tx", "data": {"amount": 140, "category": "Food", "note": "Lunch"}},
    {"sector": "tasks", "op": "add_task", "data": {"title": "Revise OS Paging", "date": "2026-10-19"}}
  ]
}

```


* **Action Execution & Undo Chips (`home_chat.dart` & `chat_message_bubble.dart`):** Execute all returned `actions` across their respective repositories and render high-contrast M3 tonal confirmation chips under the chat bubble with a 1-tap `Undo` action.





---

## 4. DEFINITION OF DONE (VERIFICATION CHECKLIST)

Before concluding your task, verify every item below:

* [ ] Zero glassmorphism (`BackdropFilter`) or glowing AI gradient borders remain in `lib/`.
* [ ] `indian_regional_food_db.dart`, `meal_planner_tab.dart`, and `grocery_pantry_tab.dart` are deleted and all broken imports are removed.
* [ ] Diet tab has zero preloaded foods, high-contrast meal logging, custom food creation/editing, and a functional Nutrition Profile that updates calorie/macro targets live.
* [ ] Tasks (`isHabit == false`) are strictly single-day one-time items; Habits (`isHabit == true`) recur daily, weekly, or monthly.
* [ ] Every button in `tasks_page.dart`, `add_task_dialog.dart`, `diet_page.dart`, and `academic_hub_view.dart` uses high-contrast M3 `FilledButton` or `secondaryContainer` styling.
* [ ] Digital Scanner pre-selects only items matching the user's context (e.g., `"CS S3"`), allows manual checkbox overrides, and auto-routes timetables, tasks, and courses to their exact modules.
* [ ] `AiService` handles deterministic logs on-device (0 tokens) and uses pruned delta contexts for cross-sector Gemini calls.
* [ ] `flutter analyze` and `flutter test` pass with 0 errors.