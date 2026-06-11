import pytest

from app.routers import matches as matches_router
from app.schemas import LineupResult, LineupSlot


@pytest.fixture
def stub_generate(monkeypatch):
    """Echo the inputs through the result so tests can assert pass-through."""
    calls = {}

    async def fake_generate(
        players,
        opponent,
        strength,
        team_size=None,
        formation=None,
        instructions=None,
        language=None,
        **kwargs,
    ):
        calls.update(
            team_size=team_size,
            formation=formation,
            instructions=instructions,
            language=language,
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
        "language": None,
    }


def test_generate_passes_language(client, team, stub_generate):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={"language": "de"})
    assert stub_generate["language"] == "de"



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


def test_starters_never_duplicated_on_bench(client, team, session, monkeypatch):
    """A player the agent lists both as starter and sub (even under their
    nickname) appears exactly once — as the starter."""
    from sqlmodel import select

    from app.models import Player

    david = session.exec(select(Player).where(Player.name == "David")).first()
    david.nickname = "Dave"
    session.add(david)
    session.commit()

    async def fake_generate(players, opponent, strength, **kwargs):
        return LineupResult(
            formation="4-3-3",
            lineup=[
                LineupSlot(player="John", position="ST"),
                LineupSlot(player="Dave", position="CM"),  # nickname variant
            ],
            subs=[
                LineupSlot(player="John", position="SUB"),  # duplicate starter
                LineupSlot(player="David", position="SUB"),  # dup of "Dave"
            ],
            reason="r",
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    match_id = _make_match(client, team)
    body = client.post(f"/api/matches/{match_id}/lineup", json={}).json()

    # Starters canonicalized to roster names; bench is empty (everyone starts).
    assert [s["player"] for s in body["lineup"]] == ["John", "David"]
    assert body["subs"] == []
    # read path stays clean too
    again = client.get(f"/api/matches/{match_id}").json()["lineup"]
    assert again["subs"] == []


def test_unavailable_players_excluded_from_generation(client, team, monkeypatch):
    """Players on the match's unavailable list never reach the agent or the
    auto-filled bench."""
    seen = {}

    async def fake_generate(players, opponent, strength, **kwargs):
        seen["names"] = [p.name for p in players]
        return LineupResult(
            formation="4-3-3",
            lineup=[LineupSlot(player=players[0].name, position="ST")],
            subs=[],
            reason="r",
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    match_id = _make_match(client, team)

    # John is id'd via the roster; mark him unavailable on the match.
    roster = client.get(f"/api/teams/{team.id}").json()["players"]
    john_id = next(p["id"] for p in roster if p["name"] == "John")
    client.patch(
        f"/api/matches/{match_id}", json={"unavailable_player_ids": [john_id]}
    )

    body = client.post(f"/api/matches/{match_id}/lineup", json={}).json()
    assert seen["names"] == ["David"]  # John filtered out
    squad = [s["player"] for s in body["lineup"]] + [
        s["player"] for s in body["subs"]
    ]
    assert "John" not in squad

    # everyone unavailable → 409
    client.patch(
        f"/api/matches/{match_id}",
        json={"unavailable_player_ids": [p["id"] for p in roster]},
    )
    assert (
        client.post(f"/api/matches/{match_id}/lineup", json={}).status_code == 409
    )


def test_absences_drive_default_availability(client, team, session, monkeypatch):
    """With no explicit unavailable list, a player whose absence covers the
    match date is excluded automatically."""
    seen = {}

    async def fake_generate(players, opponent, strength, **kwargs):
        seen["names"] = [p.name for p in players]
        return LineupResult(
            formation="4-3-3",
            lineup=[LineupSlot(player=players[0].name, position="ST")],
            subs=[],
            reason="r",
        )

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    from sqlmodel import select

    from app.models import Player

    john = session.exec(select(Player).where(Player.name == "John")).first()
    john.absences = [{"kind": "injury", "from": "2026-06-01", "to": "2026-06-30"}]
    session.add(john)
    session.commit()

    match_id = _make_match(client, team)  # date 2026-06-10 → inside the range
    client.post(f"/api/matches/{match_id}/lineup", json={})
    assert seen["names"] == ["David"]


def test_generate_by_voice(client, team, stub_generate, monkeypatch):
    async def fake_transcribe(data, filename, language=None):
        return "play five at the back"

    monkeypatch.setattr(matches_router, "transcribe_audio", fake_transcribe)
    match_id = _make_match(client, team)
    r = client.post(
        f"/api/matches/{match_id}/lineup/voice",
        files={"audio": ("cmd.webm", b"\x00\x01", "audio/webm")},
        data={"team_size": "5", "formation": "1-2-1", "language": "zh"},
    )
    assert r.status_code == 200
    assert r.json()["formation"] == "1-2-1"
    assert stub_generate == {
        "team_size": 5,
        "formation": "1-2-1",
        "instructions": "play five at the back",
        "language": "zh",
    }
