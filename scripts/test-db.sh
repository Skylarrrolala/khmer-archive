#!/usr/bin/env bash
#
# Runs the database tests in a throwaway Postgres container. It never
# connects to a Supabase project: no URL, key or password is read or needed.
#
# WHAT IT DOES
#
#   1. Starts one container from the official Postgres image, named and
#      labelled for this run, with no ports published. It is reachable only
#      through `docker exec`, so nothing else on the machine can connect to
#      it, which is why it can use trust auth: there is no password to leak.
#   2. Loads, in order:
#        tests/db/supabase-stub.sql        roles, auth.uid(), storage, grants
#        supabase/migrations/0001_init.sql
#        supabase/seed.sql                 the seven researched entries
#        tests/db/helpers.sql              assertion helpers (they refer to
#                                          public.entries, so they come after it)
#        tests/db/fixtures.sql             accounts A and B, one older pending row
#        supabase/migrations/0002_*.sql    in one transaction, as in production
#        tests/db/0002-ownership.test.sql
#        a snapshot of every row, then
#        supabase/migrations/0003_*.sql    in one transaction, as in production
#        tests/db/0003-review-gate.test.sql on the rows 0002's tests left
#        a snapshot of every row, then
#        supabase/migrations/0004_*.sql    in one transaction, as in production
#        tests/db/0004-photo-lock.test.sql  on the rows 0003's tests left
#        a snapshot of every row and file, then
#        supabase/migrations/0005_*.sql    in one transaction, as in production
#        tests/db/0005-photo-listing.test.sql on what 0004's tests left
#   3. On exit, pass or fail, removes that container and its data volume.
#      Nothing else in Docker is touched.
#
# BEFORE RUNNING
#
#   Docker running. The image (postgres:17-alpine unless KHMER_DB_TEST_IMAGE
#   says otherwise) is pulled on first use and kept for the next run.
#   `docker image rm postgres:17-alpine` removes it.
#
#   A run that is killed hard can leave its container behind. To find one:
#     docker ps -a --filter label=org.khmer-archive.purpose=db-test
#
# Exit codes: 0 all passed, 1 a test or a load step failed, 2 could not start.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${KHMER_DB_TEST_IMAGE:-postgres:17-alpine}"
NAME="khmer-archive-dbtest-$(date +%s)-$$"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running." >&2
  exit 2
fi

cleanup() { docker rm --force --volumes "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

# Production's database uses the ICU locale provider with en-US, so the test
# database does too. That matters for the text rules: what a regex counts as
# [:space:] comes from the locale.
if ! docker run --detach --name "$NAME" \
  --label org.khmer-archive.purpose=db-test \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -e POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=en-US" \
  "$IMAGE" >/dev/null; then
  echo "Could not start a container from $IMAGE." >&2
  exit 2
fi

# The image starts a temporary server to initialise the database, stops it,
# then starts the real one. Wait for the real one, or the first file would
# be loaded into a server about to shut down.
ready=0
for _ in $(seq 1 60); do
  if docker logs "$NAME" 2>&1 | grep -q "PostgreSQL init process complete" \
    && docker exec "$NAME" pg_isready -U postgres -q 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "The test database did not become ready." >&2
  docker logs "$NAME" 2>&1 | tail -20 >&2
  exit 2
fi

psql_in() {
  docker exec -i -e PGCLIENTENCODING=UTF8 "$NAME" \
    psql -U postgres -d postgres -X -q -v ON_ERROR_STOP=1 "$@"
}

# Loads one file. Setup output is hidden unless the step fails.
load() {
  local label="$1" file="$2"
  shift 2
  local out
  if ! out=$(psql_in "$@" -f - < "$file" 2>&1); then
    echo "  FAILED loading $label ($file):" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    exit 1
  fi
  echo "  loaded $label"
}

echo "== test database =="
psql_in -tA -c "select '  ' || version()" -c "select '  locale provider: ' || datlocprovider::text || ', ' || coalesce(datlocale, '') from pg_database where datname = current_database()"

echo "== setup =="
load "Supabase stand-in"   "$ROOT/tests/db/supabase-stub.sql"
load "0001_init.sql"       "$ROOT/supabase/migrations/0001_init.sql"
load "seed.sql"            "$ROOT/supabase/seed.sql"
load "test helpers"        "$ROOT/tests/db/helpers.sql"
load "fixtures"            "$ROOT/tests/db/fixtures.sql"

MIGRATION=$(ls "$ROOT"/supabase/migrations/0002_*.sql)
load "$(basename "$MIGRATION") (single transaction)" "$MIGRATION" --single-transaction

# Assertions arrive as NOTICEs ("ok N - ..."); a failure is an ERROR that
# stops the run. Query results go to /dev/null so only the assertions and
# the section headings print. Strip psql's "psql:<stdin>:LINE:" and
# "NOTICE:" prefixes.
run_tests() {
  echo
  echo "== tests: $(basename "$1") =="
  psql_in -o /dev/null -f - < "$1" 2>&1 \
    | sed -E 's/^psql:<stdin>:[0-9]+: //; s/^NOTICE:  //'
  return "${PIPESTATUS[0]}"
}

run_tests "$ROOT/tests/db/0002-ownership.test.sql"
status=$?

if [ "$status" -eq 0 ]; then
  echo
  echo "== setup: 0003 =="
  # Every row as it stands before 0003, so its tests can prove it changed none.
  psql_in -c "insert into tests.snapshots (label, hash) select 'before 0003:' || e.id, md5(e::text) from public.entries e" >/dev/null || exit 1
  MIGRATION=$(ls "$ROOT"/supabase/migrations/0003_*.sql)
  load "$(basename "$MIGRATION") (single transaction)" "$MIGRATION" --single-transaction
  run_tests "$ROOT/tests/db/0003-review-gate.test.sql"
  status=$?
fi

if [ "$status" -eq 0 ]; then
  echo
  echo "== setup: 0004 =="
  psql_in -c "insert into tests.snapshots (label, hash) select 'before 0004:' || e.id, md5(e::text) from public.entries e" >/dev/null || exit 1
  MIGRATION=$(ls "$ROOT"/supabase/migrations/0004_*.sql)
  load "$(basename "$MIGRATION") (single transaction)" "$MIGRATION" --single-transaction
  run_tests "$ROOT/tests/db/0004-photo-lock.test.sql"
  status=$?
fi

if [ "$status" -eq 0 ]; then
  echo
  echo "== setup: 0005 =="
  psql_in \
    -c "insert into tests.snapshots (label, hash) select 'before 0005:' || e.id, md5(e::text) from public.entries e" \
    -c "insert into tests.snapshots (label, hash) select 'before 0005 file:' || o.id, md5(o::text) from storage.objects o" \
    >/dev/null || exit 1
  MIGRATION=$(ls "$ROOT"/supabase/migrations/0005_*.sql)
  load "$(basename "$MIGRATION") (single transaction)" "$MIGRATION" --single-transaction
  run_tests "$ROOT/tests/db/0005-photo-listing.test.sql"
  status=$?
fi

echo
if [ "$status" -eq 0 ]; then
  echo "== all database tests passed =="
  exit 0
fi
echo "== a database test failed (psql exit $status) =="
exit 1
