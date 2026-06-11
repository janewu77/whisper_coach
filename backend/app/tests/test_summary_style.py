"""Personal report style: distill → store → used by every match summary."""

import pytest
from sqlmodel import select

from app.models import User
from app.routers import matches as matches_router
from app.routers import me as me_router
from app.schemas import (
    LineupResult,
    LineupSlot,
    StyleCardResult,
    SummaryResult,
)

from .conftest import TEST_USER


@pytest.fixture
def stub_distill(monkeypatch):
    async def fake_distill(text):
        return StyleCardResult(style_card=f"Wry, short sentences. ({len(text)})")

    monkeypatch.setattr(me_router, "distill_style", fake_distill)


def test_distill_stores_card_and_samples(client, team, stub_distill):
    r = client.post("/api/me/summary-style", json={"text": "Old summary text."})
    assert r.status_code == 200
    body = r.json()
    assert body["style_card"].startswith("Wry, short sentences.")
    assert body["samples"] == "Old summary text."

    again = client.get("/api/me/summary-style").json()
    assert again["style_card"] == body["style_card"]

    # distillation costs 1 text credit
    assert client.get("/api/credits").json()["balance"] == 99


def test_distill_requires_text(client, team, stub_distill):
    assert (
        client.post("/api/me/summary-style", json={"text": "   "}).status_code
        == 422
    )


def test_delete_style(client, team, stub_distill):
    client.post("/api/me/summary-style", json={"text": "Sample."})
    assert client.delete("/api/me/summary-style").status_code == 204
    body = client.get("/api/me/summary-style").json()
    assert body["style_card"] is None and body["samples"] is None


def test_summary_uses_stored_style_card(client, team, session, monkeypatch):
    seen = {}

    async def fake_generate(players, opponent, strength, **kwargs):
        return LineupResult(
            formation="4-3-3",
            lineup=[LineupSlot(player="John", position="ST")],
            subs=[],
            reason="r",
        )

    async def fake_summary(lineup, notes, **kwargs):
        seen.update(kwargs)
        return SummaryResult(
            summary="s", player_performance=[], improvements=[]
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    monkeypatch.setattr(matches_router, "summarize_match", fake_summary)

    user = session.exec(
        select(User).where(User.auth0_id == TEST_USER["sub"])
    ).first()
    user.summary_style_card = "Wry, short sentences."
    session.add(user)
    session.commit()

    match_id = client.post(
        "/api/matches",
        json={"team_id": team.id, "opponent": "X", "date": "2026-06-11"},
    ).json()["id"]
    client.post(f"/api/matches/{match_id}/lineup", json={})
    r = client.post(f"/api/matches/{match_id}/summary", json={})
    assert r.status_code == 200
    assert seen["style_card"] == "Wry, short sentences."
