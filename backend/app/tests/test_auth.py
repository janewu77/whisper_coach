"""Auth enforcement + per-user data isolation.

The `unauth_client` fixture leaves the real auth dependency in place; we flip
Auth0 config on with monkeypatch and stub JWT verification so we don't need a
live tenant. The `client` fixture runs as TEST_USER (auth overridden).
"""

import app.auth as auth
from sqlmodel import select

from app.config import settings
from app.models import Match, Team, User, UserTeam

from .conftest import TEST_USER


def _seed_other_team(session) -> Team:
    """A team belonging to someone else (TEST_USER is not a member)."""
    if session.exec(select(User).where(User.auth0_id == "someone-else")).first() is None:
        session.add(User(auth0_id="someone-else"))
    team = Team(name="Other FC")
    session.add(team)
    session.commit()
    session.refresh(team)
    session.add(UserTeam(user_id="someone-else", team_id=team.id))
    session.commit()
    return team


def _enable_auth(monkeypatch):
    monkeypatch.setattr(settings, "auth0_domain", "test-tenant.eu.auth0.com")
    monkeypatch.setattr(settings, "auth0_audience", "https://api.test/")


def _stub_valid_token(monkeypatch, sub):
    class _FakeKey:
        key = "stub"

    monkeypatch.setattr(
        auth,
        "_get_jwks_client",
        lambda: type(
            "C", (), {"get_signing_key_from_jwt": lambda self, t: _FakeKey()}
        )(),
    )
    monkeypatch.setattr(auth.jwt, "decode", lambda *a, **k: {"sub": sub})


# ── Enforcement ──────────────────────────────────────────────────────────────

def test_unconfigured_returns_503(unauth_client):
    """No token can be verified when Auth0 isn't configured → 503, never open."""
    assert settings.auth_enabled is False
    assert unauth_client.get("/api/matches").status_code == 503


def test_missing_token_rejected(unauth_client, monkeypatch):
    _enable_auth(monkeypatch)
    r = unauth_client.get("/api/matches")
    assert r.status_code == 401
    assert "Bearer" in r.headers.get("www-authenticate", "")


def test_invalid_token_rejected(unauth_client, monkeypatch):
    _enable_auth(monkeypatch)
    r = unauth_client.get("/api/matches", headers={"Authorization": "Bearer nope"})
    assert r.status_code == 401


def test_valid_token_accepted(unauth_client, monkeypatch):
    _enable_auth(monkeypatch)
    _stub_valid_token(monkeypatch, "auth0|123")
    r = unauth_client.get("/api/matches", headers={"Authorization": "Bearer good"})
    assert r.status_code == 200
    assert r.json() == []  # this user owns nothing yet


# ── /api/me ──────────────────────────────────────────────────────────────────

def test_me_returns_current_user(client):
    r = client.get("/api/me")
    assert r.status_code == 200
    body = r.json()
    assert body["sub"] == TEST_USER["sub"]
    assert body["email"] == TEST_USER["email"]


def test_me_requires_auth(unauth_client, monkeypatch):
    _enable_auth(monkeypatch)
    assert unauth_client.get("/api/me").status_code == 401


def test_update_me_sets_name(client):
    # name starts empty (access-token claims have no name)
    assert client.get("/api/me").json()["name"] is None
    r = client.patch("/api/me", json={"name": "Coach Z"})
    assert r.status_code == 200 and r.json()["name"] == "Coach Z"
    assert client.get("/api/me").json()["name"] == "Coach Z"
    # blank values are ignored (don't clobber)
    client.patch("/api/me", json={"name": "   "})
    assert client.get("/api/me").json()["name"] == "Coach Z"


# ── Ownership isolation ──────────────────────────────────────────────────────

def test_cannot_list_other_users_matches(client, session):
    """A match on a team you don't belong to never shows up in /api/matches."""
    other = _seed_other_team(session)
    session.add(
        Match(team_id=other.id, opponent="X", location="Away", date="2026-06-10")
    )
    session.commit()

    assert client.get("/api/matches").json() == []


def test_cannot_create_match_against_foreign_team(client, session):
    other = _seed_other_team(session)

    r = client.post(
        "/api/matches",
        json={"team_id": other.id, "opponent": "X", "location": "Away",
              "date": "2026-06-10"},
    )
    assert r.status_code == 404


def test_cannot_read_foreign_match(client, session):
    other = _seed_other_team(session)
    foreign = Match(team_id=other.id, opponent="X", location="Away",
                    date="2026-06-10")
    session.add(foreign)
    session.commit()
    session.refresh(foreign)

    assert client.get(f"/api/matches/{foreign.id}").status_code == 404
    assert client.get(f"/api/teams/{other.id}").status_code == 404
    # sanity: TEST_USER really is the client identity
    assert TEST_USER["sub"] == "test-user"
