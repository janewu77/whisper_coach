import io

import pytest

from app.routers import roster as roster_router
from app.schemas import PlayerOut, RosterResult


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
