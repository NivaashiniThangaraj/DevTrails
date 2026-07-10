# Aegis — Flutter frontend

AI-powered parametric income protection for gig-delivery workers. This is the
**frontend** of the DevTrails project and the part that is deployed to
[GitHub Pages](https://nivaashinithangaraj.github.io/DevTrails/).

- **Framework:** Flutter (Dart)
- **Platforms:** Android, iOS, and **Web** (deployed)
- **Backend:** `https://aegis-backend-i4z5.onrender.com` (deployed separately)

## Features

- Phone/OTP auth and worker KYC
- Live weather + AI risk scoring (backend ML model)
- Parametric insurance plan selection & subscription
- Real-time disruption alerts and automated payouts
- Claim submission with geo + photo verification
- In-app AI assistant (Aegis AI) backed by the backend chat endpoint

## Local development

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- For web: Chrome (the `flutter run -d chrome` target)

### Run

```bash
flutter pub get

# Web (what is deployed to GitHub Pages)
flutter run -d chrome

# Mobile (emulator / physical device)
flutter run
```

### Build a production web bundle

```bash
# The repo is served from /DevTrails/, so the base href is required:
flutter build web --base-href "/DevTrails/"
# Output: build/web/
```

To preview the production build locally:

```bash
cd build/web
python3 -m http.server 8000
# open http://localhost:8000/   (serve from build/web so the base href matches)
```

## GitHub Pages deployment

The web app is built and published automatically by
[`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) on every push
to `main`.

Flow:

1. CI checks out the repo and sets up Flutter (stable).
2. `flutter pub get`
3. `flutter build web --base-href "/DevTrails/"` (plus a `.nojekyll` so Pages
   does not strip any asset files).
4. The `build/web` folder is uploaded as a Pages artifact and deployed.

To publish manually:

- In the repo **Settings → Pages**, set *Source* to **GitHub Actions**.
- The site goes live at `https://nivaashinithangaraj.github.io/DevTrails/`.

> Changing the repository name requires updating the `--base-href` in both this
> README and `.github/workflows/deploy.yml` to match `/<new-repo>/`.

## Configuration

The web app is a **self-contained offline demo**. All data is hardcoded in:

- `lib/services/api_service.dart` — auth, profile, risk score, alerts, claims,
  weather (returns sample `Worker` / `RiskResult` / `DisruptionAlert` /
  `Claim` / `WeatherData` objects; uses `risk_engine.dart` for a real risk calc).
- `lib/services/chat_service.dart` — canned Aegis AI replies.

No backend URL, API keys, or secrets are required to build or run the app.

## Web-specific behavior

This app was originally mobile-first. The following are handled so the **web**
build compiles and runs cleanly:

| Capability            | Mobile                        | Web                                  |
| --------------------- | ----------------------------- | ------------------------------------ |
| Notifications         | Native push (`flutter_local_notifications`) | Silent no-op (`notification_service_web.dart`) |
| Device ID             | Android/iOS device info       | Generic web client tag (`platform_utils.dart`) |
| Location              | Real GPS + mock detection     | Stubbed demo position (`location_service.dart`) |
| Claim photo           | Camera capture                | File picker fallback                |

Implementation details:

- `lib/services/notification_service.dart` — platform-aware dispatcher
  (`notification_service_io.dart` ↔ `notification_service_web.dart`).
- `lib/services/platform_utils.dart` — `kIsWeb`-based device id.
- `lib/services/location_service.dart` — `kIsWeb` short-circuits for the web.

## Project layout

```
lib/
├── main.dart                 # App entry, routes
├── models/models.dart
├── providers/aegis_provider.dart
├── services/
│   ├── api_service.dart       # Backend REST client
│   ├── chat_service.dart      # Aegis AI chat client
│   ├── location_service.dart
│   ├── notification_service*.dart
│   ├── platform_utils.dart
│   └── risk_engine.dart
├── screens/                   # Onboarding, dashboard, plan, chat, alerts…
├── theme/app_theme.dart
└── widgets/common_widgets.dart
```
