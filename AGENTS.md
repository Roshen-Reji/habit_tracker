# AGENT.md — Global Motion, Physics & Animation Overhaul Specification

## 0. Core Animation Philosophy
Every interaction in `habit_tracker` must feel **physical, interruptible, andchoreographed at 120fps**.
1. **Zero Linear Motion**: Ban `Curves.linear` and sluggish `Curves.easeInOut` for UI movement. All spatial movement, scaling, and morphing must use **Spring Physics** (`SpringSimulation` / `SpringDescription`) or high-velocity custom cubic curves.
2. **Interruptibility**: Never lock user input during an animation. If a user taps or swipes mid-transition, animations must retarget dynamically from their current velocity and position.
3. **Global Unification**: Promote the isolated motion utilities in `lib/features/money/ui/motion/` (`motion_tokens.dart`, `motion_scope.dart`, `press_scale.dart`, `animated_money_text.dart`, `frame_timing_logger.dart`) into `lib/core/motion/` and merge them with `lib/core/theme/app_animations.dart` and `lib/core/theme/expressive_tokens.dart` so the entire app shares one unified motion engine.

---

## 1. Global Physics & Token Standards (`lib/core/motion/`)

Define and enforce these exact physics profiles across the entire codebase:

- **Snappy Micro-Spring (Buttons, Toggles, Checkboxes, Pills)**:
  - `SpringDescription(mass: 1.0, stiffness: 520.0, damping: 28.0)`
  - Instantaneous response with a crisp, subtle settle.
- **Fluid Spatial Spring (Bottom Nav Indicator, Sheet Expansion, Card Morphing)**:
  - `SpringDescription(mass: 1.0, stiffness: 360.0, damping: 26.0)`
  - Slight elastic overshoot (`~3%`) that gives hardware weight to moving containers.
- **Heavy Architectural Spring (Page Transitions, Modal Sheets, Wallet Stack Fling)**:
  - `SpringDescription(mass: 1.1, stiffness: 280.0, damping: 28.0)`
  - Critically damped—smooth deceleration with zero distracting bounce.
- **Curve Fallback Tokens (For Opacity & Color Interpolation Only)**:
  - `emphasizedDecelerate`: `Cubic(0.05, 0.7, 0.1, 1.0)`
  - `emphasizedAccelerate`: `Cubic(0.3, 0.0, 0.8, 0.15)`
  - `fastOutExtraSlowIn`: `Cubic(0.16, 1.0, 0.3, 1.0)`

---

## 2. Navigation Bar & Mini-Player Choreography

Refactor `lib/widgets/bottom_nav_bar.dart`, `lib/core/widgets/glass_tab_bar.dart`, and `lib/widgets/mini_player_bar.dart` into a single **Elastic Floating Dock**:

### 2.1 Liquid Sliding Active Pill
- Do NOT use `AnimatedContainer` with basic alignment jumps for the active tab indicator.
- Track the continuous horizontal index position using an `AnimationController.unbounded` driven by the **Fluid Spatial Spring**.
- **Velocity Stretch (Squash & Stretch)**: As the pill travels from Tab $A$ to Tab $B$, calculate the instantaneous velocity of the spring. Stretch the pill's width proportionally to velocity (`width = baseWidth + (velocity.abs() * stretchFactor)`) so the indicator visually "reaches" toward the new tab before snapping into place.

### 2.2 Icon & Label Micro-Choreography
- **Active Icon**: On selection, drive a spring impulse that translates the icon `-3.5px` upward, scales it to `1.12x`, and morphs the icon from outlined to filled weight, paired with `HapticFeedback.selectionClick()`.
- **Label Reveal**: Use `AnimatedSize` (curve: `fastOutExtraSlowIn`, duration: `220ms`) combined with a horizontal slide + fade so active tab labels expand smoothly without causing layout jitter in adjacent icons.

### 2.3 Mini-Player To Expanded Sheet Morph (`mini_player_bar.dart` -> `expanded_player_sheet.dart`)
- Replace the abrupt bottom-sheet pop with a continuous **Shared Container / Hero Morph**:
  - The album art thumbnail in `MiniPlayerBar` smoothly scales and translates into the large artwork frame in `ExpandedPlayerSheet`.
  - Transport controls (`Play/Pause`, `Skip`) cross-fade andagger-slide into their expanded positions.
  - Upgrade `lib/widgets/wobbly_slider.dart` so dragging the seek bar applies elastic wave tension to the track line based on vertical and horizontal finger delta, snapping back with a spring simulation on release.

---

## 3. Home Page & Scrollable Cards Choreography (`lib/features/home/`)

### 3.1 Staggered Cascade Entrance & Scroll Physics
- In `lib/screens/home_page.dart` and `lib/screens/dashboard_view.dart`, implement a **Staggered Entrance Cascade** for the Bento grid cards:
  - Each card enters with a `16px` upward translation + `0.96 -> 1.0` scale + opacity fade using `Cubic(0.16, 1.0, 0.3, 1.0)`.
  - Cap stagger delay at `25ms` per card (max total stagger `200ms`) so the screen feels alive but never blocks immediate interaction.
- **Scroll-Velocity Tilt & Parallax**:
  - Attach a `ScrollNotification` listener to the main scroll view.
  - Pass normalized scroll velocity into `lib/features/home/cards/home_card_frame.dart` and `lib/core/widgets/depth_card.dart` to apply a subtle `Matrix4` perspective pitch (`±1.5 degrees` max) and specular border highlight shift as cards scroll past the viewport center.

### 3.2 Card-to-Feature Container Transforms (`lib/core/utils/page_transitions.dart`)
- Tapping any Home Card (`finance_card.dart`, `health_summary_card.dart`, `missions_card.dart`, `reader_card.dart`, `journal_card.dart`, `brainstorm_card.dart`) must trigger a **Container Transform Transition**:
  - The tapped card's bounding box, background color, and border radius (`16px -> 0px`) smoothly expand to fill the screen while cross-fading the card summary into the full feature page (`TasksPage`, `HealthPage`, `DietPage`, `MoneyShell`, `ReaderLibraryPage`, `JournalListPage`, `BrainstormPage`).
  - Swiping back (Predictive Back / iOS interactive pop gesture) must shrink the screen back into the exact card slot on the Home grid.

### 3.3 Interactive Card Micro-Animations
- **`wallet_card_stack.dart`**: Implement 3D perspective card fanning (`Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(...)`). Dragging the top card down or up applies rubber-band resistance; releasing past the threshold flings the card to the back of the stack with a spring snap and haptic thud.
- **`home_card_size_sheet.dart`**: Changing a card between Compact, Medium, and Expanded must smoothly morph the card's height and internal layout in-place using `AnimatedSize` + `AnimatedSwitcher` with `LayoutBuilder` constraints—never an instant layout jump.
- **`missions_card.dart` & `task_card.dart`**: Checking off a task must:
  1. Compress the checkbox to `0.85x` on tap-down, then spring-pop to `1.15x -> 1.0x` on release.
  2. Draw a custom animated strikethrough line across the text (`0% -> 100%` width over `240ms`).
  3. Spawn a floating `+XP` badge that drifts upward (`-24px`) and fades out while `ScoreCard` increments.

---

## 4. Universal Rolling Number Tickers & Chart Choreography

### 4.1 Global Odometer / Metric Ticker
- Generalize `lib/features/money/ui/motion/animated_money_text.dart` into a global **`AnimatedMetricTicker`** widget.
- Apply it to **every numeric readout** in the app:
  - Home `ScoreCard` & `ScoreDeltaCard`
  - `SafeToSpendCard`, `NetWorthCard`, `FinanceCard`, and all `MoneyShell` balances
  - `CaloriesCard`, `WeightCard`, `HealthSummaryCard`, and `GalaxyWatchCard` step/sleep counters
  - Global XP counters and Rank progress bars
- Numbers must roll vertically per-digit (odometer style) with `FontFeature.tabularFigures()` so layout width never jitters during value updates.

### 4.2 Custom Painter & Chart Animations
- **`mysterious_momentum_graph.dart` & Finance Charts (`cash_flow_chart.dart`, `category_donut_chart.dart`, `net_trend_chart.dart`, `net_worth_history_chart.dart`)**:
  - Animate line charts on mount using `PathMetrics` (`extractPath(0, length * progress)`) coupled with a gradient shader fill that fades in beneath the curve.
  - Animate `category_donut_chart.dart` segments with staggered angular sweep animations and spring-scaled active segment pop-out on touch.
  - Add interactive touch-scrubbing to all line/bar charts: dragging a finger across the chart smoothly interpolates a vertical cursor line, snaps to data points with `HapticFeedback.selectionClick()`, and updates the header metric via `AnimatedMetricTicker`.
- **`progress_bar_x.dart` & `money_progress_bar.dart`**:
  - Drive all progress bar width changes with the **Fluid Spatial Spring** and add a subtle animated specular shimmer across the active fill bar when a goal or budget threshold reaches 100%.

---

## 5. Tactile Press & Sheet Physics

### 5.1 Universal `PressScale` Wrapper
- Upgrade `lib/features/money/ui/motion/press_scale.dart` and apply it to **all buttons, cards, chips, and list tiles**:
  - `onTapDown`: Immediately start a spring compression toward `scale: 0.96` (for cards) or `0.94` (for buttons) and darken the surface overlay by `4%`.
  - `onTapUp` / `onTapCancel`: Release the spring with initial velocity so even a rapid tap-and-release completes a visible, satisfying dip-and-rebound pulse.

### 5.2 Spring-Driven Bottom Sheets & Dialogs
- Replace standard `showModalBottomSheet` and `showDialog` calls (`add_task_dialog.dart`, `transaction_sheet.dart`, `quick_add_sheet.dart`, `wakeup_detail_sheet.dart`, `ages_log_sheet.dart`) with a unified **`showSpringSheet`** and **`showSpringDialog`** helper:
  - Sheets enter with a critically damped spring slide + subtle background scale-down (`HomePage` scales to `0.96x` with rounded top corners when a full sheet opens, creating depth).
  - Dialogs enter from `scale: 0.92 -> 1.0` using the **Snappy Micro-Spring** paired with a `150ms` backdrop fade.

---

## 6. 120fps Performance & Frame-Timing Guardrails

1. **Zero Blur Inside ScrollViews**: Remove `BackdropFilter` from all cards inside `DashboardView` and feature lists. Only the floating bottom dock and modal overlays may use real-time blur.
2. **Mandatory `RepaintBoundary` Isolation**: Wrap `star_background.dart`, `mysterious_momentum_graph.dart`, `wobbly_slider.dart`, every chart in `lib/features/finance/ui/widgets/charts/`, and each `HomeCard` in a `RepaintBoundary` so animations in one widget never trigger repaints across the parent screen.
3. **Offscreen Ticker Pausing**: Wrap tab views in `TickerMode(enabled: isCurrentTab)` and pause `star_background.dart` when a secondary route is pushed or when scroll velocity exceeds threshold.
4. **Verification**: Use `lib/features/money/ui/motion/frame_timing_logger.dart` in profile/debug runs and run `flutter analyze` + `flutter test` to ensure zero broken imports or ticker leaks (`SingleTickerProviderStateMixin` / `TickerProviderStateMixin` must always dispose controllers cleanly).