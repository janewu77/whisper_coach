"""The requested-formation harness: validate → retry with feedback → force."""

import asyncio

import app.agents.lineup as lineup_mod
from app.agents.lineup import generate_lineup
from app.schemas import LineupResult, LineupSlot, PlayerOut


class _FakeRun:
    def __init__(self, output):
        self.output = output


class _FakeAgent:
    """Returns the queued outputs one by one (repeats the last)."""

    def __init__(self, outputs):
        self.outputs = list(outputs)
        self.prompts = []

    async def run(self, prompt):
        self.prompts.append(prompt)
        out = self.outputs.pop(0) if len(self.outputs) > 1 else self.outputs[0]
        return _FakeRun(out)


def _players(n=11):
    return [PlayerOut(name=f"P{i}") for i in range(n)]


def _squad(formation, codes):
    return LineupResult(
        formation=formation,
        lineup=[
            LineupSlot(player=f"P{i}", position=c) for i, c in enumerate(codes)
        ],
        subs=[],
        reason="r",
    )


_CODES_442 = ["GK", "LB", "CB", "CB", "RB", "LM", "CM", "CM", "RM", "ST", "ST"]
_CODES_3331 = [
    "GK", "CB", "CB", "CB", "CM", "CM", "CM", "CAM", "CAM", "CAM", "ST",
]


def test_retry_until_requested_formation(monkeypatch):
    wrong = _squad("4-4-2", _CODES_442)
    right = _squad("3-3-3-1", _CODES_3331)
    agent = _FakeAgent([wrong, right])
    monkeypatch.setattr(lineup_mod, "build_agent", lambda *a, **k: agent)

    result = asyncio.run(
        generate_lineup(
            _players(), "X", None, team_size=11, formation="3-3-3-1"
        )
    )
    assert result.formation == "3-3-3-1"
    assert len(agent.prompts) == 2  # one retry
    assert "WRONG" in agent.prompts[1]
    assert "3-3-3-1" in agent.prompts[1]


def test_force_formation_after_retries(monkeypatch):
    """Two retries still wrong → positions are relabelled deterministically."""
    wrong = _squad("4-4-2", _CODES_442)
    agent = _FakeAgent([wrong])  # always wrong
    monkeypatch.setattr(lineup_mod, "build_agent", lambda *a, **k: agent)

    result = asyncio.run(
        generate_lineup(
            _players(), "X", None, team_size=11, formation="3-3-3-1"
        )
    )
    assert len(agent.prompts) == 3  # initial + 2 retries
    assert result.formation == "3-3-3-1"
    poss = [s.position for s in result.lineup]
    assert poss.count("GK") == 1
    assert sum(1 for p in poss if p in lineup_mod._DEF) == 3
    assert sum(1 for p in poss if p in lineup_mod._MID) == 3
    assert sum(1 for p in poss if p in lineup_mod._MID_ATT) == 3
    assert sum(1 for p in poss if p in lineup_mod._ATT) == 1
    # all eleven players kept, just relabelled
    assert {s.player for s in result.lineup} == {f"P{i}" for i in range(11)}


def test_matching_result_needs_no_retry(monkeypatch):
    right = _squad("3-3-3-1", _CODES_3331)
    agent = _FakeAgent([right])
    monkeypatch.setattr(lineup_mod, "build_agent", lambda *a, **k: agent)

    result = asyncio.run(
        generate_lineup(
            _players(), "X", None, team_size=11, formation="3-3-3-1"
        )
    )
    assert result.formation == "3-3-3-1"
    assert len(agent.prompts) == 1


def test_no_requested_formation_accepts_anything(monkeypatch):
    anything = _squad("4-4-2", _CODES_442)
    agent = _FakeAgent([anything])
    monkeypatch.setattr(lineup_mod, "build_agent", lambda *a, **k: agent)

    result = asyncio.run(generate_lineup(_players(), "X", None, team_size=11))
    assert result.formation == "4-4-2"
    assert len(agent.prompts) == 1
