import io

import pytest

from app.models import Team, User, UserTeam
from app.routers import roster as roster_router
from app.schemas import PlayerOut, PlayerProfileResult, RosterResult


@pytest.fixture
def stub_extract(monkeypatch):
    async def fake_extract(image_bytes, media_type):
        return RosterResult(
            players=[
                PlayerOut(name="John", number=9, preferred_position="ST"),
                PlayerOut(name="David", number=8, preferred_position="CM"),
            ]
        )

    monkeypatch.setattr(roster_router, "extract_roster", fake_extract)


def test_roster_extract_creates_team(client, stub_extract):
    files = {"image": ("roster.png", io.BytesIO(b"fakeimage"), "image/png")}
    r = client.post("/api/roster/extract", files=files, data={"team_name": "Test FC"})
    assert r.status_code == 200
    body = r.json()
    assert body["team_id"] > 0
    assert len(body["players"]) == 2

    # players are persisted and retrievable
    t = client.get(f"/api/teams/{body['team_id']}")
    assert t.status_code == 200
    assert t.json()["name"] == "Test FC"


def test_roster_extract_rejects_non_image(client, stub_extract):
    files = {"image": ("notes.txt", io.BytesIO(b"hello"), "text/plain")}
    r = client.post("/api/roster/extract", files=files)
    assert r.status_code == 422


def test_get_unknown_team_404(client):
    r = client.get("/api/teams/999")
    assert r.status_code == 404


def test_create_and_list_teams(client):
    assert client.get("/api/teams").json() == []

    r = client.post("/api/teams", json={"name": "Sunday FC"})
    assert r.status_code == 201
    team = r.json()
    assert team["id"] > 0 and team["name"] == "Sunday FC"

    teams = client.get("/api/teams").json()
    assert [t["name"] for t in teams] == ["Sunday FC"]


def test_create_team_requires_name(client):
    assert client.post("/api/teams", json={"name": "   "}).status_code == 422


def test_create_team_returns_join_code(client):
    body = client.post("/api/teams", json={"name": "Sunday FC"}).json()
    assert isinstance(body["join_code"], str) and len(body["join_code"]) >= 4


def test_join_team_by_code_shares_it(client, session):
    # A team that belongs to another user.
    session.add(User(auth0_id="owner-x"))
    t = Team(name="Shared FC")
    session.add(t)
    session.commit()
    session.refresh(t)
    session.add(UserTeam(user_id="owner-x", team_id=t.id))
    session.commit()

    # TEST_USER can't see it until they join.
    assert client.get(f"/api/teams/{t.id}").status_code == 404
    r = client.post("/api/teams/join", json={"code": t.join_code})
    assert r.status_code == 200 and r.json()["id"] == t.id

    # Now it's in their team list and readable.
    assert any(x["id"] == t.id for x in client.get("/api/teams").json())
    assert client.get(f"/api/teams/{t.id}").status_code == 200


def test_join_team_invalid_code_404(client):
    assert client.post("/api/teams/join", json={"code": "ZZZZZZ"}).status_code == 404


def test_list_team_members(client, session, team):
    # Add a second member to the shared team.
    session.add(User(auth0_id="mate-1", name="Mate", email="mate@x.io"))
    session.add(UserTeam(user_id="mate-1", team_id=team.id))
    session.commit()

    members = client.get(f"/api/teams/{team.id}/members").json()
    # Excludes the caller (test-user) — only the other members are listed.
    subs = {m["auth0_id"] for m in members}
    assert subs == {"mate-1"}
    assert members[0]["name"] == "Mate" and members[0]["email"] == "mate@x.io"


def test_cannot_list_members_of_foreign_team(client, session):
    session.add(User(auth0_id="stranger"))
    t = Team(name="Stranger FC")
    session.add(t)
    session.commit()
    session.refresh(t)
    session.add(UserTeam(user_id="stranger", team_id=t.id))
    session.commit()
    assert client.get(f"/api/teams/{t.id}/members").status_code == 404


def test_get_team_includes_player_ids(client, team):
    body = client.get(f"/api/teams/{team.id}").json()
    assert all(isinstance(p["id"], int) for p in body["players"])


def test_delete_player(client, team):
    body = client.get(f"/api/teams/{team.id}").json()
    pid = body["players"][0]["id"]

    r = client.delete(f"/api/teams/{team.id}/players/{pid}")
    assert r.status_code == 204

    after = client.get(f"/api/teams/{team.id}").json()
    assert len(after["players"]) == 1
    assert all(p["id"] != pid for p in after["players"])


def test_delete_unknown_player_404(client, team):
    assert (
        client.delete(f"/api/teams/{team.id}/players/999999").status_code == 404
    )


def _first_player_id(client, team):
    return client.get(f"/api/teams/{team.id}").json()["players"][0]["id"]


def test_get_player_detail_defaults(client, team):
    pid = _first_player_id(client, team)
    body = client.get(f"/api/teams/{team.id}/players/{pid}").json()
    assert body["positions"] == [] and body["traits"] == []
    assert body["preferred_foot"] is None


def test_update_player_profile_persists(client, team):
    pid = _first_player_id(client, team)
    r = client.patch(
        f"/api/teams/{team.id}/players/{pid}",
        json={
            "number": 11,
            "positions": ["ST", "RW"],
            "preferred_foot": "left",
            "height_cm": 180,
            "traits": ["strong", "good ball control"],
            "description": "Quick, direct striker.",
        },
    )
    assert r.status_code == 200
    b = r.json()
    assert b["positions"] == ["ST", "RW"]
    assert b["preferred_foot"] == "left"
    assert b["height_cm"] == 180
    assert b["traits"] == ["strong", "good ball control"]

    again = client.get(f"/api/teams/{team.id}/players/{pid}").json()
    assert again["number"] == 11
    assert again["description"] == "Quick, direct striker."


def test_describe_player_does_not_persist(client, team, monkeypatch):
    pid = _first_player_id(client, team)

    async def fake_profile(text, current):
        return PlayerProfileResult(
            positions=["ST"], preferred_foot="right", traits=["fast"],
            description="Fast forward.",
        )

    monkeypatch.setattr("app.routers.roster.extract_profile", fake_profile)
    r = client.post(
        f"/api/teams/{team.id}/players/{pid}/describe",
        json={"text": "fast right-footed striker"},
    )
    assert r.status_code == 200
    assert r.json()["positions"] == ["ST"]

    # extraction must NOT have written to the player
    assert client.get(f"/api/teams/{team.id}/players/{pid}").json()["positions"] == []


def test_update_player_absences_roundtrip(client, team):
    pid = _first_player_id(client, team)
    absence = {
        "kind": "injury",
        "from": "2026-06-01",
        "to": "2026-06-10",
        "note": "hamstring",
    }
    r = client.patch(
        f"/api/teams/{team.id}/players/{pid}", json={"absences": [absence]}
    )
    assert r.status_code == 200
    assert r.json()["absences"] == [absence]

    # also surfaced in the team roster list
    roster = client.get(f"/api/teams/{team.id}").json()["players"]
    me = next(p for p in roster if p["id"] == pid)
    assert me["absences"][0]["from"] == "2026-06-01"
    assert me["absences"][0]["to"] == "2026-06-10"


def test_roster_extract_appends_to_existing_team(client, stub_extract):
    team_id = client.post("/api/teams", json={"name": "Existing FC"}).json()["id"]

    files = {"image": ("roster.png", io.BytesIO(b"fakeimage"), "image/png")}
    r = client.post(
        "/api/roster/extract", files=files, data={"team_id": str(team_id)}
    )
    assert r.status_code == 200
    assert r.json()["team_id"] == team_id

    # players landed on the existing team, no new team was created
    t = client.get(f"/api/teams/{team_id}").json()
    assert t["name"] == "Existing FC"
    assert len(t["players"]) == 2
    assert len(client.get("/api/teams").json()) == 1
