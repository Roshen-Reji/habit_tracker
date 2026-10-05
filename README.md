# Commander Habit Tracker

Commander Habit Tracker is a comprehensive, multi-functional Flutter application designed to help you build better habits, manage your finances, organize inspirational speeches, and enjoy music. 

> 📖 **Full System Architecture & Technical Documentation:** For an in-depth breakdown of the database schemas, hybrid AI engine, feature lifecycles, and directory architecture, see [APP_DOCUMENTATION.md](file:///d:/Roshen/Habit%20Tracker/habit_tracker/APP_DOCUMENTATION.md).

## Features

This application combines multiple productivity and lifestyle tools into one cohesive experience:

1. **Mission/Goal Tracking**
   - Create, manage, and track your daily habits and goals.
   - Categorize your goals and track progress over time.
   - Persistent local storage using Hive.

2. **Finance Manager**
   - Track your expenses, income, and transactions.
   - Manage your financial assets with "Asset Vaults".
   - Local, secure, offline-first finance tracking.

3. **Music Library & Player**
   - Integrated music player.
   - Play audio using local device storage.
   - YouTube video integration capabilities.

4. **Speech Vault**
   - Store and organize motivational or important speeches.
   - Dedicated library for your most valuable audio/video inspiration.

5. **Wearables & Galaxy Watch 7 (MVP 4.1)**
   - Honest health telemetry synced directly with Samsung Health / Health Connect.
   - Automatic sleep session tracking, wake-up verification, and exercise burn ledger credit.
   - Pure-Dart `CalorieReconciler` preventing double-counting with manual burn logs.
   - Samsung Health AGEs index manual logging with biological markers and trend curves.
   - Idempotent `XpLedger` awarding daily health XP (capped at 40 XP/day).

6. **Document Reader & Library**
   - Distraction-free PDF reader with continuous vertical reading, zoom, and night mode.
   - Persistent page progress tracking with auto-resume.
   - Protected document storage under app documents directory (`app_docs/pdf_books/`).

## Getting Started

### Prerequisites

To run and test this application, you will need the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version >=3.0.0 <4.0.0)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio or Visual Studio Code (with Flutter/Dart extensions)
- An Android/iOS Emulator or a physical device connected via USB/Wi-Fi.

### Installation

1. **Clone or Download the Repository:**
   Navigate to the project directory:
   ```bash
   cd path/to/habit_tracker
   ```

2. **Install Dependencies:**
   Run the following command to fetch all required packages:
   ```bash
   flutter pub get
   ```

3. **Run Code Generation (if necessary):**
   Since this project uses Hive type adapters (`hive_generator`), you may need to run the build runner to generate adapter files if they are missing or if you modify the models:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

## How to Test the App

1. **Start an Emulator or Connect a Device:**
   Ensure you have a device available for Flutter to deploy to. You can verify this by running:
   ```bash
   flutter devices
   ```

2. **Run the App:**
   Execute the following command to run the app in debug mode:
   ```bash
   flutter run
   ```
   
   If you want to test on a specific device, use the `-d` flag:
   ```bash
   flutter run -d <device_id>
   ```

3. **Testing Functionality:**
   - **Goals:** Navigate to the Goals/Mission page, try adding a new goal, check it off, and restart the app to ensure Hive is saving the data locally.
   - **Finance:** Add dummy transactions and check if the Asset Vaults update correctly.
   - **Music/Speech:** Grant necessary storage permissions (handled via `permission_handler`) to allow the app to scan for local audio files.

## Project Structure

- `lib/main.dart` - The entry point of the application. It initializes Hive, registers data adapters, and runs the main `CommanderApp` widget.
- `lib/models/` - Contains data models and Hive Type Adapters (e.g., `goals.dart`, `finance_model.dart`, `speech_model.dart`).
- `lib/screens/` - Contains the UI for different features (e.g., `home_page.dart`, `finance_page.dart`, `music_player_page.dart`).
- `lib/services/` - Contains business logic and service wrappers.
- `lib/widgets/` - Reusable UI components.

## Data Storage
All data is stored locally on the device using [Hive](https://pub.dev/packages/hive), a lightweight and blazing fast key-value database written in pure Dart. The app does not require an active internet connection for core functionality (unless using YouTube or Health AI features).

## Troubleshooting

- **Black Screen / Hive Errors:** If the app fails to start due to a Hive exception, it might be due to a schema change. You can clear the app data on your emulator/device to reset the Hive boxes.
- **Permission Denied:** The app requires storage permissions to access local music. Ensure permissions are granted in the device settings if the music player fails to load.
