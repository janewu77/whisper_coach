"""rename user_team.user_id -> auth0_id

The membership column held the Auth0 sub but was named user_id, which clashed
with the new surrogate users.id. Rename it to auth0_id for consistency (it is a
FK to users.auth0_id).

Revision ID: c9d0e1f2a3b4
Revises: b8c9d0e1f2a3
Create Date: 2026-06-09 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'c9d0e1f2a3b4'
down_revision: Union[str, None] = 'b8c9d0e1f2a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('user_team') as batch:
        batch.alter_column('user_id', new_column_name='auth0_id')


def downgrade() -> None:
    with op.batch_alter_table('user_team') as batch:
        batch.alter_column('auth0_id', new_column_name='user_id')
