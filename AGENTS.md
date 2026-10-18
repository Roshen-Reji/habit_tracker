# AGENTS.md — Tasks Page Emergency UI De-Congestion & Visual Bug Fix Spec

## 0. Critical Visual Defects Identified (Must Fix Immediately)
1. **Header Overlap Bug (`lib/features/tasks/tasks_page.dart`):** The `"TASKS"` title, `"✓ 0"` badge, sun icon, `"AI: SUGGEST"` chip, and search icon are colliding and overlapping horizontally in the top bar.
2. **Broken "Pill-in-Pill" Giant White Boxes (`tasks_page.dart`, `smart_plan_banner.dart`, `quick_add_nl_bar.dart`):** Buttons inside the "Next Up" card, "AI Morning Plan" card, and Quick-Add bar are rendering a dark pill inside a giant white rectangular box (or white text on a white box) due to conflicting `FilledButton`/`ElevatedButton` theme defaults vs. inner `Container` decorations.
3. **Extreme Text Wrapping in `SmartPlanBanner` (`lib/features/tasks/widgets/smart_plan_banner.dart`):** `"AI Morning Plan (PLAN-3)"` is wrapping 2–5 characters per line (`AI Mor / ning / Plan (P / LAN-3)`) because the oversized `"Rebalance"` button steals horizontal width. Also, raw spec codes like `(PLAN-3)` must never appear in user-facing UI.
4. **Unnecessary "Background Alarms Verified" Banner:** A 2-line alarm verification banner is permanently eating vertical space even when notifications are healthy.
5. **Bottom Quick-Add Bar & Floating Button Collision (`quick_add_nl_bar.dart` / `home_page.dart`):** A giant white square/circle sparkle button (`✨`) is overlapping the right side of the Quick-Add bar, and the text field is squeezed to `"Add task (e.g. D..."`.
6. **Severe Vertical Congestion:** Header + Alarm Banner + Workspace Tabs + Habits + Giant Next Up Card + Giant AI Plan Card + Quick Add Bar leave 0 pixels for the actual task list.

---

## Phase 1: Fix Header Overlap & Remove Banner Clutter (`lib/features/tasks/tasks_page.dart`)

1. **Redesign the Top Header Row (Single Clean Row, `height: 48px`):**
   - **Left Side:** Render `"Tasks"` (`fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5`) followed by a `8px` gap and a single subtle pill badge showing completed count (`"✓ $completedCount"`, `fontSize: 12`, `#141414` background, `#262626` border).
   - **Remove from Header:** Remove the `"AI: SUGGEST"` chip and the overlapping sun icon from the main title row.
   - **Right Side:** Render **at most 3** compact `36x36` circular icon buttons with `8px` spacing:
     1. `Icons.search_rounded` (toggles search bar)
     2. `Icons.bar_chart_rounded` (opens `TaskAnalyticsPage`)
     3. `Icons.more_horiz_rounded` (opens a clean bottom sheet or popup menu containing: **Filter Tasks**, **Wake-Up Log (`WakeupDetailSheet`)**, **AI Autonomy Mode (`$autonomyLabel`)**, **End-of-Day Shutdown Ritual**, **Weekly Review**, and **Import / Export**).
2. **Delete the "Background Alarms Verified" Banner:**
   - Completely remove the `_reminderBannerDismissed` / `"Background alarms verified: Reminders fire on exact time"` widget from `tasks_page.dart`.

---

## Phase 2: Fix "Pill-in-Pill" White Box Buttons & Typography Leaks

### Target Files
- `lib/features/tasks/tasks_page.dart`
- `lib/features/tasks/widgets/smart_plan_banner.dart`
- `lib/features/tasks/widgets/quick_add_nl_bar.dart`
- `lib/features/tasks/widgets/academic_hub_view.dart`

### Implementation Rules
1. **Never Nest Styled Containers Inside `FilledButton` / `ElevatedButton`:**
   - Build a reusable helper widget `_TaskActionPill` (using `PressScale` + `InkWell` + `Container` with a **single** decoration layer):
     - **Primary Variant (`isPrimary: true`):**
       - Background: `Colors.white` (Dark mode) / `Colors.black` (Light mode)
       - Foreground (Icon + Text): `Colors.black` (Dark mode) / `Colors.white` (Light mode)
       - Height: `38px`, Horizontal Padding: `14px`, BorderRadius: `12px`.
     - **Secondary Variant (`isPrimary: false`):**
       - Background: `const Color(0xFF141414)` (Dark mode) / `const Color(0xFFF4F4F5)` (Light mode)
       - Border: `1px solid const Color(0xFF262626)`
       - Foreground (Icon + Text): `Colors.white` (Dark mode) / `Colors.black` (Light mode)
       - Height: `38px`, Horizontal Padding: `14px`, BorderRadius: `12px`.
2. **Purge All Spec IDs from UI Strings:**
   - Search `lib/features/tasks/` for `PLAN-`, `CAP-`, `TSK-`, `ACA-`, `REM-`, `VIEW-`, `FOC-`, `HAB-`, `INS-` and remove every spec code from user-visible strings (e.g., change `"AI Morning Plan (PLAN-3)"` to `"Morning Plan"`).

---

## Phase 3: De-Congest `Today` View & Compact Cards

### Target Files
- `lib/features/tasks/tasks_page.dart`
- `lib/features/tasks/widgets/smart_plan_banner.dart`
- `lib/features/tasks/widgets/animated_task_os_tile.dart`

### Implementation Steps
1. **Sleek Workspace Switcher (`SlidingWorkspacePillBar`):**
   - Set height to `40px`, margin to `EdgeInsets.symmetric(horizontal: 16, vertical: 6)`.
   - Ensure all 5 labels (`Today`, `Upcoming`, `Inbox`, `Academic`, `Board`) use `fontSize: 13`, `maxLines: 1`, `FittedBox(fit: BoxFit.scaleDown)` so they never wrap or clip.
2. **Compact "Next Up" Hero Card (`tasks_page.dart`):**
   - Reduce vertical footprint by 40%:
     - Padding: `const EdgeInsets.all(14)`
     - Top Row: Compact `"🔥 NEXT UP"` badge on left + `"Urgency $score"` muted caption (`fontSize: 12, color: Color(0xFF8E8E93)`) on right.
     - Middle: Task Title (`fontSize: 16, fontWeight: FontWeight.w600, maxLines: 2`) + single-line metadata subtitle (`"Due in 6h · #DBMS · ~45m"`, `fontSize: 12, color: Color(0xFF8E8E93)`).
     - Bottom Row: Two single-layer `36px`-tall action pills side-by-side (`Expanded`):
       - Left (`Secondary`): `⚡ 5m Start`
       - Right (`Primary`): `⏱ Focus`
3. **Single-Line Collapsible `SmartPlanBanner` (`lib/features/tasks/widgets/smart_plan_banner.dart`):**
   - When collapsed (default state!), `SmartPlanBanner` must be a **single sleek `48px` row**:
     - `[✨ 16px Icon]` + `8px` gap + `Expanded(child: Text("Morning Plan · ${blocks.length} time blocks", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))` + compact `Rebalance` pill (`height: 30px`, `padding: horizontal 10px`, `fontSize: 12`) + `Icon(Icons.keyboard_arrow_down_rounded)`.
   - Tapping the row smoothly expands (`AnimatedSize`, `260ms`, `Cubic(0.22, 1.0, 0.36, 1.0)`) to show the proposed blocks and `Approve All` button.
4. **Compact Habits Strip:**
   - Render habits in a single horizontal `SizedBox(height: 34)` scroll strip with slim pills (`padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)`, `fontSize: 12`).

---

## Phase 4: Fix Bottom Quick-Add Bar & Floating Button Overlap

### Target Files
- `lib/features/tasks/widgets/quick_add_nl_bar.dart`
- `lib/features/tasks/tasks_page.dart`
- `lib/screens/home_page.dart`

### Implementation Steps
1. **Eliminate Overlapping Floating Action Button:**
   - Check `lib/screens/home_page.dart` and `lib/features/tasks/tasks_page.dart` for any `floatingActionButton` or positioned AI button overlapping the bottom-right corner on the Tasks tab. Hide or remove any `floatingActionButton` when the active tab is `Tasks`.
2. **Redesign `QuickAddNlBar` as a Unified Single-Row Dock (`height: 52px`):**
   - Container: `margin: const EdgeInsets.fromLTRB(16, 6, 16, 12)`, `padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)`, `decoration: BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.circular(26), border: Border.all(color: Color(0xFF262626)))`.
   - Inner `Row`:
     - Mic IconButton (`32x32`, `Icons.mic_none_rounded`, `size: 18`)
     - Camera/Syllabus IconButton (`32x32`, `Icons.document_scanner_outlined`, `size: 18`)
     - `const SizedBox(width: 6)`
     - `Expanded`: Borderless `TextField` (`hintText: "Quick add task..."`, `isDense: true`, `contentPadding: EdgeInsets.symmetric(vertical: 8)`, `style: TextStyle(fontSize: 14)`).
     - `const SizedBox(width: 6)`
     - Submit Button: A clean `34x34` circular container (`color: Colors.white`, `shape: BoxShape.circle`) with a `18px` `Icons.arrow_upward_rounded` (`color: Colors.black`)—**NOT** a giant white square/rectangle.
   - Ensure bottom padding in `TasksPage` accounts for the floating `BottomNavBar` (`kBottomNavigationBarHeight + 28`) so `QuickAddNlBar` sits cleanly above the navigation bar without clipping.

---

## Phase 5: Verification Gate
1. `flutter analyze` — Must report **0 errors and 0 warnings**.
2. `flutter test` — All tests must pass.