"""Credits: initial grant, balance/history endpoints, and spending on LLM calls."""

import io

from sqlmodel import select

from app import credits
from app.models import User
from app.schemas import PlayerProfileResult

from .conftest import TEST_USER


def test_new_user_gets_initial_credits(client, session):
    """A user registered on first request is granted the welcome credits."""
    # `client` runs as TEST_USER; the first request registers + grants.
    r = client.get("/api/credits")
    assert r.status_code == 200
    assert r.json()["balance"] == credits.INITIAL_CREDITS

    history = client.get("/api/credits/transactions").json()
    assert len(history) == 1
    assert history[0]["kind"] == "initial"
    assert history[0]["amount"] == credits.INITIAL_CREDITS
    assert history[0]["balance_after"] == credits.INITIAL_CREDITS


def test_existing_user_without_grant_gets_initial_credits(client, session):
    """An account that predates the credits system (user row exists, empty
    ledger) is granted the welcome credits on its next request."""
    session.add(User(auth0_id=TEST_USER["sub"], email=TEST_USER["email"], credits=0))
    session.commit()

    r = client.get("/api/credits")
    assert r.json()["balance"] == credits.INITIAL_CREDITS
    history = client.get("/api/credits/transactions").json()
    assert [t["kind"] for t in history] == ["initial"]


def test_spent_down_user_is_not_regranted(client, session):
    """A zero balance alone does not re-trigger the grant — only a missing
    'initial' ledger entry does."""
    # First request registers + grants 100.
    assert client.get("/api/credits").json()["balance"] == credits.INITIAL_CREDITS
    # Simulate having spent everything.
    user = session.exec(
        select(User).where(User.auth0_id == TEST_USER["sub"])
    ).first()
    user.credits = 0
    session.add(user)
    session.commit()

    assert client.get("/api/credits").json()["balance"] == 0
    history = client.get("/api/credits/transactions").json()
    assert [t["kind"] for t in history] == ["initial"]  # still just the one grant


def test_text_llm_call_spends_one_credit(client, team, monkeypatch):
    """Describing a player (text) costs 1 credit and records a transaction."""
    pid = client.get(f"/api/teams/{team.id}").json()["players"][0]["id"]

    async def fake_profile(text, current):
        return PlayerProfileResult(positions=["ST"], description="quick")

    monkeypatch.setattr("app.routers.roster.extract_profile", fake_profile)

    before = client.get("/api/credits").json()["balance"]
    r = client.post(
        f"/api/teams/{team.id}/players/{pid}/describe",
        json={"text": "fast striker"},
    )
    assert r.status_code == 200
    after = client.get("/api/credits").json()["balance"]
    assert after == before - credits.COST_TEXT

    latest = client.get("/api/credits/transactions").json()[0]
    assert latest["kind"] == "text"
    assert latest["amount"] == -credits.COST_TEXT
    assert latest["balance_after"] == after


def test_image_llm_call_spends_five_credits(client, team, monkeypatch):
    """An image extraction costs 5 credits."""
    from app.schemas import MatchDraft, MatchExtractResult

    async def fake_extract(data, media_type):
        return MatchExtractResult(matches=[MatchDraft(opponent="X", date="2026-06-14")])

    monkeypatch.setattr(
        "app.routers.matches.extract_matches_from_image", fake_extract
    )
    before = client.get("/api/credits").json()["balance"]
    files = {"image": ("f.png", io.BytesIO(b"x"), "image/png")}
    r = client.post("/api/matches/extract", files=files, data={"team_id": team.id})
    assert r.status_code == 200
    after = client.get("/api/credits").json()["balance"]
    assert after == before - credits.COST_IMAGE
    assert client.get("/api/credits/transactions").json()[0]["kind"] == "image"


def test_insufficient_credits_returns_402(client, team, session, monkeypatch):
    """With an empty balance, an LLM call is rejected before any state change."""
    pid = client.get(f"/api/teams/{team.id}").json()["players"][0]["id"]

    # Drain the balance.
    user = session.exec(
        select(User).where(User.auth0_id == TEST_USER["sub"])
    ).first()
    user.credits = 0
    session.add(user)
    session.commit()

    async def fake_profile(text, current):
        return PlayerProfileResult(description="x")

    monkeypatch.setattr("app.routers.roster.extract_profile", fake_profile)

    r = client.post(
        f"/api/teams/{team.id}/players/{pid}/describe",
        json={"text": "fast striker"},
    )
    assert r.status_code == 402
    assert client.get("/api/credits").json()["balance"] == 0


def test_credits_require_auth(unauth_client, monkeypatch):
    import app.auth as auth
    from app.config import settings

    monkeypatch.setattr(settings, "auth0_domain", "test-tenant.eu.auth0.com")
    monkeypatch.setattr(settings, "auth0_audience", "https://api.test/")
    assert unauth_client.get("/api/credits").status_code == 401
