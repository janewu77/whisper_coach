# Whisper Coach — Backend

FastAPI + [PydanticAI](https://ai.pydantic.dev/) + SQLite. An AI football coaching
assistant: extract a roster from a team photo, auto-generate a lineup, take live
in-match notes (text/voice) for tactical adjustments, and produce a post-match summary.

See `IMPLEMENTATION.md` for the design and the full REST contract, and
`../docs/mvp_prompt.md` for product scope.

## Requirements

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (`pip` works too)
- An `ANTHROPIC_API_KEY` — only needed for the **AI endpoints**; the server boots
  and the tests run without it.

## Local development

From the `backend/` directory:

```bash
# 1. Create a virtualenv and install dependencies (incl. dev/test tools)
uv venv
uv pip install -e ".[dev]"

# 2. Configure your API key
cp .env.example .env
# then edit .env and set ANTHROPIC_API_KEY=sk-ant-...

# 3. Run the dev server (auto-reload)
uv run uvicorn app.main:app --reload
```

The server starts at **http://localhost:8000**.

- Interactive API docs (Swagger UI): http://localhost:8000/docs
- OpenAPI schema (the frontend client is generated against this): http://localhost:8000/openapi.json
- Health check: http://localhost:8000/api/health

The SQLite database (`wc.db`) is created automatically on startup. To reset it,
stop the server and delete the file.

> Without an API key the server still runs and the non-AI routes work
> (create/get match, get team). The four AI endpoints will return `502` until a
> valid key is set.

## Running tests

Tests stub the LLM agents, so they need **no API key and make no network calls**.

```bash
uv run pytest            # all tests
uv run pytest -v         # verbose
uv run pytest app/tests/test_lineup.py::test_generate_returns_formation   # one test
```

`live`-marked tests (real LLM calls) are skipped by default; run them explicitly
with `uv run pytest -m live` once an API key is configured.

## API at a glance

Base URL `http://localhost:8000`. Full contract in `IMPLEMENTATION.md`.

| Method | Path | What |
|---|---|---|
| GET  | `/api/health` | liveness |
| POST | `/api/roster/extract` | photo (multipart) → players, creates a team |
| GET  | `/api/teams/{id}` | team + players |
| POST | `/api/matches` | create a match |
| GET  | `/api/matches/{id}` | match incl. latest lineup + notes |
| POST | `/api/matches/{id}/lineup` | generate formation + lineup |
| POST | `/api/matches/{id}/notes` | in-match note → adjustment suggestion |
| POST | `/api/matches/{id}/summary` | post-match summary |

### Quick manual run-through

```bash
# create a match (use a team_id from /api/roster/extract, or any int for now)
curl -s localhost:8000/api/matches -H 'content-type: application/json' \
  -d '{"team_id":1,"opponent":"Rivals","location":"Home Park","date":"2026-06-10","strength":"strong"}'

# generate a lineup (needs the team to have players + a valid API key)
curl -s localhost:8000/api/matches/1/lineup -H 'content-type: application/json' -d '{}'
```

## Project layout

```
app/
  main.py            FastAPI app, CORS, router wiring, startup DB init
  config.py          settings (.env): DB_URL, ANTHROPIC_API_KEY, LLM_MODEL
  db.py              SQLite engine + session dependency
  models.py          SQLModel tables (Team, Player, Match, Lineup, Note)
  schemas.py         request/response + agent result models (the API contract)
  routers/           roster.py, matches.py
  agents/            roster.py, lineup.py, analyst.py (lazily-built PydanticAI agents)
  tests/             pytest suite with stubbed agents
```
