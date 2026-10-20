# AGENT.md — Master Engineering & Visual Overhaul Specification (v2.0)
**Target Agent:** Antigravity Agent (Gemini 3.8 Flash)
**Project:** `habit_tracker` (Flutter Personal OS)
**Role:** Chief Flutter Architect & Lead UI/UX Motion Designer

---

## 0. CRITICAL ANTI-HALLUCINATION GUARDRAILS
1. **READ BEFORE WRITE:** Always read the existing file from disk before modifying it. Never invent file paths, class names, or method signatures.
2. **NO PHANTOM PACKAGES:** Do NOT add external packages to `pubspec.yaml` that are not already installed. Implement all 2D vector stickers, ECG waveforms, dot matrices, spline charts, and particle bursts using Flutter's native `CustomPainter`, `Canvas`, `flutter/physics.dart`, and existing packages (`fl_chart`, `hive`, `flutter_local_notifications`, `google_generative_ai`).
3. **HIVE ADAPTER SAFETY:** Never alter existing `@HiveType(typeId: ...)` numbers or existing `@HiveField(index)` types.
4. **PHASE VERIFICATION:** After each phase, run `flutter analyze` and fix all errors before moving to the next phase.

---

## 1. PHASE 1: STRICT MONOCHROME MODE & 3D FROSTED NAVIGATION BAR

### 1.1 Strict Monochrome Theme Engine
- **Target Files:**
  - `lib/core/theme/app_colors.dart`
  - `lib/core/theme/app_theme.dart`
  - `lib/core/theme/expressive_tokens.dart`
  - `lib/screens/settings_page.dart`
- **Implementation Rules:**
  1. Add a boolean setting `isMonochromeMode` persisted in `SharedPreferences` / Hive settings.
  2. When `isMonochromeMode == true`:
     - **Zero Chromatic Colors:** Every primary, secondary, tertiary, card, chart, and progress bar token MUST resolve to pure achromatic grayscale:
       - **Dark Monochrome:** `surface: #0A0A0A`, `surfaceContainerLow: #141414`, `surfaceContainer: #1C1C1E`, `surfaceContainerHigh: #2C2C2E`, `primary: #FFFFFF`, `onPrimary: #000000`, `primaryContainer: #3A3A3C`, `onPrimaryContainer: #F2F2F7`, `secondary: #AEAEB2`, `outline: #48484A`.
       - **Light Monochrome:** `surface: #F5F5F7`, `surfaceContainerLow: #FFFFFF`, `surfaceContainer: #EBEBF0`, `surfaceContainerHigh: #D8D8DC`, `primary: #111111`, `onPrimary: #FFFFFF`, `primaryContainer: #E5E5EA`, `onPrimaryContainer: #1C1C1E`, `secondary: #636366`, `outline: #C7C7CC`.
     - **Alerts Exception ONLY:** Only semantic alert/status tokens retain color:
       - `error`: `#FF3B30` (Critical alert / budget overrun / missed medicine)
       - `warning`: `#FF9F0A` (Low attendance warning / approaching limit)
  3. Create a helper `AppColors.resolveAccent(BuildContext context, Color chromaticColor, {bool isAlert = false})` that returns `chromaticColor` in standard mode, `chromaticColor` if `isAlert == true`, and `Theme.of(context).colorScheme.primary` (grayscale) when `isMonochromeMode == true`. Apply this helper across all home cards, health charts, diet macro bars, and finance charts.

### 1.2 Persistent 3D Frosted Navigation Bar
- **Target Files:**
  - `lib/widgets/bottom_nav_bar.dart`
  - `lib/core/widgets/glass_tab_bar.dart`
  - `lib/screens/home_page.dart`
  - `lib/features/finance/ui/shell/money_shell_page.dart`
- **Implementation Rules:**
  1. **Persistent Visibility Across All Navigations:**
     - In `lib/screens/home_page.dart` (and any sub-shell like `money_shell_page.dart`), set `extendBody: true` on the `Scaffold` so screen content scrolls smoothly behind the floating navigation bar.
     - Ensure all tab pages add bottom padding (`MediaQuery.of(context).padding.bottom + 96.0`) so the last scrollable item is never obscured.
  2. **3D Tactile + Frosted Glass Visual Construction:**
     - Wrap the navigation bar in a floating pill (`margin: EdgeInsets.fromLTRB(16, 0, 16, 20)`, `BorderRadius.circular(36)`).
     - **Layer 1 (Ambient 3D Elevation Shadow):** Outer `Container` with dual `BoxShadow`:
       - Deep shadow: `BoxShadow(color: Colors.black.withOpacity(0.38), blurRadius: 28, spreadRadius: 2, offset: Offset(0, 12))`
       - Tight contact shadow: `BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 6, offset: Offset(0, 3))`
     - **Layer 2 (Frosted Blur):** `ClipRRect(borderRadius: BorderRadius.circular(36))` $\rightarrow$ `BackdropFilter(filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0))`.
     - **Layer 3 (3D Specular Rim & Surface Tint):** Inner `Container` with a subtle vertical gradient fill (`surface.withOpacity(0.72)` top $\rightarrow$ `surfaceContainerHigh.withOpacity(0.85)` bottom) and a 3D bevel border (`top` border `1.5px` white with `0.28` opacity for top light catch; `bottom` border `1.0px` black with `0.4` opacity).
     - **Layer 4 (Active Tab 3D Pill):** The active tab indicator is a raised 3D pill (`BoxShadow` + convex top highlight) that slides between tabs using `SpringDescription(mass: 1.0, stiffness: 340.0, damping: 26.0)`.

---

## 2. PHASE 2: HOME SCREEN CARDS OVERHAUL (OXYGENOS EXPANDABLE WIDGET STACK)

### 2.1 Visual & Motion Spec (Matching Video Reference)
- **Target Files:**
  - `lib/screens/dashboard_view.dart`
  - `lib/features/home/cards/home_card_frame.dart`
  - `lib/features/home/cards/home_card.dart`
  - `lib/features/home/cards/calories_card.dart`
  - `lib/features/home/cards/health_summary_card.dart`
  - `lib/features/home/cards/finance_card.dart`
  - `lib/features/home/cards/missions_card.dart`
- **Implementation Rules:**
  1. **Compact Home Grid Tiles (Resting State):**
     - Render home cards in a clean 2-column Bento grid with `28dp` squircle corners (`BorderRadius.circular(28)`).
     - **Square Metric Tile (1x1 — e.g., Steps / Calories):** Dark matte surface (`#26292E` in dark mode) featuring a 270-degree circular gauge arc in the center (`#22C55E` green in color mode, `#FFFFFF` in monochrome), a top walking/metric icon inside the arc, huge centered tabular number (`993`, `34sp`, `FontWeight.w700`), and sub-metric (`702 m`, `13sp`) at the bottom gap of the arc.
     - **Smart Folder / Cluster Tile (1x1):** 2x2 mini-grid preview of sector icons (`Tasks`, `Diet`, `Finance`, `Health`) that expands into the full **"AI Suggest / Daily Cluster"** modal when tapped.
  2. **Expandable Frosted Cluster Modal (Expanded State on Tap):**
     - Tapping a cluster tile or compact card opens an interactive hero overlay (`showGeneralDialog` with `BackdropFilter(sigmaX: 20, sigmaY: 20)` and spring scale/rect morphing `SpringDescription(mass: 1.0, stiffness: 320.0, damping: 28.0)`).
     - Inside the expanded 3-tier cluster container (`width: MediaQuery.size.width - 32`, `padding: 16`, rounded `32dp` outer frame):
       - **Row 1 — `AI Daily` Insight Card (Full Width):** Deep navy/slate card (`#182235` or monochrome `#1E1E1E`), top row with `AI Daily` badge on left and `Updated [time]` on right, bold headline insight (`17sp`, `FontWeight.w700`) with a right-side thumbnail/icon badge, and 2 clickable divider rows below for secondary cross-sector insights (e.g., budget status + upcoming task).
       - **Row 2 — `Steps / Goal` Contrast Card (Full Width):** High-contrast white card (`#F8FAFC` in light/hybrid, `#25282E` in dark mode) with an animated walking icon perched on a horizontal rounded progress bar (`height: 8dp`, `#22C55E` fill), right-aligned goal label (`7007 steps to your goal (8000)`), large bold count (`993 steps`, `32sp`), bottom-left `Distance 702 m`, and bottom-right `Highest 24182 steps`.
       - **Row 3 — Two 1x1 Action Cards Side-by-Side:**
         - **Left Square Card (e.g., `Tasks / Budget Quota`):** Title at top-left, multi-segment horizontal bar (blue/amber/grey segments), `X / Y completed` subtitle, and a bottom pill button (`✓ Complete Next` / `Clean up`) with dark translucent fill.
         - **Right Square Card (e.g., `Quick Action / Focus / Sync`):** Title + subtitle at top-left, and a bottom-right circular primary action button (`44dp` circle) surrounded by 3 concentric animated radar/ripple rings.
     - Tapping outside the cluster smoothly collapses the cards back into the home screen tile using reverse spring physics.

---

## 3. PHASE 3: HEALTH TAB REDESIGN (IDENTICAL TO DRIBBBLE REFERENCE + DARK MODE)

### 3.1 Master Health Dashboard (`Personal Health`)
- **Target Files:**
  - `lib/features/health/health_page.dart`
  - `lib/features/wearables/ui/fitness_tab.dart`
- **Color Palette (Light Mode & Dark Mode):**
  - **Light Mode:** Background `#F8F9FA`, Card Surface `#FFFFFF`, Secondary Surface `#F3F5F7`, Primary Text `#111417`, Subtitle Text `#8A929A`, Emerald Accent `#05B87C`, Coral Accent `#FF6E6E`, Action Circle `#111111`.
  - **Dark Mode:** Background `#0D1014`, Card Surface `#161B22`, Secondary Surface `#1F2630`, Primary Text `#F0F4F8`, Subtitle Text `#8B949E`, Emerald Accent `#10B981`, Coral Accent `#FF6B6B`, Action Circle `#10B981` (with `#002114` text/icon).
  - *(Note: Respect `isMonochromeMode` via `AppColors.resolveAccent`)*.
- **Exact Layout Structure for `health_page.dart`:**
  1. **Top Header Row:**
     - Left: Circular user avatar (`42dp`) + `Welcome` (`12sp`, muted) + User Name (`16sp`, `FontWeight.w700`).
     - Right: `42dp` circular surface button with a 2x2 dot grid icon (`Icons.grid_view_rounded`).
  2. **Hero Steps & Day-Ruler Pill Card:**
     - Rounded stadium container (`BorderRadius.circular(64)`, height `116dp`, `padding: 12dp`).
     - **Left Circle (`92dp` diameter):** Solid `#05B87C` green circle containing a walking figure icon, bold step count (`4754`, `22sp`, white), and `Steps` label (`12sp`, white/80%). Tapping this opens the **Walking Steps Detail View**.
     - **Right Timeline Ruler:** Horizontal scrollable/selectable 5-day strip (`Sat`, `Sun`, `Mon`, `Tue`, `Wed`) with the selected day bolded (`Tue`) above a custom-painted horizontal ruler of major and minor vertical tick marks (`CustomPainter`).
  3. **Section Heading:** `Personal Health` (`24sp`, `FontWeight.w700`, `padding: EdgeInsets.symmetric(vertical: 16)`).
  4. **Asymmetric 2-Column Bento Grid:**
     - **Left Column (`Expanded`):**
       - **Card 1 (`Cardiac Rhythm`, height `175dp`, `BorderRadius.circular(28)`):**
         - Top row: Soft pink circle (`36dp`) with red heart icon + `Cardiac\nRhythm` label.
         - Middle: `95 bpm` (`26sp`, `FontWeight.w800` for `95`, `14sp` for `bpm`).
         - Bottom: Custom-painted ECG waveform (`EcgWaveformPainter`) with a vertical emerald highlight band and glowing dot on the peak.
       - **Card 2 (`Brain Activity` / `Sleep & Mental Load`, height `115dp`, `BorderRadius.circular(28)`):**
         - Top row: Soft pink circle (`36dp`) + `Brain\nActivity` label.
         - Bottom: Smooth coral-pink spline wave with soft gradient fill underneath (`SmoothWavePainter`).
     - **Right Column (`Expanded`):**
       - **Card 3 (`Acid Balance` / `Hydration & Recovery`, height `175dp`, `BorderRadius.circular(28)`):**
         - Top row: Soft coral circle (`36dp`) + `Acid\nBalance` (or `Hydration\nBalance`) label.
         - Middle: `14 pH` (or hydration/recovery index, `26sp`, `FontWeight.w800`).
         - Bottom: 6-column x 3-row dot matrix (`DotMatrixPainter`) where active dots render in emerald green (`#05B87C`), mid dots in soft mint, and inactive dots in muted grey.
       - **Card 4 (`Exercise` Circular CTA, `115dp` diameter circle):**
         - Solid black circle (`#111111` in Light Mode; `#1F2937` with `#10B981` border/text in Dark Mode) centered in the bottom-right slot.
         - Displays a fast-running icon + `Exercise` (`14sp`, `FontWeight.w600`, white). Tapping opens the Exercise/Workout logger sheet.
  5. **Bottom Full-Width Card (`Activity` Weekly Bar Card, height `96dp`, `BorderRadius.circular(28)`):**
     - Left: `Activity` (`13sp`, muted) + current day name e.g. `Thursday` (`18sp`, `FontWeight.w700`).
     - Right: 5 vertical rounded bars (`width: 14dp`, `borderRadius: 6dp`) representing recent days, with the active day's bar in solid `#05B87C` emerald and the other 4 in subtle `surfaceContainerHighest`.

### 3.2 Walking Steps Detail Screen (`WalkingStepsDetailPage`)
- Triggered via shared-element / spring transition when tapping the Hero Steps pill or Activity card:
  1. **Top Bar:** Circular back button (`<-`) on left, circular `...` options button on right.
  2. **Header Card:** Soft green circular icon (`Icons.directions_walk_rounded`) + `Walking steps` (`22sp`, `FontWeight.w700`) + `See your Walking Statistics` (`13sp`, muted).
  3. **Main Spline Chart Card (`BorderRadius.circular(32)`):**
     - Top Metrics Row:
       - Left: `Total Distance` label + `142.47 Km/h` (or `km` from `WearableRepository` step distance).
       - Right: `Total Steps` label + `475.47` (formatted step count).
     - Interactive Area Chart (`height: 220dp`):
       - Smooth cubic Bézier emerald curve (`#05B87C`) with vertical linear gradient fill (`#05B87C` at 30% opacity $\rightarrow$ transparent).
       - Active peak callout: Floating bold label (`2400`) above a coral-red circle (`#FF6B6B`) with a vertical coral drop-line extending down to the time axis.
       - Bottom Time Axis: Horizontal row of time pills (`05:00`, `06:00`, `07:00`, `08:00`) where the selected time (`06:00`) is highlighted in a solid emerald pill (`#05B87C`) with white text.
  4. **Bottom 2-Column Summary Row:**
     - **Left Card (`Burnt Calories`):** Coral flame icon + `Burnt\nCalories`, `957 kCal` (`22sp`, bold), and a filled coral wave chart at the bottom edge.
     - **Right Card (`Speed Average`):** Coral gauge icon + `Speed\nAverage`, `6.2 Km/h` (`22sp`, bold), and a 4-row dashed horizontal multi-segment track indicator at the bottom.

---

## 4. PHASE 4: SAMSUNG HEALTH GOAL & TASK COMPLETION ANIMATIONS

- **Target Files:**
  - `lib/core/motion/SHealthCelebrationOverlay.dart` *(Create inside `lib/core/motion/`)*
  - `lib/features/tasks/widgets/animated_task_os_tile.dart`
  - `lib/features/diet/diet_page.dart`
  - `lib/features/health/health_page.dart`
- **Implementation Rules:**
  1. **Task / Habit Checkmark Spring & Ripple:**
     - When a user checks off a Task or Habit in `animated_task_os_tile.dart`:
       - Morph the checkbox from a `28dp` circle to a `12dp` squircle with an elastic spring bounce (`SpringDescription(mass: 0.8, stiffness: 500.0, damping: 18.0)` — underdamped so it overshoots to `1.18x` scale before settling at `1.0x`).
       - Emit a radial burst of 12 geometric micro-particles (circles and rounded pills) around the checkbox using a lightweight `CustomPainter` (`CelebrationBurstPainter`, `600ms` duration).
       - Fire a double-tap celebratory haptic (`HapticFeedback.mediumImpact()` followed `80ms` later by `HapticFeedback.lightImpact()`).
  2. **Daily Goal Completion (100% Steps, Calorie Target, or All Daily Habits Completed):**
     - Trigger a Samsung Health-style **Goal Achieved Banner & Ring Pulse**:
       - The progress ring overshoots with an elastic wave, glowing with a radial pulse ring that expands outward and fades over `750ms`.
       - A floating spring-animated badge (`🏆 Daily Goal Reached! +XP`) drops from the top safe area with confetti/geometric sparkles, holds for `2.2s`, and springs away.

---

## 5. PHASE 5: MOOD-DRIVEN ANIMATED STICKER AI CHAT BUBBLE

### 5.1 The 12 Geometric Mood Characters (Vector `CustomPainter`)
- **Target Files:**
  - `lib/features/home/widgets/mood_sticker_avatar.dart` *(Create new widget)*
  - `lib/features/home/home_chat.dart`
  - `lib/features/home/widgets/chat_message_bubble.dart`
- **Specification (Matching the 12-Sticker Reference Sheet):**
  Define `enum UserMoodState` with these exact 12 states, shapes, colors, and facial expressions:
  1. `excited`: Soft Pink (`#F9A8D4`) **Circle** — closed upward happy arc eyes (`◡ ◡`) above a wide curved smile.
  2. `joyful`: Hot Pink (`#F472B6`) **4-Lobed Clover** — double-arc crinkle eyes inside a wide open-top smile arc.
  3. `grateful`: Purple (`#9353D3`) **Vertical Figure-8 / Peanut Shape** — serene closed downward-arc eyes (`◡ ◡`) + gentle smile.
  4. `energized`: Lavender (`#A882DD`) **3-Crown Scalloped Top Rounded Square** — winged happy eyes + compact smile.
  5. `sensitive`: Sky Blue (`#0EA5E9`) **Rounded Arch / Dome** — sad downward eyes with a white animated teardrop hanging from the left eye.
  6. `confused`: Royal Blue (`#1D4ED8`) **Hexagon** — two large white sclera circles; left pupil is a black dot, right eye contains a rotating orange spiral (`#F97316`).
  7. `bored`: Forest Green (`#15803D`) **Circle** — two joined white eyes with black pupils rolling upward toward the top-right.
  8. `stressed`: Emerald Green (`#059669`) **Rounded Equilateral Triangle** — tight angled `> <` eyes and a short flat tense mouth.
  9. `angry`: Red-Orange (`#EA580C`) **Rounded Square** — flat-topped glaring white eyes with centered black pupils above a straight horizontal mouth line.
  10. `insecure`: Orange (`#F97316`) **Circle** — horizontal cyclops/pill white eye band with a black pupil shifting nervously side-to-side.
  11. `hurt`: Amber (`#F59E0B`) **3-Wave Scalloped Vertical Rectangle** — closed downward eyes (`◡ ◡`) and a short flat line mouth.
  12. `guilty`: Golden Yellow (`#EAB308`) **Quarter-Circle Wedge** — two white eyes tucked in the lower-left corner glancing sideways.

### 5.2 Continuous 60fps Emoji-Style Micro-Animations
- `MoodStickerAvatar` must use an `AnimationController` (repeating `3600ms` idle cycle + reactive state triggers) to animate:
  - **Eye Blinking:** Smooth vertical scale (`1.0` $\rightarrow$ `0.08` $\rightarrow$ `1.0` over `160ms`) every ~3 seconds.
  - **Eye Tracking / Glancing:** Pupils shift smoothly (`Offset(-2.5, 0)` $\leftrightarrow$ `Offset(2.5, -1.5)`) during idle and look directly at the text input when the user is typing.
  - **Speaking / Smiling Animation:** While the AI is streaming a response or when tapped, the mouth curvature animates rhythmically and the body squashes/stretches (`scaleX: 1.05, scaleY: 0.95` $\leftrightarrow$ `scaleX: 0.96, scaleY: 1.04`).
  - **Mood-Specific Loops:** Continuous slow rotation on the `confused` orange spiral; gentle bobbing teardrop on `sensitive`; subtle high-frequency shiver on `stressed`.
- **Where Used:**
  1. Replaces the floating AI Assistant launcher button on the Home screen and bottom chat bar.
  2. Replaces the AI avatar next to every AI message in `chat_message_bubble.dart` and `home_chat.dart`.
  3. Tapping the sticker avatar opens a quick **"Check-in time: How are you today?"** 4x3 grid sheet allowing the user to see why the AI detected their current mood or manually override their mood for the day.

### 5.3 Multi-Sector Mood Detection Engine
- Compute the active `UserMoodState` automatically from live repository data:
  - **Tasks & Habits (`TaskOsRepository`):** Overdue tasks $> 3$ $\rightarrow$ weights toward `stressed` / `guilty`. Completion rate $> 85\%$ $\rightarrow$ weights toward `excited` / `energized`.
  - **Finance (`FinanceController`):** Today's spending $>$ daily safe-to-spend by $> 50\%$ $\rightarrow$ weights toward `stressed` / `guilty` / `hurt`. Under budget + savings goal on track $\rightarrow$ weights toward `grateful` / `joyful`.
  - **Diet (`DietRepository`):** Logged meals $= 0$ after 2:00 PM $\rightarrow$ weights toward `bored` / `insecure`. Within 15% of calorie & protein target $\rightarrow$ weights toward `energized` / `joyful`.
  - **Health (`WearableRepository`):** Sleep $< 5.5\text{h}$ $\rightarrow$ weights toward `sensitive` / `hurt`. Steps $\ge$ goal $\rightarrow$ weights toward `excited`.

---

## 6. PHASE 6: FIX ALARM SYSTEM, AI VISION RATE LIMIT & MULTI-INTENT PARSING

### 6.1 Fix the Alarm & Reminder System
- **Target Files:**
  - `android/app/src/main/AndroidManifest.xml`
  - `lib/data/services/notification_service.dart`
  - `lib/data/services/reminder_scheduler.dart`
  - `lib/features/wearables/data/wake_service.dart`
  - `lib/features/tasks/widgets/wakeup_detail_sheet.dart`
- **Implementation Rules:**
  1. **`AndroidManifest.xml`:** Ensure the following permissions and receivers are present inside `<manifest>` and `<application>`:
     - `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
     - `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>`
     - `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>`
     - `<uses-permission android:name="android.permission.WAKE_LOCK"/>`
     - `<uses-permission android:name="android.permission.VIBRATE"/>`
     - `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>`
     - `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>`
     - Register `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` for `flutter_local_notifications`.
  2. **`notification_service.dart` & `reminder_scheduler.dart`:**
     - Initialize `tz.initializeTimeZones()` and set local location (`Asia/Kolkata` fallback if device timezone lookup fails) **before** scheduling any alarm.
     - Request both `requestNotificationsPermission()` and `requestExactAlarmsPermission()` on Android 13/14+.
     - Configure high-priority alarm channel with `Importance.max`, `Priority.max`, `fullScreenIntent: true`, `playSound: true`, and `enableVibration: true`.
     - Always use `AndroidScheduleMode.exactAllowWhileIdle` in `zonedSchedule()`.
     - If `tz.TZDateTime` for a daily alarm/reminder is in the past for today, roll it forward by `+1 day` (`scheduledDate.add(const Duration(days: 1))`) so `zonedSchedule` never silently drops it or throws an past-date exception.
     - Call `ReminderScheduler.rescheduleAllActiveAlarms()` during `main.dart` startup so alarms survive app restarts.

### 6.2 Fix AI Vision `"omni rate exceeded"` Error
- **Target Files:**
  - `lib/data/services/gemini_client.dart`
  - `lib/data/services/ai_service.dart`
- **Implementation Rules:**
  1. **Sanitize Error Handling & Remove Hardcoded/Proxy Rate Strings:**
     - Search the entire `lib/` directory for `"omni"`, `"rate exceeded"`, or custom HTTP/SDK error wrappers in `gemini_client.dart` and `ai_service.dart`.
  2. **Image Downscaling Before Upload:**
     - When sending an image (e.g., a photo of orange juice or a meal) to `GeminiClient`, resize/compress the image bytes (`maxWidth: 512, maxHeight: 512, imageQuality: 70`) so payload size stays under `80KB` (~258 tokens).
  3. **Model Fallback Cascade & Retry:**
     - If the primary model (`gemini-2.5-flash` or configured model) returns a `429 Too Many Requests`, `Quota Exceeded`, or `"omni rate exceeded"` error, automatically retry once after `1200ms` across a fallback model list: `['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash']`.
  4. **Graceful Local Vision/Food Fallback:**
     - If all API calls fail due to network or quota exhaustion, never show `"omni rate exceeded"`. Instead, prompt/estimate using the on-device food macro estimator or open the pre-filled `ManualFoodInput` sheet with estimated macros so the user can log the item in 1 tap.

### 6.3 Fix Multi-Intent Compound Parsing (`"orange juice 20rs 200ml"`)
- **Target Files:**
  - `lib/data/services/ai_service.dart`
  - `lib/features/finance/engine/capture_engine.dart`
  - `lib/features/diet/engine/native_diet_ai_engine.dart`
- **Root Cause & Fix:**
  - Previously, when the user sent `"orange juice 20rs 200ml"`, the parser matched `20rs` as a Finance transaction and returned early—completely ignoring `orange juice 200ml` for Diet/Nutrition!
  - **Non-Exclusive Parallel Extraction Pipeline:**
    1. In `AiService.processUserInput(String text, {Uint8List? imageBytes})`, evaluate **ALL** domain extractors independently on the same input string:
       - **Finance Extractor:** Detects currency/price patterns (`20rs`, `₹20`, `rs 20`, `paid 20`). Extracts item name `"Orange Juice"` and amount `₹20`, logging an Expense to `FinanceRepository`.
       - **Diet & Hydration Extractor:** Detects food/beverage names and volume/weight/quantity (`orange juice`, `200ml`, `250g`, `2 eggs`, `1 plate`). Even when a price (`20rs`) is present in the same message, strip the price token (`20rs`) and evaluate the remaining item (`"orange juice 200ml"`).
       - **On-Device Nutrient Estimator Table (`NativeDietAiEngine`):** Built-in per-100g / per-100ml macro lookup for common beverages and foods (e.g., `orange juice`: `45 kcal, 0.7g protein, 10.4g carbs, 0.2g fat per 100ml` $\rightarrow$ for `200ml`: **`90 kcal, 1.4g protein, 20.8g carbs, 0.4g fat` + `+200ml hydration`**). If the item isn't in the user's `CustomFoodItem` list or local macro table, query Gemini for the exact macros of the quantity specified.
       - **Tasks & Habits Extractor:** Checks for task/habit triggers in the same sentence.
    2. **Unified Confirmation Output:**
       - When the user types `"orange juice 20rs 200ml"`, execute **both** actions and display both confirmation chips under the chat reply:
         - `[✓ Finance: Logged ₹20 for Orange Juice]`
         - `[✓ Diet: Logged Orange Juice (200ml) — 90 kcal, 21g Carbs, 1.4g Protein, +200ml Water]`

---

## 7. FINAL VERIFICATION CHECKLIST
- [ ] **Home Screen Cards:** Compact 1x1 / 2x2 tiles expand smoothly with spring physics into the 3-row frosted cluster (`AI Daily` dark card + `Steps` light progress card + two 1x1 bottom action cards) matching the video reference.
- [ ] **Monochrome Mode:** Selecting Monochrome strips all chromatic colors across the entire app except semantic `error` and `warning` alerts.
- [ ] **Samsung Health Animations:** Completing tasks, habits, or daily goals triggers the elastic ring overshoot, particle burst, and haptic celebration.
- [ ] **Alarms Fixed:** Exact alarms schedule reliably with timezone initialization, `exactAllowWhileIdle`, past-time rollover, and boot rescheduling.
- [ ] **AI Vision & Compound Input:** Sending an image of orange juice never throws `"omni rate exceeded"`, and sending `"orange juice 20rs 200ml"` logs BOTH the `₹20` expense in Finance AND the `200ml` nutrient/calorie count in Diet.
- [ ] **3D Frosted Nav Bar:** Floating 3D frosted bottom navigation bar is persistently visible across all navigation screens (`extendBody: true`).
- [ ] **Health Tab UI:** Identical to the Dribbble `Personal Health` and `Walking steps` UI in both Light Mode and Dark Mode.
- [ ] **Animated Sticker AI Bubble:** Displays the 12 mood-driven geometric stickers based on live Health, Money, Diet, and Task data with 60fps eye-blinking, pupil-glancing, and smiling animations.
- [ ] skip flutter analysis and flutter test 