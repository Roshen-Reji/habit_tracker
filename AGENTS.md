
## 0. STRICT RULES FOR THIS PASS
1. **ZERO FAKE METRICS:** Do NOT display fake medical data (`Cardiac Rhythm 95 bpm`, `Acid Balance 14 pH`, `Brain Activity`, or hardcoded `142.47 Km/h`) anywhere in the app. Every single number, chart, dot matrix, and waveform on the Health Tab and Home Screen MUST bind to real data from `WearableRepository`, `DietRepository`, `TaskOsRepository`, `WakeLogRepository`, and `FinanceController`.
2. **READ BEFORE WRITE:** Always inspect the target file on disk before editing to match existing repository getters and model field names.
3. **COMPILE GATE:** Run `flutter analyze` after each section and resolve all warnings/errors immediately.

---

## 1. FIX THE 3D FROSTED NAVIGATION BAR & REMOVE THE "WEIRD OVERLAY"

### 1.1 Why the Overlay Bug Happens & How to Fix It
- **Target Files:**
  - `lib/widgets/bottom_nav_bar.dart`
  - `lib/core/widgets/glass_tab_bar.dart`
  - `lib/screens/home_page.dart`
  - `lib/features/finance/ui/shell/money_shell_page.dart`
- **Bug Fix Requirements:**
  1. **Remove Rectangular Blur Bleed:** `BackdropFilter` blurs its entire parent clip region. You MUST place `ClipRRect(borderRadius: BorderRadius.circular(38))` **directly** around `BackdropFilter`. Never put a `Container` with `margin` inside the `ClipRRect`—keep `margin` and `boxShadow` on an **outer wrapper `Container` outside the `ClipRRect`**.
  2. **Remove Scaffold Bottom Tint Overlay:**
     - In `home_page.dart` (and `money_shell_page.dart`), ensure `Scaffold` has `extendBody: true`.
     - Wrap the `bottomNavigationBar` root in `Material(color: Colors.transparent, elevation: 0, surfaceTintColor: Colors.transparent)` so Flutter's `Scaffold` never paints a translucent grey/black bar across the bottom of the screen.
     - Remove any duplicate bottom gradient scrims or secondary overlays behind the nav bar.

### 1.2 True 3D Tactile Capsule Construction (`lib/widgets/bottom_nav_bar.dart`)
Build the navigation bar using this exact 4-layer physical hierarchy:

```dart
// LAYER 1: Outer Transparent Shell (Holds 3D Drop Shadows Outside ClipRRect)
SafeArea(
  top: false,
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          // Deep 3D floating elevation shadow
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.65 : 0.18),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          // Tight physical contact shadow
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.40 : 0.10),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // LAYER 2: Strict ClipRRect + Frosted BackdropFilter
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28.0, sigmaY: 28.0),
          // LAYER 3: 3D Bevel Body (Top Specular Rim + Vertical Depth Gradient)
          child: CustomPaint(
            foregroundPainter: _Nav3DBevelRimPainter(isDark: isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xD92C313A), // Lighter top lip catches light
                          const Color(0xEB16191E), // Deeper bottom base for 3D mass
                        ]
                      : [
                          Colors.white.withOpacity(0.88),
                          const Color(0xE6E8ECF2),
                        ],
                ),
              ),
              child: /* LAYER 4: Spring-Animated 3D Active Tab Capsule + Icons */,
            ),
          ),
        ),
      ),
    ),
  ),
)

```

* **`_Nav3DBevelRimPainter` Spec:**
* Paint a `1.5px` stroke along `RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(38))` using a vertical `LinearGradient`:
* Top edge (`0.0`): `Colors.white.withOpacity(isDark ? 0.38 : 0.90)` (crisp 3D top specular highlight).
* Middle (`0.5`): `Colors.white.withOpacity(0.06)`.
* Bottom edge (`1.0`): `Colors.black.withOpacity(isDark ? 0.65 : 0.15)` (bottom 3D lip shadow).




* **Layer 4 — Raised 3D Active Tab Pill:**
* The sliding active tab pill must look physically extruded:
* `borderRadius: BorderRadius.circular(30)`
* `gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [activeColor.withOpacity(0.95), activeColor.withOpacity(0.75)])`
* `boxShadow`: `[BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 10, offset: Offset(0, 4))]`
* Top inner highlight border (`1px` `Colors.white.withOpacity(0.35)`).





---

## 2. REVAMP THE HEALTH TAB: EXACT DRIBBBLE STRUCTURE + 100% REAL APP DATA

* **Target Files:**
* `lib/features/health/health_page.dart`
* `lib/features/wearables/ui/fitness_tab.dart`


* **Core Principle:**
Preserve the **exact layout, card geometry, proportions, and visual graphics** of the Dribbble `Personal Health` and `Walking steps` design, but replace every fake medical label with **real, live metrics** from the user's app repositories!

### 2.1 Real-Data Mapping to the Dribbble Layout (`health_page.dart`)

| Dribbble Visual Slot | Fake Label to REMOVE | REAL App Metric to Bind | Data Source in Codebase | Visual Graphic Inside Card |
| --- | --- | --- | --- | --- |
| **Top Hero Pill — Left Green Circle** | Hardcoded `4754 Steps` | **Live Daily Steps** (`e.g., 6,420 Steps` or `0 Steps`) | `WearableRepository` (`DailyActivity.steps`) | Solid `#05B87C` circle, walking icon, real tabular step count. Tap opens `WalkingStepsDetailPage`. |
| **Top Hero Pill — Right Day Ruler** | Static `Sat..Wed` text | **Interactive 7-Day Selector** (`Mon`..`Sun`) | `selectedDate` state in `HealthPage` | Horizontal day strip + custom-painted tick-mark ruler. Tapping any day updates all cards below to that date's real data! |
| **Bento Card 1 (Top-Left, Tall `175dp`)** | `Cardiac Rhythm / 95 bpm` | **Sleep & Recovery** (`e.g., 7h 15m` or `Score 84` or `Tap to log`) | `WearableRepository` (`SleepSession`) + `WakeLogRepository` | Soft coral/indigo icon badge + real sleep hours/score + **ECG/Rhythm Waveform** driven by the last 7 days of sleep durations (with emerald peak highlight on best night). |
| **Bento Card 2 (Top-Right, Tall `175dp`)** | `Acid Balance / 14 pH` | **Nutrition & Calorie Target** (`e.g., 1,650 kcal` or `78% Hit`) | `DietRepository` (Today's consumed kcal vs `NutritionProfile.targetCalories`) | Soft coral/orange icon badge + real kcal/percentage + **6x3 Dot Matrix (18 dots)** representing the last 18 meals/days (Emerald dot = target met, Mint = logged/partial, Grey = missed). |
| **Bento Card 3 (Bottom-Left, `115dp`)** | `Brain Activity` | **Body Weight Trend** (`e.g., 68.5 kg`) | `WearableRepository` (`BodyCompSample`) / Hive weight log | Soft rose icon badge + `Body Weight` + real kg value + **Smooth Coral Area Spline** plotted from the user's actual logged weight entries. Tap opens Weight Log sheet. |
| **Bento Card 4 (Bottom-Right, `115dp` Circle)** | Dummy `Exercise` button | **Workouts & Active Mins** (`Exercise` / `e.g., 35 min`) | `WearableRepository` (`ExerciseSession`) | Solid `#111111` circle (Light) / `#1E293B` with `#10B981` rim (Dark) + running icon + `Exercise`. Tapping opens Workout Logger / Health Connect sync. |
| **Bottom Wide Card (`96dp`)** | Static `Activity Thursday` | **Weekly Activity (`[Selected Day Name]`)** | Last 7 days of `DailyActivity.steps` | Left: `Activity` + selected weekday name (`Tuesday`). Right: 7 vertical rounded bars scaled to real daily step counts (selected day highlighted in `#05B87C`). |

### 2.2 Walking Steps Detail Screen (`WalkingStepsDetailPage`) — 100% Real Data

When the user taps the green Steps circle or the bottom Activity card, navigate to `WalkingStepsDetailPage`:

1. **Header Card:** Soft green circle icon + `Walking steps` + `See your Walking Statistics`.
2. **Main Spline Chart Card (`BorderRadius.circular(32)`):**
* **Top-Left Metric (`Total Distance`):** Real distance in `km` calculated from `DailyActivity.distanceMeters / 1000.0` (or `steps * 0.000762` if sensor distance is 0), formatted as `e.g., 4.89 km` (NEVER `142.47 Km/h`).
* **Top-Right Metric (`Total Steps`):** Real formatted step count (`e.g., 6,420`) vs Goal (`8,000`).
* **Interactive Emerald Area Spline Chart:**
* Plots real step progression across the day (or 7-day history if hourly buckets aren't available from Health Connect).
* Peak callout bubble (`e.g., 2,400`) with the coral dot (`#FF6B6B`) and vertical drop-line positioned dynamically at the highest data point!
* Bottom time/day pills (`06:00`, `12:00`, `18:00`, `21:00` or day pills) with the peak slot highlighted in a solid `#05B87C` pill.




3. **Bottom 2-Column Row:**
* **Left Card (`Burnt Calories`):** Real active/burnt calories (`DailyActivity.activeCalories`, e.g., `340 kcal`) + coral wave graphic.
* **Right Card (`Active Pace / Goal Progress`):** Real active minutes or step goal completion % (`e.g., 42 mins` or `80% Goal`) + the 4-row dashed horizontal multi-segment track graphic.



### 2.3 Light Mode & Dark Mode Surface Tokens for Health Tab

* **Light Mode:** Scaffold `#F6F7F9`, Cards `#FFFFFF` with subtle shadow `BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8))`, Primary Text `#111417`, Muted Text `#8A929A`, Emerald `#05B87C`, Coral `#FF6E6E`.
* **Dark Mode:** Scaffold `#0B0E11`, Cards `#15191E` with `1px` border `#222831`, Primary Text `#F3F6F9`, Muted Text `#8B949E`, Emerald `#10B981`, Coral `#FF6B6B`.
* *(If `isMonochromeMode == true`, map Emerald and Coral through `AppColors.resolveAccent(context, ...)` so they render in crisp grayscale).*

---

## 3. HOME PAGE CARDS REVAMP: ULTRA-CLASSY OXYGENOS 15 / COLOROS 15 AESTHETIC

### 3.1 Why Current Cards Look Unrefined & How to Make Them Classy

* **Target Files:**
* `lib/screens/dashboard_view.dart`
* `lib/features/home/cards/home_card_frame.dart`
* `lib/features/home/cards/calories_card.dart`
* `lib/features/home/cards/health_summary_card.dart`
* `lib/features/home/cards/finance_card.dart`
* `lib/features/home/cards/missions_card.dart`


* **Design Rules for "Classy Flagship OS" Cards (Matching the Video Reference):**
1. **Kill Visual Clutter (The 3-Element Rule):**
* No compact 1x1 card on the home grid may contain more than **3 text/visual elements** (1 Icon/Title, 1 Hero Number, 1 Muted Subtitle). Remove mini-buttons, multi-line paragraphs, and clutter from compact home cards.


2. **Refined Matte Surfaces & Hairline Specular Rim (`home_card_frame.dart`):**
* **Corner Radius:** Continuous squircle `BorderRadius.circular(28)` (`padding: EdgeInsets.all(18)`).
* **Matte Graphite Card Surface (Dark):** `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF262A30), Color(0xFF1C1F24)])` with a `0.8px` border `Colors.white.withOpacity(0.09)`.
* **Alabaster Contrast Card Surface (Used for 1 Hero Wide Card in the Cluster):** `#F4F6F9` with `#111417` primary text and `#64748B` muted text, creating the exact high-craft dark/light juxtaposition seen in the OxygenOS video.


3. **Exact Card Designs on the Home Grid:**
* **Card A — 1x1 Circular Gauge Card (Steps or Calories):**
* Matte charcoal square (`aspectRatio: 1.0`).
* Centered 260° open-bottom circular gauge (`strokeWidth: 9.5`, `StrokeCap.round`, background track `Colors.white.withOpacity(0.08)`, active arc `#22C55E` in color mode / `#FFFFFF` in monochrome).
* Small `18dp` icon (`Icons.directions_walk_rounded` or `Icons.local_fire_department_rounded`) positioned at the top-center inside the ring.
* Hero number (`e.g., 993`, `34sp`, `FontWeight.w700`, `letterSpacing: -1.0`, `color: Colors.white`) dead-center.
* Sub-metric (`e.g., 702 m` or `kcal left`, `12sp`, `color: Color(0xFF94A3B8)`) nestled cleanly in the bottom gap of the arc.


* **Card B — 1x1 Smart Cluster Folder (`AI Suggest / Daily Hub`):**
* Matte charcoal square (`aspectRatio: 1.0`) containing a 2x2 grid of 4 rounded-circle/squircle mini-tiles (`Tasks`, `Diet`, `Money`, `Academic`).
* Tapping smoothly morphs and expands into the **Frosted 3-Tier Cluster Overlay** (matching the video):
1. **Top Wide Card (`AI Daily` — Deep Slate `#1A2232`):** Header row (`AI Daily` pill on left + `Updated [time]` on right), bold 2-line primary insight from `AiContext`, and 2 clean hairline-separated live status rows below (e.g., today's pending task + remaining daily budget).
2. **Middle Wide Card (`Steps / Daily Goal` — Crisp Contrast Card `#F4F6F9`):** Top linear progress bar (`8dp` height, `#22C55E` fill) with the walking figure icon riding above the fill position + right-aligned `X steps to your goal (Y)`. Huge bottom-left metric (`993 steps`, `32sp`, `#111417`) and bottom metadata row (`Distance 702 m` left, `Highest X steps` right).
3. **Bottom Two 1x1 Square Cards Side-by-Side (`12dp` gap):**
* **Bottom-Left (`Tasks / Habits Quota` — Matte Dark `#1E2126`):** Top-left title `Today's Focus`, 3-segment thin color-coded progress bar (Completed / Habit / Pending), `X / Y done` label, and a bottom translucent pill button (`✓ Complete Next`).
* **Bottom-Right (`Quick Sync / Focus` — Matte Dark `#1E2126`):** Top-left title + subtitle, and a bottom-right `44dp` circular accent button surrounded by 3 subtle concentric radar rings (`CustomPainter`).


---

## 4. VERIFICATION CHECKLIST

* [ ] **Health Tab:** Zero fake metrics (`95 bpm`, `14 pH`, `Brain Activity`, `142.47 Km/h` are completely gone). The Dribbble layout structure is 100% preserved and bound to real `Steps`, `Sleep`, `Calories/Nutrition`, `Weight`, and `Exercise` data in both Light and Dark mode.
* [ ] **Navigation Bar:** No rectangular blur or grey tint overlay behind the pill. The bar floats cleanly over scrolling content with a true 3D specular top rim, deep elevation shadow, frosted blur core, and raised 3D active tab capsule.
* [ ] **Home Screen Cards:** Clean, minimalist matte charcoal squircle cards with 1 hero metric per card and smooth spring expansion into the 3-tier OxygenOS cluster.
* [ ] `flutter analyze` passes with 0 errors.