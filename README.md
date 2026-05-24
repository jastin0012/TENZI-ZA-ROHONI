# Tenzi za Rohoni

Swahili hymns app with favorites, daily notifications, search, and offline data.

## How to Run

1. Ensure Flutter SDK is installed and on PATH.
2. Fetch packages:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

The entry point is `lib/main.dart`, which boots `TenziZaRohoniApp` from `lib/app.dart`.

## Startup & Initialization

- `lib/main.dart`
  - Ensures bindings are initialized.
  - Calls `ServiceLocator.setup()` to register singletons (SharedPreferences, HymnService, FavoritesManager, NotificationService, AdService, etc).
  - Reads initial theme from `SharedPreferences` and passes it to `TenziZaRohoniApp`.
  - After `runApp`, initializes notifications if enabled (permissions and schedules daily reminders).

- `lib/app.dart`
  - Wraps the app in `Bloc` for theme (`ThemeCubit`).
  - Sets light/dark themes and `MainLayout` as `home`.

- `lib/main_layout.dart`
  - Hosts the `RouterOutlet` body and the global banner ad + bottom navigation.

- `lib/router_outlet.dart`
  - Switches between tabs (Home, Favorites, Recent, Settings).
  - Exposes helpers to open detail/notifications screens with guarded navigation.

## Dependency Injection

This project uses a manual `GetIt` service locator defined in `lib/core/service_locator.dart`.

- Access a service via:
  ```dart
  import 'package:get_it/get_it.dart';
  final prefs = GetIt.I<SharedPreferences>();
  ```
- Prefer resolving shared services from `GetIt` instead of creating new instances in UI code.

Note: An `injectable`-based setup (`lib/core/di/injection_container.dart`) exists but is not wired on startup. The active DI path is `core/service_locator.dart`.

## Notifications

- Daily notifications are scheduled at app startup if enabled.
- Users can toggle notifications in `Settings`.
- Notification taps deep-link to hymn details where possible.

## Search

- Unified search screen: `lib/screens/search/search_screen.dart`.
- Available from Home (app bar) and the main layout.

## Theming

- Theme is managed by `ThemeCubit` (light/dark) in `features/settings/presentation`.
- `Settings` toggles persist to `SharedPreferences` and update the active theme.

## Project Structure (selected)

- `lib/app.dart` – MaterialApp and theme wiring
- `lib/main_layout.dart` – primary scaffold, bottom navigation, banner ad
- `lib/router_outlet.dart` – tab routing and navigation helpers
- `lib/core/service_locator.dart` – DI/registrations
- `lib/services/` – app services (hymns, favorites, notifications, ads)
- `lib/screens/` – feature screens (home, favorites, recent, settings, search)
- `lib/widgets/` – reusable UI widgets

## Ads

- `google_mobile_ads` is initialized for supported platforms.
- Banner ad is shown globally at the bottom in `MainLayout`.
- Interstitials are preloaded and only shown on explicit back from details (policy-friendly).

## Notes

- If you change DI, do it in one place. Prefer `core/service_locator.dart` consistently.
- If you enable named routing, wire `onGenerateRoute` with `core/app_router.dart` and use `Navigator.pushNamed` across the app.
