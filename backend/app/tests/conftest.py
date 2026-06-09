import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.auth import get_current_user
from app.db import get_session
from app.main import app
from app.models import Player, Team, User, UserTeam

# The identity all `client` requests run as. Auth verification is bypassed in
# tests by overriding get_current_user; enforcement itself is covered in
# test_auth.py via the `unauth_client` fixture (no override).
TEST_USER = {"sub": "test-user", "email": "tester@example.com"}


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
    """Authenticated client: DB + auth both overridden (runs as TEST_USER)."""
    app.dependency_overrides[get_session] = lambda: session
    app.dependency_overrides[get_current_user] = lambda: TEST_USER
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture(name="unauth_client")
def unauth_client_fixture(session):
    """Client with the real auth dependency in place (for enforcement tests)."""
    app.dependency_overrides[get_session] = lambda: session
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture(name="team")
def team_fixture(session):
    """A seeded team with two players, with TEST_USER as a member."""
    existing = session.exec(
        select(User).where(User.auth0_id == TEST_USER["sub"])
    ).first()
    if existing is None:
        session.add(User(auth0_id=TEST_USER["sub"], email=TEST_USER["email"]))
    team = Team(name="Test FC")
    session.add(team)
    session.commit()
    session.refresh(team)
    session.add(UserTeam(auth0_id=TEST_USER["sub"], team_id=team.id))
    session.add(Player(team_id=team.id, name="John", number=9, preferred_position="ST"))
    session.add(Player(team_id=team.id, name="David", number=8, preferred_position="CM"))
    session.commit()
    return team
