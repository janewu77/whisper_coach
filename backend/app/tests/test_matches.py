def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_create_match(client, team):
    r = client.post(
        "/api/matches",
        json={
            "team_id": team.id,
            "opponent": "Rivals",
            "location": "Home Park",
            "date": "2026-06-10",
        },
    )
    assert r.status_code == 201
    body = r.json()
    assert body["id"] > 0
    assert body["opponent"] == "Rivals"


def test_create_match_validation_error(client, team):
    # missing required "opponent"
    r = client.post(
        "/api/matches",
        json={"team_id": team.id, "location": "Home Park", "date": "2026-06-10"},
    )
    assert r.status_code == 422


def test_get_unknown_match_404(client):
    r = client.get("/api/matches/999")
    assert r.status_code == 404
