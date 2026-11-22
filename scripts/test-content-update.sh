#!/usr/bin/env bash
#
# Exercises docs/v2/content/proposed-content-update.sql and
# rollback-content-update.sql in a throwaway Postgres container: the normal
# update and rollback, and every way they must refuse. Like scripts/test-db.sh
# it publishes no ports, never connects to Supabase, and removes the container
# and its data on exit, pass or fail.
#
# Each scenario starts from a fresh copy of one template database:
#   the Supabase stand-in (tests/db/supabase-stub.sql), migrations 0001-0008,
#   the seven researched rows exactly as in production-snapshot-2026-11-21.json,
#   and one contributor's entry that the scripts must never touch.
# A refusal only passes if the SQL failed with the expected message AND the
# whole database (every entry and every review-history row) is byte-identical
# to what it was just before the script ran: nothing was partially applied.
#
# Run from anywhere:  bash scripts/test-content-update.sh
set -uo pipefail
cd "$(dirname "$0")/.."

IMAGE="${KHMER_DB_TEST_IMAGE:-postgres:17-alpine}"
NAME="khmer-content-test-$$"
# Overridable so an older version of the scripts can be checked against the same scenarios.
UPDATE="${CONTENT_UPDATE_SQL:-docs/v2/content/proposed-content-update.sql}"
ROLLBACK="${CONTENT_ROLLBACK_SQL:-docs/v2/content/rollback-content-update.sql}"
PREFLIGHT=docs/v2/content/preflight-content-update.sql
PLAE_AI=31d7fcb7-5d07-4cff-aeee-e40444e2653b   # one of the seven targets
OWNER=aaaaaaaa-1111-4111-8111-111111111111

if ! docker info >/dev/null 2>&1; then echo "Docker is not running." >&2; exit 2; fi
TMP=$(mktemp -d)
cleanup() { docker rm --force --volumes "$NAME" >/dev/null 2>&1 || true; rm -r "$TMP"; }
trap cleanup EXIT INT TERM
docker run --detach --name "$NAME" --label org.khmer-archive.purpose=db-test \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -e POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=en-US" \
  "$IMAGE" >/dev/null || { echo "Could not start $IMAGE." >&2; exit 2; }
for _ in $(seq 1 60); do
  docker logs "$NAME" 2>&1 | grep -q "PostgreSQL init process complete" \
    && docker exec "$NAME" pg_isready -U postgres -q 2>/dev/null && break
  sleep 1
done

sql() { local db=$1; shift; docker exec -i -e PGCLIENTENCODING=UTF8 "$NAME" psql -U postgres -d "$db" -X -q -v ON_ERROR_STOP=1 "$@"; }

# ---- template ------------------------------------------------------------
docker exec "$NAME" createdb -U postgres template_content
sql template_content -f - < tests/db/supabase-stub.sql >/dev/null || exit 1
for m in supabase/migrations/000*.sql; do sql template_content -f - < "$m" >/dev/null || exit 1; done
node --no-warnings --input-type=module \
  -e "import { snapshotFixtureSql } from './scripts/generate-content-update.ts'; process.stdout.write(snapshotFixtureSql());" \
  | sql template_content -f - >/dev/null || exit 1
sql template_content >/dev/null <<SQL || exit 1
insert into auth.users (id, email) values ('$OWNER', 'owner@test.invalid');
insert into public.entries (id, name_khmer, name_english, told_by, context, description, photo_url, status, contributor_id)
values ('bbbbbbbb-2222-4222-8222-222222222222', 'នំក្រូច', 'Num Kroch', 'Family', 'Everyday snack', 'A contributor''s own words.',
  'https://example.test/storage/v1/object/public/entry-photos/$OWNER/cccccccc-3333-4333-8333-333333333333.jpg',
  'published', '$OWNER');
SQL

# ---- helpers ---------------------------------------------------------------
passed=0; failed=0
fresh() { sql postgres -c "set client_min_messages = warning" -c "drop database if exists s" -c "create database s template template_content" >/dev/null; }
# Everything a script could disturb: every entry (ids, text, markers, photos,
# timestamps, owners, statuses) and every review-history row.
fingerprint() {
  sql "$1" -tA -c "select md5(coalesce((select string_agg(e::text, '|' order by e.id) from public.entries e), ''))
    || '/' || md5(coalesce((select string_agg(h::text, '|' order by h.id) from public.review_history h), ''))"
}
ok() { passed=$((passed + 1)); echo "ok   $1"; }
bad() { failed=$((failed + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/     /' | head -8; }
apply() { sql s -f - < "$1" 2>&1; }
# Preflight lines: label|present|ready_for_update|ready_for_rollback
ready() { sql s -tA -F'|' -f - < "$PREFLIGHT" | grep -c "|t|$1|$2$"; }

expect_applied() {  # name, script
  local out; out=$(apply "$2") && ok "$1" || bad "$1" "$out"
}
expect_refused() {  # name, script, expected message
  local before after out code
  before=$(fingerprint s)
  out=$(apply "$2"); code=$?
  after=$(fingerprint s)
  if [ $code -eq 0 ]; then bad "$1 (the script succeeded)" "$out"
  elif ! grep -q -- "$3" <<<"$out"; then bad "$1 (wrong reason)" "$out"
  elif [ "$before" != "$after" ]; then bad "$1 (database changed)" "$out"
  else ok "$1 — refused: $(grep -o "aborted: .*changed\." <<<"$out" | head -1)"; fi
}
edit() { sql s -c "$1" >/dev/null; }

TEMPLATE=$(fingerprint template_content)
PROTECTED="select md5(string_agg(id || told_by || photo_url || created_at::text || coalesce(contributor_id::text, '-') || status, '|' order by id)) from public.entries"
PROTECTED_BEFORE=$(sql template_content -tA -c "$PROTECTED")

echo "# Normal path"
fresh
[ "$(ready t f)" = 7 ] && ok "preflight: all 7 ready for the update" || bad "preflight before update"
expect_applied "update applies" "$UPDATE"
[ "$(ready f t)" = 7 ] && ok "every row now holds exactly its reviewed text" || bad "post-update state"
[ "$(sql s -tA -c "$PROTECTED")" = "$PROTECTED_BEFORE" ] \
  && ok "ids, source markers, photos, timestamps, owners and statuses preserved" || bad "protected fields"
[ "$(sql s -tA -c "select md5(coalesce(string_agg(h::text, '|' order by h.id), '')) from public.review_history h")" \
  = "$(sql template_content -tA -c "select md5(coalesce(string_agg(h::text, '|' order by h.id), '')) from public.review_history h")" ] \
  && ok "review history untouched" || bad "review history"
[ "$(sql s -tA -c "select description from public.entries where contributor_id is not null")" = "A contributor's own words." ] \
  && ok "contributor's entry untouched" || bad "contributor's entry"
expect_refused "running the update a second time" "$UPDATE" "not in the expected starting state"
expect_applied "rollback applies" "$ROLLBACK"
[ "$(fingerprint s)" = "$TEMPLATE" ] && ok "after rollback the database is byte-identical to the start" || bad "rollback result"
expect_refused "running the rollback a second time" "$ROLLBACK" "not in the expected starting state"

echo "# The update refuses drift"
for change in \
  "Khmer name|update public.entries set name_khmer = name_khmer || 'x' where id = '$PLAE_AI'" \
  "English name|update public.entries set name_english = name_english || ' (edited)' where id = '$PLAE_AI'" \
  "occasion|update public.entries set context = context || ' / Weddings' where id = '$PLAE_AI'" \
  "description|update public.entries set description = description || ' A new memory.' where id = '$PLAE_AI'" \
  "source marker|update public.entries set told_by = 'Grandmother' where id = '$PLAE_AI'" \
  "photo|update public.entries set photo_url = '/entries/replaced.jpg' where id = '$PLAE_AI'" \
  "status|update public.entries set status = 'pending' where id = '$PLAE_AI'" \
  "ownership|update public.entries set contributor_id = '$OWNER', photo_url = 'https://example.test/storage/v1/object/public/entry-photos/$OWNER/dddddddd-4444-4444-8444-444444444444.jpg' where id = '$PLAE_AI'"
do
  fresh; edit "${change#*|}"
  expect_refused "update after a changed ${change%%|*}" "$UPDATE" "not in the expected starting state: Num Plae Ai"
done
fresh; edit "delete from public.entries where id = '$PLAE_AI'"
expect_refused "update with a target row missing" "$UPDATE" "6 of 7 target rows found"

echo "# The update refuses an unexpected count or result"
fresh; edit "create function pg_temp_skip() returns trigger language plpgsql as \$\$ begin if new.id = '$PLAE_AI' then return null; end if; return new; end \$\$;
  create trigger skip_one before update on public.entries for each row execute function pg_temp_skip();"
expect_refused "update when only 6 rows change" "$UPDATE" "6 of 7 rows changed"
fresh; edit "create function pg_temp_tamper() returns trigger language plpgsql as \$\$ begin new.told_by := 'tampered'; return new; end \$\$;
  create trigger tamper before update on public.entries for each row execute function pg_temp_tamper();"
expect_refused "update when a protected field changes underneath" "$UPDATE" "unexpected result for"
fresh; edit "create function pg_temp_log() returns trigger language plpgsql as \$\$ begin insert into public.review_history (entry_id, new_status) values (new.id, new.status); return new; end \$\$;
  create trigger log_change after update on public.entries for each row execute function pg_temp_log();"
expect_refused "update when review history would change" "$UPDATE" "review history changed"

echo "# The rollback refuses edits made after the update"
for change in \
  "Khmer name|update public.entries set name_khmer = name_khmer || 'x' where id = '$PLAE_AI'" \
  "English name|update public.entries set name_english = name_english || ' (edited)' where id = '$PLAE_AI'" \
  "occasion|update public.entries set context = context || ' / Weddings' where id = '$PLAE_AI'" \
  "description|update public.entries set description = description || ' A later correction.' where id = '$PLAE_AI'" \
  "status|update public.entries set status = 'pending' where id = '$PLAE_AI'"
do
  fresh; apply "$UPDATE" >/dev/null; edit "${change#*|}"
  expect_refused "rollback after a later ${change%%|*} edit" "$ROLLBACK" "not in the expected starting state: Num Plae Ai"
done
fresh; apply "$UPDATE" >/dev/null; edit "delete from public.entries where id = '$PLAE_AI'"
expect_refused "rollback with a target row missing" "$ROLLBACK" "6 of 7 target rows found"
fresh; apply "$UPDATE" >/dev/null; edit "create function pg_temp_skip() returns trigger language plpgsql as \$\$ begin if new.id = '$PLAE_AI' then return null; end if; return new; end \$\$;
  create trigger skip_one before update on public.entries for each row execute function pg_temp_skip();"
expect_refused "rollback when only 6 rows change" "$ROLLBACK" "6 of 7 rows changed"

# Fault injections: triggers that tamper with the database while a script runs.
ID_SWAP="create function pg_temp_swap_id() returns trigger language plpgsql as \$\$ begin
    if old.id = '$PLAE_AI' then new.id := 'eeeeeeee-5555-4555-8555-555555555555'; end if; return new; end \$\$;
  create trigger swap_id before update on public.entries for each row execute function pg_temp_swap_id();"
HISTORY_RETIME="create function pg_temp_retime() returns trigger language plpgsql as \$\$ begin
    update public.review_history set changed_at = changed_at + interval '1 second'
      where id = (select min(id) from public.review_history); return new; end \$\$;
  create trigger retime after update on public.entries for each row execute function pg_temp_retime();"
HISTORY_INSERT="create function pg_temp_log() returns trigger language plpgsql as \$\$ begin
    insert into public.review_history (entry_id, new_status) values (new.id, new.status); return new; end \$\$;
  create trigger log_change after update on public.entries for each row execute function pg_temp_log();"
HISTORY_DELETE="create function pg_temp_forget() returns trigger language plpgsql as \$\$ begin
    delete from public.review_history where id = (select min(id) from public.review_history); return new; end \$\$;
  create trigger forget after update on public.entries for each row execute function pg_temp_forget();"

echo "# Identity and history are verified in full"
fresh; edit "$ID_SWAP"
expect_refused "update when a target id changes underneath" "$UPDATE" "6 of 7 target ids present afterwards"
fresh; edit "$HISTORY_RETIME"
expect_refused "update when a history timestamp changes (row count unchanged)" "$UPDATE" "review history changed"
fresh; edit "$HISTORY_DELETE"
expect_refused "update when a history row is deleted" "$UPDATE" "review history changed"
fresh; apply "$UPDATE" >/dev/null; edit "$ID_SWAP"
expect_refused "rollback when a target id changes underneath" "$ROLLBACK" "6 of 7 target ids present afterwards"
fresh; apply "$UPDATE" >/dev/null; edit "$HISTORY_RETIME"
expect_refused "rollback when a history timestamp changes (row count unchanged)" "$ROLLBACK" "review history changed"
fresh; apply "$UPDATE" >/dev/null; edit "$HISTORY_INSERT"
expect_refused "rollback when a history row is inserted" "$ROLLBACK" "review history changed"
fresh; apply "$UPDATE" >/dev/null; edit "$HISTORY_DELETE"
expect_refused "rollback when a history row is deleted" "$ROLLBACK" "review history changed"

echo "# Concurrent writers wait until the update has finished"
# Run the real update with a pause inserted just before its COMMIT, and meanwhile
# try to write review history and edit a target row from a second session.
fresh
HISTORY_START=$(sql s -tA -c "select md5(coalesce(string_agg(h::text, '|' order by h.id), '')) from public.review_history h")
( awk '/^commit;$/ { print "select pg_sleep(4);" } 1' "$UPDATE" | sql s -f - > "$TMP/update.out" 2>&1; echo $? > "$TMP/update.code" ) &
sleep 1.5
history_write=$(sql s -c "set lock_timeout = '1s'" -c "insert into public.review_history (entry_id, new_status) values ('$PLAE_AI', 'published')" 2>&1)
history_code=$?
row_write=$(sql s -c "set lock_timeout = '1s'" -c "update public.entries set context = context || ' / edited' where id = '$PLAE_AI'" 2>&1)
row_code=$?
wait
[ $history_code -ne 0 ] && grep -q "lock timeout" <<<"$history_write" \
  && ok "a history write during the update waits on its lock (timed out after 1s)" || bad "concurrent history write" "$history_write"
[ $row_code -ne 0 ] && grep -q "lock timeout" <<<"$row_write" \
  && ok "an edit to a target row during the update waits on its lock (timed out after 1s)" || bad "concurrent row edit" "$row_write"
[ "$(cat "$TMP/update.code")" = 0 ] && [ "$(ready f t)" = 7 ] \
  && [ "$(sql s -tA -c "select md5(coalesce(string_agg(h::text, '|' order by h.id), '')) from public.review_history h")" = "$HISTORY_START" ] \
  && ok "the update still completed, and the history is exactly as it was" || bad "update under contention" "$(cat "$TMP/update.out")"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
