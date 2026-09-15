#!/usr/bin/env bash
#
# Exercises every Row Level Security policy in supabase/migrations/0001_init.sql
# against the real Supabase project, and prints a pass/fail line for each.
#
# WHY THIS TALKS TO POSTGREST AND NOT TO THE APP
#
# The claim this project makes is that ownership and the review workflow are
# enforced by Postgres, not by the user interface. Clicking around the app
# cannot demonstrate that — a hidden button proves nothing about what a
# determined visitor can do with the publishable key and curl. So every request
# below goes straight to the REST API with a real access token, exactly as
# someone bypassing the app would. A policy that only existed in React would
# fail here.
#
# BEFORE RUNNING
#
#   1. Supabase dashboard -> Authentication -> Sign In / Providers -> Email:
#      turn "Confirm email" OFF. The script needs a usable session, and a
#      project that requires confirmation returns a user with no token.
#   2. Have .env.local filled in (the script reads the URL and publishable key
#      from it, and never prints them).
#
# AFTERWARDS
#
#   1. Turn "Confirm email" back ON. Leaving it off lets anyone sign up with an
#      address they do not control.
#   2. Delete the throwaway rls-probe-*@mailinator.com user in Authentication
#      -> Users. The script cannot: removing a user needs the service_role key,
#      which this project deliberately does not have.
#
# WHAT IT WRITES
#
# It creates one entry of its own and removes it again, and uploads one small
# file into its own storage folder and removes that too. It also *attempts* an
# update and a delete against an existing published entry — those are the
# ownership checks, and they are expected to change nothing. If the policies
# were broken, that delete would really remove a row; supabase/seed.sql
# restores the seven researched entries if that ever happens.
#
# Exit codes: 0 all checks passed, 1 a check failed, 2 could not sign in.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"

if [ ! -f "$ENV_FILE" ]; then
  echo "No env file at $ENV_FILE — copy .env.example and fill it in." >&2
  exit 2
fi

URL=$(grep '^NEXT_PUBLIC_SUPABASE_URL' "$ENV_FILE" | cut -d= -f2)
KEY=$(grep '^NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY' "$ENV_FILE" | cut -d= -f2)

if [ -z "${URL:-}" ] || [ -z "${KEY:-}" ]; then
  echo "$ENV_FILE is missing NEXT_PUBLIC_SUPABASE_URL or ..._PUBLISHABLE_KEY." >&2
  exit 2
fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m  %s\n        got: %s\n' "$1" "$2"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "$2"; fi; }

# Reads one value out of a JSON response. Keeps the curl lines readable.
py() { python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); sys.exit()
print($1)" 2>/dev/null; }

# PostgREST answers a write that RLS filtered out with an empty array, and a
# write its `with check` refused with an error object. Both mean "refused"; the
# distinction is not one this script needs to make.
rows() { py "len(d) if isinstance(d,list) else -1"; }
refused() { [ "$1" = "0" ] || [ "$1" = "-1" ]; }

# example.com is rejected by Supabase's address validator, so the throwaway
# account uses a domain it accepts. No mail is sent while confirmation is off.
EMAIL="rls-probe-$(date +%s)@mailinator.com"
PASSWORD="probe-$(python3 -c 'import secrets; print(secrets.token_hex(12))')"

echo "== signing up a throwaway contributor =="
SIGNUP=$(curl -s -X POST "$URL/auth/v1/signup" -H "apikey: $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
TOKEN=$(printf '%s' "$SIGNUP" | py "d.get('access_token','')")
MY_UID=$(printf '%s' "$SIGNUP" | py "d.get('user',{}).get('id','')")

if [ -z "$TOKEN" ]; then
  echo "  No session returned. Is \"Confirm email\" still on?" >&2
  printf '  %s\n' "$(printf '%s' "$SIGNUP" | head -c 200)" >&2
  exit 2
fi
echo "  signed in as $MY_UID"

AUTH=(-H "apikey: $KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")
ANON=(-H "apikey: $KEY" -H "Content-Type: application/json")
REPR=(-H "Prefer: return=representation")
PROBE='"name_khmer":"[RLS PROBE]","told_by":"[RLS PROBE]","context":"[RLS PROBE]","description":"[RLS PROBE] written by scripts/verify-rls.sh"'

echo
echo "== a contributor may create their own entry, and it lands pending =="
NEW=$(curl -s -X POST "$URL/rest/v1/entries" "${AUTH[@]}" "${REPR[@]}" \
  -d "{$PROBE,\"name_english\":\"RLS PROBE — automated test row\",\"contributor_id\":\"$MY_UID\"}")
MINE=$(printf '%s' "$NEW" | py "d[0]['id'] if isinstance(d,list) and d else ''")
if [ -n "$MINE" ]; then ok "insert accepted"; else bad "insert accepted" "$(printf '%s' "$NEW" | head -c 160)"; fi
check "pending" "$(printf '%s' "$NEW" | py "d[0]['status'] if isinstance(d,list) and d else '?'")" \
  "the new row is pending, not published"

echo
echo "== the pending row is mine to see, and nobody else's =="
check "1" "$(curl -s "$URL/rest/v1/entries?id=eq.$MINE&select=id" "${AUTH[@]}" | rows)" \
  "its owner can read it"
check "0" "$(curl -s "$URL/rest/v1/entries?id=eq.$MINE&select=id" "${ANON[@]}" | rows)" \
  "an anonymous visitor cannot"

echo
echo "== a contributor cannot publish their own entry =="
N=$(curl -s -X PATCH "$URL/rest/v1/entries?id=eq.$MINE" "${AUTH[@]}" "${REPR[@]}" -d '{"status":"published"}' | rows)
if refused "$N"; then ok "self-publishing refused"; else bad "self-publishing refused" "$N rows changed"; fi
check "pending" "$(curl -s "$URL/rest/v1/entries?id=eq.$MINE&select=status" "${AUTH[@]}" | py "d[0]['status'] if d else '?'")" \
  "it is still pending afterwards"

echo
echo "== a contributor cannot claim an entry for someone else =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/rest/v1/entries" "${AUTH[@]}" \
  -d "{$PROBE,\"name_english\":\"RLS PROBE — forged owner\",\"contributor_id\":\"00000000-0000-0000-0000-000000000001\"}")
if [ "$CODE" = "403" ] || [ "$CODE" = "401" ]; then
  ok "insert carrying another uid refused (http $CODE)"
else
  bad "insert carrying another uid refused" "http $CODE"
fi

echo
echo "== a contributor cannot touch a row that is not theirs =="
# A published seed row. Its contributor_id is null, so auth.uid() = contributor_id
# is null rather than false — it fails the USING clause the same way another
# contributor's row would.
OTHER=$(curl -s "$URL/rest/v1/entries?select=id&limit=1" "${ANON[@]}" | py "d[0]['id'] if d else ''")
N=$(curl -s -X PATCH "$URL/rest/v1/entries?id=eq.$OTHER" "${AUTH[@]}" "${REPR[@]}" -d '{"context":"[RLS PROBE] should never land"}' | rows)
if refused "$N"; then ok "updating it changed nothing"; else bad "updating it changed nothing" "$N rows"; fi
N=$(curl -s -X DELETE "$URL/rest/v1/entries?id=eq.$OTHER" "${AUTH[@]}" "${REPR[@]}" | rows)
if refused "$N"; then ok "deleting it deleted nothing"; else bad "deleting it deleted nothing" "$N rows"; fi
check "7" "$(curl -s "$URL/rest/v1/entries?select=id&status=eq.published" "${ANON[@]}" | rows)" \
  "all seven seed entries are intact"

echo
echo "== storage: a contributor may only write into their own folder =="
TMP=$(mktemp)
printf 'rls probe' > "$TMP"
upload() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/storage/v1/object/entry-photos/$1/probe.png" \
    -H "apikey: $KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: image/png" --data-binary "@$TMP"
}
check "200" "$(upload "$MY_UID")" "upload into their own folder accepted"
CODE=$(upload "00000000-0000-0000-0000-000000000001")
if [ "$CODE" = "403" ] || [ "$CODE" = "400" ]; then
  ok "upload into another uid's folder refused (http $CODE)"
else
  bad "upload into another uid's folder refused" "http $CODE"
fi

echo
echo "== the contributor's own edit and delete do work =="
check "1" "$(curl -s -X PATCH "$URL/rest/v1/entries?id=eq.$MINE" "${AUTH[@]}" "${REPR[@]}" -d '{"context":"[RLS PROBE] edited","status":"pending"}' | rows)" \
  "editing their own entry succeeds"
check "1" "$(curl -s -X DELETE "$URL/rest/v1/entries?id=eq.$MINE" "${AUTH[@]}" "${REPR[@]}" | rows)" \
  "deleting their own entry succeeds"

echo
echo "== cleanup =="
curl -s -o /dev/null -X DELETE "$URL/storage/v1/object/entry-photos/$MY_UID/probe.png" \
  -H "apikey: $KEY" -H "Authorization: Bearer $TOKEN"
rm -f "$TMP"
echo "  archive holds $(curl -s "$URL/rest/v1/entries?select=id" "${ANON[@]}" | rows) entries again"
echo "  still to do by hand: delete $EMAIL, and turn \"Confirm email\" back on"

echo
printf '== %d passed, %d failed ==\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
