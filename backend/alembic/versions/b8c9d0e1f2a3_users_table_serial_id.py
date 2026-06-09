"""rename user->users, userteam->user_team; add serial users.id

The previous revision created `user`/`userteam` with auth0_id as the primary
key. This renames them to `users`/`user_team` and switches the primary key to a
new serial `id`, keeping auth0_id as a UNIQUE constraint (the FK target for
user_team.user_id).

Revision ID: b8c9d0e1f2a3
Revises: a7b8c9d0e1f2
Create Date: 2026-06-09 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b8c9d0e1f2a3'
down_revision: Union[str, None] = 'a7b8c9d0e1f2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.rename_table('user', 'users')
    op.rename_table('userteam', 'user_team')

    if op.get_bind().dialect.name == 'postgresql':
        # Swap the PK from auth0_id to a new serial id, keeping auth0_id UNIQUE.
        # The user_team FK is bound to the old PK index, so drop it first, then
        # re-point it at the new unique constraint. ADD COLUMN ... SERIAL
        # backfills existing rows.
        op.execute('ALTER TABLE users ADD CONSTRAINT uq_users_auth0_id UNIQUE (auth0_id)')
        op.execute('ALTER TABLE user_team DROP CONSTRAINT userteam_user_id_fkey')
        op.execute('ALTER TABLE users DROP CONSTRAINT user_pkey')
        op.execute('ALTER TABLE users ADD COLUMN id SERIAL PRIMARY KEY')
        op.execute(
            'ALTER TABLE user_team ADD CONSTRAINT user_team_user_id_fkey '
            'FOREIGN KEY (user_id) REFERENCES users (auth0_id)'
        )
    else:
        # SQLite (dev only): add the column; the PK swap isn't reproduced here.
        op.add_column('users', sa.Column('id', sa.Integer(), nullable=True))


def downgrade() -> None:
    if op.get_bind().dialect.name == 'postgresql':
        op.execute('ALTER TABLE user_team DROP CONSTRAINT user_team_user_id_fkey')
        op.execute('ALTER TABLE users DROP COLUMN id')  # drops users_pkey + seq
        op.execute('ALTER TABLE users ADD PRIMARY KEY (auth0_id)')
        op.execute('ALTER TABLE users DROP CONSTRAINT uq_users_auth0_id')
        op.execute(
            'ALTER TABLE user_team ADD CONSTRAINT userteam_user_id_fkey '
            'FOREIGN KEY (user_id) REFERENCES users (auth0_id)'
        )
    else:
        op.drop_column('users', 'id')

    op.rename_table('user_team', 'userteam')
    op.rename_table('users', 'user')
