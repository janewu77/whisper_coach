import io

import pytest

from app.routers import matches as matches_router
from app.schemas import AdjustResult, LineupResult, LineupSlot, Substitution


@pytest.fixture
def stub_voice(monkeypatch):
    async def fake_generate(players, opponent, strength, **kwargs):
        return LineupResult(
            formation="4-3-3",
            lineup=[LineupSlot(player="John", position="ST")],
            reason="ok",
        )

    async def fake_adjust(current_lineup, note):
        return AdjustResult(
            substitutions=[Substitution(out="John", in_="David")],
            position_changes=[],
            reason=f"because: {note}",
        )

    async def fake_transcribe(data, filename, language=None):
        return "John is tired"

    monkeypatch.setattr(matches_router, "generate_lineup", fake_generate)
    monkeypatch.setattr(matches_router, "adjust_lineup", fake_adjust)
    monkeypatch.setattr(matches_router, "transcribe_audio", fake_transcribe)


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


def _audio():
    return {"audio": ("note.webm", io.BytesIO(b"fake audio bytes"), "audio/webm")}


def test_voice_note_transcribes_and_suggests(client, team, stub_voice):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={})
    r = client.post(f"/api/matches/{match_id}/notes/voice", files=_audio())
    assert r.status_code == 200
    body = r.json()
    assert body["transcription"] == "John is tired"
    assert body["suggestion"]["substitutions"][0]["in"] == "David"
    # the suggestion was driven by the transcribed text
    assert "John is tired" in body["suggestion"]["reason"]


def test_voice_note_requires_lineup_first(client, team, stub_voice):
    match_id = _make_match(client, team)
    r = client.post(f"/api/matches/{match_id}/notes/voice", files=_audio())
    assert r.status_code == 409


def test_voice_note_rejects_non_audio(client, team, stub_voice):
    match_id = _make_match(client, team)
    client.post(f"/api/matches/{match_id}/lineup", json={})
    files = {"audio": ("note.txt", io.BytesIO(b"hello"), "text/plain")}
    r = client.post(f"/api/matches/{match_id}/notes/voice", files=files)
    assert r.status_code == 422
