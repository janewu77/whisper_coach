# Whisper Coach ⚽

**🌐 Home page: [whisper-coach.dacheng.dev](https://whisper-coach.dacheng.dev/)**

An AI football (soccer) coaching assistant. From a team photo and a few words it
produces automatic lineups, gives live tactical suggestions during the match
(text or voice), and generates a post-match analysis.

Core flow: roster from photo → match setup → auto formation/lineup →
in-match adjustments (voice/text) → post-match summary.

## Structure

- **[`backend/`](backend/README.md)** — FastAPI + PydanticAI + PostgreSQL. Three
  AI agents (roster extractor, lineup generator, match analyst) behind a REST API.
  Also serves the home page above at `/`.
- **`frontend/`** — Flutter app, three screens (create match, 2D pitch, live notes).
  See [`frontend/IMPLEMENTATION.md`](frontend/IMPLEMENTATION.md).
- **`docs/`** — product scope ([`mvp_prompt.md`](docs/mvp_prompt.md)) and pitch deck.

## Quick start

See [`backend/README.md`](backend/README.md) for local dev, the REST contract,
Docker, and Coolify deployment.
