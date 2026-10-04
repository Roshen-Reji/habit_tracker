# Commander Habit Tracker: MVP 2 Manual QA & Device Verification Guide

This document lists all device-only, hardware-dependent, and permission-sensitive checks for Commander Habit Tracker (MVP 2). These flows require a physical Android device or emulator with appropriate capabilities.

---

## 1. Hive Data Backup & Upgrade Procedure

Before running the MVP 2 build over an existing MVP 1 installation, take a backup of the app's internal Hive data directory:

### Backup Procedure
1. Connect device with USB debugging enabled.
2. Run via ADB:
   ```bash
   # Create a local backup directory
   mkdir -p ./backup_mvp1_hive

   # Backup app data directory
   adb backup -f ./backup_mvp1_hive/habit_tracker_backup.ab -noapk com.example.habit_tracker
   
   # Or directly pull from app internal storage (on rooted device or debug builds):
   adb shell "run-as com.example.habit_tracker cp -r /data/data/com.example.habit_tracker/app_flutter /sdcard/Download/hive_backup"
   adb pull /sdcard/Download/hive_backup ./backup_mvp1_hive/
   ```
3. Install and launch the MVP 2 build.
4. Verify:
   - All existing daily/weekly/monthly goals (`mission_box_v4`) are intact.
   - All legacy finance transactions (`finance_transactions`) and vaults (`finance_vaults`) persist.
   - XP history (`xp_history`) and Diet logs (`diet_logs`) are retained.
   - No crashes or `HiveError` migration exceptions occur on startup.

---

## 2. Shell & Navigation Layout (Small & Large Screens)

### Test Screens:
- Compact screen: 360 x 640 dp (e.g. Nexus 5 / small phone)
- Modern standard screen: 412 x 915 dp (e.g. Pixel 7 / Pixel 8)

### Verification Steps:
1. Launch the app and verify the bottom navigation bar height is ~62px (slender modern profile).
2. Check that the bottom navigation bar displays exactly **3 tabs**:
   - Tab 0: Home (Wallet Card Stack)
   - Tab 1: Tasks / Missions / Finance
   - Tab 2: Diet & Calories
3. Verify that the Global Floating Mini Player and Home Chat FAB hover smoothly above the navigation bar without clipping or dead whitespace.
4. Scroll to the very bottom of the card stack and task list: confirm the last item is fully reachable and visible above the nav bar.

---

## 3. Gemini Model Chain & Settings Test Connection

### Verification Steps:
1. Navigate to Settings (gear icon on Home screen).
2. Verify the **Gemini AI Configuration** section:
   - "Active Model": shows current resolved model (e.g. `gemini-3.8-flash` or `gemini-2.5-flash`).
   - "Custom Model Override": optional input to manually specify an alternative model ID.
3. Tap **Test Connection**:
   - With valid API key in environment or settings: shows green confirmation banner with model name and status 200 OK.
   - With invalid API key: shows guidance to update key.
4. Try voice / chat NLP with music commands:
   - "Pause music" / "Play next song" / "Gaana badlo".
   - Confirm proper execution through `NowPlayingService`.

---

## 4. SIP Debits on Due Day

### Verification Steps:
1. Navigate to Tasks -> Finance -> Planner.
2. Add a test SIP with:
   - Name: `Index Fund SIP`
   - Amount: `₹5,000`
   - Due Day: Today's date (or next debit date).
3. Trigger due check or advance device system clock to the due day.
4. Restart or resume the app.
5. Verify:
   - A local notification is received: "SIP Debited: Index Fund SIP for ₹5,000".
   - An expense transaction is posted with category "Investment" and date matching the due date.
   - Overview net balance drops by ₹5,000 once.
   - PLAN tab reflects next month's due date without double-counting.

---

## 5. Android MediaSession Bridge & Now Playing Detection

### Prerequisites:
- Android 8.0+ device with Spotify, YouTube Music, or other media player installed.

### Verification Steps:
1. Open Commander Habit Tracker and scroll to the **Music Controller** card.
2. If Notification Listener access is not yet granted:
   - Card displays: "Notification access required to detect playing music".
   - Tap "Enable Access": opens Android System Notification Access settings directly to Habit Tracker.
   - Toggle permission ON and return to app.
3. Start playback in Spotify or YouTube Music.
4. Return to Habit Tracker:
   - Music card immediately shows: Song Title, Artist Name, Album Art, and Play/Pause state.
   - Mini Player bar appears floating above the bottom navigation bar.
5. Tap Play/Pause on the card: media playback on Spotify/YouTube Music pauses and resumes.
6. Tap Next / Previous: tracks skip forward and backward accurately.
7. Tap the mini player to open the **Expanded Player Sheet**:
   - Displays full-resolution artwork, WobblySlider seek bar, and playback controls.
   - Dynamic accent background extracts dominant color from active album art.

---

## 6. Health & Wellness (Medicine, Weight, and Summary)

### Medicine Reminders:
1. Tap the Medicine Reminder card or open Health Page (Medicine tab).
2. Tap "+ Add Medication":
   - Name: `Amoxicillin`
   - Dose: `500mg`
   - Time: 2 minutes in the future.
   - Weekdays: Daily.
3. On Android 12+, if exact alarm permission is denied:
   - Verify amber banner displays on card: "Inexact reminders: allow exact alarms in Settings".
   - Grant exact alarms permission in system settings.
4. Wait for scheduled notification:
   - Confirm notification banner pops with sound and vibration.
   - Actions appear: **Taken** and **Snooze (10 min)**.
   - Tap "Taken": notification dismisses, medicine log records dose as taken, and card progress updates to 100%.

### Weight Journey:
1. Tap Weight Journey card or switch to Weight tab on Health Page.
2. Set Start Weight (e.g. 75 kg) and Goal Weight (e.g. 70 kg).
3. Log two weigh-in entries across distinct days:
   - Confirm `fl_chart` sparkline renders smoothly on the card.
   - Health Page displays interactive full-screen weight curve.

### Health Summary:
1. Verify Health Summary card computes composite score (0-100):
   - 35 pts for Calorie balance.
   - 35 pts for Medicine adherence.
   - 30 pts for Daily health missions.
   - Score badge displays colored rating (green >= 80, amber >= 50, red < 50).

---

## 7. Private Journal (Hardware Encryption & Biometrics)

### Verification Steps:
1. Tap "Create" on the Private Journal card:
   - Opens `JournalEditorPage` immediately without requiring authentication.
   - Test rich text editing: bold, italic, checklists, bullet points, and headers.
   - Add `#reflection` and `#weekly` tags.
   - Tap back: confirms entry is saved securely with AES-256 cipher.
2. Tap "View Vault" on the Private Journal card:
   - Prompts for device fingerprint, face unlock, or device PIN/pattern.
   - On successful biometric scan: opens `JournalListPage` displaying saved entries.
   - Tap top-right lock button: immediately locks vault.
3. Auto-Lock & Backgrounding:
   - Unlock vault and press device Home button to send app to background.
   - Return to app: confirm vault is automatically re-locked and requires authentication again.
   - Wait 60 seconds without interaction: confirm auto-lock triggers.

---

## 8. Brainstorm & Document Reader (PDFs)

### Brainstorm Vault:
1. Tap "Add Idea" on the Brainstorm card:
   - Enter Title and multi-line Description.
   - Tap "Save Idea": updates card immediately.
2. Tap "View All": opens `BrainstormPage` with search filter, edit dialog, and deletion confirmation.

### Document Reader:
1. Tap "Configure PDF Folders" or gear icon in Library.
2. Grant "All-files access" (`MANAGE_EXTERNAL_STORAGE`) when prompted.
3. Select a folder on device storage containing PDF files.
4. Verify:
   - Scanner indexes `.pdf` files recursively.
   - Up to 3 book covers appear on the Home screen Reader card.
5. Tap a book:
   - Opens `PdfReaderPage` with continuous scrolling.
   - Test bookmarking current page (bookmark icon turns blue).
   - Test Night Mode toggle (inverts/dims document colors for night reading).
   - Test page slider to jump to specific pages.
   - Exit reader and reopen: confirms last page is remembered and resumed.

---

## 9. Money OS (MVP 3) Device-Only & Hardware Verification

This section covers device-only hardware tests, OS permissions, biometric sensors, camera input, and background lifecycle for the Money OS subsystem.

### 9.1 App Lock & Biometrics (local_auth)
1. **Enable App Lock**:
   - Open Money tab -> Settings icon -> "Privacy & Data" (or AI & Privacy page).
   - Under "Security & App Lock", toggle **Lock Money on App Launch** ON.
   - Choose timeout: "Immediately" or "After 1 minute".
2. **Biometric Unlock Test**:
   - Background the app and return immediately (or wait for the timeout).
   - Verify: The screen displays the biometric shield overlay ("Money OS Locked").
   - Authenticate with fingerprint or face: screen unlocks instantly.
   - Test "Use Device PIN": authenticate with system PIN/pattern fallback.
3. **App Switcher Privacy**:
   - Open Android Recent Apps / Task Switcher.
   - Verify Money OS screen content is obscured or protected by the lock overlay.

### 9.2 Camera & Receipt Attachment
1. **Camera Capture**:
   - Open Transactions tab -> Tap "+" (New Transaction).
   - Under "Receipts", tap **Take Photo**.
   - Grant Android Camera permission when prompted.
   - Snap a photo of a physical receipt and accept.
   - Verify thumbnail strip renders the image with a remove (x) badge.
2. **Gallery Picker**:
   - Tap **Gallery** and pick an image.
   - Save the transaction.
   - Reopen the transaction from the list: verify attached receipts are preserved and loaded from `receipts/{txId}/`.

### 9.3 SMS Transaction Parser (Android-Only)
1. **SMS Permission**:
   - Open Transactions tab -> Tap 3-dot overflow on search bar -> "Import from SMS".
   - Review the explanation dialog ensuring no data leaves the device.
   - Grant SMS permission.
2. **Draft Parsing**:
   - Verify incoming bank/UPI alerts (HDFC, SBI, ICICI, Axis, Paytm, GPay) generate review drafts:
     - Correct amount, debit/credit direction, and merchant/beneficiary.
     - Account number tail (last 4 digits) matched to an existing account.
   - Confirm: drafts are never auto-posted without explicit user review.

### 9.4 Bill & Recurring Notifications (Exact Alarms)
1. **Bill Reminders**:
   - Open Recurring / Bills -> Add a test bill due tomorrow with reminder set to "1 day before at 09:00".
   - Confirm notification permission and exact alarm permission on Android 12+.
   - Verify notification triggers at the scheduled time with the bill name and amount.
   - Tap notification: deep-links directly into the Money OS Recurring tab.

### 9.5 CSV RFC 4180 Export & Share Plus
1. **Export Execution**:
   - Open Money tab -> Reports -> Export CSV (or Settings -> Privacy & Data -> Export All Data).
   - Verify: Android system share sheet appears (`share_plus`).
   - Share to Google Drive, Files, or email.
   - Inspect the exported CSV in Excel or text editor:
     - Verify RFC 4180 compliance (fields containing commas or linebreaks are properly quoted: `"..."`).
     - Verify paise precision and column headers (`Date`, `Title`, `Amount`, `Kind`, `Category`, `Account`).

### 9.6 At-Rest AES-256 Encryption Migration
1. **Encryption Enablement**:
   - In Settings -> Privacy & Data, tap "Enable At-Rest Encryption".
   - Verify:
     - A 32-byte key is generated and stored in Android Keystore via `FlutterSecureStorage`.
     - All 11 Hive boxes are duplicated into encrypted format with verification checksums.
     - The old unencrypted boxes are retained as a backup until the user taps "Delete Backup".
2. **Failure Injection Safety**:
   - If key retrieval fails or process is interrupted, the app falls back safely to the verified backup boxes without data loss.

### 9.7 Complete Data Wipe (P13-4)
1. **Safety Gating**:
   - In Settings -> Privacy & Data -> Danger Zone, tap "Delete All Finance Data".
   - Notice the prompt offering "Export JSON Backup First".
   - The deletion dialog requires explicitly typing the uppercase word `"DELETE"`.
   - Tap "Confirm Delete":
     - All 11 finance Hive boxes are erased and cleared from storage.
     - Local receipts directory is wiped.
     - `fin_schema_version` is reset.
     - App navigates back cleanly with empty ledger state.
