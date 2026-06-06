import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

from app.db import get_session
from app.main import app
from app.models import Player, Team


@pytest.fixture(name="session")
def session_fixture():
    """Fresh in-memory SQLite per test (StaticPool keeps one shared connection)."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


@pytest.fixture(name="client")
def client_fixture(session):
    def get_session_override():
        return session

    app.dependency_overrides[get_session] = get_session_override
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture(name="team")
def team_fixture(session):
    """A seeded team with two players."""
    team = Team(name="Test FC")
    session.add(team)
    session.commit()
    session.refresh(team)
    session.add(Player(team_id=team.id, name="John", number=9, preferred_position="ST"))
    session.add(Player(team_id=team.id, name="David", number=8, preferred_position="CM"))
    session.commit()
    return team
