"""add owner_id to team and match

Scopes data to the authenticated Auth0 user. Pre-auth rows have no owner to
attribute them to, so this migration DELETES all existing teams/matches/players/
lineups/notes and then adds the (NOT NULL, no-default) owner_id columns.

Revision ID: c2d3e4f5a6b7
Revises: a0f1e44bf3bd
Create Date: 2026-06-08 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'c2d3e4f5a6b7'
down_revision: Union[str, None] = 'a0f1e44bf3bd'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Child-first order so foreign keys are satisfied during the wipe.
_TABLES_CHILD_FIRST = ('note', 'lineup', 'match', 'player', 'team')


def upgrade() -> None:
    # Clean all pre-auth data — it predates ownership and cannot be attributed.
    for table in _TABLES_CHILD_FIRST:
        op.execute(f'DELETE FROM "{table}"')

    # Tables are now empty, so a NOT NULL column needs no server_default. Use
    # batch mode so SQLite (which rejects a plain ADD COLUMN ... NOT NULL) can
    # recreate the table; on Postgres this is a normal ALTER.
    with op.batch_alter_table('team') as batch:
        batch.add_column(
            sa.Column('owner_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False)
        )
        batch.create_index(batch.f('ix_team_owner_id'), ['owner_id'])
    with op.batch_alter_table('match') as batch:
        batch.add_column(
            sa.Column('owner_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False)
        )
        batch.create_index(batch.f('ix_match_owner_id'), ['owner_id'])


def downgrade() -> None:
    with op.batch_alter_table('match') as batch:
        batch.drop_index(batch.f('ix_match_owner_id'))
        batch.drop_column('owner_id')
    with op.batch_alter_table('team') as batch:
        batch.drop_index(batch.f('ix_team_owner_id'))
        batch.drop_column('owner_id')
