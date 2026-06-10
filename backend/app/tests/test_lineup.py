import pytest

from app.routers import matches as matches_router
from app.schemas import LineupResult, LineupSlot


@pytest.fixture
def stub_generate(monkeypatch):
    """Echo the inputs through the result so tests can assert pass-through."""
    calls = {}

    async def fake_generate(
        players, opponent, strength, team_size=None, formation=None, instructions=None
    ):
        calls.update(
            team_size=team_size, formation=formation, instructions=instructions
        )
        size = team_size or 11
        return LineupResult(
            formation=formation or "4-3-3",
            lineup=[
                LineupSlot(player="John", position="ST"),
                LineupSlot(player="David", position="CM"),
            ][: min(2, size)],
            subs=[LineupSlot(player="Sub One", position="GK")],
            reason=f"vs {opponent} ({strength or 'unknown'})",
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    return calls


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
    assert body["subs"] == [
        {"player": "Sub One", "position": "GK", "nickname": None}
    ]
    assert "reason" in body


def test_generate_passes_size_formation_instructions(client, team, stub_generate):
    match_id = _make_match(client, team)
    r = client.post(
        f"/api/matches/{match_id}/lineup",
        json={"team_size": 7, "formation": "2-3-1", "instructions": "press high"},
    )
    assert r.status_code == 200
    assert r.json()["formation"] == "2-3-1"
    assert stub_generate == {
        "team_size": 7,
        "formation": "2-3-1",
        "instructions": "press high",
    }


def test_generate_persists_and_regenerates(client, team, stub_generate):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={})
    client.post(f"/api/matches/{match_id}/lineup", json={})
    # latest lineup (incl. subs) is surfaced on the match
    r = client.get(f"/api/matches/{match_id}")
    assert r.json()["lineup"]["formation"] == "4-3-3"
    assert r.json()["lineup"]["subs"] == [
        {"player": "Sub One", "position": "GK", "nickname": None}
    ]


def test_lineup_unknown_match_404(client, stub_generate):
    r = client.post("/api/matches/999/lineup", json={})
    assert r.status_code == 404


def test_bench_autofilled_with_remaining_roster(client, team, session, monkeypatch):
    """Starters + subs must always cover the whole roster, even when the agent
    forgets the bench — and slots carry the roster nickname."""
    from sqlmodel import select

    from app.models import Player

    async def fake_generate(players, opponent, strength, **kwargs):
        return LineupResult(
            formation="4-3-3",
            lineup=[LineupSlot(player="John", position="ST")],
            subs=[],  # agent returned no bench
            reason="r",
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    david = session.exec(select(Player).where(Player.name == "David")).first()
    david.nickname = "Dave"
    session.add(david)
    session.commit()

    match_id = _make_match(client, team)
    body = client.post(f"/api/matches/{match_id}/lineup", json={}).json()
    assert [s["player"] for s in body["lineup"]] == ["John"]
    # David (the only other roster player) was appended to the bench with his
    # preferred position and nickname.
    assert body["subs"] == [
        {"player": "David", "position": "CM", "nickname": "Dave"}
    ]
    # the read path returns the completed squad too
    again = client.get(f"/api/matches/{match_id}").json()["lineup"]
    assert [s["player"] for s in again["subs"]] == ["David"]


def test_generate_by_voice(client, team, stub_generate, monkeypatch):
    async def fake_transcribe(data, filename, language=None):
        return "play five at the back"

    monkeypatch.setattr(matches_router, "transcribe_audio", fake_transcribe)
    match_id = _make_match(client, team)
    r = client.post(
        f"/api/matches/{match_id}/lineup/voice",
        files={"audio": ("cmd.webm", b"\x00\x01", "audio/webm")},
        data={"team_size": "5", "formation": "1-2-1"},
    )
    assert r.status_code == 200
    assert r.json()["formation"] == "1-2-1"
    assert stub_generate == {
        "team_size": 5,
        "formation": "1-2-1",
        "instructions": "play five at the back",
    }
