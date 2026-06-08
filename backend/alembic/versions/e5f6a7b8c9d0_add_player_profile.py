"""add player profile columns

Revision ID: e5f6a7b8c9d0
Revises: c2d3e4f5a6b7
Create Date: 2026-06-08 17:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'e5f6a7b8c9d0'
down_revision: Union[str, None] = 'c2d3e4f5a6b7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('player', sa.Column('positions', sa.JSON(), nullable=True))
    op.add_column(
        'player',
        sa.Column('preferred_foot', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )
    op.add_column('player', sa.Column('height_cm', sa.Integer(), nullable=True))
    op.add_column('player', sa.Column('traits', sa.JSON(), nullable=True))
    op.add_column(
        'player',
        sa.Column('description', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('player', 'description')
    op.drop_column('player', 'traits')
    op.drop_column('player', 'height_cm')
    op.drop_column('player', 'preferred_foot')
    op.drop_column('player', 'positions')
