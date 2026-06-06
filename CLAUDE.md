# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This repo is a **fresh hackathon scaffold**. As of writing it contains only empty `backend/`, `frontend/`, and `docs/` directories (with empty `.gitignore` files) plus the planning doc `docs/01_MVP砍刀版.md`. There is **no implementation, build system, or tests yet** — you will be creating these. Don't assume commands exist; establish them as you build, and update this file when you do.

## What this project is

"Whisper Coach" (`wc`) — an AI football (soccer) coaching assistant. The MVP, per `docs/01_MVP砍刀版.md`, turns team photos and simple match inputs into automatic lineups, gives live tactical suggestions during a match (voice/text driven), and generates post-match analysis.

Core flow: roster from photo → match setup → auto formation/lineup → in-match adjustments (voice/text) → post-match summary.

## Intended architecture

The plan deliberately keeps the stack minimal for a 1–2 day hackathon build.

**Backend** (`backend/`): FastAPI + **PydanticAI** (the centerpiece) + SQLite/Postgres, simple REST. The AI work is organized as **three PydanticAI agents** — keep this decomposition:
1. **roster extractor** — team photo → structured `players` list
2. **lineup generator** — players + opponent info → `{formation, lineup, reason}` (e.g. 4-3-3 / 4-2-3-1 / 3-5-2)
3. **match analyst** — notes + events → post-match summary

**Frontend** (`frontend/`): Flutter, three screens only — Home/Create Match (upload photo, opponent input), Pitch Screen (2D pitch with clickable player icons), Live/Notes Screen (text + voice input, AI response cards).

## Explicitly out of scope (do not build)

The planning doc cuts these on purpose to protect the timeline — do not add them unless the user explicitly asks:
- Auth / Auth0, permission systems
- Full/normalized database schema design
- LangGraph (use PydanticAI instead — it was chosen specifically for speed)
- WebSocket live system
- Full stats system, tactical history analysis

## Notes

- The primary planning doc (`docs/01_MVP砍刀版.md`) is in Chinese; it is the source of truth for product scope.
- Default to the latest Claude models for the PydanticAI agents.
