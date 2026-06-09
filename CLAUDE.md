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
6. **text roster extractor** (`agents/roster.py::extract_players_from_text`) — spoken/typed player list → `players` (powers the Players tab's "add by voice")
7. **player profiler** (`agents/player_profile.py`) — a spoken/typed description → a structured player profile (positions, foot, height, traits, bio) for the player detail screen

**Frontend** (`frontend/`): Flutter. After login the user picks/creates a
**team** (`TeamGate` → `CreateTeamScreen` on first run; otherwise `HomeShell`).
`HomeShell` is a tabbed scaffold with a **team selector** in the app bar (switch
team / "Create new team…" / "Join team…" by code) and a bottom
`BottomNavigationBar`:
- **Players tab** (`PlayersTab`) — the current team's roster (each row has
  **edit** → `PlayerDetailScreen` and delete actions). The detail screen edits a
  player's full profile (number, positions, preferred foot, height, traits, bio,
  and injury/vacation **absences** with from–to dates) in grouped sections, with
  a voice "describe" button that calls the player profiler and merges the result
  into the form (saved only on Save, via PATCH). Each roster row shows an
  availability line derived from absences (Available / Injured · back in Nd) and
  the list can be **filtered** by position (line/side) and by availability
  (available today / for the next match).
  Two add buttons both stage a **roster import review**
  (`ImportReviewScreen`) instead of saving directly: "add from photo" (crop via
  `CropScreen` → image) and "add by voice" (record → transcribe → extract). See
  "Roster import review" below.
- **Matches tab** (`MatchesTab`) — the current team's matches; "New match"
  (`HomeScreen`) → Pitch Screen (2D pitch, clickable icons) → Live/Notes Screen
  (text + voice input, AI response cards).
- **Profile tab** (`ProfileTab`) — user info, the current team's **join code**
  (copyable, to share the team) + **speaker language** preference
  (English/Chinese/German/… or auto). The app UI is English-only; the language
  is an ISO-639-1 code persisted by `services/settings_service.dart`
  (shared_preferences) and sent as a `language` form field on every voice upload
  to steer Whisper transcription.

Current team state lives in `lib/services/team_service.dart` (a `ChangeNotifier`
singleton, like `AuthService`). More tabs can be added to `HomeShell`.

## Explicitly out of scope (do not build)

The planning doc cuts these on purpose to protect the timeline — do not add them unless the user explicitly asks:
- Permission / role systems (beyond authentication)
- Full/normalized database schema design
- LangGraph (use PydanticAI instead — it was chosen specifically for speed)
- WebSocket live system
- Full stats system, tactical history analysis

## Authentication & membership (shared teams)

The project moved past the hackathon MVP and now has **mandatory Auth0 login**
with **shared teams** (a team can belong to several users).

- **Auth is required** on every `/api` route. `app/auth.py` verifies Auth0
  access tokens (JWT/JWKS); `current_user_id` injects the token `sub` **and
  registers the user** in the `users` table on first sight (auth0 `sub` is the
  PK). If `AUTH0_DOMAIN` + `AUTH0_AUDIENCE` are unset the API returns 503 (never
  open). See `backend/.env.example`.
- **Membership, not ownership:** `users` + a `user_team` join table govern
  access. A `Team` has a unique `join_code`; access to a team and its
  matches/roster is granted to **every member** (no roles). Helpers in
  `app/membership.py` (`is_member`, `team_ids_for`, `add_member`); endpoints 404
  on non-members. Sharing: `POST /api/teams/join {code}` adds the caller as a
  member; `POST /api/teams` creates a team and joins the creator. `Team`/`Match`
  no longer have `owner_id`. Migration
  `alembic/versions/a7b8c9d0e1f2_shared_teams.py` creates `user`/`userteam`,
  backfills each team's old `owner_id` into a user + membership + join code, then
  drops the `owner_id` columns (existing users keep access).
- **Tests** override `get_current_user` (see `conftest.py` `TEST_USER` +
  `unauth_client`); the `team` fixture seeds a `User` + `UserTeam`. Enforcement,
  isolation, and join-by-code are covered in `tests/test_auth.py` /
  `tests/test_roster.py`.
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
  `POST /api/teams/{id}/imports` (image → review) plus `.../imports/voice` and
  `.../imports/text` (speak/type players to add → review, via the text roster
  extractor), `GET /api/imports/{sid}`,
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
