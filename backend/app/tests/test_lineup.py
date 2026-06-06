import pytest

from app.routers import matches as matches_router
from app.schemas import LineupResult, LineupSlot


@pytest.fixture
def stub_generate(monkeypatch):
    async def fake_generate(players, opponent, strength):
        return LineupResult(
            formation="4-3-3",
            lineup=[
                LineupSlot(player="John", position="ST"),
                LineupSlot(player="David", position="CM"),
            ],
            reason=f"vs {opponent} ({strength or 'unknown'})",
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)


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


def test_generate_returns_formation(client, team, stub_generate):
    match_id = _make_match(client, team)
    r = client.post(f"/api/matches/{match_id}/lineup", json={})
    assert r.status_code == 200
    body = r.json()
    assert body["formation"] == "4-3-3"
    assert {s["player"] for s in body["lineup"]} == {"John", "David"}
    assert "reason" in body


def test_generate_persists_and_regenerates(client, team, stub_generate):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={})
    client.post(f"/api/matches/{match_id}/lineup", json={})
    # latest lineup is surfaced on the match
    r = client.get(f"/api/matches/{match_id}")
    assert r.json()["lineup"]["formation"] == "4-3-3"


def test_lineup_unknown_match_404(client, stub_generate):
    r = client.post("/api/matches/999/lineup", json={})
    assert r.status_code == 404
