from collections.abc import Generator

from sqlmodel import Session, create_engine

from app.config import settings

# check_same_thread=False is SQLite-only (lets the connection cross FastAPI
# threads); Postgres takes no such arg.
_connect_args = (
    {"check_same_thread": False} if settings.db_url.startswith("sqlite") else {}
)
engine = create_engine(settings.db_url, echo=False, connect_args=_connect_args)

# Schema is managed by Alembic (see alembic/ and README). Run `alembic upgrade
# head` to create/update tables; the app does not create them itself.


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
