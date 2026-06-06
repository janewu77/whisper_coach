# Whisper Coach — Backend

FastAPI + [PydanticAI](https://ai.pydantic.dev/) + SQLite. An AI football coaching
assistant: extract a roster from a team photo, auto-generate a lineup, take live
in-match notes (text/voice) for tactical adjustments, and produce a post-match summary.

See `IMPLEMENTATION.md` for the design and the full REST contract, and
`../docs/mvp_prompt.md` for product scope.

## Requirements

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (`pip` works too)
- An `OPENAI_API_KEY` — only needed for the **AI endpoints**; the server boots
  and the tests run without it.

## Local development

From the `backend/` directory:

```bash
# 1. Create a virtualenv and install dependencies (incl. dev/test tools)
uv venv
uv pip install -e ".[dev]"

# 2. Configure your DB + API key
cp .env.example .env
# DB_URL defaults to local Postgres (see .env); set OPENAI_API_KEY=sk-...

# 3. Create the database schema (runs Alembic migrations)
uv run alembic upgrade head

# 4. Run the dev server (auto-reload)
uv run uvicorn app.main:app --reload
```

The server starts at **http://localhost:8000**.

- Interactive API docs (Swagger UI): http://localhost:8000/docs
- OpenAPI schema (the frontend client is generated against this): http://localhost:8000/openapi.json
- Health check: http://localhost:8000/api/health

## Database & migrations

The schema is managed by **Alembic** (the app does not auto-create tables).
Alembic reads `DB_URL` from your `.env`, so it always targets the same database
as the app.

```bash
uv run alembic upgrade head            # apply all migrations (run after pulling)
uv run alembic revision --autogenerate -m "describe change"   # after editing models.py
uv run alembic downgrade -1            # roll back one migration
uv run alembic current                 # show the applied revision
```

Workflow when you change `app/models.py`: autogenerate a revision, **review the
generated file** in `alembic/versions/`, then `upgrade head`.

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

## Docker

The image runs migrations on startup, then serves the API on port `8000`.

```bash
docker build -t whisper-coach-backend ./backend

docker run -p 8000:8000 \
  -e DB_URL="postgresql+psycopg://user:pass@host:5432/whisper_coach" \
  -e OPENAI_API_KEY="sk-..." \
  whisper-coach-backend
```

The entrypoint runs `alembic upgrade head` before launching uvicorn. Set
`RUN_MIGRATIONS=false` to skip that (e.g. when migrations run as a separate job).

## Deploying to Coolify

Deploy as a **Dockerfile** application (no compose needed):

1. **New Resource → Application → from your Git repo.**
2. Build Pack: **Dockerfile**. Set **Base Directory** to `/backend` so Coolify
   uses `backend/Dockerfile` and the backend build context.
3. Provision Postgres: add a **Coolify Postgres database** (or use an external
   one). Coolify gives you an internal connection string.
4. **Environment variables** (Coolify → the app → Environment):
   - `DB_URL` = `postgresql://<user>:<pass>@<pg-host>:5432/<db>`
     (use the **internal** host Coolify shows for the database). A plain
     `postgresql://` URL is fine — the app normalizes it to the psycopg driver.
   - `OPENAI_API_KEY` = your key
   - `LLM_MODEL` (optional) = `openai-chat:gpt-4o`
5. **Port**: the app listens on `8000` — set Coolify's exposed/port mapping to
   `8000`.
6. **Health check path**: `/api/health`.
7. Deploy. Migrations run automatically on container start.

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
  config.py          settings (.env): DB_URL, OPENAI_API_KEY, LLM_MODEL
  db.py              SQLite engine + session dependency
  models.py          SQLModel tables (Team, Player, Match, Lineup, Note)
  schemas.py         request/response + agent result models (the API contract)
  routers/           roster.py, matches.py
  agents/            roster.py, lineup.py, analyst.py (lazily-built PydanticAI agents)
  tests/             pytest suite with stubbed agents
alembic/             migration env + versions/ (schema source of truth)
alembic.ini          alembic config (DB URL is injected from settings)
Dockerfile           runtime image (uv + locked deps)
docker-entrypoint.sh runs migrations then starts uvicorn
```

