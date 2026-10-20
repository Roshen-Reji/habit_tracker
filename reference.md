### Architectural & Visual Overhaul Summary

1. **Home Screen Expandable Widget Cluster (Video Reference):** Your home screen cards in `lib/screens/dashboard_view.dart` and `lib/features/home/cards/` will adopt the OxygenOS/ColorOS smart-folder expansion mechanics shown in the video. Compact 2x2 summary tiles on the home grid (like the circular progress step counter `993 / 702 m` and grouped quick-tiles) will use an interruptible spring container-transform to expand into a floating frosted-backdrop modal. Inside the expanded view, cards follow the exact 3-tier bento hierarchy: a dark navy `AI Daily` insight header card, a high-contrast light `Steps / Progress` wide card with a linear goal bar, and two bottom 1x1 square action cards with pill buttons and concentric ripple rings.


2. **Strict Monochrome Mode (Zero Chromatic Bleed Except Alerts):** In `lib/core/theme/app_colors.dart` and `lib/core/theme/app_theme.dart`, enabling Monochrome Mode will override all sector accent colors, chart gradients, and progress bars into pure grayscale (`#000000`, `#121212`, `#1E1E1E`, `#8E8E93`, `#FFFFFF`), reserving color exclusively for semantic `error` (`#FF3B30`) and `warning` (`#FF9F0A`) alerts.


3. **Samsung Health Goal & Task Completion Animations:** Completing a task, habit, or daily calorie/step target will trigger a multi-stage physics celebration: elastic ring overshoot, radial particle burst, morphing checkmark squircle, and tiered haptic feedback.
4. **Alarm & Reminder System Fix:** The silent/failing alarms in `lib/data/services/notification_service.dart`, `lib/data/services/reminder_scheduler.dart`, and `android/app/src/main/AndroidManifest.xml` will be fixed by registering exact alarm permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`), initializing local timezones properly, switching to `AndroidScheduleMode.exactAllowWhileIdle`, and re-registering pending alarms on app boot.


5. **AI Vision Rate-Limit Fix & Multi-Intent Compound Parser (`"orange juice 20rs 200ml"`):**
* **"Omni Rate Exceeded" Fix:** `lib/data/services/gemini_client.dart` will compress and resize images on-device (`maxWidth: 512`, `quality: 70`) before base64 encoding, implement automatic model fallback (`gemini-2.5-flash` $\rightarrow$ `gemini-2.0-flash` $\rightarrow$ `gemini-1.5-flash`) with exponential backoff on HTTP 429, and fall back to an on-device nutrition estimator if offline or rate-limited.


* **Compound Input Fix:** `lib/data/services/ai_service.dart` will stop treating Finance and Diet intents as mutually exclusive. Sending `"orange juice 20rs 200ml"` will run parallel domain extractors—logging **₹20** to Finance (`FinanceRepository`) **AND** **200ml Orange Juice (~90 kcal, 21g carbs, +200ml water)** to Diet (`DietRepository`) simultaneously.




6. **3D Frosted Floating Navigation Bar:** `lib/widgets/bottom_nav_bar.dart` and `lib/core/widgets/glass_tab_bar.dart` will be rebuilt as a persistent floating 3D frosted pill (`BackdropFilter` blur + top specular 3D rim bevel + deep ambient elevation shadow) pinned via `Scaffold(extendBody: true)` so it stays visible over scrolling content across every tab.


7. **Health Tab Redesign (Light & Dark Mode):** `lib/features/health/health_page.dart` and `lib/features/wearables/ui/fitness_tab.dart` will replicate the **Personal Health** and **Walking Steps** Dribbble UI—including the green circular step counter with the horizontal day-tick ruler (`Sat Sun Mon Tue Wed`), the 2x2 bento grid (`Cardiac Rhythm` ECG wave, `Acid/Hydration` dot matrix, `Brain/Sleep Activity` area wave, and circular `Exercise` button), the `Activity` bar chart, and the `Walking steps` spline chart detail screen in both Light and Dark modes.


8. **Mood-Driven Animated Sticker AI Avatar:** `lib/features/home/home_chat.dart` and `lib/features/home/widgets/chat_message_bubble.dart` will replace the static AI chat bubble with a live 60fps `CustomPainter` widget rendering the 12 geometric mood stickers (`Excited`, `Joyful`, `Grateful`, `Energized`, `Sensitive`, `Confused`, `Bored`, `Stressed`, `Angry`, `Insecure`, `Hurt`, `Guilty`). The active character is dynamically selected from your real-time Health, Money, Diet, and Task metrics, with animated blinking eyes, glancing pupils, smiling mouths, and breathing physics.

