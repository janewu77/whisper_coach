# Whisper Coach — Frontend

**🌐 App: [janewu77.github.io/whisper_coach/app/](https://janewu77.github.io/whisper_coach/app/)**

Flutter client. Upload a team photo, create a match, view the AI lineup, take live voice or text notes for tactical suggestions, and generate a post-match summary.

Repo: [github.com/janewu77/whisper_coach](https://github.com/janewu77/whisper_coach)  
Home page: [janewu77.github.io/whisper_coach/](https://janewu77.github.io/whisper_coach/) (GitHub Pages, repo `docs/`)  
Backend API: [whisper-coach.dacheng.dev](https://whisper-coach.dacheng.dev) · [docs /docs](https://whisper-coach.dacheng.dev/docs)

See [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) for design details and [`docs/ACCEPTANCE.md`](docs/ACCEPTANCE.md) for acceptance scenarios.

## Screens

| Route | Screen | Purpose |
|-------|--------|---------|
| `/` | Match list | Entry point; browse existing matches |
| `/new` | Create match | Upload roster photo, fill opponent info, generate lineup |
| `/pitch` | Pitch | 2D lineup view, formation notes, regenerate |
| `/live` | Live notes | Voice (default) or text → AI suggestions; end match → summary |

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.16 (see `pubspec.yaml`)
- A reachable backend (defaults to production; local setup in [`../backend/README.md`](../backend/README.md))

## Local development

From the `frontend/` directory:

```bash
flutter pub get
flutter run                    # default device
flutter run -d chrome --web-port 3000
```

Change the API base URL in `lib/config.dart`:

```dart
static const String baseUrl = 'https://whisper-coach.dacheng.dev';
// local backend: 'http://localhost:8000'
```

## Build & deploy (Web)

The site is hosted on GitHub Pages (repo `docs/` directory):

| Path | Content | Live URL |
|------|---------|----------|
| `docs/index.html` | Project home page | [janewu77.github.io/whisper_coach/](https://janewu77.github.io/whisper_coach/) |
| `docs/app/` | Flutter Web app | [janewu77.github.io/whisper_coach/app/](https://janewu77.github.io/whisper_coach/app/) |

One-shot build and copy to `docs/app/`:

```bash
sh scripts/build-web-git-docs.sh
```

- base-href: `/whisper_coach/app/`

Manual build:

```bash
flutter build web --release --base-href /whisper_coach/app/
```

## Layout

```
frontend/
  lib/
    main.dart          # routes
    config.dart        # API base URL
    api/               # REST client
    models/            # data models
    screens/           # four screens
    widgets/           # pitch, AI cards, etc.
  scripts/
    build-web-git-docs.sh
```
