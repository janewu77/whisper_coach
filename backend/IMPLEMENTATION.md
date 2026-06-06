# Backend Implementation Plan

FastAPI + **PydanticAI** + SQLite. Source of truth for product scope: `../docs/01_MVP砍刀版.md`. Read `../CLAUDE.md` for the out-of-scope list (no auth, no LangGraph, no WebSockets, no full stats).

This document is the contract: the **REST Interface** section below is shared with `../frontend/IMPLEMENTATION.md`. Keep them in sync — if you change a route or payload here, update both.

---

## 1. Stack & layout

- **FastAPI** — REST server, auto OpenAPI docs at `/docs`.
- **PydanticAI** — three agents (roster extractor, lineup generator, match analyst). Use the latest Claude model.
- **SQLite** — single file `wc.db`, accessed via SQLModel (Pydantic + SQLAlchemy, least boilerplate).
- **uv** — dependency/venv manager (fast, hackathon-friendly). `pip` works too.

Proposed structure:

```
backend/
  pyproject.toml
  app/
    main.py            # FastAPI app, router includes, CORS
    config.py          # settings (ANTHROPIC_API_KEY, DB_URL, model id)
    db.py              # engine, session, init_db()
    models.py          # SQLModel tables: Team, Player, Match, Lineup, Note
    schemas.py         # request/response Pydantic models (the API contract)
    routers/
      roster.py        # /api/roster
      matches.py       # /api/matches
    agents/
      __init__.py      # shared model/client config
      roster.py        # roster extractor agent
      lineup.py        # lineup generator agent
      analyst.py       # match analyst agent
    tests/
      conftest.py      # test client + temp DB fixtures
      test_roster.py
      test_matches.py
      test_lineup.py
      test_summary.py
```

---

## 2. Data model (SQLite via SQLModel)

Keep it minimal — no normalization beyond what the flow needs.

- **Team**: `id`, `name`, `created_at`
- **Player**: `id`, `team_id`, `name`, `number` (nullable), `preferred_position` (nullable)
- **Match**: `id`, `team_id`, `opponent`, `location`, `date`, `notes`, `strength` (`strong`/`weak`/null), `created_at`
- **Lineup**: `id`, `match_id`, `formation` (e.g. `4-3-3`), `slots` (JSON: `[{player_id, name, position}]`), `reason`, `created_at`
- **Note**: `id`, `match_id`, `kind` (`text`/`voice`), `content`, `ai_response` (JSON), `created_at`

Voice is transcribed client-side or via a transcription step; the backend receives text in `Note.content`. (If we add server-side transcription it goes in `agents/`, but it is out of MVP scope unless requested.)

---

## 3. REST Interface (shared contract)

Base URL: `http://localhost:8000`. All bodies JSON unless noted. CORS open in dev.

### Health
- `GET /api/health` → `{"status": "ok"}`

### Roster extractor (Agent 1)
- `POST /api/roster/extract` — `multipart/form-data`, field `image` (the team-sheet photo), optional `team_name`.
  - **200** → `{ "team_id": int, "players": [{"name": str, "number": int|null, "preferred_position": str|null}] }`
  - Creates a Team + Players from the extracted list.
- `GET /api/teams/{team_id}` → `{ "id", "name", "players": [...] }`

### Matches
- `POST /api/matches` — `{ "team_id", "opponent", "location", "date", "notes"?, "strength"? }`
  - **201** → full match object `{ "id", "team_id", "opponent", "location", "date", "notes", "strength" }`
- `GET /api/matches/{id}` → match object incl. latest `lineup` and `notes[]`.

### Lineup generator (Agent 2)
- `POST /api/matches/{id}/lineup` — `{ "strength"? }` (overrides match.strength if given)
  - **200** → `{ "formation": "4-3-3", "lineup": [{"player": str, "position": str}], "reason": str }`
  - Persists a Lineup row tied to the match. Calling again regenerates and stores a new one.

### In-match adjustment (Agent 2, adjustment mode)
- `POST /api/matches/{id}/notes` — `{ "kind": "text"|"voice", "content": "John 太累了 / left wing exposed" }`
  - **200** → `{ "note_id": int, "suggestion": { "substitutions": [{"out": str, "in": str}], "position_changes": [{"player": str, "to": str}], "reason": str } }`
  - Uses current lineup + the note as context to produce adjustments. Persists the Note with `ai_response`.

### Match analyst (Agent 3)
- `POST /api/matches/{id}/summary`
  - **200** → `{ "summary": str, "player_performance": [{"player": str, "rating": str, "comment": str}], "improvements": [str] }`
  - Input = formation + all notes/adjustments for the match.

### Error shape
All errors → standard FastAPI `{ "detail": str }` with appropriate status (`404` unknown id, `422` validation, `502` agent/LLM failure).

---

## 4. PydanticAI agents

Each agent has a `result_type` (Pydantic model) matching the response schema above, so output is validated/retried automatically.

1. **roster extractor** (`agents/roster.py`) — multimodal input (image bytes) → `RosterResult { players: list[PlayerOut] }`. Prompt: extract every player name, jersey number, and position if visible; ignore non-player text.
2. **lineup generator** (`agents/lineup.py`) — two entry points sharing one agent:
   - `generate(players, opponent, strength)` → `LineupResult { formation, lineup, reason }`
   - `adjust(current_lineup, note)` → `AdjustResult { substitutions, position_changes, reason }`
3. **match analyst** (`agents/analyst.py`) — `(formation, notes)` → `SummaryResult { summary, player_performance, improvements }`.

Config (`agents/__init__.py`): single place setting the model id and reading `ANTHROPIC_API_KEY`. Agents must be unit-testable with a stubbed/`TestModel` so tests don't hit the network.

---

## 5. Implementation phases

1. **Skeleton** — `pyproject.toml`, FastAPI app, `GET /api/health`, CORS, `/docs` works. `uv run uvicorn app.main:app --reload`.
2. **DB layer** — models, `init_db()` on startup, session dependency.
3. **Matches CRUD** — `POST/GET /api/matches`, no AI. Establishes the persistence path end to end.
4. **Lineup generator agent** — wire Agent 2, `POST /api/matches/{id}/lineup`.
5. **Roster extractor agent** — `POST /api/roster/extract` with image upload → Team/Players.
6. **In-match adjustments** — `POST /api/matches/{id}/notes` (adjust mode).
7. **Match analyst** — `POST /api/matches/{id}/summary`.
8. **Polish** — error handling, seed/demo script, finalize OpenAPI for the frontend.

Build the agent that has no external dependency (lineup, phase 4) before the image one (phase 5) to de-risk the PydanticAI integration early.

---

## 6. Test plan

Framework: **pytest** + FastAPI `TestClient`. Run: `uv run pytest` (single test: `uv run pytest app/tests/test_lineup.py::test_generate_returns_formation`).

**Principle:** agents are stubbed in tests via PydanticAI `TestModel`/dependency override — no live LLM calls in CI. One optional, marked (`@pytest.mark.live`) smoke test may hit the real model, skipped by default.

- **Fixtures** (`conftest.py`): temp SQLite DB per test, `TestClient`, a seeded team+players factory, agent override fixture.
- **Health/contract**: `/api/health` 200; OpenAPI schema generates.
- **Matches**: create returns 201 + id; get unknown id → 404; validation error on missing `opponent` → 422.
- **Lineup**: with stubbed agent, `POST .../lineup` returns the three keys and persists a Lineup row; regenerating creates a new row; unknown match → 404.
- **Roster**: posting an image (small fixture file) with stubbed agent creates Team + Players and returns the players list; non-image / missing file → 422.
- **Notes/adjust**: posting a note returns a `suggestion` and persists the Note with `ai_response`; works only after a lineup exists (define behavior: 409 or auto-generate — pick and test it).
- **Summary**: returns summary + per-player ratings + improvements from seeded notes.
- **Agent units**: each agent tested with `TestModel` to assert it returns the correct `result_type` shape and that prompts include the expected context (players, opponent, notes).
- **Error mapping**: simulate agent raising → endpoint returns 502 with `detail`.

Coverage target for the hackathon: the four AI endpoints + matches CRUD all have at least one happy-path and one error-path test.
