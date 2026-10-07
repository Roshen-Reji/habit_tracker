# Design System Specification

## 1. Core Principles
1. **Calm & Borderless**: Surfaces and cards have no borders. Depth and separation are achieved exclusively through layered surfaces, soft two-layer shadows (`AppElevation`), and a faint top-light overlay, never through strokes.
2. **Performance First (No Blur on Lists)**: Avoid `BackdropFilter` or `ImageFilter` across scrollable lists and repeated items. The single allowed blur is the floating navigation bar. All cards use `RepaintBoundary`.
3. **Color Discipline & Neutral Accent**: One neutral accent (`BentoTheme.accent` = textPrimary). Semantic indicators are muted and peaceful (`#6BB58A` positive, `#E07A7A` negative, `#D9AE6B` warning). Neon and flashy colors are eliminated. Media accent (`BentoTheme.mediaAccent`) is strictly scoped to music playback surfaces.
4. **Typographic Hierarchy**: High-contrast, tabular numbers for all monetary figures (`FontFeature.tabularFigures()`). Large hero numerals (44/48 700) with generous breathing room.

---

## 2. Tokens Reference

### Color Tokens

| Token | Dark Mode | Light Mode | Description |
|---|---|---|---|
| `background` | `#0A0A0B` | `#F3F3F6` | Deep base canvas |
| `surface` | `#151517` | `#FFFFFF` | Standard card and container background |
| `surfaceRaised` | `#1B1B1E` | `#FFFFFF` | Elevated components, top gradient layer |
| `surfaceSunken` | `#101011` | `#ECECF0` | Text input fields and recessed zones |
| `textPrimary` | `#FFFFFF` (100%) | `#16161A` (100%) | Headings, primary metrics |
| `textSecondary`| `rgba(255,255,255,0.64)` | `rgba(22,22,26,0.62)` | Subtitles, labels, descriptions |
| `textMuted` | `rgba(255,255,255,0.40)` | `rgba(22,22,26,0.40)` | Disabled items, hints |
| `positive` | `#6BB58A` | `#2F8F5B` | Muted green for inflow & surplus |
| `negative` | `#E07A7A` | `#C0504D` | Muted red/coral for expense & deficit |
| `warning` | `#D9AE6B` | `#B8873A` | Muted amber for upcoming dues & alerts |
| `accent` | Neutral (White / `#16161A`)| Neutral | Universal interface accent |
| `mediaAccent` | Dynamic dominant album art | Dynamic | Scoped to music player & mini player |
| `divider` | `rgba(255,255,255,0.06)` | `rgba(22,22,26,0.06)` | Hairline dividers |

### Radii
- `card`: 20.0px (`BorderRadius.circular(20)`)
- `hero`: 28.0px (`BorderRadius.circular(28)`)
- `innerChip`: 14.0px (`BorderRadius.circular(14)`)
- `pill`: 999.0px (`BorderRadius.circular(999)`)

### Spacing Grid (4px Base)
- `xs`: 4.0px
- `sm`: 8.0px
- `md`: 12.0px
- `lg`: 16.0px
- `xl`: 20.0px
- `xxl`: 24.0px
- `huge`: 32.0px

### Typography Scale
- **Hero Number**: 44px, height 48px, weight 700 (`tabularFigures`)
- **Headline / Section Title**: 20px, weight 600
- **Body**: 15px, weight 400
- **Overline / Category Label**: 11px, weight 700, letterSpacing 1.1 (all-caps)

---

## 3. Elevation Levels (`AppElevation`)

Depth is rendered using dual-layer soft ambient shadows with spread reduction:

1. **e1 (List rows & nested items)**:
   - Dark: `0 1 2` black at 35% opacity
   - Light: `0 1 2` black at 6% opacity
2. **e2 (Standard Cards & Bento Containers)**:
   - Dark: `0 1 2` black at 40% + `0 8 24` spread -6 at 55%
   - Light: `0 1 2` black at 6% + `0 10 28` spread -8 at 14%
3. **e3 (Hero & Focused Cards)**:
   - Dark: e2 + `0 18 40` spread -12 at 55%
   - Light: e2 + `0 18 40` spread -12 at 18%
4. **e4 (Floating Nav Bar & Modal Sheets)**:
   - Dark: `0 14 32` spread -8 at 60%
   - Light: `0 14 32` spread -8 at 20%

In Dark Mode, card backgrounds render a subtle vertical gradient from `surfaceRaised` to `surface`, complemented by a 3.5% white top-light overlay across the top 40% of the surface.

---

## 4. Key Components

### `DepthCard` (`lib/core/widgets/depth_card.dart`)
- Drop-in card container replacing stroked containers.
- Supports elevation levels `e1`, `e2`, `e3`, and `e4`.
- Integrated micro-scale press interaction (scales to `0.985`, steps down shadow, 120ms animation).
- Wrapped in `RepaintBoundary` for zero paint invalidation of neighbors.
- Optional 3D tilt on scroll (`tiltOnScroll: true`) for hero elements.

### `ProgressBarX` (`lib/core/widgets/progress_bar_x.dart`)
- Replaces uncalibrated linear progress bars across the application.
- Clamped, NaN-safe progress handling via `ProgressMath.ratio(current, target)`.
- Semantic color mapping: `neutral`, `positive`, `warning`, `negative`, `over`.
- Animated with `TweenAnimationBuilder` (400ms `easeOutCubic`).
- 8% opacity background track.
- `XpProgressBar` variant binds directly to `ProgressionService` for synchronized leveling.

### `BentoContainer` (`lib/core/theme/bento_theme.dart`)
- Preserves the legacy API while internally rendering an e2 `DepthCard`.
- Stripped of all 5% white borders and harsh glow shadows.

---

## 5. Implementation Rules
1. **Surfaces and cards have NO border**: Never call `Border.all` on card containers. Only `// allowed: input focus` rings and 1px dividers at 6% opacity (`BentoTheme.divider`) are permitted.
2. **Never read Hive during build or theme lookups**: All tokens are resolved once per theme change via `ThemeExtension` (`AppTokens`).
3. **Zero Neon**: Replace all `Colors.greenAccent`, `Colors.redAccent`, neon cyan, or saturated blues with semantic tokens (`positive`, `negative`, `warning`, `accent`).
