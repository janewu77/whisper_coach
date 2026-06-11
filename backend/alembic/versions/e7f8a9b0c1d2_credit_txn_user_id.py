"""credit_transaction references users.id instead of auth0_id

The ledger now points at the user's surrogate integer PK (users.id) rather
than the auth0_id string. Existing rows are backfilled via the users table;
the old auth0_id column is then dropped.

Revision ID: e7f8a9b0c1d2
Revises: d6e7f8a9b0c1
Create Date: 2026-06-11 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7f8a9b0c1d2'
down_revision: Union[str, None] = 'd6e7f8a9b0c1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'credit_transaction', sa.Column('user_id', sa.Integer(), nullable=True)
    )
    op.execute(
        "UPDATE credit_transaction SET user_id = users.id "
        "FROM users WHERE credit_transaction.auth0_id = users.auth0_id"
    )
    # Drop any orphaned rows (no matching user) before tightening the column.
    op.execute("DELETE FROM credit_transaction WHERE user_id IS NULL")
    op.alter_column('credit_transaction', 'user_id', nullable=False)
    op.create_index(
        op.f('ix_credit_transaction_user_id'), 'credit_transaction', ['user_id']
    )
    op.create_foreign_key(
        'fk_credit_transaction_user_id_users',
        'credit_transaction',
        'users',
        ['user_id'],
        ['id'],
    )
    op.drop_index('ix_credit_transaction_auth0_id', table_name='credit_transaction')
    op.drop_column('credit_transaction', 'auth0_id')


def downgrade() -> None:
    op.add_column(
        'credit_transaction',
        sa.Column('auth0_id', sa.String(), nullable=True),
    )
    op.execute(
        "UPDATE credit_transaction SET auth0_id = users.auth0_id "
        "FROM users WHERE credit_transaction.user_id = users.id"
    )
    op.alter_column('credit_transaction', 'auth0_id', nullable=False)
    op.create_index(
        'ix_credit_transaction_auth0_id', 'credit_transaction', ['auth0_id']
    )
    op.drop_constraint(
        'fk_credit_transaction_user_id_users',
        'credit_transaction',
        type_='foreignkey',
    )
    op.drop_index(
        op.f('ix_credit_transaction_user_id'), table_name='credit_transaction'
    )
    op.drop_column('credit_transaction', 'user_id')
