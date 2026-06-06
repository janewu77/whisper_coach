# Frontend Test Plan

Source: `IMPLEMENTATION.md` §5. Pairs with `../backend/TEST.md`.

---

## 1. Overview

| Item | Detail |
|---|---|
| Framework | `flutter_test` + `mockito` / `http_mock_adapter` (for dio) |
| Run all tests | `flutter test` |
| Run single file | `flutter test test/api_test.dart` |
| Principle | **No real network requests.** Isolate via mock dio adapter or injected fake `Api` class |

---

## 2. Test Setup

### 2.1 Dev dependencies (`pubspec.yaml`)

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0        # mockito code generation
  http_mock_adapter: ^0.6.0   # dio request interception
```

### 2.2 Mock injection pattern

Pick one approach and use it consistently:

**Option A — Fake `Api` class** (recommended; simple)
```dart
class FakeApi implements Api {
  @override
  Future<Lineup> generateLineup(int matchId, {String? strength}) async =>
      Lineup(formation: '4-3-3', lineup: [], reason: 'stub');
  // remaining methods return fixed values
}
```
Pass `FakeApi` via dependency injection or `Provider`.

**Option B — `http_mock_adapter`** (use when testing the dio layer itself)
```dart
final dioAdapter = DioAdapter(dio: dio);
dioAdapter.onPost('/api/matches', (server) => server.reply(201, {...}));
```

---

## 3. Test Cases

### 3.1 `test/model_test.dart` — Model serialization

Use real backend contract payloads for round-trip tests. Catches camelCase/snake_case drift.

| ID | Model | Test |
|---|---|---|
| MOD-01 | `Team` | `fromJson` parses `{id, name}`; `toJson` round-trips to same structure |
| MOD-02 | `Player` | `fromJson` parses `{id, team_id, name, number, preferred_position}` including null fields |
| MOD-03 | `Match` | `fromJson` parses full match object with nested lineup and notes array |
| MOD-04 | `Lineup` | `fromJson` parses `{formation, lineup: [{player, position}], reason}` |
| MOD-05 | `Suggestion` | `fromJson` parses `{substitutions: [{out, in}], position_changes: [{player, to}], reason}` |
| MOD-06 | `Summary` | `fromJson` parses `{summary, player_performance: [{player, rating, comment}], improvements: [str]}` |
| MOD-07 | snake_case mapping | Backend field `team_id` maps to Dart field `teamId` across all models |

---

### 3.2 `test/api_test.dart` — API client

Uses `http_mock_adapter` to intercept dio requests.

| ID | Method | Assertions |
|---|---|---|
| API-01 | `extractRoster(file)` | Issues `POST /api/roster/extract`; Content-Type is multipart; returns parsed `{teamId, players}` |
| API-02 | `getTeam(id)` | Issues `GET /api/teams/{id}`; returns `Team` object |
| API-03 | `createMatch(input)` | Issues `POST /api/matches`; body includes `team_id`, `opponent`; returns `Match` |
| API-04 | `getMatch(id)` | Issues `GET /api/matches/{id}`; returns `Match` with lineup and notes |
| API-05 | `generateLineup(matchId)` | Issues `POST /api/matches/{id}/lineup`; returns `Lineup` |
| API-06 | `sendNote(matchId, input)` | Issues `POST /api/matches/{id}/notes`; body has `kind` and `content`; returns `Suggestion` |
| API-07 | `getSummary(matchId)` | Issues `POST /api/matches/{id}/summary`; returns `Summary` |
| API-08 | Backend returns `{detail}` error | Method throws or returns an error (define behavior, then test it) |
| API-09 | Network timeout | Throws exception catchable by UI layer |

---

### 3.3 `test/pitch_view_test.dart` — Pitch view widget

| ID | Description | Assertions |
|---|---|---|
| PV-01 | Lineup with 11 players | Renders 11 player chips |
| PV-02 | Empty lineup (0 players) | Widget renders without exception |
| PV-03 | Tap a player chip | `onPlayerTap` callback fires with the correct player object |
| PV-04 | Formation label | Formation string (e.g. "4-3-3") is visible on screen |

---

### 3.4 `test/home_screen_test.dart` — Home screen widget

Inject `FakeApi`.

| ID | Description | Assertions |
|---|---|---|
| HS-01 | Fill opponent + location + date → tap Generate | `createMatch` then `generateLineup` called in order |
| HS-02 | Successful generation | Navigates to `PitchScreen` (pushed onto `Navigator`) |
| HS-03 | Photo upload succeeds | Player list shown, no errors |
| HS-04 | `createMatch` throws | SnackBar error shown, no crash |
| HS-05 | Required fields empty on submit | Form validation blocks API call |

---

### 3.5 `test/ai_response_card_test.dart` — AI response card widget

| ID | Description | Assertions |
|---|---|---|
| ARC-01 | `Suggestion` with substitutions | "Out" and "In" player names visible |
| ARC-02 | `Suggestion` with position changes | Player name and target position visible |
| ARC-03 | `reason` field | Reason string is visible |
| ARC-04 | Empty substitutions + position changes | Widget renders without crash |

---

### 3.6 `test/smoke_test.dart`

| ID | Description | Assertions |
|---|---|---|
| SMK-01 | App startup | `MaterialApp` renders to Home screen, no uncaught exceptions |
| SMK-02 | All three screen routes | `Navigator.pushNamed` to each route does not throw |

---

## 4. Manual QA Checklist

Run end-to-end against a live backend (`http://localhost:8000`) before demo:

- [ ] Upload team photo → player list shown correctly
- [ ] Fill opponent, location, date → create match succeeds
- [ ] Tap Generate Lineup → Pitch screen shows formation label and AI reason
- [ ] Tap a player icon on pitch → Live notes sheet opens with player pre-selected
- [ ] Type a text note → Send → suggestion card renders substitutions/changes
- [ ] Tap voice button → speak → text auto-filled in note field
- [ ] Tap End Match → summary shown with per-player ratings and improvement points

---

## 5. Known Test Boundaries

| Scenario | Approach |
|---|---|
| `speech_to_text` permissions and real voice recognition | Not covered by automated tests; manual QA only |
| `image_picker` camera/gallery permissions | Widget tests use a mock file object |
| Complex pitch gestures (drag-to-reorder) | Basic tap covered; complex interactions verified manually |
