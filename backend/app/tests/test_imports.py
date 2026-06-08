"""Roster import review workflow tests.

The two AI agents (roster matcher, command parser) and the OCR extractor are
stubbed; we test the classification, edit/delete/merge mechanics, and that
NOTHING reaches the `player` table until confirm.
"""

import io

import pytest
from sqlmodel import select

from app.models import Player
from app.schemas import (
    CommandResult,
    ImportAction,
    MatchCandidate,
    MatchResult,
    PlayerOut,
    RosterResult,
)

IMG = {"image": ("roster.png", io.BytesIO(b"fakeimage"), "image/png")}


@pytest.fixture(autouse=True)
def _clear_store():
    """The import store is an in-memory singleton — reset it around each test."""
    from app.services.import_store import store

    store.clear()
    yield
    store.clear()


def _players(session, team_id):
    return list(session.exec(select(Player).where(Player.team_id == team_id)).all())


def _stub_extract(monkeypatch, players):
    async def fake_extract(data, content_type):
        return RosterResult(players=players)

    monkeypatch.setattr("app.routers.imports.extract_roster", fake_extract)


def _stub_match(monkeypatch):
    """Match imported 'Li Gang' to an existing '李刚' at 0.92 confidence."""

    async def fake_match(imported, existing):
        by_name = {p.name: pid for pid, p in existing}
        matches = []
        for idx, p in imported:
            if p.name == "Li Gang" and "李刚" in by_name:
                matches.append(
                    MatchCandidate(
                        imported_index=idx,
                        matched_player_id=by_name["李刚"],
                        confidence=0.92,
                        rationale="English/Chinese form of the same name",
                    )
                )
        return MatchResult(matches=matches)

    monkeypatch.setattr("app.services.import_review.match_roster", fake_match)


@pytest.fixture
def imported_review(client, session, team, monkeypatch):
    """Run a stubbed import against a team (John #9 ST, David #8 CM, 李刚 #11)
    and return (review_body, team_id, session_id)."""
    li = Player(team_id=team.id, name="李刚", number=11, preferred_position="RB")
    session.add(li)
    session.commit()

    _stub_extract(
        monkeypatch,
        [
            PlayerOut(name="John", number=9, preferred_position="ST"),     # unchanged
            PlayerOut(name="David", number=10, preferred_position="CM"),   # updated 8->10
            PlayerOut(name="Mike", number=7, preferred_position="LW"),     # new
            PlayerOut(name="Li Gang", number=5, preferred_position="RB"),  # dup -> 李刚
        ],
    )
    _stub_match(monkeypatch)

    r = client.post(f"/api/teams/{team.id}/imports", files=IMG)
    assert r.status_code == 200, r.text
    return r.json(), team.id, r.json()["session_id"]


def test_create_import_classifies_into_sections(imported_review, session):
    body, team_id, _ = imported_review

    assert [p["name"] for p in body["new_players"]] == ["Mike"]
    assert [p["name"] for p in body["updated_players"]] == ["David"]
    assert [p["name"] for p in body["unchanged_players"]] == ["John"]

    dups = body["duplicate_candidates"]
    assert len(dups) == 1
    assert dups[0]["name"] == "Li Gang"
    assert dups[0]["confidence"] == 0.92
    assert dups[0]["match"]["name"] == "李刚"

    # before/after on the updated player
    changes = {c["field"]: (c["before"], c["after"]) for c in body["updated_players"][0]["changes"]}
    assert changes["number"] == ("8", "10")

    # the live roster is untouched: still John, David, 李刚 (3)
    assert len(_players(session, team_id)) == 3


def test_edit_only_touches_session(imported_review, client, session):
    body, team_id, sid = imported_review
    mike_id = body["new_players"][0]["id"]

    r = client.patch(f"/api/imports/{sid}/items/{mike_id}", json={"number": 21})
    assert r.status_code == 200
    assert r.json()["new_players"][0]["number"] == 21

    # nothing named Mike in the DB
    assert all(p.name != "Mike" for p in _players(session, team_id))


def test_delete_excludes_item(imported_review, client):
    body, _, sid = imported_review
    mike_id = body["new_players"][0]["id"]

    r = client.delete(f"/api/imports/{sid}/items/{mike_id}")
    assert r.status_code == 200
    assert r.json()["new_players"] == []


def test_merge_duplicate_into_existing(imported_review, client):
    body, _, sid = imported_review
    dup = body["duplicate_candidates"][0]

    r = client.post(
        f"/api/imports/{sid}/items/{dup['id']}/merge",
        json={"target_player_id": dup["match_player_id"]},
    )
    assert r.status_code == 200
    out = r.json()
    assert out["duplicate_candidates"] == []
    # now an update of the existing 李刚 (name + number differ)
    updated_names = [p["name"] for p in out["updated_players"]]
    assert "Li Gang" in updated_names


def test_command_applies_structured_actions(imported_review, client, monkeypatch):
    body, _, sid = imported_review
    david_id = body["updated_players"][0]["id"]

    async def fake_parse(text, items, existing):
        return CommandResult(
            actions=[ImportAction(type="edit", item_id=david_id, number=99)],
            reply="Set David's number to 99.",
        )

    monkeypatch.setattr("app.routers.imports.parse_command", fake_parse)

    r = client.post(f"/api/imports/{sid}/command", json={"text": "change David to 99"})
    assert r.status_code == 200
    out = r.json()
    assert out["reply"] == "Set David's number to 99."
    assert out["updated_players"][0]["number"] == 99


def test_confirm_writes_to_database(imported_review, client, session):
    body, team_id, sid = imported_review

    r = client.post(f"/api/imports/{sid}/confirm")
    assert r.status_code == 200
    res = r.json()
    assert res == {"created": 2, "updated": 1, "skipped": 1}  # Mike+LiGang, David, John

    players = _players(session, team_id)
    assert len(players) == 5  # 3 existing + Mike + Li Gang
    david = next(p for p in players if p.name == "David")
    assert david.number == 10

    # second confirm is rejected
    assert client.post(f"/api/imports/{sid}/confirm").status_code == 409


def test_unknown_session_404(client):
    assert client.get("/api/imports/999").status_code == 404


def test_create_import_from_text(client, team, monkeypatch):
    async def fake_text(text):
        assert "New Guy" in text
        return RosterResult(
            players=[PlayerOut(name="New Guy", number=21, preferred_position="LB")]
        )

    monkeypatch.setattr("app.routers.imports.extract_players_from_text", fake_text)
    r = client.post(
        f"/api/teams/{team.id}/imports/text",
        json={"text": "add New Guy, number 21, left back"},
    )
    assert r.status_code == 200
    body = r.json()
    assert [p["name"] for p in body["new_players"]] == ["New Guy"]
    assert body["new_players"][0]["number"] == 21


def test_create_import_from_text_requires_text(client, team):
    assert (
        client.post(f"/api/teams/{team.id}/imports/text", json={"text": "  "}).status_code
        == 422
    )
