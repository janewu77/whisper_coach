"""add match unavailable_player_ids

Per-match availability overrides from the lineup screen. NULL means the coach
never touched the list (availability then derives from player absences).

Revision ID: d6e7f8a9b0c1
Revises: c5d6e7f8a9b0
Create Date: 2026-06-10 20:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd6e7f8a9b0c1'
down_revision: Union[str, None] = 'c5d6e7f8a9b0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'match', sa.Column('unavailable_player_ids', sa.JSON(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column('match', 'unavailable_player_ids')
