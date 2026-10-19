# IMPLEMENTATION_PLAN.md — Step-by-Step Execution Blueprint for Gemini 3.8 Flash

Execute this plan sequentially from **Phase 1** to **Phase 5**. After each phase, run `flutter analyze` and fix any warnings or broken imports before moving to the next phase.

---

## PHASE 1: UI Foundation — Scrap Glassmorphism & Implement Material 3 Expressive
**Goal:** Replace all glassmorphic widgets, star backgrounds, and invisible buttons with high-contrast Material 3 Expressive surfaces and OxygenOS/One UI spring physics.

### Step 1.1: Overhaul Theme & Tokens
- **Files:** `lib/core/theme/app_colors.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/expressive_tokens.dart`, `lib/core/theme/tactile_tokens.dart`
- **Actions:**
  1. Define the M3 Expressive Dark & Light `ColorScheme` in `app_colors.dart` & `app_theme.dart` using solid tonal surface containers (`surface`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`).
  2. Configure global `FilledButtonThemeData`, `ElevatedButtonThemeData`, `OutlinedButtonThemeData`, `FloatingActionButtonThemeData`, and `ChipThemeData` in `app_theme.dart` so all buttons across the app automatically render with high-contrast fills (`primary` / `onPrimary` and `secondaryContainer` / `onSecondaryContainer`) and minimum `48dp` touch targets.
  3. Remove all gradient border helpers or AI glow decorations from `expressive_tokens.dart` and `bento_theme.dart`.

### Step 1.2: Remove Starfield & Glass Containers
- **Files:** `lib/widgets/star_background.dart`, `lib/core/widgets/depth_card.dart`, `lib/core/widgets/glass_tab_bar.dart`, `lib/widgets/bottom_nav_bar.dart`, `lib/screens/home_page.dart`
- **Actions:**
  1. In `star_background.dart`, replace the custom star/particle painter with a clean, zero-overhead `ColoredBox(color: Theme.of(context).colorScheme.surface, child: child)`.
  2. In `depth_card.dart`, remove `BackdropFilter` and translucent opacity layers. Render a solid Material 3 `Container` using `colorScheme.surfaceContainer` (or `surfaceContainerHigh` when elevated), `BorderRadius.circular(24)`, and a subtle 1px solid border (`colorScheme.outlineVariant`).
  3. In `glass_tab_bar.dart` and `bottom_nav_bar.dart`, strip all blur filters. Convert the indicator into a spring-animated pill (`colorScheme.primaryContainer`) with `colorScheme.onPrimaryContainer` active icons/labels and `colorScheme.onSurfaceVariant` inactive icons/labels.

### Step 1.3: Upgrade Spring Physics & Shape Morphing
- **Files:** `lib/core/motion/motion_tokens.dart`, `lib/core/motion/press_scale.dart`, `lib/core/motion/spring_sheet.dart`, `lib/core/widgets/tactile_button.dart`, `lib/core/utils/page_transitions.dart`
- **Actions:**
  1. Update `press_scale.dart` and `tactile_button.dart` to use `SpringSimulation` (`mass: 1.0, stiffness: 420.0, damping: 28.0`) and animate `BorderRadius` from `28dp` (resting) to `14dp` (pressed/active).
  2. Ensure `tactile_button.dart` defaults to `colorScheme.primary` background and `colorScheme.onPrimary` text so no button is ever invisible.
  3. Update `page_transitions.dart` to use Material 3 Shared Z/X Axis transitions with `Cubic(0.2, 0.0, 0.0, 1.0)` forward curve and `Cubic(0.3, 0.0, 0.8, 0.15)` reverse curve.

---

## PHASE 2: Diet Module Purge & High-Visibility Rebuild
**Goal:** Delete all preloaded data, diet planners, recipes, and grocery tabs. Rebuild the Diet tab around fast user-authored meal logging and a functional, reactive Nutrition Profile.

### Step 2.1: Delete Bloated Diet Files & Preloaded Data
- **Delete Files:**
  - `lib/features/diet/data/indian_regional_food_db.dart`
  - `lib/features/diet/widgets/meal_planner_tab.dart`
  - `lib/features/diet/widgets/grocery_pantry_tab.dart`
- **Clean Models & Repository:**
  - In `lib/features/diet/models/diet_planner_models.dart` and `lib/features/diet/data/diet_repository.dart`:
    1. Remove all references to `IndianRegionalFoodDb`, preloaded food seeding, recipe templates, weekly meal planner slots, and grocery/pantry lists.
    2. Retain and clean up:
       - `NutritionProfile` (weightKg, heightCm, age, gender, activityLevel, goalType, targetCalories, targetProteinG, targetCarbsG, targetFatG, targetWaterMl).
       - `CustomFoodItem` (user-created saved food item: `id`, `name`, `servingUnit`, `calories`, `proteinG`, `carbsG`, `fatG`, `isFavorite`).
       - `MealLogEntry` (`id`, `timestamp`, `mealType` [Breakfast, Lunch, Dinner, Snack], `name`, `servings`, `calories`, `proteinG`, `carbsG`, `fatG`).
    3. Add full CRUD methods in `DietRepository`:
       - `saveNutritionProfile(NutritionProfile profile)`
       - `upsertCustomFood(CustomFoodItem item)` / `deleteCustomFood(String id)`
       - `logMeal(MealLogEntry entry)` / `updateMealLog(MealLogEntry entry)` / `deleteMealLog(String id)`

### Step 2.2: Fix Nutrition Profile & Target Engine
- **Files:** `lib/features/diet/engine/nutrition_science_engine.dart`, `lib/features/diet/widgets/nutrition_profile_sheet.dart`, `lib/features/home/cards/calories_card.dart`
- **Actions:**
  1. In `nutrition_science_engine.dart`, verify Mifflin-St Jeor BMR & TDEE calculation. Provide both **Auto-Calculate Targets** (from weight, height, age, activity, goal) and **Manual Override** (allowing the user to directly edit daily Calorie, Protein, Carb, and Fat targets).
  2. Rebuild `nutrition_profile_sheet.dart` with M3 Expressive `surfaceContainerHigh` cards, high-visibility `TextFormField` inputs with clear `OutlineInputBorder`, segmented choice pills for Goal (`Cut`, `Maintain`, `Bulk`), and a live preview card showing calculated `Target kcal`, `Protein (g)`, `Carbs (g)`, and `Fats (g)` before tapping **Save Profile**.
  3. Wire `DietRepository` listeners so saving the profile immediately updates `diet_page.dart` and `lib/features/home/cards/calories_card.dart`.

### Step 2.3: Rebuild `diet_page.dart` & `manual_food_input.dart`
- **Files:** `lib/features/diet/diet_page.dart`, `lib/features/diet/widgets/diet_dashboard_widgets.dart`, `lib/features/diet/widgets/manual_food_input.dart`, `lib/features/diet/widgets/diet_progress_tab.dart`
- **Actions:**
  1. Simplify `diet_page.dart` to 2 clean views via an M3 Segmented Pill Bar: **Today's Log** and **Trends & Profile**. (No Planner tab, no Grocery tab, no Recipes).
  2. **Today's Log View:**
     - **Hero Macro Summary Card:** Large, high-contrast remaining/consumed Calories ring + 3 horizontal progress bars for Protein, Carbs, and Fats bound directly to `NutritionProfile` targets, plus a quick-tap Edit Profile button.
     - **Meal Sections (Breakfast, Lunch, Dinner, Snacks):** Each section shows logged items for today with tap-to-edit and swipe-to-delete, plus a high-visibility `+ Log` tonal button.
  3. **Rebuild `manual_food_input.dart`:**
     - No preloaded regional database search.
     - Tab 1: **Quick Log / Create Food** — Clean form for Food Name, Calories, Protein, Carbs, Fat, Meal Slot, and a toggle `"Save to My Custom Foods"`.
     - Tab 2: **My Saved Foods** — List of user-created `CustomFoodItem`s with 1-tap logging, portion multiplier (`0.5x`, `1x`, `1.5x`, `2x`), and inline Edit/Delete buttons.

---

## PHASE 3: Tasks vs. Habits Domain Split & Button Visibility Fix
**Goal:** Strictly separate one-time Tasks (single day) from recurring Habits (daily/weekly/monthly) and fix all invisible buttons on the Tasks page.

### Step 3.1: Enforce Model & Repository Separation
- **Files:** `lib/features/tasks/models/task_os_models.dart`, `lib/features/tasks/data/task_os_repository.dart`, `lib/data/services/task_reset_service.dart`, `lib/features/tasks/engine/rrule_recurrence_engine.dart`
- **Actions:**
  1. In `task_os_models.dart`, ensure `TaskItem` (or the primary task model) has an explicit distinction:
     - **One-Time Task (`isHabit == false`):** Has a `scheduledDate` (normalized to `YYYY-MM-DD`), `rrule = null`, `recurrenceType = RecurrenceType.none`. Appears **only** on its `scheduledDate` (or in an explicit "Overdue" toggle if incomplete). Once created for today, it never duplicates or recurs tomorrow.
     - **Recurring Habit (`isHabit == true`):** Has `recurrenceType` (`daily`, `weekly`, `monthly`), `recurrenceDays` (e.g., `[1,2,3,4,5]` for weekdays or day-of-month), `currentStreak`, `bestStreak`, and completion logged in `TaskDayLogRepository` per date.
  2. In `task_reset_service.dart`, ensure daily reset logic **only** resets completion state for `isHabit == true` items according to `RRuleRecurrenceEngine` and never mutates or re-spawns one-time Tasks.

### Step 3.2: Rebuild Tasks Page UI & Fix Button Visibility
- **Files:** `lib/features/tasks/tasks_page.dart`, `lib/features/tasks/widgets/add_task_dialog.dart`, `lib/features/tasks/widgets/task_card.dart`, `lib/features/tasks/widgets/animated_task_os_tile.dart`, `lib/features/tasks/widgets/task_action_pill.dart`, `lib/features/tasks/widgets/sliding_workspace_pill_bar.dart`
- **Actions:**
  1. In `tasks_page.dart`, structure the workspace tabs clearly: **Tasks (One-Time)** | **Habits (Recurring)** | **Academics**.
  2. In `add_task_dialog.dart`:
     - Add a top M3 Segmented Button: **`One-Time Task`** vs **`Recurring Habit`**.
     - When **`One-Time Task`** is selected: Show Title, Date Picker (defaults to Today), Priority, and Optional Time. Hide all recurrence controls.
     - When **`Recurring Habit`** is selected: Show Title, Frequency Selector (`Every Day`, `Specific Days of Week`, `Monthly on Day X`), and Target Streak/Time.
     - Fix the **Save / Create** button at the bottom of `add_task_dialog.dart`: Use a full-width `FilledButton` (`colorScheme.primary` background, `colorScheme.onPrimary` bold text).
  3. Fix `task_action_pill.dart`, `task_card.dart`, and `animated_task_os_tile.dart`:
     - Replace all transparent/low-opacity action icons and pills with solid `colorScheme.secondaryContainer` fills and `colorScheme.onSecondaryContainer` icons/text.
     - Add spring-animated checkbox morphing (`28dp` circle $\rightarrow$ `10dp` rounded square on check) with `AnimatedStrikethrough`.

---

## PHASE 4: Context-Aware Digital Scanner & Smart Auto-Router
**Goal:** Rework the PDF/document scanner so user context (e.g., `"CS S3"`) filters and pre-selects only relevant items while allowing manual selection, and automatically routes timetables, tasks, and syllabus items to their respective modules.

### Step 4.1: Build the Smart Scanner & Classifier Pipeline
- **Files:** `lib/features/tasks/widgets/academic_hub_view.dart`, `lib/data/services/reader_service.dart`, `lib/data/services/ai_service.dart`
- **Actions:**
  1. Create a structured scanner model `ScannedDocumentResult` containing:
     - `detectedCategory`: `enum ScanDocCategory { timetable, examSchedule, syllabus, tasks, expenses }`
     - `items`: `List<ScannedExtractItem>` where each item has `id`, `title`, `subtitle`, `targetModule` (`timetable` | `course` | `task` | `habit` | `finance`), `matchedContextTag` (e.g., `"CS S3"`), `isRelevant` (`bool`), `isSelected` (`bool`, initialized to `isRelevant`), and `structuredPayload` (`Map<String, dynamic>`).
  2. When the user uploads a PDF/image and provides a context filter (e.g., `"CS S3"` or `"Semester 3 CSE"`):
     - Extract text on-device first via `ReaderService` (saving vision tokens if text layer exists in PDF).
     - Pass the extracted text + user filter context (`"CS S3"`) to `AiService.parseDocumentWithFilter()`.
     - The parser marks `isRelevant = true` **only** for rows matching the user's branch/semester/context (e.g., `CS`, `CSE`, `S3`, `Slot A-F` for CS S3) and `isRelevant = false` for other branches (e.g., `ME`, `EC`, `CE`, `S5`, `S7`).
     - Initialize `item.isSelected = item.isRelevant`.

### Step 4.2: Interactive Selection & Auto-Routing UI
- **Files:** `lib/features/tasks/widgets/academic_hub_view.dart`, `lib/features/tasks/data/task_os_repository.dart`
- **Actions:**
  1. Display a **Scanner Review Bottom Sheet** (`SpringSheet`) before importing:
     - Header badge showing the auto-detected destination: e.g., **`Auto-Routing to: Academic Timetable`** (with a dropdown to override destination if desired).
     - Filter bar: `Relevant Only (Auto-Selected)` | `Show All Extracted Items` | `Select All` | `Clear All`.
     - Checkable list of `ScannedExtractItem` tiles where the user can manually check/uncheck any item or tap to edit its title/time/slot.
  2. **Confirm Import Auto-Router:**
     - Items with `targetModule == 'timetable'` automatically populate the weekly **Timetable** in `AcademicHubView` (`TaskOsRepository`).
     - Items with `targetModule == 'examSchedule'` or `'task'` automatically create dated **One-Time Tasks** on their respective exam/due dates.
     - Items with `targetModule == 'syllabus'` or `'course'` populate the **Academic Courses & Attendance/GPA** tracker.
     - Items with `targetModule == 'finance'` route to `FinanceRepository`.

---

## PHASE 5: Unified, Inter-Modular AI Agent (On-Device First + Token Optimization)
**Goal:** Connect Diet, Finance, Tasks, Habits, Academics, Health/Wearables, and Journal into one unified AI orchestrator with an on-device deterministic fast-path and ultra-compact token prompts.

### Step 5.1: Unified Cross-Module Context Builder (Delta Token Optimization)
- **Files:** `lib/data/services/ai_context.dart`, `lib/data/services/ai_service.dart`, `lib/data/services/gemini_client.dart`
- **Actions:**
  1. Refactor `ai_context.dart` to support **Intent-Scoped Delta Contexts**:
     - Instead of serializing all Hive boxes on every chat message, classify the prompt on-device into required sectors: `Set<AiSector> { diet, finance, tasks, habits, academics, health, journal }`.
     - Build a minified JSON snapshot containing **only** the active sectors using short keys:
       - `diet`: `{"cal_in":1450,"cal_tgt":2200,"p_in":95,"p_tgt":150,"meals_today":["Oats 350kcal","Chicken 500kcal"]}`
       - `finance`: `{"safe_day":450,"bal":12400,"spent_today":180,"upcoming_bills":[{"n":"Hostel","amt":4500,"due":"2026-10-25"}]}`
       - `tasks`: `{"today_tasks":[{"id":"t1","t":"OS Lab Record","done":false}],"habits":[{"id":"h1","t":"Gym","freq":"daily","done":true,"strk":12}]}`
       - `academics`: `{"sem":"CS S3","low_att":["Maths 71%"],"today_classes":["9:00 DS","10:00 OS"]}`
       - `health`: `{"steps":6400,"sleep_h":6.8,"wt_kg":68.5}`
  2. Configure `gemini_client.dart` to use `gemini-3.8-flash` (or configurable model constant with fallback to `gemini-2.5-flash`) with a compact system instruction (<250 tokens) and `responseMimeType: 'application/json'`.

### Step 5.2: On-Device Fast-Path Router (0 API Tokens)
- **Files:** `lib/data/services/ai_service.dart`, `lib/features/tasks/engine/task_nl_parser.dart`, `lib/features/finance/engine/capture_engine.dart`
- **Actions:**
  1. In `AiService.processUserInput(String input)`, run the **On-Device Deterministic Router** first:
     - **Expense/Income Match:** e.g., `"spent 150 onshawarma"`, `"paid 60 auto"` $\rightarrow$ Parse via `CaptureEngine`, write to `FinanceRepository`, and return instant confirmation without calling Gemini.
     - **Meal Log Match:** e.g., `"ate 3 eggs and toast 380 cal 22g protein"` or matching a saved `CustomFoodItem` $\rightarrow$ Log directly to `DietRepository` (0 tokens).
     - **Task / Habit Match:** e.g., `"remind me to submit assignment today at 5pm"` (Task) or `"every day read 20 mins"` (Habit) $\rightarrow$ Parse via `TaskNlParser`, write to `TaskOsRepository` (0 tokens).
  2. If the query requires multi-step reasoning or cross-domain synthesis (e.g., *"I have ₹500 left for the week and need 140g protein today, plus I have an OS exam tomorrow—plan my evening"*), route to `GeminiClient` with the relevant sector deltas (`finance` + `diet` + `academics` + `tasks`).

### Step 5.3: Cross-Module Action Executor
- **Files:** `lib/data/services/ai_service.dart`, `lib/features/home/home_chat.dart`, `lib/features/home/widgets/chat_message_bubble.dart`
- **Actions:**
  1. Implement `AiActionDispatcher` inside `ai_service.dart` capable of executing an array of cross-sector mutations returned by the AI in a single turn:
     - `diet.log_meal`, `diet.update_targets`, `diet.save_custom_food`
     - `tasks.create_one_time_task`, `tasks.complete_task`
     - `habits.create_habit`, `habits.log_habit`
     - `academics.add_timetable_slot`, `academics.mark_attendance`
     - `finance.add_transaction`, `finance.update_budget`
     - `journal.append_entry`
  2. In `chat_message_bubble.dart` and `home_chat.dart`, render executed actions as crisp Material 3 Expressive tonal confirmation chips (e.g., `[✓ Logged 450 kcal to Diet]`, `[✓ Added One-Time Task: OS Revision]`, `[✓ Logged ₹120 Expense]`) with a 1-tap **Undo** button.

---

## PHASE 6: Final Verification & Cleanup (COMPLETED)
1. [x] Deleted all unused imports referencing `indian_regional_food_db.dart`, `meal_planner_tab.dart`, `grocery_pantry_tab.dart`, and starfield canvas effects.
2. [x] Verified zero glassmorphism (`BackdropFilter`) and zero glowing AI gradient borders across the entire codebase.
3. [x] Strict Task vs. Habit separation established across models, repositories, and UI.
4. [x] Context-aware Digital Scanner with auto-routing implemented and verified.
5. [x] Tier 1 deterministic on-device fast-path & Tier 2 delta-pruned AI agent with universal 1-tap Undo implemented.
6. [x] `flutter analyze` completed with **0 issues found** (0 errors).
7. [x] `flutter test` skipped per user command (`skip all flutter test`).