# DESIGN_SYSTEM.md — Material 3 Expressive & Fluid Motion System

## 1. Anti-"AI Slop" Manifesto (Strictly Enforced)
To ensure the application feels like a flagship native OS experience (Samsung One UI 7 / OxygenOS 15 / Google Pixel Material 3 Expressive), the following patterns are **BANNED** across the entire codebase:

1. **NO Glassmorphism:** Do not use `BackdropFilter`, `ImageFilter.blur`, or semi-transparent card backgrounds (`Colors.white.withOpacity(0.04)`).
2. **NO "AI Borders":** Do not use multi-color gradient borders (`LinearGradient` or `SweepGradient` strokes in purple/cyan/magenta) on any card, input field, or button.
3. **NO Sparkle Spam:** Remove decorative `✨` emojis and `Icons.auto_awesome` from navigation bars, section headers, and buttons. Reserve a single clean geometric icon for the unified assistant.
4. **NO Invisible/Ghost Buttons:** Never use low-opacity text buttons or dark-on-dark outlines for primary or secondary actions. Every interactive control must have an unmistakable tonal fill and high-contrast label.
5. **NO Starfield/Particle Backgrounds:** Disable and remove `StarBackground` (`lib/widgets/star_background.dart`) from all screens.

---

## 2. Material 3 Expressive Color & Surface Hierarchy
Update `lib/core/theme/app_colors.dart` and `lib/core/theme/app_theme.dart` to use solid, high-contrast tonal surfaces:

### Dark Theme (Default Flagship Palette)
- `surface`: `#0E1113` (Deep carbon-slate base canvas)
- `surfaceContainerLowest`: `#090B0D`
- `surfaceContainerLow`: `#161A1D` (Secondary grouping container)
- `surfaceContainer`: `#1C2126` (Standard card fill — replaces glass cards)
- `surfaceContainerHigh`: `#252B31` (Elevated interactive cards, dialogs, bottom sheets)
- `surfaceContainerHighest`: `#30373F` (Input fields, unselected pills, chip backgrounds)
- `onSurface`: `#F2F5F8` (Primary text — crisp, 100% opaque)
- `onSurfaceVariant`: `#A6B0BB` (Secondary labels & subtitles — minimum 7:1 / 4.5:1 contrast)
- `outline`: `#444D56` (Visible control borders)
- `outlineVariant`: `#2A3138` (Subtle structural dividers, 1px solid)

### Expressive Accent Tokens
- `primary`: `#67E8F9` -> Tonal M3 Teal/Cyan `#4FD8EB` (`onPrimary`: `#00363D`, `primaryContainer`: `#004F58`, `onPrimaryContainer`: `#97F0FF`)
- `secondary`: `#B4C8DF` (`onSecondary`: `#1F3244`, `secondaryContainer`: `#35485B`, `onSecondaryContainer`: `#D0E4FB`)
- `tertiary` (Warm Energy / Habits): `#FFB784` (`onTertiary`: `#4F2500`, `tertiaryContainer`: `#6F3800`, `onTertiaryContainer`: `#FFDCC5`)
- `error`: `#FFB4AB` (`onError`: `#690005`, `errorContainer`: `#93000A`, `onErrorContainer`: `#FFDAD6`)

---

## 3. Expressive Shape Morphing & Geometry
Material 3 Expressive uses tension between generous curves and crisp squircles to communicate state changes without relying on color alone:

- **Resting Card Radius:** `24.0` (`BorderRadius.circular(24)`)
- **Grouped List Item Radius:**
  - Top item in group: `BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(6))`
  - Middle item in group: `BorderRadius.circular(6)`
  - Bottom item in group: `BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(24))`
- **Interactive Shape Morphing (`TactileButton`, `TaskActionPill`, Filter Chips):**
  - **Unselected / Resting State:** Stadium/Pill (`BorderRadius.circular(28)`)
  - **Pressed / Selected State:** Morphs smoothly over `220ms` to a squircle (`BorderRadius.circular(12)`)

---

## 4. OxygenOS / One UI Physics & Motion System
Update `lib/core/motion/motion_tokens.dart`, `lib/core/motion/press_scale.dart`, and `lib/core/motion/spring_sheet.dart`:

1. **Micro-Interaction Spring (Buttons, Checkboxes, Toggles):**
   - `SpringDescription(mass: 1.0, stiffness: 420.0, damping: 28.0)`
   - Scale down to `0.96` on pointer down (`TapDownDetails`), release with spring velocity on pointer up/cancel.
   - Trigger `HapticFeedback.lightImpact()` on state toggle.
2. **Spatial / Layout Spring (Bottom Sheets, Card Expansion, Tab Indicators):**
   - `SpringDescription(mass: 1.0, stiffness: 300.0, damping: 26.0)`
   - No linear curves (`Curves.linear` is banned). For non-simulation tweens, use `Cubic(0.2, 0.0, 0.0, 1.0)` (M3 Emphasized Decelerate).
3. **Staggered List Choreography:**
   - When switching tabs or dates, list items animate in with a subtle vertical slide (`Offset(0, 0.06)` $\rightarrow$ `Offset.zero`) + fade (`240ms`), staggered by `25ms` per item (capped at the first 6 visible items so long lists never lag).

---

## 5. Typography & Button Visibility Standards
- **Display / Hero Metrics:** `36sp`, `FontWeight.w800`, `letterSpacing: -0.8`, tabular figures (`FontFeature.tabularFigures()`).
- **Section Headers:** `20sp`, `FontWeight.w700`, `letterSpacing: -0.3`.
- **Card Titles:** `16sp`, `FontWeight.w600`.
- **Button Rules (Mandatory):**
  - **Primary CTA:** `FilledButton` with `backgroundColor: colorScheme.primary`, `foregroundColor: colorScheme.onPrimary`, minimum height `52dp`, `FontWeight.w700`.
  - **Secondary CTA:** `FilledButton.tonal` with `backgroundColor: colorScheme.secondaryContainer`, `foregroundColor: colorScheme.onSecondaryContainer`, minimum height `48dp`.
  - **Icon Buttons:** Always wrapped in a tonal container (`surfaceContainerHighest`) so they never disappear against the page background.