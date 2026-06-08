"""Auth enforcement + per-user data isolation.

The `unauth_client` fixture leaves the real auth dependency in place; we flip
Auth0 config on with monkeypatch and stub JWT verification so we don't need a
live tenant. The `client` fixture runs as TEST_USER (auth overridden).
"""

import app.auth as auth
from app.config import settings
from app.models import Match, Team

from .conftest import TEST_USER


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


# ── Ownership isolation ──────────────────────────────────────────────────────

def test_cannot_list_other_users_matches(client, session):
    """A match owned by someone else never shows up in /api/matches."""
    other = Team(name="Other FC", owner_id="someone-else")
    session.add(other)
    session.commit()
    session.refresh(other)
    session.add(
        Match(owner_id="someone-else", team_id=other.id, opponent="X",
              location="Away", date="2026-06-10")
    )
    session.commit()

    assert client.get("/api/matches").json() == []


def test_cannot_create_match_against_foreign_team(client, session):
    other = Team(name="Other FC", owner_id="someone-else")
    session.add(other)
    session.commit()
    session.refresh(other)

    r = client.post(
        "/api/matches",
        json={"team_id": other.id, "opponent": "X", "location": "Away",
              "date": "2026-06-10"},
    )
    assert r.status_code == 404


def test_cannot_read_foreign_match(client, session):
    other = Team(name="Other FC", owner_id="someone-else")
    session.add(other)
    session.commit()
    session.refresh(other)
    foreign = Match(owner_id="someone-else", team_id=other.id, opponent="X",
                    location="Away", date="2026-06-10")
    session.add(foreign)
    session.commit()
    session.refresh(foreign)

    assert client.get(f"/api/matches/{foreign.id}").status_code == 404
    assert client.get(f"/api/teams/{other.id}").status_code == 404
    # sanity: TEST_USER really is the client identity
    assert TEST_USER["sub"] == "test-user"
