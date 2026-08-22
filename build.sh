#!/usr/bin/env bash
# Local build helper — mirrors the GHA workflow logic for reproducible dev builds.
# Uses podman by default; override with ENGINE=docker.
set -euo pipefail

ENGINE="${ENGINE:-podman}"
IMAGE="${IMAGE:-postgres-cnpg-extensions}"
TAG="${TAG:-local}"
PLATFORM="${PLATFORM:-}"

cd "$(dirname "$0")"

args=(build -t "${IMAGE}:${TAG}")
if [[ -n "${PLATFORM}" ]]; then
    args+=(--platform="${PLATFORM}")
fi
args+=(.)

echo "==> ${ENGINE} ${args[*]}"
"${ENGINE}" "${args[@]}"

echo
echo "==> Smoke test — initdb + start postgres + CREATE EXTENSION for all four"
# CNPG image has no ENTRYPOINT (operator injects boot logic). For smoke we run our own
# initdb/postgres cycle inside the container as UID 26 (postgres).
smoke_script='
set -eux
export PGDATA=/tmp/pgdata
initdb -D "$PGDATA" -U postgres --auth=trust >/dev/null
{
    echo "shared_preload_libraries = '\''pg_cron'\''"
    echo "cron.database_name = '\''postgres'\''"
} >> "$PGDATA/postgresql.conf"
pg_ctl -D "$PGDATA" -l /tmp/pg.log -w start
psql -U postgres -v ON_ERROR_STOP=1 -f /tmp/smoke.sql
pg_ctl -D "$PGDATA" stop -m fast >/dev/null
'

smoke_sql='
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_jsonschema;
CREATE EXTENSION IF NOT EXISTS temporal_tables;
SELECT extname, extversion FROM pg_extension
 WHERE extname IN ('\''vector'\'','\''pg_cron'\'','\''pg_jsonschema'\'','\''temporal_tables'\'')
 ORDER BY extname;
'

"${ENGINE}" run --rm -i \
    --entrypoint bash \
    "${IMAGE}:${TAG}" \
    -c "printf %s \"\$1\" > /tmp/smoke.sql && bash -c \"\$2\"" _ "${smoke_sql}" "${smoke_script}"

echo
echo "==> Build + smoke OK: ${IMAGE}:${TAG}"
