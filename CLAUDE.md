# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This repo is a **fresh hackathon scaffold**. As of writing it contains only empty `backend/`, `frontend/`, and `docs/` directories (with empty `.gitignore` files) plus the planning doc `docs/01_MVP砍刀版.md`. There is **no implementation, build system, or tests yet** — you will be creating these. Don't assume commands exist; establish them as you build, and update this file when you do.

## What this project is

"Whisper Coach" (`wc`) — an AI football (soccer) coaching assistant. The MVP, per `docs/01_MVP砍刀版.md`, turns team photos and simple match inputs into automatic lineups, gives live tactical suggestions during a match (voice/text driven), and generates post-match analysis.

Core flow: roster from photo → match setup → auto formation/lineup → in-match adjustments (voice/text) → post-match summary.

## Intended architecture

The plan deliberately keeps the stack minimal for a 1–2 day hackathon build.

**Backend** (`backend/`): FastAPI + **PydanticAI** (the centerpiece) + SQLite/Postgres, simple REST. The AI work is organized as **PydanticAI agents** — keep this decomposition. The first three are the original core; the last two power the roster import-review flow:
1. **roster extractor** — team photo → structured `players` list
2. **lineup generator** — players + opponent info → `{formation, lineup, reason}` (e.g. 4-3-3 / 4-2-3-1 / 3-5-2)
3. **match analyst** — notes + events → post-match summary
4. **roster matcher** (`agents/matcher.py`) — finds cross-language / spelling-variant duplicate candidates (Li Gang ↔ 李刚) with a confidence score
5. **import command parser** (`agents/import_editor.py`) — turns a coach's natural-language / voice command into structured edit/delete/merge actions

**Frontend** (`frontend/`): Flutter. After login the user picks/creates a
**team** (`TeamGate` → `CreateTeamScreen` on first run; otherwise `HomeShell`).
`HomeShell` is a tabbed scaffold with a **team selector** in the app bar (switch
team / "Create new team…") and a bottom `BottomNavigationBar`:
- **Players tab** (`PlayersTab`) — the current team's roster; "add from photo"
  stages a **roster import review** (`ImportReviewScreen`) instead of saving
  directly. See "Roster import review" below.
- **Matches tab** (`MatchesTab`) — the current team's matches; "New match"
  (`HomeScreen`) → Pitch Screen (2D pitch, clickable icons) → Live/Notes Screen
  (text + voice input, AI response cards).

Current team state lives in `lib/services/team_service.dart` (a `ChangeNotifier`
singleton, like `AuthService`). More tabs can be added to `HomeShell`.

## Explicitly out of scope (do not build)

The planning doc cuts these on purpose to protect the timeline — do not add them unless the user explicitly asks:
- Permission / role systems (beyond authentication)
- Full/normalized database schema design
- LangGraph (use PydanticAI instead — it was chosen specifically for speed)
- WebSocket live system
- Full stats system, tactical history analysis

## Authentication & ownership

The project moved past the hackathon MVP and now has **mandatory Auth0 login**
with **per-user data ownership**.

- **Auth is required** on every `/api` route. `app/auth.py` verifies Auth0
  access tokens (JWT/JWKS); `current_user_id` injects the token `sub` into each
  endpoint. If `AUTH0_DOMAIN` + `AUTH0_AUDIENCE` are unset the API returns 503
  (never open). See `backend/.env.example`.
- **Ownership:** `Team` and `Match` carry an `owner_id` (the Auth0 `sub`).
  Endpoints scope every read/write to the caller and 404 on cross-user access;
  lineups/notes are guarded via their parent match. Migration:
  `alembic/versions/c2d3e4f5a6b7_add_owner_id.py` — **deletes all pre-auth data**
  (it has no owner) then adds the NOT NULL `owner_id` columns.
- **Tests** override `get_current_user` (see `conftest.py` `TEST_USER` +
  `unauth_client`); enforcement and isolation are covered in `tests/test_auth.py`.
- **Frontend** uses `auth0_flutter` via `lib/auth/` (conditional import:
  `Auth0Web` on web, `Auth0` on native). Config comes from `--dart-define`
  (`AUTH0_DOMAIN` / `AUTH0_CLIENT_ID` / `AUTH0_AUDIENCE`); a Dio interceptor
  attaches the bearer token. Web is the priority platform.
- Setup details (Auth0 dashboard, native config) live in the root `README.md`.

## Roster import review

Importing players from a photo is **staged for review** — OCR/AI output never
writes straight to the `player` table (prevents recognition errors corrupting
the official roster).

- **Temp storage:** an **in-memory** session buffer, NOT a DB table
  (`services/import_store.py` — a process-local `store` of `MemSession`/`MemItem`,
  owner/team scoped, lost on restart). Each item carries the editable imported
  values plus a `classification`: `new` | `updated` | `duplicate` | `unchanged`,
  a `match_player_id` (the existing player a non-new item maps to), and a
  `confidence` for duplicate candidates. (Single-worker assumption; sessions are
  short-lived and re-runnable from the photo.)
- **Classification** (`services/import_review.py`): exact-name matches are
  resolved deterministically (unchanged vs updated by field diff); leftovers go
  to the **roster matcher** agent to surface cross-language/spelling duplicates.
- **Endpoints** (`routers/imports.py`, all owner-scoped):
  `POST /api/teams/{id}/imports` (image → review), `GET /api/imports/{sid}`,
  `PATCH/DELETE .../items/{iid}`, `POST .../items/{iid}/merge`,
  `POST .../command` + `.../command/voice` (NL/voice editing via the import
  command parser), and `POST .../confirm` — **the only step that writes to the
  roster** (new+duplicate→create, updated→update, unchanged→skip).
- **Frontend:** `ImportReviewScreen` (sections, before/after diffs, confidence,
  per-item Edit/Delete/Merge, NL+voice command bar, "Confirm Import"), reached
  from the Players tab. Models in `models/import_review.dart`.
- The legacy direct-save `POST /api/roster/extract` still exists (and is tested)
  but the app no longer uses it.

## Notes

- The primary planning doc (`docs/01_MVP砍刀版.md`) is in Chinese; it is the source of truth for product scope.
- Default to the latest Claude models for the PydanticAI agents.
