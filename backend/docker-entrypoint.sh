#!/bin/sh
# Apply DB migrations on startup, then hand off to the container CMD.
# Set RUN_MIGRATIONS=false to skip (e.g. when running multiple replicas and
# migrations are applied by a separate job).
set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "[entrypoint] running database migrations..."
  alembic upgrade head
fi

exec "$@"
