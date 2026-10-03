# COMMANDER HABIT TRACKER — SYSTEM ARCHITECTURE & COMPLETE MANUAL

> **Version:** 1.0.0+1  
> **Platform Support:** Android, iOS, macOS, Web, Linux, Windows  
> **Primary Framework:** Flutter 3.x / Dart 3.x  
> **Core Architecture:** Clean Layered Architecture (Feature-Driven)  
> **Data Persistence:** Hive NoSQL Local Key-Value & Object Store (Offline-First)  
> **AI Engine:** Google Gemini Flash (Multimodal Vision + Text) + On-Device NLP Rule Engine  

---

## 1. Executive Summary & App Identity

**Commander Habit Tracker** is an all-in-one personal command center designed around a sleek **Bento-style Cyberpunk / Tactical Aesthetic**. Unlike conventional single-purpose apps, Commander combines six vital lifestyle pillars into a unified, privacy-focused, offline-first ecosystem:

1. **Mission & Habit Engine**: Structured habit and goal tracking with military-style ranks, XP gamification, and automated lifecycle resets.
2. **Personal Finance Management**: Comprehensive offline double-entry ledger with multi-category budgeting, asset vaults, cashflow planning, and savings goals.
3. **Diet & Caloric Intelligence**: Macro/calorie tracking with daily targets, deficit/surplus XP incentives, and AI-powered food photo analysis.
4. **Offline Music Player**: Complete audio player supporting local storage indexing, background service controls, dynamic album art color themes, and synchronized LRC lyrics.
5. **Speech & Knowledge Vault**: Integrated video library for motivational and instructional content with embedded YouTube playback.
6. **Commander AI Copilot**: A hybrid multimodal assistant that uses on-device natural language heuristics for offline task execution and Google Gemini Flash models for complex queries and photo recognition.

---

## 2. High-Level System Architecture

The application adopts a **Feature-Driven Layered Clean Architecture**. The codebase decouples the presentation UI from the business logic, runtime services, and underlying storage adapters.

```
                          ┌──────────────────────────────────────┐
                          │          Presentation Layer          │
                          │   (Screens, Pages, Bento Widgets)    │
                          └──────────────────┬───────────────────┘
                                             │
                                             ▼
                          ┌──────────────────────────────────────┐
                          │            Domain / Logic            │
                          │   (GlobalXP, RankService, Resets)    │
                          └──────┬────────────────────────┬──────┘
                                 │                        │
                                 ▼                        ▼
        ┌────────────────────────────────┐        ┌────────────────────────────────┐
        │      Local Data Layer          │        │     External Services & AI     │
        │   Hive NoSQL Binary Store      │        │  • Google Gemini REST API      │
        │   (Tasks, Finance, Diet, XP)   │        │  • LRCLIB (Synced Lyrics)      │
        │   On-Device SQLite/MediaStore  │        │  • YouTube Player Service      │
        └────────────────────────────────┘        │  • Local Notifications (OS)    │
                                                  └────────────────────────────────┘
```

### Architectural Principles:
- **Offline-First & Sovereign Data**: All habit, finance, diet, and XP records reside strictly on the user's physical device in encrypted/binary format. No cloud account or external database server is mandated.
- **Dynamic Theming**: The app dynamically adapts its color palette (`BentoTheme`) based on the dominant and vibrant hues extracted from the currently playing music track's album art using `palette_generator`.
- **Hybrid AI Fallback**: Commands are first evaluated by an on-device regex/NLP parser (supporting English and Hinglish) to execute actions instantly without network latency or API token consumption. The remote Gemini API is invoked for unstructured reasoning or visual food recognition.

---

## 3. Directory & File Structure

```
lib/
├── app.dart                                # MaterialApp configuration, dynamic theme listener, scroll physics
├── main.dart                               # Application entry point, Hive initialization, adapter registrations
├── core/
│   ├── theme/
│   │   ├── app_animations.dart             # Micro-animation curves, durations, and transitions
│   │   ├── app_colors.dart                 # Color constants (surface, glass, accents, borders)
│   │   ├── app_theme.dart                  # Material theme specifications
│   │   └── bento_theme.dart                # Bento UI design system, containers, toggles, buttons
│   └── utils/
│       ├── format_utils.dart               # Date, currency, and numerical formatters
│       └── page_transitions.dart          # Custom route transitions (fade, slide-up, scale)
├── data/
│   ├── models/
│   │   ├── diet_models.dart                # FoodEntry, CalorieBurnEntry, DietDayLog, MealType
│   │   ├── diet_models.g.dart              # Hive generated adapter for diet models
│   │   ├── goal.dart                       # Goal model, GoalType, GoalCategory, streak tracking
│   │   ├── goal.g.dart                     # Hive generated adapter for Goal
│   │   └── user_rank.dart                  # UserRank metadata (title, level, position, progress)
│   └── services/
│       ├── ai_context.dart                 # Compact context generator for Gemini prompt efficiency
│       ├── ai_service.dart                 # Hybrid AI engine (Local Regex NLP + Gemini REST client)
│       ├── global_xp_service.dart          # Global XP ledger and 7-day historical tracker
│       ├── notification_service.dart       # Local scheduled task alerts via timezone
│       ├── permission_service.dart         # Storage, audio, camera, and notification permission requests
│       ├── rank_service.dart               # Rank calculation and position determination algorithms
│       └── task_reset_service.dart         # Daily/Weekly/Monthly midnight reset scheduler
├── features/
│   ├── diet/
│   │   ├── diet_page.dart                  # Today and Dashboard tabs for nutritional tracking
│   │   └── widgets/
│   │       ├── diet_dashboard_widgets.dart # FL Chart calorie trends, macro breakdowns, AI opinion
│   │       └── manual_food_input.dart      # Dialog for manual meal/food entry
│   ├── finance/
│   │   └── finance_page.dart               # Complete finance engine (Overview, Txns, Budget, Plan, Goals)
│   ├── home/
│   │   ├── home_chat.dart                  # Floating Action Button and bottom-sheet AI chat interface
│   │   └── widgets/
│   │       └── chat_message_bubble.dart    # Interactive action confirmation bubbles
│   ├── music/
│   │   ├── music_library_page.dart         # Local song browser, playlists, and favorites
│   │   ├── music_player_page.dart          # Full-screen player with synced lyrics and vinyl visuals
│   │   └── widgets/
│   │       └── procedural_artwork.dart     # Algorithmic procedural art for songs without artwork
│   ├── speech_vault/
│   │   └── speech_vault_page.dart          # Motivational video library and YouTube player
│   └── tasks/
│       ├── task_analytics_page.dart        # Completion rate circular gauges, streaks, category radar
│       ├── tasks_page.dart                 # Horizon-based task manager (Today, Daily, Weekly, Monthly)
│       └── widgets/
│           ├── add_task_dialog.dart        # Dialog for creating and scheduling missions
│           └── task_card.dart              # Interactive mission card with progress slider
├── models/
│   ├── finance_model.dart                  # Transaction and AssetVault models
│   ├── finance_model.g.dart                # Hive generated adapter for finance models
│   ├── goals.dart                          # Legacy goal representations
│   ├── quote.dart                          # Motivational quote data model
│   ├── song_model.dart                     # SongModel, LyricLine, SongSource, RepeatMode
│   ├── speech_model.dart                   # SpeechModel data class
│   └── speech_model.g.dart                 # Hive generated adapter for SpeechModel
├── screens/
│   ├── dashboard_view.dart                 # Primary landing view (Greetings, Quote, Momentum Graph, Missions)
│   ├── home_page.dart                      # Root navigation shell with BottomNavBar and Global Mini Player
│   └── settings_page.dart                  # Configuration, API keys, ranks, music folder picker, data purge
├── services/
│   ├── lyrics_service.dart                 # LRCLIB REST API client for synchronized lyrics (.lrc)
│   └── music_manager.dart                  # Singleton audio playback manager (just_audio + palette extraction)
└── widgets/
    ├── bottom_nav_bar.dart                 # Custom floating Bento navigation bar
    ├── local_music_manager.dart            # Helper for local music scanning
    ├── mini_player_bar.dart                # Global floating mini-player accessible across all screens
    ├── mysterious_momentum_graph.dart      # 7-day interactive XP velocity chart
    ├── mysterious_quote_card.dart          # Bento card displaying daily motivational wisdom
    ├── star_background.dart                # Cyberpunk animated background canvas
    └── wobbly_slider.dart                  # Elastic, physics-based seeking slider for audio
```

---

## 4. Database Architecture & Storage Models (Hive NoSQL)

All persistent application data is managed locally using **Hive**, a fast, lightweight, pure-Dart key-value database that serializes binary data through custom `TypeAdapter` implementations.

### 4.1 Hive Boxes Summary

| Box Name | Storage Type | Content / Purpose |
| :--- | :--- | :--- |
| `mission_box_v4` | `Box<Goal>` | All user habits, daily tasks, weekly milestones, and monthly objectives. |
| `settings` | `Box<dynamic>` | App config (`username`, `theme_mode`, `currency_symbol`, `gemini_api_key`, `music_folders`, `global_xp`). |
| `xp_history` | `Box<int>` | Daily XP archive keyed by date (`yyyy-MM-dd`) for velocity analytics. |
| `diet_logs` | `Box<DietDayLog>` | Daily nutrition logs keyed by date (`yyyy-MM-dd`), storing meals, macros, and burns. |
| `finance_transactions` | `Box<Transaction>` | Financial ledger recording income, expense, category, date, and payment mode. |
| `finance_vaults` | `Box<AssetVault>` | Account balances (e.g., Checking, Cash, Savings, Crypto, Brokerage). |
| `finance_settings` | `Box<dynamic>` | Monthly category budgets, long-term savings goals, and recurring commitments/SIPs. |
| `speech_vault` | `Box<SpeechModel>` | Bookmarked motivational and educational videos with YouTube identifiers. |

---

### 4.2 Detailed Data Schemas

#### 1. Mission / Goal Model (`lib/data/models/goal.dart`)
* **Hive Type ID:** `Goal` (1), `GoalType` (0), `GoalCategory` (2)
* **Fields:**
  - `id` (`String`): Unique identifier.
  - `title` (`String`): Name of the mission.
  - `type` (`GoalType`): Enum (`today`, `daily`, `weekly`, `monthly`).
  - `category` (`GoalCategory`): Enum (`health`, `productivity`, `learning`, `fitness`, `hobby`).
  - `targetValue` (`double`): Numerical completion threshold (e.g., 8 glasses of water, 10 km).
  - `currentValue` (`double`): Current progress value.
  - `unit` (`String`): Unit of measurement (`km`, `pages`, `minutes`, `count`).
  - `isCompleted` (`bool`): Completion state.
  - `streakCount` (`int`): Consecutive completion streak count.
  - `createdDate`, `lastCompletedDate`, `lastReset` (`DateTime?`): Timestamps for streak calculation.
  - `reminderTime` (`DateTime?`): Time scheduled for device push notification.
  - `endDate` (`DateTime?`): Optional expiration date for the mission.
* **XP Valuation Rules:**
  - Monthly Goal: **50 XP**
  - Weekly Goal: **20 XP**
  - Daily / Today Goal: **5 XP**

#### 2. Diet & Nutrition Models (`lib/data/models/diet_models.dart`)
* **Hive Type ID:** `MealType` (20), `FoodEntry` (21), `CalorieBurnEntry` (22), `DietDayLog` (23)
* **`FoodEntry` Fields:** `id`, `name`, `calories`, `protein`, `carbs`, `fat`, `timestamp`, `mealType` (breakfast/lunch/dinner/snack).
* **`CalorieBurnEntry` Fields:** `id`, `activity`, `caloriesBurned`, `durationMinutes`, `timestamp`.
* **`DietDayLog` Fields:** `dateKey` (`yyyy-MM-dd`), `entries` (`List<FoodEntry>`), `burnEntries` (`List<CalorieBurnEntry>`), `targetCalories`, `notes`.
* **Calculated Metrics:**
  - `totalCalories` = $\sum \text{FoodEntry.calories}$
  - `totalBurned` = $\sum \text{CalorieBurnEntry.caloriesBurned}$
  - `netCalories` = $\text{totalCalories} - \text{totalBurned}$
  - `deficit` = $\text{targetCalories} - \text{netCalories}$

#### 3. Finance Models (`lib/models/finance_model.dart`)
* **Hive Type ID:** `Transaction` (10), `AssetVault` (11)
* **`Transaction` Fields:**
  - `title` (`String`): Description of expense or income.
  - `amount` (`double`): Monetary value.
  - `category` (`String`): Expense classification (e.g., Food, Housing, Transport, Entertainment).
  - `date` (`DateTime`): Transaction timestamp.
  - `mode` (`String`): Payment method / mode (`expense` vs `income`).
  - `icon` (`String`): Visual identifier.
* **`AssetVault` Fields:**
  - `name` (`String`): Vault name (e.g., "Primary Checking", "Emergency Fund", "Crypto Wallet").
  - `balance` (`double`): Current liquidity.
  - `bank` (`String`): Financial institution or custodian.
  - `type` (`String`): Vault categorization (`Savings`, `Current`, `Investment`, `Cash`).
  - `colorValue` (`int`): UI tint hex code.

#### 4. Speech Vault Model (`lib/models/speech_model.dart`)
* **Hive Type ID:** `SpeechModel` (4)
* **Fields:** `id`, `title`, `speaker`, `youtubeVideoId`, `thumbnailUrl`, `durationLabel`.

---

## 5. In-Depth Feature Breakdown & Workflows

### 5.1 Mission & Habit Tracking Engine

```
[User Creates Mission] ───► [Assign Horizon & Category] ───► [Set Target & Unit]
           │
           ├───► [Daily Execution: Check-off / Slider Progress]
           │          │
           │          ├──► [Target Reached] ──► [Award XP] ──► [Increment Streak]
           │
           └───► [TaskResetService: Midnight / Monday / Month-End Boundary]
                      │
                      └──► [Reset isCompleted to false, Retain Streaks]
```

#### Horizon Segregation:
1. **Today**: One-off tasks that expire at midnight.
2. **Daily**: Recurring daily habits (e.g., workout, meditation, coding).
3. **Weekly**: Larger objectives evaluated across a 7-day sprint (Monday to Sunday).
4. **Monthly**: Strategic projects and macro targets evaluated per calendar month.

#### Lifecycle & Automated Reset Engine (`TaskResetService`):
Every time the application boots or resumes from the background, `TaskResetService.checkAndResetTasks()` runs synchronously:
- **Daily Tasks**: Compares `lastCompletedDate` with `DateTime.now()`. If the day has rolled over, resets `isCompleted` to `false` and `currentValue` to `0.0`.
- **Weekly Tasks**: Determines if a Monday boundary has been crossed or if $>7$ days have elapsed.
- **Monthly Tasks**: Resets if the calendar month or year has incremented.

#### Gamification & Military Rank Progression:
XP is accumulated into a persistent global pool and tracked daily in `xp_history`:
- **Formula:**
  $$\text{Total XP} = \sum (\text{Base Weight} \times \text{Completed}) + \sum (\text{Streak Count} \times \text{Base Weight} \times 0.1)$$
- **Ranks:**
  1. `RECRUIT` (Level 1)
  2. `OPERATIVE` (Level 2)
  3. `SPECIALIST` (Level 3)
  4. `VETERAN` (Level 4)
  5. `LEADER` (Level 5)
  6. `LEGEND` (Level 6+)
- **Tactical Positions / Specializations:**
  The user is assigned a specific tactical position based on where the majority of their completed XP points originate:
  - *Learning* focus $\rightarrow$ **LEAD RESEARCHER**
  - *Fitness* focus $\rightarrow$ **TACTICAL ATHLETE**
  - *Productivity* focus $\rightarrow$ **OPERATIONS CHIEF**
  - *Health* focus $\rightarrow$ **BIO-SECURITY OFFICER**
  - *Hobby* focus $\rightarrow$ **CREATIVE DIRECTOR**

---

### 5.2 Personal Finance Command Center (`FinanceDashboard`)

The finance system is organized into five dedicated sub-views:

1. **Overview**:
   - Aggregate net worth computed across all `AssetVault` records.
   - Monthly cashflow indicator displaying total Income vs Expenses.
   - **Monthly Burn Rate**: Real-time spending velocity.
   - Horizontal carousel of Asset Vaults displaying balances and bank providers.
   - Recent transaction ledger with one-tap entry details.

2. **Transactions (`TXNS`)**:
   - Filterable chronological ledger.
   - Filter by month, transaction type (All, Incomes, Expenses), or search query.
   - Add transaction modal supporting dynamic category selection, custom dates, and payment methods.

3. **Budget Planner (`BUDGET`)**:
   - Category-wise monthly limits (e.g., Dining: \$400, Utilities: \$250, Fuel: \$150).
   - Visual progress indicators showing percentage consumed:
     - Green ($<75\%$) $\rightarrow$ Amber ($75\% - 99\%$) $\rightarrow$ Red Flashing ($>100\%$ Overbudget).

4. **Cashflow Planner (`PLAN`)**:
   - Proactive planning for recurring monthly obligations:
     - **Fixed Commitments**: Rent, utilities, loan EMIs, insurance premiums.
     - **SIPs (Systematic Investment Plans)**: Monthly mutual funds, index funds, recurring crypto deposits.
   - Calculates **Projected Disposable Income** after all fixed commitments and investments are deducted.

5. **Financial Goals (`GOALS`)**:
   - Long-term purchasing and savings targets (e.g., "Emergency Fund", "New Laptop", "Europe Trip").
   - Tracks target amount, currently allocated savings, and projected completion dates with progress bars.

---

### 5.3 Diet & Caloric Intelligence (`DietPage`)

```
                 ┌─────────────────────────────────┐
                 │       Meal Intake / Photo       │
                 └───────────────┬─────────────────┘
                                 │
                                 ▼
                     [DietDayLog: Today's Date]
                                 │
         ┌───────────────────────┴───────────────────────┐
         │                                               │
         ▼                                               ▼
[+ Total Calories & Macros]                   [- Calorie Burn Entries]
(Protein, Carbs, Fat)                         (Workouts, Running, Steps)
         │                                               │
         └───────────────────────┬───────────────────────┘
                                 │
                                 ▼
           [Net Calories = Total Calories - Burned]
                                 │
                     [Compare to Calorie Target]
                                 │
            ┌────────────────────┴────────────────────┐
            ▼                                         ▼
   [In Deficit: +20 XP]                     [Over Target: -20 XP]
```

- **Daily Calorie Target**: Configurable in Settings (default: 2,000 kcal).
- **Macro Distribution**: Automatic summation of protein, carbohydrates, and fats in both grams and macro-nutrient percentages.
- **Calorie Burn Log**: Track exercise sessions with duration and burned kcal.
- **Gamified Caloric Deficit**:
  - Pushing daily net calories into a healthy deficit awards **+20 Global XP**.
  - Exceeding the caloric target deducts **-20 Global XP**.
- **AI Multimodal Vision**:
  - The user can snap a photograph of their food using `image_picker`.
  - The image is converted to Base64 and transmitted to Gemini Vision.
  - The model calculates the food name, estimates weight, and extracts calories, protein, carbs, and fat, outputting a pre-structured `food_entry` card for one-tap verification.

---

### 5.4 Music Library & Player Engine

- **Local Storage Indexing**: Utilizes `on_audio_query` to query the device's MediaStore on Android / iOS filesystem.
- **Directory Isolation**: Supports folder-based filtering in Settings so non-music audio (e.g., WhatsApp audio, call recordings) is excluded.
- **Background Playback**: Powered by `just_audio` and `just_audio_background` with an Android foreground service, lock screen controls, and notification tray artwork.
- **Dynamic Theming via Album Art**:
  When a song starts playing, `MusicManager` extracts its embedded album artwork, feeds it into `PaletteGenerator`, and updates `MusicManager().currentDominantColor`. The entire application's background, accents, and button glows smoothly interpolate to match the album's artwork.
- **Real-Time Synced Lyrics Engine**:
  Queries the open-source **LRCLIB API** (`https://lrclib.net/api/get?artist_name=...&track_name=...`). The parsed `.lrc` timestamps synchronize with the player's millisecond playback position, highlighting active lyrics line-by-line with autoscrolling.
- **Procedural Album Artwork**:
  If a song lacks embedded album art, `procedural_artwork.dart` deterministically generates an abstract geometric canvas using the song title and artist string as random seeds.
- **Global Mini Player**:
  A floating mini player bar remains anchored above the navigation bar across all views, allowing quick play/pause, scrubbing, and navigation to the expanded player.

---

### 5.5 Knowledge & Speech Vault (`SpeechVaultPage`)

- Built for motivational speeches, educational seminars, and mental conditioning.
- Direct embedded playback of YouTube videos via `youtube_player_flutter`.
- Pre-seeded with Scott Geller's *"The Psychology of Self-Motivation"*.
- Users can add any YouTube URL or video identifier with custom title and speaker attribution.
- Can be triggered directly by the AI Copilot (e.g., *"Play motivation video"*).

---

### 5.6 Multimodal AI Copilot ("Commander AI")

The AI engine in `lib/data/services/ai_service.dart` is architected as a **two-tier hybrid system**:

```
[User Chat Message / Image Input]
               │
               ▼
[Smart Intent Detection: detectIntent()]
               │
               ├───► [Has Image?] ──► Transmit to Gemini Flash Vision API
               │
               ├───► [Matches Local Regex / NLP Rule?]
               │          │
               │          ▼
               │   [Execute Locally via On-Device Engine]
               │   (No Internet, No API Key, 0ms Latency)
               │
               └───► [Complex Query / Reasoning Required]
                          │
                          ▼
                   [Gemini REST API Call]
                   (Model fallback chain: 2.5-flash -> 2.0-flash -> 1.5-flash)
                          │
                          ▼
            [Structured JSON Response Parsing]
                          │
                          ▼
            [Render Interactive Action Bubble]
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
       [CONFIRM]                     [REJECT]
            │                           │
  [Write to Hive DB]            [Discard Action]
```

#### 1. Tier 1: Local Regex & Multilingual NLP Parser
Runs directly on the user's phone with zero network access. It parses command structures in both English and Hinglish:
- **Finance**: *"spent 450 on fuel"*, *"kharcha 200 food"*, *"salary credited 85000"* $\rightarrow$ Creates `finance_transaction`.
- **Diet**: *"ate 3 eggs and toast for breakfast"*, *"burned 300 kcal running 30 mins"* $\rightarrow$ Creates `food_entry` / `burn_entry`.
- **Missions**: *"add daily goal read 20 pages"*, *"new task gym 60 mins"* $\rightarrow$ Creates `task_create`.
- **Music**: *"play starboy"*, *"gana bajao believer"*, *"pause music"* $\rightarrow$ Directly calls `MusicManager`.
- **Vault**: *"play motivational video"* $\rightarrow$ Dispatches `play_vault_video`.

#### 2. Tier 2: Cloud Gemini REST Client
When complex contextual reasoning, natural conversation, or image analysis is required:
- Compresses application state into token-efficient context lines via `AiContext`:
  ```
  [CONTEXT]
  [DIET] In:1450 Net:1150 Tgt:2000
  [FIN] Inc:85000 Exp:24300
  [TASK] Act:4 Dn:2
  [USER MESSAGE]
  What should I eat tonight to hit my protein goal without exceeding calories?
  ```
- **Candidate Fallback Chain**: Attempts requests using `gemini-2.5-flash`, then falls back to `gemini-2.0-flash` and `gemini-1.5-flash` in the event of upstream version changes.
- **Guaranteed Structured Output**: Enforces `responseMimeType: 'application/json'` to reliably extract action payloads (`AiAction`).
- **Interactive Confirmation Bubbles**: The AI never silently alters database records. It renders interactive confirmation cards in the chat where the user must tap **"Engage" (Confirm)** or **"Cancel" (Reject)**.

---

## 6. Technology Stack & Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
    
  # Database & Offline Storage
  hive: ^2.2.3                    # High-performance NoSQL key-value database
  hive_flutter: ^1.1.0            # Flutter bindings and ValueListenable helpers for Hive

  # Audio & Media Playback
  just_audio: ^0.10.6             # Robust audio player engine
  just_audio_background: ^0.0.1   # Lock-screen controls & background audio playback service
  on_audio_query: ^2.9.0          # Queries device MediaStore for local music files
  youtube_player_flutter: ^9.1.3  # Inline YouTube video player
  palette_generator: ^0.3.3+3     # Extracts dominant color palettes from album art in real time

  # Visuals, Icons & Animations
  fl_chart: ^1.2.0                # Smooth line charts, momentum graphs, and pie charts
  lucide_icons_flutter: ^3.1.14+2 # Clean, modern feather/lucide iconography
  flutter_animate: ^4.5.2         # Declarative micro-animations and physics spring curves
  rive: 0.14.9                    # Vector runtime animations

  # System & Device APIs
  permission_handler: ^12.0.3     # Runtime permission manager (Storage, Audio, Camera)
  flutter_local_notifications: ^22.0.1 # Scheduled alarms and habit reminders
  timezone: ^0.11.1               # Timezone database for precise notification scheduling
  image_picker: ^1.0.7            # Camera and gallery image selector for food recognition
  file_picker: ^8.1.4             # Directory and file selector for custom music folders
  path_provider: ^2.1.2           # Filesystem paths for app storage and caches
  http: ^1.1.0                    # HTTP client for Gemini API and LRCLIB lyrics service
  intl: ^0.20.3                   # Date formatting and currency utilities
```

---

## 7. How to Run, Build, and Maintain

### 7.1 Prerequisites
- **Flutter SDK:** Version `>=3.0.0 <4.0.0`
- **Dart SDK:** Version `>=3.0.0 <4.0.0`
- **Android Studio / Xcode:** Configured with platform toolchains.
- **Java:** JDK 17 (recommended for modern Android Gradle Plugin builds).

### 7.2 Installation & Build Steps

1. **Clone the Repository:**
   ```bash
   cd "d:/Roshen/Habit Tracker/habit_tracker"
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run Code Generation (Hive Type Adapters):**
   Whenever models with `@HiveType` or `@HiveField` are modified, regenerate the serialization adapters:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the Application:**
   ```bash
   # Run on connected Android / iOS device or emulator
   flutter run
   ```

5. **Release APK / AppBundle Build:**
   ```bash
   flutter build apk --release
   ```

---

## 8. Troubleshooting & Common Pitfalls

| Issue | Root Cause | Solution |
| :--- | :--- | :--- |
| **Hive TypeAdapter Exception on Boot** | Model schema changed without running code generation or mismatched Type ID. | Run `flutter pub run build_runner build --delete-conflicting-outputs`. If fields were modified destructively, clear app storage or delete the old Hive box. |
| **No Local Songs Found** | Missing runtime audio or storage permissions, or audio files are in unselected folders. | Verify storage/audio permissions in device settings. Navigate to **Settings $\rightarrow$ Music Folders** and ensure the music directory is selected. |
| **Gemini AI Returns Error (401/403/Fallback)** | Missing, invalid, or expired Gemini API key. | Enter a valid Gemini API key in **Settings $\rightarrow$ Gemini API Key**. Note: Common commands (music, tasks, expenses) continue to function offline via the local NLP engine. |
| **Scheduled Notifications Not Triggering** | Battery optimization killing background alerts or exact alarm permission denied on Android 12+. | Ensure notification permission is granted, and exempt the app from battery optimization in Android settings. |
| **Background Music Stops When App Minimized** | Android killing process without foreground service declaration. | Verify `just_audio_background` configuration in `main.dart` and ensure `FOREGROUND_SERVICE` permission exists in `AndroidManifest.xml`. |

---
*Documentation compiled and verified for Commander Habit Tracker.*
