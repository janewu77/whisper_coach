"""credits system

Adds a per-user credit balance (users.credits) and an append-only ledger
(credit_transaction). Existing users are backfilled to the initial 100 credits
with a matching "initial" ledger entry so the history is consistent.

Revision ID: a3b4c5d6e7f8
Revises: f2a3b4c5d6e7
Create Date: 2026-06-10 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = 'a3b4c5d6e7f8'
down_revision: Union[str, None] = 'f2a3b4c5d6e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

INITIAL_CREDITS = 100


def upgrade() -> None:
    # Balance column (server_default so existing rows get 0, then backfill).
    op.add_column(
        'users',
        sa.Column('credits', sa.Integer(), nullable=False, server_default='0'),
    )

    op.create_table(
        'credit_transaction',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('auth0_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('amount', sa.Integer(), nullable=False),
        sa.Column('balance_after', sa.Integer(), nullable=False),
        sa.Column('kind', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('description', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['auth0_id'], ['users.auth0_id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_credit_transaction_auth0_id'),
        'credit_transaction',
        ['auth0_id'],
    )

    # Backfill: grant existing users the initial credits + a ledger entry.
    bind = op.get_bind()
    bind.execute(
        sa.text("UPDATE users SET credits = :c"), {"c": INITIAL_CREDITS}
    )
    bind.execute(
        sa.text(
            "INSERT INTO credit_transaction "
            "(auth0_id, amount, balance_after, kind, description, created_at) "
            "SELECT auth0_id, :c, :c, 'initial', 'Welcome credits', "
            "CURRENT_TIMESTAMP FROM users"
        ),
        {"c": INITIAL_CREDITS},
    )

    # Drop the server_default now that all rows have a value (app sets it).
    op.alter_column('users', 'credits', server_default=None)


def downgrade() -> None:
    op.drop_index(
        op.f('ix_credit_transaction_auth0_id'), table_name='credit_transaction'
    )
    op.drop_table('credit_transaction')
    op.drop_column('users', 'credits')
