# AGENTS.md — Antigravity Execution Specification (UX & Architecture Overhaul)

## Role & Objective
You are the Lead Flutter Systems & UX Engineer executing a high-priority stabilization and UX overhaul on `habit_tracker`. Your mission is to eliminate UI jank, enforce a Native Black & White default theme with selectable color schemes, fix the broken Settings navigation and screen, implement smart per-item text-cutoff detection in the bottom navigation bar, and strip out dynamic backgrounds.

## Global Engineering Guardrails
1. **Zero Regressions in Domain Logic:** Do NOT alter business math in `lib/features/finance/engine/`, `lib/features/money/core/`, `lib/core/progression/`, or `lib/features/wearables/engine/`.
2. **Strict Null & Hive Safety:** Never call `Hive.box(...)` synchronously in a widget `build()` method without verifying `Hive.isBoxOpen(...)` or providing a safe fallback default.
3. **60/120fps Frame Budget:** Avoid `BackdropFilter` inside scrolling lists (`dashboard_view.dart`). Do not animate `BoxShadow` blur radius or layout constraints (`padding`/`margin`) on every frame; use `Transform.scale` and `FadeTransition` instead.
4. **Test-Driven Verification:** Every task below must pass `flutter analyze` and `flutter test` before completion.

---

## Task 1: Native Black & White Theme + Selectable Color Schemes

### Target Files
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/bento_theme.dart`
- `lib/core/theme/tactile_tokens.dart`
- `lib/core/theme/expressive_tokens.dart`
- `lib/app.dart`
- `lib/screens/settings_page.dart`

### Implementation Steps
1. **Define `AppColorSchemePreset` Enum & Palettes (`lib/core/theme/app_colors.dart`):**
   - Create an enum `AppColorSchemePreset` with IDs:
     - `monochrome` (**Default** — Native Black & White)
     - `obsidianEmerald` (Emerald `#10B981` accent)
     - `cobaltPulse` (Cobalt `#3B82F6` accent)
     - `solarAmber` (Amber `#F59E0B` accent)
     - `crimsonEditorial` (Crimson `#F43F5E` accent)
     - `violetNebula` (Violet `#8B5CF6` accent)
   - For `AppColorSchemePreset.monochrome`:
     - **Dark Mode:** `background: #000000`, `surface: #0A0A0A`, `surfaceElevated: #141414`, `border: #262626`, `primary: #FFFFFF`, `onPrimary: #000000`, `secondary: #A1A1AA`, `textPrimary: #FFFFFF`, `textSecondary: #8E8E93`.
     - **Light Mode:** `background: #FFFFFF`, `surface: #F4F4F5`, `surfaceElevated: #FFFFFF`, `border: #E4E4E7`, `primary: #000000`, `onPrimary: #FFFFFF`, `secondary: #52525B`, `textPrimary: #000000`, `textSecondary: #71717A`.
   - For non-monochrome presets, keep the high-contrast neutral backgrounds (`#000000` / `#0A0A0A` in dark, `#FFFFFF` / `#F4F4F5` in light) and apply the preset's primary/secondary accent colors to interactive highlights, progress bars, charts, active badges, and selection pills.

2. **Persist & Broadcast Theme Selection (`lib/core/theme/app_theme.dart` & `lib/app.dart`):**
   - Store `'color_scheme_preset'` in the settings Hive box (defaulting to `'monochrome'`).
   - Expose a `ValueNotifier<AppColorSchemePreset>` or `ChangeNotifier` theme controller initialized at startup in `main.dart` / `app.dart`.
   - Update `BentoTheme`, `TactileTokens`, and `ExpressiveTokens` so they dynamically resolve tokens from the active `ThemeData` / `ColorScheme` rather than hardcoded neon/glass colors.

---

## Task 2: Remove Dynamic Background Everywhere

### Target Files
- `lib/widgets/star_background.dart`
- `lib/screens/home_page.dart`
- `lib/screens/dashboard_view.dart`
- `lib/screens/settings_page.dart`
- `lib/app.dart`

### Implementation Steps
1. **Unmount `StarBackground`:**
   - Remove `StarBackground` (and any animated particle, nebula, or dynamic gradient background wrappers) from `lib/screens/home_page.dart`, `lib/screens/dashboard_view.dart`, and `lib/app.dart`.
   - Replace the scaffold background with `Theme.of(context).scaffoldBackgroundColor` (which resolves to `#000000` in Dark Monochrome or `#FFFFFF` in Light Monochrome).
2. **Deprecate `star_background.dart`:**
   - Replace `StarBackground` implementation in `lib/widgets/star_background.dart` with a lightweight, no-op `SizedBox.expand(child: child)` passthrough (or remove all references to it) so no `Ticker` or `CustomPainter` runs in the background.
3. **Remove Settings Toggle:**
   - Remove any "Dynamic Background", "Star Background", or "Ambient Background" toggle switches from `lib/screens/settings_page.dart` and related settings state keys.

---

## Task 3: Fix Broken Settings Tab & Overhaul `SettingsPage`

### Target Files
- `lib/core/navigation/app_nav.dart`
- `lib/screens/home_page.dart`
- `lib/widgets/bottom_nav_bar.dart`
- `lib/screens/settings_page.dart`
- `test/navigation/app_nav_test.dart`

### Root Cause Diagnosis & Fix
1. **Audit Navigation Wiring (`app_nav.dart`, `home_page.dart`, `bottom_nav_bar.dart`):**
   - Verify that every tab destination in `AppNav` / `BottomNavBar` maps 1:1 to a valid widget in `HomePage`'s body switcher (`IndexedStack` or active view builder).
   - Ensure that tapping the Settings tab in `BottomNavBar` OR tapping any Settings action button in the header/app bar updates the active navigation index or pushes `SettingsPage` cleanly without throwing a `RangeError` or being swallowed by an overlay (`mini_player_bar.dart`).
2. **Eliminate Crash Vectors in `SettingsPage` (`lib/screens/settings_page.dart`):**
   - Audit `initState()` and `build()` in `SettingsPage`.
   - Guard all Hive box reads (e.g., settings box, user box, wearables settings) with safe fallback values if a box is not yet open or a key returns `null` or a mismatched type.
3. **Rebuild `SettingsPage` UI:**
   - Structure `SettingsPage` with clean monochrome Bento grouping:
     - **Appearance Section:** Theme Mode (`System`, `Dark`, `Light`) + **Color Scheme Selector** (interactive horizontal list or grid of swatches showing `Monochrome B&W` selected by default alongside the other presets, updating the app theme immediately on tap).
     - **Dashboard & Layout Section:** Navigation tile to `HomeLayoutSettingsPage`.
     - **Modules & Sync Section:** Wearables Settings, Reminders Settings, AI Privacy.
     - **Data Management Section:** Finance Privacy & Backup, Reset/Clear cache with confirmation dialogs.

---

## Task 4: Fix Overflowing Navigation Bar (Smart Per-Item Icon-Only Fallback)

### Target Files
- `lib/widgets/bottom_nav_bar.dart`
- `lib/core/widgets/glass_tab_bar.dart`
- `test/widgets/bottom_nav_bar_test.dart`

### Implementation Steps
1. **Fix Container & Flex Overflow:**
   - In `bottom_nav_bar.dart` (and `glass_tab_bar.dart` if used), ensure the outer `Row` wraps each navigation item in `Expanded` so total width never exceeds viewport width.
   - Remove rigid horizontal padding or fixed widths that cause `RenderFlex overflowed by X pixels on the right`.
2. **Implement Per-Item Text Cutoff Detection:**
   - Inside each navigation bar item widget, use `LayoutBuilder` to obtain `constraints.maxWidth`.
   - Calculate the available horizontal width for the text label:
     `final availableTextWidth = constraints.maxWidth - horizontalItemPadding;`
   - Measure the exact rendered width of the label string using `TextPainter`:
     ```dart
     final textPainter = TextPainter(
       text: TextSpan(text: label, style: effectiveLabelStyle),
       maxLines: 1,
       textDirection: Directionality.of(context),
       textScaler: MediaQuery.textScalerOf(context),
     )..layout(minWidth: 0, maxWidth: double.infinity);

     final boolutsOff = textPainter.width > availableTextWidth;
     ```
   - **Conditional Rendering Rule:**
     - If `cutsOff == true` (the word would truncate, wrap, or overflow its slot): render **ONLY the `Icon`** (centered nicely with a `Tooltip(message: label)`), hiding the `Text` widget for that item.
     - If `cutsOff == false` (the word fits cleanly on a single line): render **both `Icon` and `Text(label, maxLines: 1, softWrap: false)`**.
3. **Update Widget Tests:**
   - Update `test/widgets/bottom_nav_bar_test.dart` to test both standard width (labels visible where they fit) and narrow/constrained width (items with long labels automatically switch to icon-only with zero `RenderFlex` overflow errors).

---

## Task 5: Fix Glitchy Home Page Card Animations

### Target Files
- `lib/screens/dashboard_view.dart`
- `lib/features/home/cards/home_card.dart`
- `lib/features/home/cards/home_card_frame.dart`
- `lib/features/home/widgets/wallet_card_stack.dart`
- `lib/core/widgets/depth_card.dart`
- `lib/core/motion/press_scale.dart`
- `lib/core/motion/motion_tokens.dart`
- `lib/core/theme/app_animations.dart`

### Root Cause Diagnosis & Fix
1. **Eliminate Competing Animation Wrappers:**
   - Inspect `HomeCard`, `HomeCardFrame`, `DepthCard`, and `PressScale`. Currently, cards suffer from nested scale/elevation/container animations fighting each other on tap and rebuild.
   - Standardize on **one** press interaction wrapper (`PressScale` using `AnimationController` + `Transform.scale` to `0.97` over `120ms` `Curves.easeOutCubic`).
   - Replace `AnimatedContainer` inside `HomeCardFrame` / `DepthCard` with a static `Container` or `DecoratedBox` for layout properties, using `TweenAnimationBuilder` or `AnimatedTheme` only when the theme changes.
2. **Decouple Entrance Animations from Data Rebuilds (`dashboard_view.dart`):**
   - Ensure staggered entrance animations run **only once** when `DashboardView` first mounts (track `_hasAnimatedEntrance = true` in `State`), NOT every time a `ValueListenableBuilder` or Hive box emits a new value.
   - Assign a stable `ValueKey('home_card_${card.id}')` to every card in the grid/list so Flutter's Element tree updates cards in-place without unmounting and remounting their `State`.
3. **Stabilize `WalletCardStack` & Complex Cards:**
   - In `lib/features/home/widgets/wallet_card_stack.dart`, ensure card swap/expand transitions use a single `AnimationController` with `Curves.easeOutQuart` (`280ms`), clamp drag deltas to prevent negative/NaN matrix transforms, and keep `test/widgets/wallet_card_stack_test.dart` passing.
   - Wrap each card in `dashboard_view.dart` with a `RepaintBoundary` to isolate repaints from `animated_metric_ticker.dart` and `momentum_sparkline.dart`.

---

## Task 6: Holistic UX Polish

### Target Files
- `lib/core/theme/app_tokens.dart`
- `lib/features/home/cards/*.dart`
- `lib/widgets/mini_player_bar.dart`

### Implementation Steps
1. **Consistent Card Geometry & Borders:**
   - Standardize card border radius to `20.0` (`AppTokens.radiusLg`), internal card padding to `16.0`, and grid spacing to `12.0`.
   - Use crisp `1.0px` borders (`Theme.of(context).dividerColor` / `#262626` in dark mode, `#E4E4E7` in light mode) instead of heavy multi-layered drop shadows.
2. **Typography & Hierarchy:**
   - Ensure primary metrics use tabular figures (`FontFeature.tabularFigures()`) so animated numbers in `animated_metric_ticker.dart` never jitter horizontally while counting.
3. **Safe Area & Bottom Clearance:**
   - Ensure `dashboard_view.dart` and all primary scroll views include bottom padding that accounts for `BottomNavBar` + `MiniPlayerBar` height so the last row of cards is never obscured.

---

## Verification & Acceptance Checklist
Run the following commands and resolve all issues before concluding:
1. `flutter analyze` — Must report **0 errors and 0 warnings**.
2. `flutter test` — All unit and widget tests (`test/navigation/app_nav_test.dart`, `test/widgets/bottom_nav_bar_test.dart`, `test/widgets/wallet_card_stack_test.dart`, `test/cards/home_card_registry_test.dart`, and finance/service suites) must pass.
3. **Manual Sanity Checks:**
   - App boots into native Black & White theme by default.
   - Tapping Settings opens `SettingsPage` immediately without errors.
   - Selecting a different Color Scheme in Settings updates accents across the app and persists across restarts.
   - `StarBackground` / dynamic background is completely gone.
   - Bottom navigation bar never overflows; tabs whose labels would cut off show only their icon, while tabs that fit show icon + label.
   - Home page cards scroll, tap, and update metrics at 60/120fps without layout jumps or animation glitches.