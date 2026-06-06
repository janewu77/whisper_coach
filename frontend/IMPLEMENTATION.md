# Frontend Implementation Plan

Flutter app — **three screens only**. Source of truth for scope: `../docs/01_MVP砍刀版.md`. Read `../CLAUDE.md` for the out-of-scope list (no auth, no complex UI).

The REST contract this app consumes lives in `../backend/IMPLEMENTATION.md` § "REST Interface (shared contract)". Treat that as canonical — the section below mirrors it from the client's perspective. If a route changes, update both files.

---

## 1. Stack & layout

- **Flutter** (Dart), Material.
- **http** or **dio** for REST (dio preferred: interceptors + multipart for the photo upload).
- **image_picker** — camera/gallery for the roster photo.
- **speech_to_text** — on-device voice → text for the live notes screen (backend receives text, not audio).
- State: keep it light — `provider` or `ChangeNotifier`/`setState`. No heavy architecture for a 1–2 day build.

Proposed structure:

```
frontend/
  pubspec.yaml
  lib/
    main.dart            # MaterialApp, routes
    config.dart          # API base URL (http://localhost:8000)
    api/
      client.dart        # dio instance + error handling
      api.dart           # typed calls: extractRoster, createMatch, generateLineup, sendNote, getSummary
    models/              # Dart models mirroring backend schemas
      team.dart  player.dart  match.dart  lineup.dart  suggestion.dart  summary.dart
    screens/
      home_screen.dart   # Screen 1: create match
      pitch_screen.dart  # Screen 2: lineup on a pitch
      live_screen.dart   # Screen 3: notes + summary
    widgets/
      pitch_view.dart    # 2D pitch + draggable/tappable player icons
      player_chip.dart
      ai_response_card.dart
  test/
    api_test.dart
    pitch_view_test.dart
    home_screen_test.dart
```

---

## 2. Screens (the only three)

### Screen 1 — Home / Create Match (`home_screen.dart`)
- Button: **Upload team photo** (`image_picker`) → `POST /api/roster/extract` → shows extracted players, returns `team_id`.
- Form: opponent, location, date, optional notes, optional strength (strong/weak) → `POST /api/matches` → `match_id`.
- **Generate lineup** button → `POST /api/matches/{id}/lineup` → navigate to Pitch screen.

### Screen 2 — Pitch (`pitch_screen.dart` + `pitch_view.dart`)
- Renders a simple 2D pitch (`CustomPaint`).
- Player icons positioned by formation/position from the lineup response. Tappable.
- Shows `formation` and the AI `reason`.
- Tapping a player → opens the Live notes sheet pre-targeted at that player.
- **Regenerate** button re-calls the lineup endpoint.

### Screen 3 — Live / Notes (`live_screen.dart`)
- Text field + **voice button** (`speech_to_text` fills the text field).
- Send → `POST /api/matches/{id}/notes` → render `suggestion` (substitutions, position changes, reason) in an `ai_response_card`.
- **End match / Summary** button → `POST /api/matches/{id}/summary` → render summary, per-player ratings, improvements.

---

## 3. API client (mirrors backend contract)

`lib/api/api.dart` exposes one typed method per endpoint:

| Method | Endpoint | Returns |
|---|---|---|
| `extractRoster(File image, {String? teamName})` | `POST /api/roster/extract` (multipart) | `{teamId, List<Player>}` |
| `getTeam(int id)` | `GET /api/teams/{id}` | `Team` |
| `createMatch(MatchInput)` | `POST /api/matches` | `Match` |
| `getMatch(int id)` | `GET /api/matches/{id}` | `Match` (incl. lineup, notes) |
| `generateLineup(int matchId, {String? strength})` | `POST /api/matches/{id}/lineup` | `Lineup {formation, lineup[], reason}` |
| `sendNote(int matchId, NoteInput)` | `POST /api/matches/{id}/notes` | `Suggestion {substitutions[], positionChanges[], reason}` |
| `getSummary(int matchId)` | `POST /api/matches/{id}/summary` | `Summary {summary, playerPerformance[], improvements[]}` |

Dart models in `lib/models/` mirror the backend JSON exactly (camelCase in Dart ↔ snake_case JSON via `fromJson`/`toJson`). Errors: read FastAPI `{detail}` and surface a snackbar.

---

## 4. Implementation phases

1. **Scaffold** — `flutter create`, MaterialApp, 3 empty routed screens, `config.dart` base URL.
2. **API client + models** — dio client, all model classes, methods wired (point at backend `/docs` to verify shapes). Test against a running backend or stub.
3. **Home screen** — match creation form → `createMatch`; navigate to Pitch with returned id (lineup faked until backend ready).
4. **Pitch view** — `pitch_view.dart` rendering icons from a lineup; wire `generateLineup`.
5. **Roster upload** — `image_picker` + `extractRoster`, show extracted players on Home.
6. **Live screen** — text notes → `sendNote` → response card.
7. **Voice input** — `speech_to_text` into the note field.
8. **Summary** — `getSummary` rendering.
9. **Polish** — loading/error states, empty states, basic theming.

Build screens against the backend OpenAPI (`/docs`); if the backend lags, stub the client to return canned JSON so UI work isn't blocked.

---

## 5. Test plan

Framework: `flutter_test` (+ `mockito`/`http_mock_adapter` for dio). Run: `flutter test` (single: `flutter test test/api_test.dart`).

**Principle:** no real network in tests — mock the dio adapter / inject a fake `Api`.

- **Model (de)serialization**: each model `fromJson`/`toJson` round-trips with sample backend payloads (copy real examples from the contract). Catches camelCase/snake_case drift.
- **API client (mocked)**: each method hits the right path/verb, sends the right body (incl. multipart for `extractRoster`), parses the success body, and maps a `{detail}` error to a thrown/handled error.
- **Widget — pitch_view**: given a lineup with N players, renders N tappable player chips; tap fires the callback with the right player.
- **Widget — home_screen**: filling the form and tapping Generate calls `createMatch` then `generateLineup` (with a mocked Api) and navigates.
- **Widget — ai_response_card**: renders substitutions/position changes/reason from a `Suggestion`.
- **Smoke**: app boots to Home without exceptions.

Manual QA checklist (hackathon demo path): photo → roster shown → create match → lineup on pitch → tap player + voice note → suggestion card → summary. Run once end-to-end against the live backend before demo.
