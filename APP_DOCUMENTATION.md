# COMMANDER HABIT TRACKER — SYSTEM ARCHITECTURE & COMPLETE MANUAL (MVP 2 & MVP 3 MONEY OS)

> **Version:** 3.0.0 (MVP 3 Money OS)  
> **Platform Support:** Android (primary), iOS, macOS, Web, Linux, Windows  
> **Primary Framework:** Flutter 3.x / Dart 3.x  
> **Design Language:** Google Material 3 Expressive + Dark Bento Cyberpunk  
> **Core Architecture:** Clean Layered Architecture (Feature-Driven, Offline-First, Local-First Ledger)  
> **Data Persistence:** Hive NoSQL Binary Store with AES-256 Hardware Encryption & SecureStorage Key Vault  
> **AI Engine:** Google Gemini Flash (`GeminiClient` with dynamic fallback chain) + Local Deterministic Finance Query & Regex Engine  
> **Media Architecture:** Android System MediaSession Bridge (`NotificationListenerService` + `NowPlayingService`)  
> **Finance Subsystem:** Double-Entry Ledger, Paise Accuracy (RFC 4180 CSV, Rules Engine, Minimal-Settlements, App Lock)

---

## 1. Executive Summary & App Identity

**Commander Habit Tracker (MVP 2)** is an all-in-one personal command center designed around a sleek **Material 3 Expressive & Dark Bento Aesthetic**. The home screen features a tactile **Wallet Card Stack** that gracefully compresses and stacks cards on scroll.

Commander integrates eight vital personal development pillars:

1. **Wallet-Stack Command Deck**: Interactive overlapping cards with real-time peeking, spring physics, and full layout reordering/hiding from Settings.
2. **Mission & Habit Engine**: Daily, weekly, and monthly goal tracking with military ranks, streaks, XP gamification, and automated resets.
3. **Personal Finance & Automated SIPs**: Multi-category ledger, asset vaults, savings goals, and automated SIP debits posted on their designated monthly due dates.
4. **Diet & Caloric Intelligence**: Macro/calorie logs, daily targets, deficit/surplus XP incentives, and AI nutritional breakdown.
5. **Universal Music Controller**: Android MediaSession controller detecting whatever media app is currently playing (Spotify, YouTube Music, etc.) with remote controls and dynamic album art theming.
6. **Health & Wellness Vault**: Scheduled medication reminders with Taken/Snooze notification actions, weight journey with sparkline curves, and composite health scoring.
7. **Private Journal**: Hardware-encrypted (AES-256) notes with rich text formatting (`flutter_quill`), biometric / device credential authentication, and automatic background lock.
8. **Brainstorm & Document Reader**: Rapid idea capture board and a distraction-free PDF document reader with continuous scrolling, bookmarks, and night mode.

---

## 2. High-Level System Architecture

```
                          ┌──────────────────────────────────────┐
                          │          Presentation Layer          │
                          │ • Wallet Card Stack (CustomScroll)   │
                          │ • 3-Tab Nav (Home, Tasks, Diet)      │
                          │ • Global Floating Mini Player & FAB  │
                          └──────────────────┬───────────────────┘
                                             │
                                             ▼
                          ┌──────────────────────────────────────┐
                          │            Domain / Logic            │
                          │ • AppNav (Global Nav Coordinator)    │
                          │ • SipService & FinanceCalculator     │
                          │ • MedicineService & HealthCalculator │
                          │ • JournalService & ReaderService     │
                          │ • NowPlayingService (Media Bridge)   │
                          │ • GlobalXPService & TaskResetService │
                          └──────┬────────────────────────┬──────┘
                                 │                        │
                                 ▼                        ▼
        ┌────────────────────────────────┐        ┌────────────────────────────────┐
        │      Local Storage Layer       │        │     External Services & OS     │
        │ • Hive NoSQL Binary Store      │        │ • Android MediaSession Bridge  │
        │ • AES-256 Encrypted Journals   │        │ • Google Gemini Flash REST API │
        │ • SecureStorage (Key Vault)    │        │ • Local Notifications & Alarms │
        │ • Recursive File System Reader │        │ • Device Biometrics (local_auth│
        └────────────────────────────────┘        └────────────────────────────────┘
```

---

## 3. Directory & File Structure

```
lib/
├── app.dart                                # MaterialApp configuration, theme listener, lifecycle & localizations
├── main.dart                               # Boot entry point, Hive adapter registrations, box init, background hooks
├── core/
│   ├── navigation/
│   │   └── app_nav.dart                    # AppNav global navigation coordinator (tab & subview switching)
│   ├── theme/
│   │   ├── app_animations.dart             # Micro-animation curves, durations, and transitions
│   │   ├── app_colors.dart                 # Color constants (surface, glass, accents, borders)
│   │   ├── bento_theme.dart                # Dark Bento theme tokens, elevated surfaces, dynamic accents
│   │   └── expressive_tokens.dart          # Material 3 Expressive corner radii, spring curves, and elevations
│   └── utils/
│       ├── format_utils.dart               # Date, currency, and numerical formatters
│       └── page_transitions.dart          # Custom expressive route transitions
├── data/
│   ├── models/
│   │   ├── diet_models.dart                # FoodEntry, CalorieBurnEntry, DietDayLog, MealType (typeIds 20-23)
│   │   ├── finance_model.dart              # Transaction, AssetVault (typeIds 10-11)
│   │   ├── goal.dart                       # Goal, GoalType, GoalCategory (typeIds 0-2)
│   │   ├── health_models.dart              # Medicine, MedicineLog, WeightEntry (typeIds 30-32)
│   │   ├── productivity_models.dart        # JournalEntry, Idea, BookProgress (typeIds 33-35)
│   │   └── speech_model.dart               # SpeechModel (typeId 4)
│   └── services/
│       ├── ai_context.dart                 # Compact context generator for Gemini prompt efficiency
│       ├── ai_service.dart                 # Hybrid AI engine (Local Regex NLP + GeminiClient)
│       ├── finance_calculator.dart         # Pure finance snapshot and balance calculator
│       ├── gemini_client.dart              # Resilient Gemini REST client with dynamic model discovery & backoff
│       ├── global_xp_service.dart          # Global XP ledger and 7-day historical tracker
│       ├── health_calculator.dart          # Pure composite health score and summary generator
│       ├── journal_service.dart            # AES-256 encrypted Hive storage and biometric authentication
│       ├── medicine_service.dart           # Medication recurrence calculator and notification scheduler
│       ├── notification_service.dart       # Local scheduled task alerts, action buttons, background entry point
│       ├── reader_service.dart             # Recursive PDF file scanner, cover caching, and progress tracker
│       ├── score_service.dart              # XP totals (week/month/year) and velocity score deltas
│       ├── sip_service.dart                # Idempotent SIP posting on monthly due dates
│       └── task_reset_service.dart         # Daily/Weekly/Monthly midnight reset scheduler
├── features/
│   ├── brainstorm/
│   │   └── brainstorm_page.dart            # Full-page idea management, search, and editing
│   ├── diet/
│   │   ├── diet_page.dart                  # Today and Dashboard tabs for nutritional tracking
│   │   └── widgets/
│   │       ├── diet_dashboard_widgets.dart # FL Chart calorie trends, macro breakdowns, AI opinion
│   │       └── manual_food_input.dart      # Dialog for manual meal/food entry
│   ├── finance/
│   │   └── finance_page.dart               # Complete finance engine (Overview, Txns, Budget, Plan, Goals)
│   ├── health/
│   │   └── health_page.dart                # Unified Health Page with Medicine | Weight tab switcher
│   ├── home/
│   │   ├── cards/
│   │   │   ├── brainstorm_card.dart        # Brainstorm ideas preview & quick capture
│   │   │   ├── calories_card.dart          # Daily calorie & macro summary
│   │   │   ├── finance_card.dart           # Month net, balance, and next SIP debit
│   │   │   ├── health_summary_card.dart    # Composite health score (0-100) and metric tiles
│   │   │   ├── home_card.dart              # HomeCardSpec, HomeCardRegistry, and layout merger
│   │   │   ├── home_card_frame.dart        # Unified M3 Expressive card frame
│   │   │   ├── journal_card.dart           # Private journal Create / View Vault card
│   │   │   ├── medicine_card.dart          # Medication next dose & adherence tracker
│   │   │   ├── missions_card.dart          # Daily missions list
│   │   │   ├── momentum_card.dart          # Active-days strip expanding to dot-matrix XP graph
│   │   │   ├── music_card.dart             # Universal music controller card
│   │   │   ├── quote_card.dart             # Daily wisdom quote card
│   │   │   ├── reader_card.dart            # PDF book covers preview & library shortcut
│   │   │   ├── score_card.dart             # XP totals (week / month / year)
│   │   │   ├── score_delta_card.dart       # XP velocity deltas (day / week / month)
│   │   │   └── weight_card.dart            # Weight journey with fl_chart sparkline
│   │   ├── widgets/
│   │   │   ├── expanded_player_sheet.dart  # Modal music controller with seek slider & artwork
│   │   │   └── wallet_card_stack.dart      # Wallet-stack scrolling card engine
│   │   └── home_chat.dart                  # Floating Action Button and bottom-sheet AI chat interface
│   ├── journal/
│   │   ├── journal_editor_page.dart        # Rich text note editor with flutter_quill & tags
│   │   └── journal_list_page.dart          # Biometric lock screen & searchable journal list
│   ├── reader/
│   │   ├── pdf_reader_page.dart            # Continuous scroll PDF reader with bookmarks & night mode
│   │   └── reader_library_page.dart        # Grid document library and directory settings
│   └── tasks/
│       ├── tasks_page.dart                 # Missions, Finance subview, Speech Vault switcher
│       └── task_analytics_page.dart        # Mission analytics and category performance charts
├── screens/
│   ├── dashboard_view.dart                 # Home dashboard root containing greeting and WalletCardStack
│   ├── home_layout_settings_page.dart      # Reorderable card layout and visibility manager
│   ├── home_page.dart                      # 3-tab bottom navigation shell
│   └── settings_page.dart                  # App settings (theme, Gemini model, folders, resets)
├── services/
│   └── now_playing_service.dart            # Dart service wrapping Android MediaSessionBridge
└── widgets/
    ├── bottom_nav_bar.dart                 # Slender (62px) floating navigation bar
    ├── mini_player_bar.dart                # Global floating mini player hooked to NowPlayingService
    ├── mysterious_momentum_graph.dart      # Full 70-dot XP matrix graph
    └── wobbly_slider.dart                  # Tactile physics-based slider for media seeking
```

---

## 4. Hive NoSQL Persistence Matrix

| TypeId | Model Class | Hive Box Name | Storage Type | Description |
|---|---|---|---|---|
| `0` | `Goal` | `mission_box_v4` | Typed | Habit and mission tracking records |
| `1` | `GoalType` | `mission_box_v4` | Enum | Daily, Weekly, or Monthly cadence |
| `2` | `GoalCategory` | `mission_box_v4` | Enum | Health, Productivity, Learning, Fitness, Hobby |
| `4` | `SpeechModel` | `speech_vault` | Typed | Saved motivational & instructional videos |
| `10` | `Transaction` | `finance_transactions` | Typed | Double-entry income and expense transactions |
| `11` | `AssetVault` | `finance_vaults` | Typed | Bank accounts, cash reserves, and investment vaults |
| `20` | `MealType` | `diet_logs` | Enum | Breakfast, Lunch, Dinner, Snack |
| `21` | `FoodEntry` | `diet_logs` | Typed | Itemized meal items with macronutrients |
| `22` | `CalorieBurnEntry` | `diet_logs` | Typed | Logged physical activities and calories burned |
| `23` | `DietDayLog` | `diet_logs` | Typed | Daily aggregated nutritional logs keyed `yyyy-MM-dd` |
| `30` | `Medicine` | `medicines` | Typed | Medication schedule, dose labels, slots, and weekdays |
| `31` | `MedicineLog` | `medicine_logs` | Typed | Historical logs of taken, skipped, and snoozed doses |
| `32` | `WeightEntry` | `weight_entries` | Typed | Weight logs keyed `yyyy-MM-dd` with notes |
| `33` | `JournalEntry` | `journals` | **AES-256** | Hardware-encrypted private journal notes |
| `34` | `Idea` | `ideas` | Typed | Brainstorming insights, concepts, and notes |
| `35` | `BookProgress` | `reader_progress` | Typed | Reading bookmarks, last read page, and total pages |
| — | Untyped | `settings` | Key-Value | General preferences, `home_layout`, `reader_folders` |
| — | Untyped | `finance_settings` | Key-Value | `planner` (fixed expenses, SIPs), `sip_ledger` |
| — | Untyped | `xp_history` | Key-Value | Daily XP history keyed `yyyy-MM-dd` |

---

## 5. Universal Music Architecture (Android MediaSession)

In MVP 2, the legacy in-app audio player, local file indexer, and lyrics service were completely replaced with a native **System MediaSession Controller**:

1. **Native Kotlin Layer**:
   - `MediaNotificationListenerService.kt`: Listens to Android system media sessions using `MediaSessionManager.getActiveSessions`.
   - `MediaSessionBridge.kt`: Exposes a bidirectional `MethodChannel` (`habit/media_control`) and `EventChannel` (`habit/now_playing`).
2. **Dart NowPlayingService**:
   - Maintains a reactive `ValueNotifier<NowPlaying?>`.
   - Performs **local time-delta progress interpolation** (`position + (now - updatedAt) * speed`) without costly periodic polling.
   - Provides playback commands: `play`, `pause`, `next`, `previous`, `seekTo`, `openApp`, `playFromSearch`.
3. **UI Integration**:
   - **MusicCard**: Displays currently playing track, artwork, and primary playback controls on the Home wallet stack.
   - **Global Mini Player**: Floats above the bottom navigation bar whenever active media is detected.
   - **Expanded Player Sheet**: Features full artwork, `WobblySlider` seek bar, and transport controls.
   - **Dynamic Theming**: Extracts dominant colors via `palette_generator` to style borders and accents.
4. **AI Media Intents**:
   - Supports natural language controls in English and Hinglish (e.g., "pause music", "next song", "gaana badlo", "play Taylor Swift").

---

## 6. AI Engine & Dynamic Gemini Fallback Chain

`GeminiClient` provides high-availability access to Google Gemini:

1. **Resolution Priority**:
   - **User Override**: Custom model ID specified in Settings.
   - **Dynamic ListModels Discovery**: Queries the Gemini `models` endpoint to discover newest flash models supporting `generateContent`, cached for 24 hours.
   - **Built-in Fallback Chain**: `['gemini-3.8-flash', 'gemini-3.6-flash', 'gemini-2.5-flash', 'gemini-1.5-flash']`.
2. **Error Handling & Resilience**:
   - `404 Not Found`: Automatically rolls over to next candidate model.
   - `429 Rate Limit`: Executes exponential backoff (honoring `Retry-After`), retries once, then rolls over.
   - `401 / 403 Forbidden`: Halts chain immediately with clear guidance on API key configuration.
   - `400 Bad Request`: Halts chain and surfaces specific syntax errors.
3. **Settings Test Connection**: Dedicated verification button testing connection and surfacing active model in real time.

---

## 7. Automated SIP Deductions

1. **Execution**: Evaluated on app boot and on app resume from background.
2. **Idempotency**: Ledger stored in `finance_settings['sip_ledger'] = {id: 'yyyy-MM'}` ensures no month is ever double-debited.
3. **Calendar Rollover**: Correctly resolves leap years and shorter months (e.g. Due 31 in Feb -> posts on Feb 28 or Feb 29).
4. **Disposable Income Invariant**: PLAN view dynamically deducts only SIPs not yet posted in the current calendar month.

---

## 8. MVP 3 Money OS Architecture

MVP 3 elevates personal finance in Commander from a simple transaction recorder into a robust, offline-first personal **Money OS**.

### 8.1 Core Ledger Invariants
The finance engine strictly enforces 6 fundamental accounting and mathematical invariants across all models, storage, calculations, and UI representations:

- **Invariant I1 (Atomic Transfer)**: A transfer is an atomic operation affecting two accounts. For every transfer transaction with `fromAccountId` and `toAccountId`, the debited amount from the source equals the credited amount to the destination. Deleting or modifying a transfer adjusts both accounts simultaneously.
- **Invariant I2 (Opening Balances)**: Every account has an immutable or explicitly edited `openingBalance` dated at `openingDate`. An account's balance as of date $T$ is computed deterministically as:
  $$\text{Balance}(T) = \text{openingBalance} + \sum_{t \le T} \Delta(t)$$
  where $\Delta(t)$ represents the net signed impact of confirmed transactions.
- **Invariant I3 (Net Calculation & Reimbursements)**:
  $$\text{Net} = \text{Total Income} - \text{Total Expenses}$$
  Reimbursements received (e.g., from settling group splits) directly offset receivables/expenses rather than inflating gross taxable income. Refunds credit the exact original expense category.
- **Invariant I4 (Credit Card Transfers)**: Credit card payments are classified as transfers from a bank/cash account to the credit card liability account. Card repayments are never recorded as expense or income.
- **Invariant I5 (Split Consistency)**: For any itemized transaction with split lines or multiple categories:
  $$\sum \text{SplitLine.amount} = \text{Transaction.amount}$$
- **Invariant I6 (Paise Accuracy)**: All internal currency arithmetic is computed either in integer paise or rounded using deterministic half-up precision via `Money.r2()`, eliminating IEEE 754 floating-point drift across millions of transactions.

### 8.2 Hive Persistence Matrix (Type IDs 40–50)

| TypeId | Model Class | Hive Box Name | Key Type | Purpose |
|---|---|---|---|---|
| `10` | `Transaction` | `fin_transactions` | String UUID | Double-entry transactions (kind: expense, income, transfer, investment, debt_payment, reimbursement) |
| `40` | `Account` | `fin_accounts` | String UUID | Asset & liability accounts (bank, cash, credit_card, loan, investment, wallet) |
| `41` | `Category` | `fin_categories` | String UUID | Hierarchical income and expense categories with color, icon, and parent reference |
| `42` | `Budget` | `fin_budgets` | String UUID | Period budgets (monthly, custom) with category limits and rollover support |
| `43` | `Goal` | `fin_goals` | String UUID | Target savings goals with linked accounts, target dates, and monthly contributions |
| `44` | `RecurringRule` | `fin_recurring` | String UUID | Generalized recurrence engine for subscriptions, bills, salaries, and SIPs |
| `45` | `Debt` | `fin_debts` | String UUID | Amortized loans, mortgages, BNPL with interest schedules and EMI tracking |
| `46` | `CategoryRule` | `fin_category_rules` | String UUID | Deterministic merchant and description matching rules for automatic categorization |
| `47` | `CsvMappingProfile` | `fin_import_profiles` | String UUID | Bank-specific CSV header mapping and date/amount parsing profiles |
| `48` | `SplitGroup` | `fin_split_groups` | String UUID | Group expense containers with participant rosters and trip mode metadata |
| `49` | `SplitEntry` | `fin_split_entries` | String UUID | Multi-way split transactions with payer, shares, and settlement status |
| — | Untyped Key-Value | `fin_settings` | String | Preferences: base currency, lock timeout, privacy flags, home card ordering |
| — | Untyped Key-Value | `fin_audit_log` | ISO Timestamp | Append-only ledger of security events, migrations, and schema changes |

### 8.3 Specialized Intelligence & Calculation Engines

1. **Forecast Engine (`engine/forecast.dart`)**:
   - Computes deterministic 30-day forward projections of cash flow.
   - Evaluates confirmed recurring obligations, historical median variable spending, and planned income.
   - Generates confidence intervals with clear natural-language summaries.
2. **Health Score Engine (`engine/health_score.dart`)**:
   - 100-point composite scoring evaluated across 5 key pillars:
     1. Savings Rate (30 pts)
     2. Emergency Fund Runway (25 pts)
     3. Debt-to-Income / Credit Utilisation (20 pts)
     4. Budget Adherence (15 pts)
     5. Goal Pacing (10 pts)
   - Identifies weakest area and recommends actionable next milestones.
3. **Insights Engine (`engine/insights.dart`)**:
   - 11 deterministic rule generators analyzing transaction frequency, duplicate charges (same amount/merchant $\le 24$h), category spikes ($> +20\%$ and $> \text{\textrupee}500$), large transactions ($> 3\times$ median), subscription creep, and bill collision risks.
   - Outputs structured `Insight` objects with stable keys for persistent dismissal.
4. **What-If Cockpit (`engine/what_if.dart`)**:
   - Answers purchase affordability queries before spending: "Can I afford $\text{\textrupee}50,000$ for a phone?".
   - Categorizes outcomes into: `Comfortable`, `Tight`, `Not Now`, and calculates exact `months_to_save`.
5. **Reports Engine (`engine/reports.dart`)**:
   - Monthly and multi-month trend analysis (3, 6, 12 months).
   - Category breakdowns, merchant rankings, and RFC 4180 compliant CSV exports with proper comma and quote escaping.
6. **Capture Engine (`engine/capture_engine.dart`)**:
   - **RFC 4180 CSV Tokenizer**: Parses arbitrary bank statements with auto-detected delimiters (comma, semicolon, tab).
   - **Transfer Pair Detection**: Auto-detects complementary debits and credits across accounts within 2 days.
   - **Receipt Capture**: Stores camera/gallery images under `receipts/{txId}/` with on-device OCR pre-fill.
   - **SMS Parser (Android)**: Local template-based regex parsing for bank/UPI SMS notifications, creating review drafts without auto-posting.
7. **Query Engine (`engine/query.dart`)**:
   - Pure-Dart deterministic execution for natural-language queries (`sum`, `count`, `avg`, `list`, `top`).
   - Supports filtering across period ranges, accounts, categories, and tags.
8. **Split & Settle Engine (`engine/split_settle_engine.dart`)**:
   - Paise-accurate equal splits with deterministic remainder distribution.
   - Greedy minimal-transactions algorithm reducing $N$-person debts to at most $N-1$ bilateral transfers.
   - Trip mode reports tracking per-person contributions and net balances.

### 8.4 AI & Privacy Safeguards (§6.9)

Commander enforces strict data privacy invariants for all AI and cloud interactions:
- **Zero Raw Financial Data to Cloud**: Raw transaction histories, balances, and account numbers are never sent to external LLMs.
- **Deterministic Local Fast Paths**: Financial queries, What-If calculations, and transfers are executed entirely on-device by Dart engines.
- **Normalized Merchant Privacy**: When AI category suggestions are requested, only stripped merchant names (e.g., "Swiggy", "Uber") are transmitted; amounts and dates are excluded.
- **Kill-Switch Privacy Toggle**: Setting `ai_finance_privacy = false` immediately empties all financial context passed into `ai_context.dart`.
- **Mandatory Write Confirmations**: All actions creating or modifying financial records require explicit user confirmation.

### 8.5 Security, Hardware Encryption & App Lock

- **`FinanceLockService`**: Integrates `local_auth` for biometric (fingerprint/face) and device-PIN authentication. Features configurable idle timeout, background lock on app pause, and privacy overlay protection.
- **`FinanceEncryptionService`**: AES-256 binary encryption of all 11 finance Hive boxes using a 32-byte cryptographic key secured within `FlutterSecureStorage`. Migration uses a **copy, verify checksums, switch** pattern that retains unencrypted backup boxes until confirmed by the user.
- **Data Privacy & Wipe (`FinancePrivacyDataPage`)**: Complete local storage transparency, permission toggles (notifications, camera, SMS, storage), full JSON/CSV export, and typed "DELETE" safety-gated complete data wipe.
