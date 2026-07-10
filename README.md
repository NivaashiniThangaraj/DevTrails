# DevTrails — Aegis

**Aegis** is an AI-powered parametric income-protection app for gig-delivery
workers. It monitors weather, air quality and disruption risk, quotes
parametric insurance plans, and automates payouts when a covered disruption
hits — all from a mobile-first Flutter app.

This repository is a **monorepo** with two parts:

| Folder            | What it is                                                        | Hosted on GitHub Pages? |
| ----------------- | ----------------------------------------------------------------- | :---------------------: |
| `aegis_app/`      | **Flutter frontend** (mobile + **web**) — the part deployed here  |           ✅ Yes         |
| `aegis_backend/`  | Python (FastAPI/Flask) backend API — reference only; **not used** by the web demo |           ❌ No          |

> 🌐 **Live web app:** https://nivaashinithangaraj.github.io/DevTrails/
>
> The deployed web app is a **fully self-contained demo**: it runs entirely
> offline using **hardcoded sample data** (workers, weather, alerts, claims,
> risk scores and the AI chat). No backend or API keys are required.

---

## Repository structure

```
DevTrails/
├── aegis_app/          # Flutter app (frontend)
│   ├── lib/            # Dart source
│   ├── web/            # Web entry (index.html, manifest, icons)
│   └── README.md       # Frontend-specific docs & deploy steps
├── aegis_backend/      # Python backend API (deployed on Render)
└── .github/
    └── workflows/
        └── deploy.yml  # Builds the Flutter web app → GitHub Pages
```

## What is deployed to GitHub Pages

Only the **Flutter web build** of `aegis_app/` is published. The backend stays
on Render; this repo contains no secrets and no server code in the deployed
artifact.

Because the repo lives at `/DevTrails/`, the web app is built with
`--base-href "/DevTrails/"` so all assets resolve correctly under the
sub-path.

## Quick start (frontend only)

```bash
cd aegis_app
flutter pub get
flutter run -d chrome            # local dev on the web
# or a phone/emulator:
flutter run
```

See [`aegis_app/README.md`](aegis_app/README.md) for full frontend docs,
configuration, and how the GitHub Pages deployment works.

## Deploying to GitHub Pages

Deployment is fully automated via GitHub Actions:

1. Push to the `main` branch (or run the workflow manually).
2. `.github/workflows/deploy.yml` builds the web app and publishes it to the
   `gh-pages` branch / GitHub Pages.
3. In **Settings → Pages**, set *Source* to **GitHub Actions** (already wired
   by the workflow).

No manual build artifacts are committed — everything is produced in CI.

## Notes & limitations on the web build

- The web demo uses **hardcoded data** (see `aegis_app/lib/services/api_service.dart`
  and `chat_service.dart`), so it works with no network or backend.
- Native **push notifications**, **camera capture**, and **background GPS** are
  unavailable in a browser. The code degrades gracefully (notifications become
  silent no-ops; the claim photo picker falls back to a file chooser; location
  uses a stubbed demo position).
