# Migration 0004 only — review draft, 10 November 2026

> Historical preparation record. Production has since advanced to verified
> migrations 0001–0008. See [rollout results](rollout-results-0004-0008.md).
> Do not replay these baseline/dry-run instructions on the migrated database.
> The original dry-run embeds 0008 before its separately tested sequence fix;
> the applied SQL and committed migration include that fix.

No SQL has been executed during this preparation. No migration file was
changed. This document does not authorize permanent application.

## Sequence finding from the supplied dry-run result

The temporary `public.review_history_id_seq` had direct `rwU` grants to
`anon` and `authenticated`: SELECT, UPDATE and USAGE. Those are excessive
for a private audit sequence. UPDATE permits `setval()`; UPDATE or USAGE
permits `nextval()`. Resetting or exhausting it could make a later audit
insert fail, which would roll back the entry write that fired its trigger.
SELECT also permits reading sequence state. Sequence privileges are separate
from the history table's grants; its REVOKE ALL does not revoke this ACL.

The ACL alone does not demonstrate a public REST/browser exploit. A path to
execute a sequence function as one of those roles would also be required;
none was found in this repository's public RPCs. `kind = S` is a sequence,
and its false RLS flags are normal. The excessive ACL is the issue.

Before a future permanent 0008 rollout, prepare and approve a separate
numbered hardening migration to revoke API-role/PUBLIC access to this
specific sequence. Apply it in the same transaction as 0008 so the excessive
grants never become visible as committed state. Keep the existing migration
files unchanged, leave unrelated default privileges alone, and add a small
sequence-grant regression check then. None of that fix is included in 0004.

The dry-run did not call nextval/setval. Changes to an existing sequence's
counter would not be undone by ROLLBACK, but creation of this new identity
sequence was inside the transaction. Its absence still needs to be checked
explicitly with the complete post-rollback query below.

## Baseline reported fully verified on 10 November

The user supplied an original PostgreSQL 17.6 baseline with these fingerprints:

| Data | Count | MD5 |
| --- | --- | --- |
| Entries | 10 | `38ec0562e30bac68e96107d3f4ccf272` |
| Reviewers | 1 | `5fc749c633b6ae1a0650ebd453f7e099` |
| Entry-photo object metadata | 2 | `971e5099367f4c7852edbcab3fb8211f` |

The owner subsequently reports that the complete post-rollback query passed
all 10 checks, history is exactly 0001–0003, and original policies, functions,
permissions and fingerprints match. This is owner-reported verification;
Codex has not opened a production connection or independently compared raw
production results. The apply preflight still checks the critical schema,
ownership/permission, RLS and history invariants immediately before DDL.

Keep the saved full baseline JSON for the post-application comparison. The
[read-only post-rollback query](check-post-rollback-0004-0008.sql) remains a
0003-baseline check; it is not the query to run after applying 0004 because
it deliberately expects later objects to be absent.

## Proposed 0004 application and verification — approval still required

1. Retain the owner's verified complete post-rollback result. Select the
   intended production project in Supabase, open SQL Editor in a fresh query,
   and select the normal `postgres` administrative role. This document is
   still a review draft; execution remains separately authorized by the owner.
2. Review [apply-0004.sql](apply-0004.sql). It embeds only the exact committed
   `0004_prevent_approved_photo_changes.sql` from `14a5c29`, SHA-256
   `db805bd16bb0e6dc2d5afb0b35359f5850a109ac678d4a91e87e523a2919fc9b`.
   It uses one BEGIN, baseline/permission checks and local timeouts, verifies
   the main 0004 result, records only version `0004`, and ends COMMIT.
   Application and the history row become permanent together. This is a
   permanent rollout draft, not the old rollback script. Do not run it yet.
3. Only after explicit execution approval, use one fresh administrative
   connection: paste the complete current `apply-0004.sql`, ensure no partial
   selection, and run the whole file once. Never run selected migration
   statements. On error, ROLLBACK and stop. If the connection drops around
   COMMIT, verify the resulting state before deciding whether it applied;
   do not blindly rerun. Policy DDL can block live requests
   briefly, even with a 3-second lock-wait limit and 120-second transaction limit.
4. Open a separate SQL Editor query using the same role. Paste the complete
   [verify-0004.sql](verify-0004.sql), run it and save all three output columns:
   `database_state`, `migration_versions`, `migration_0004_checks`. Expect all
   12 check flags true and versions `0001`, `0002`, `0003`, `0004`. Also expect:
   `photo_in_use(text)` exists as a stable SECURITY DEFINER function with
   an empty pinned search path, authenticated EXECUTE and no anon EXECUTE;
   Storage has three policies, no UPDATE/ALL policy, guarded own-folder
   INSERT/DELETE, and the original public SELECT policy.
5. Compare its full `database_state` with the saved complete pre-0004 state.
   Only the helper function and three Storage policy changes should differ.
   Entry rows/statuses, reviewers, photo metadata/bytes/URLs, bucket settings,
   managed ownership, six entries policies, column grants and `review_entry()`
   must stay unchanged. No later migration function/table/trigger/sequence
   should appear. Counts and the supplied fingerprints should still match
   unless legitimate concurrent writes occurred.
6. The sole application-time data write is the version `0004` ledger row,
   after the result guard and before COMMIT. If DDL, checks or that insert
   fail, the transaction cannot independently commit the other part. The
   script never creates/repairs history, rewrites old versions, masks duplicate
   rows with ON CONFLICT, or runs a separate CLI history command. The minimum
   Supabase ledger schema requires its `version` primary key; optional
   `name`/`statements` metadata is not populated by this version-only insert.
   The committed repository SQL remains authoritative. Remote migration-file
   fetching would need separately populated metadata. Stop after verification:
   do not run 0005–0008, `db push`, history repair, an app push or deployment.

0004 does not delete, replace or re-encode existing photos, nor change entry
content/status. It prevents future overwrites and removal of referenced files.
It does not add the 0005 listing restriction, 0006 limits, 0007 self-review
restriction or 0008 audit history. No app deployment is part of this step.

Preparation validation was static only: exact embedded committed bytes and
SHA-256, transaction/ledger ordering, read-only query contents, supplied
fingerprint constants, and a separate static review. The initial static
history-order check failed against the old no-history draft, then passed
after updating only the wrapper and verifier. No SQL was executed and no
database connection was opened during this preparation.

References: [PostgreSQL 17 sequence functions](https://www.postgresql.org/docs/17/functions-sequence.html),
[ACL privilege letters](https://www.postgresql.org/docs/17/ddl-priv.html),
[separate sequence grants](https://www.postgresql.org/docs/17/sql-grant.html),
[Supabase's migration history schema](https://github.com/supabase/cli/blob/bd0d25023ed2315b2a8048bbd5de60e619dbc6c4/pkg/migration/history.go).
