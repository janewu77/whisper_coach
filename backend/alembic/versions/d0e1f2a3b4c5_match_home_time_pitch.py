"""add match is_home, pitch, kickoff_time

Revision ID: d0e1f2a3b4c5
Revises: c9d0e1f2a3b4
Create Date: 2026-06-09 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'd0e1f2a3b4c5'
down_revision: Union[str, None] = 'c9d0e1f2a3b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'match',
        sa.Column('is_home', sa.Boolean(), nullable=False,
                  server_default=sa.text('true')),
    )
    op.add_column(
        'match',
        sa.Column('pitch', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    )
    op.add_column(
        'match',
        sa.Column('kickoff_time', sqlmodel.sql.sqltypes.AutoString(),
                  nullable=True),
    )


def downgrade() -> None:
    op.drop_column('match', 'kickoff_time')
    op.drop_column('match', 'pitch')
    op.drop_column('match', 'is_home')
