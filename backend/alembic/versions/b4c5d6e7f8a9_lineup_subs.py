"""add lineup subs column

The lineup generator now also returns the bench (subs in recommended
substitution order); store it next to the starting slots.

Revision ID: b4c5d6e7f8a9
Revises: a3b4c5d6e7f8
Create Date: 2026-06-10 16:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b4c5d6e7f8a9'
down_revision: Union[str, None] = 'a3b4c5d6e7f8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('lineup', sa.Column('subs', sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column('lineup', 'subs')
