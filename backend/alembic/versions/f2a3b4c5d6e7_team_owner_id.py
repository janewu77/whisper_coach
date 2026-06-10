"""add team owner_id

Re-introduces an owner on each team (the auth0_id of the creator). Ownership
governs team deletion and join-code rotation, and hides the join code from
non-owners. Existing teams are backfilled to their earliest member (the creator
joined their team first).

Revision ID: f2a3b4c5d6e7
Revises: e1f2a3b4c5d6
Create Date: 2026-06-10 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'f2a3b4c5d6e7'
down_revision: Union[str, None] = 'e1f2a3b4c5d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'team',
        sa.Column('owner_id', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )
    op.create_index(op.f('ix_team_owner_id'), 'team', ['owner_id'])

    # Backfill: the earliest member of each team is its creator/owner.
    bind = op.get_bind()
    rows = bind.execute(
        sa.text(
            "SELECT team_id, auth0_id FROM user_team ut "
            "WHERE created_at = ("
            "  SELECT MIN(created_at) FROM user_team WHERE team_id = ut.team_id"
            ")"
        )
    ).fetchall()
    for team_id, auth0_id in rows:
        bind.execute(
            sa.text("UPDATE team SET owner_id = :u WHERE id = :t"),
            {"u": auth0_id, "t": team_id},
        )


def downgrade() -> None:
    op.drop_index(op.f('ix_team_owner_id'), table_name='team')
    op.drop_column('team', 'owner_id')
