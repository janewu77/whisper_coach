"""shared teams: users + user_team membership, join codes

Replaces per-row owner_id with a users table and a user_team membership join, so
a team (and its matches/roster) can be shared across users. Existing data is
migrated: each team's current owner_id becomes a user + a membership, and every
team gets a unique join code. The owner_id columns are then dropped.

Revision ID: a7b8c9d0e1f2
Revises: f6a7b8c9d0e1
Create Date: 2026-06-09 12:00:00.000000

"""
import secrets
from datetime import datetime, timezone
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'a7b8c9d0e1f2'
down_revision: Union[str, None] = 'f6a7b8c9d0e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def upgrade() -> None:
    op.create_table(
        'user',
        sa.Column('auth0_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('email', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('name', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('auth0_id'),
    )
    op.create_table(
        'userteam',
        sa.Column('user_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('team_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['team_id'], ['team.id']),
        sa.ForeignKeyConstraint(['user_id'], ['user.auth0_id']),
        sa.PrimaryKeyConstraint('user_id', 'team_id'),
    )
    op.add_column(
        'team',
        sa.Column('join_code', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )

    # ── Backfill: owner_id -> users + memberships, and assign join codes ──
    bind = op.get_bind()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    teams = bind.execute(sa.text("SELECT id, owner_id FROM team")).fetchall()

    seen_users: set[str] = set()
    used_codes: set[str] = set()

    def _code() -> str:
        while True:
            c = "".join(secrets.choice(_ALPHABET) for _ in range(6))
            if c not in used_codes:
                used_codes.add(c)
                return c

    for team_id, owner in teams:
        if owner:
            if owner not in seen_users:
                bind.execute(
                    sa.text(
                        'INSERT INTO "user" (auth0_id, created_at) '
                        "VALUES (:a, :t)"
                    ),
                    {"a": owner, "t": now},
                )
                seen_users.add(owner)
            bind.execute(
                sa.text(
                    "INSERT INTO userteam (user_id, team_id, created_at) "
                    "VALUES (:u, :tid, :t)"
                ),
                {"u": owner, "tid": team_id, "t": now},
            )
        bind.execute(
            sa.text("UPDATE team SET join_code = :c WHERE id = :id"),
            {"c": _code(), "id": team_id},
        )

    op.create_index(op.f('ix_team_join_code'), 'team', ['join_code'], unique=True)

    # ── Drop the legacy owner columns ──
    with op.batch_alter_table('match') as batch:
        batch.drop_index(batch.f('ix_match_owner_id'))
        batch.drop_column('owner_id')
    with op.batch_alter_table('team') as batch:
        batch.drop_index(batch.f('ix_team_owner_id'))
        batch.drop_column('owner_id')


def downgrade() -> None:
    op.add_column(
        'team',
        sa.Column('owner_id', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )
    op.add_column(
        'match',
        sa.Column('owner_id', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )

    # Best-effort: pick one member per team as the restored owner.
    bind = op.get_bind()
    rows = bind.execute(
        sa.text("SELECT team_id, user_id FROM userteam ORDER BY created_at")
    ).fetchall()
    owner_by_team: dict[int, str] = {}
    for team_id, user_id in rows:
        owner_by_team.setdefault(team_id, user_id)
    for team_id, owner in owner_by_team.items():
        bind.execute(
            sa.text("UPDATE team SET owner_id = :u WHERE id = :t"),
            {"u": owner, "t": team_id},
        )
        bind.execute(
            sa.text("UPDATE match SET owner_id = :u WHERE team_id = :t"),
            {"u": owner, "t": team_id},
        )

    op.create_index(op.f('ix_team_owner_id'), 'team', ['owner_id'])
    op.create_index(op.f('ix_match_owner_id'), 'match', ['owner_id'])
    op.drop_index(op.f('ix_team_join_code'), table_name='team')
    op.drop_column('team', 'join_code')
    op.drop_table('userteam')
    op.drop_table('user')
