# Backend Test Plan

Source: `IMPLEMENTATION.md` §6. Pairs with `../frontend/TEST.md`.

---

## 1. Overview

| Item | Detail |
|---|---|
| Framework | pytest + FastAPI `TestClient` |
| Run all tests | `uv run pytest` |
| Run single test | `uv run pytest app/tests/test_lineup.py::test_generate_returns_formation` |
| CI principle | **No live LLM calls.** All agents replaced by PydanticAI `TestModel` — zero network requests |

---

## 2. Test Setup

### 2.1 Dev dependencies (`pyproject.toml`)

```toml
[tool.uv.dev-dependencies]
pytest       = ">=8"
httpx        = ">=0.27"   # required by FastAPI TestClient
pytest-anyio = ">=0.0"    # if agents use async
```

### 2.2 `app/tests/conftest.py` fixtures

```python
@pytest.fixture
def db():
    # isolated temp SQLite DB per test, auto-cleaned after

@pytest.fixture
def client(db):
    # FastAPI TestClient with temp DB injected

@pytest.fixture
def seeded_team(client):
    # creates one Team + N Players; returns (team_id, [player_id, ...])

@pytest.fixture
def stub_agents(monkeypatch):
    # replaces all three agents with PydanticAI TestModel returning preset structs
```

---

## 3. Test Cases

### 3.1 `test_health.py`

| ID | Description | Expected |
|---|---|---|
| H-01 | `GET /api/health` | 200, body = `{"status": "ok"}` |
| H-02 | OpenAPI schema generation | `GET /openapi.json` 200, all routes present |

---

### 3.2 `test_matches.py`

| ID | Description | Expected |
|---|---|---|
| M-01 | `POST /api/matches` happy path | 201, body contains `id`, `team_id`, `opponent` |
| M-02 | `GET /api/matches/{id}` known id | 200, full match object with empty `lineup` and `notes` |
| M-03 | `GET /api/matches/9999` unknown id | 404, `{"detail": ...}` |
| M-04 | `POST /api/matches` missing `opponent` | 422 |
| M-05 | `POST /api/matches` invalid `strength` value | 422 |

---

### 3.3 `test_lineup.py`

Requires: `stub_agents` + `seeded_team`.

| ID | Description | Expected |
|---|---|---|
| L-01 | `POST /api/matches/{id}/lineup` first call | 200, body has `formation`, `lineup`, `reason`; one Lineup row persisted |
| L-02 | Call again on same match | 200, a second Lineup row created (old row not overwritten) |
| L-03 | Pass optional `strength` override | 200, agent receives correct strength in context |
| L-04 | `POST /api/matches/9999/lineup` unknown match | 404 |

---

### 3.4 `test_roster.py`

Requires: `stub_agents`; fixture directory contains a small test PNG.

| ID | Description | Expected |
|---|---|---|
| R-01 | `POST /api/roster/extract` valid image | 200, body has `team_id` + `players` list; Team + Player rows created in DB |
| R-02 | Optional `team_name` provided | 200, `Team.name` equals provided value |
| R-03 | `GET /api/teams/{team_id}` | 200, returns team + players |
| R-04 | Upload non-image file (e.g. `.txt`) | 422 |
| R-05 | Request missing `image` field | 422 |

---

### 3.5 `test_notes.py`

Requires: match exists with an existing lineup (run L-01 flow first).

| ID | Description | Expected |
|---|---|---|
| N-01 | `POST /api/matches/{id}/notes` text note | 200, body has `note_id` + `suggestion` (`substitutions`/`position_changes`/`reason`); Note row persisted with non-null `ai_response` |
| N-02 | `POST .../notes` on match with no lineup | **409** — lineup must exist first |
| N-03 | `kind = "voice"` note | 200, same handling as N-01 |
| N-04 | Unknown match | 404 |

---

### 3.6 `test_summary.py`

Requires: match with several pre-seeded Note rows.

| ID | Description | Expected |
|---|---|---|
| S-01 | `POST /api/matches/{id}/summary` | 200, body has `summary` (str), `player_performance` (list of `{player, rating, comment}`), `improvements` (list of str) |
| S-02 | Match with no notes | 200, agent returns valid structure (content may be empty) |
| S-03 | Unknown match | 404 |

---

### 3.7 `test_agents.py` — Agent unit tests

Tests hit agent functions directly with `TestModel`, bypassing the HTTP layer.

| ID | Description | Assertions |
|---|---|---|
| A-01 | Roster extractor: input image bytes | Returns `RosterResult`, `players` is a list; prompt contains "name", "number", "position" |
| A-02 | Lineup generator `generate()`: players + opponent + strength | Returns `LineupResult` with `formation`, `lineup`, `reason`; prompt includes opponent and strength |
| A-03 | Lineup generator `adjust()`: current_lineup + note | Returns `AdjustResult` with `substitutions`, `position_changes`, `reason` |
| A-04 | Match analyst: formation + notes list | Returns `SummaryResult` with three top-level fields; prompt contains note content |

---

### 3.8 `test_errors.py` — Error mapping

| ID | Description | Expected |
|---|---|---|
| E-01 | Roster agent raises exception | `POST /api/roster/extract` → 502, `{"detail": <message>}` |
| E-02 | Lineup agent raises exception | `POST /api/matches/{id}/lineup` → 502 |
| E-03 | Analyst agent raises exception | `POST /api/matches/{id}/summary` → 502 |

---

## 4. Coverage Target

| Endpoint / Module | Happy path | Error path |
|---|---|---|
| `GET /api/health` | H-01 | — |
| `POST/GET /api/matches` | M-01, M-02 | M-03, M-04 |
| `POST /api/matches/{id}/lineup` | L-01 | L-04 |
| `POST /api/roster/extract` | R-01 | R-04, R-05 |
| `POST /api/matches/{id}/notes` | N-01 | N-02 |
| `POST /api/matches/{id}/summary` | S-01 | S-03 |
| Agent units | A-01 – A-04 | E-01 – E-03 |

**Hackathon minimum**: all 4 AI endpoints + matches CRUD have ≥1 happy-path and ≥1 error-path test.

---

## 5. Live Smoke Tests (optional)

Tagged `@pytest.mark.live`, skipped by default. Enable with:

```bash
uv run pytest -m live
```

| ID | Description |
|---|---|
| LIVE-01 | Roster agent real call: real image → valid `RosterResult` shape |
| LIVE-02 | Lineup agent real call: 5 players → valid `LineupResult` shape |
| LIVE-03 | Analyst agent real call: 3 notes → valid `SummaryResult` shape |

Requires `ANTHROPIC_API_KEY` set in environment.
