import pytest

from app.routers import matches as matches_router
from app.schemas import (
    AdjustResult,
    LineupResult,
    LineupSlot,
    PlayerPerformance,
    Substitution,
    SummaryResult,
)


@pytest.fixture
def stub_agents(monkeypatch):
    async def fake_generate(players, opponent, strength):
        return LineupResult(
            formation="4-3-3",
            lineup=[LineupSlot(player="John", position="ST")],
            reason="ok",
        )

    async def fake_adjust(current_lineup, note):
        return AdjustResult(
            substitutions=[Substitution(out="John", in_="David")],
            position_changes=[],
            reason=f"because: {note}",
        )

    async def fake_summary(lineup, notes):
        return SummaryResult(
            summary="Good game.",
            player_performance=[
                PlayerPerformance(player="John", rating="7", comment="Sharp")
            ],
            improvements=["Press higher"],
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    monkeypatch.setattr(matches_router, "adjust_lineup", fake_adjust)
    monkeypatch.setattr(matches_router, "summarize_match", fake_summary)


def _make_match(client, team):
    return client.post(
        "/api/matches",
        json={
            "team_id": team.id,
            "opponent": "Rivals",
            "location": "Home Park",
            "date": "2026-06-10",
        },
    ).json()["id"]


def test_note_requires_lineup_first(client, team, stub_agents):
    match_id = _make_match(client, team)
    r = client.post(
        f"/api/matches/{match_id}/notes",
        json={"kind": "text", "content": "John is tired"},
    )
    assert r.status_code == 409


def test_note_returns_suggestion(client, team, stub_agents):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={})
    r = client.post(
        f"/api/matches/{match_id}/notes",
        json={"kind": "text", "content": "John is tired"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["note_id"] > 0
    assert body["suggestion"]["substitutions"][0]["in"] == "David"


def test_summary(client, team, stub_agents):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={})
    r = client.post(f"/api/matches/{match_id}/summary")
    assert r.status_code == 200
    body = r.json()
    assert body["summary"] == "Good game."
    assert body["player_performance"][0]["player"] == "John"
    assert body["improvements"]
