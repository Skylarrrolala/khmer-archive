# Recovery verified at migrations 0001–0003 — 10 November 2026

This records the pre-rollout recovery checkpoint. Production subsequently advanced
to verified migrations 0001–0008; see [the rollout results](rollout-results-0004-0008.md).

The approved backup was created and restore-tested. No permanent migrations,
production role changes, Git commit/push, or deployment were performed in this
checkpoint. Migration 0004 remains a separate approval step.

## Backup and isolation

A private logical export captured `public`, `auth`, `storage` and
`supabase_migrations`: **40 tables / 196 rows, 30 functions, 10 policies and 11
enums**, including actual constraints, indexes, triggers, grants, column grants,
default privileges, reviewer assignments, Auth dependencies and sequence state.
The entire JSON payload was transported as text to preserve exact 64-bit values.

The snapshot was restored into a Docker container using Supabase PostgreSQL
**17.6**, image `public.ecr.aws/supabase/postgres:17.6.1.166`, with networking
set to `none` and no published ports. A standard PostgreSQL custom-format backup
was then created from the verified restore and restored into a second database.
Explicit schema permissions are retained as a required supplement: pg_dump
omitted PUBLIC schema usage as an assumed default, which the second comparison
caught and the tested supplement restores.

Private artifacts are retained outside Git in the owner's backup folder; the
exact location was supplied in chat. They contain Auth records/password hashes,
so they must not be committed or shared publicly. The package includes a guarded
self-contained restore SQL file, standard `archive.dump`, schema permissions,
role metadata without database-role passwords, read-only source/verification SQL,
a strict local verifier, instructions, evidence and SHA-256 checksums.

`archive.dump` SHA-256: `a3ee4c4e24cb3699f30ad32a715a016384bb754e7c41ac9e614df749730fa738`.

This verifies logical database recovery for the four named schemas. Vault/Realtime
and other platform schemas, API/JWT keys, environment settings, database-role
passwords and running Auth/Storage/Vercel services are outside this backup scope.
Photo bytes remain in their existing separate backup; both checksums still match,
and no photo file or photo backup was changed.

## Results

| Check | Result |
| --- | --- |
| All 40 restored table counts and data fingerprints | Match, both restores |
| Schema, policies, functions, owners, grants, roles/settings, defaults, constraints, indexes, triggers, sequence state | Match; zero captured metadata differences |
| Enum ACLs and ICU en-US / collation version 153.121 | Match |
| Original archive baseline checks | 10/10 pass, both restores |
| Production full baseline after backup | Unchanged; 10/10 checks pass |
| Production role-name inventory | Unchanged |
| Migration history | Exactly 0001, 0002, 0003 |
| Wrong-database guards / strict verifier | Reject unintended target |
| Local visitor/contributor/reviewer SQL-role checks | Pass |
| 0004 preflight and before-state guards | Pass locally inside READ ONLY transaction |

Original archive fingerprints remain:

| Data | Count | MD5 |
| --- | --- | --- |
| Entries | 10 | `38ec0562e30bac68e96107d3f4ccf272` |
| Reviewers | 1 | `5fc749c633b6ae1a0650ebd453f7e099` |
| Entry-photo object metadata | 2 | `971e5099367f4c7852edbcab3fb8211f` |

Local read-only SQL-role checks confirmed published-only visitor reads, no visitor
review-RPC execution, contributor unpublished-entry privacy and review refusal,
private reviewer assignments, and the restored reviewer's membership/pending
visibility. These are database simulations, not live HTTP/JWT/browser tests, and
they preserve the 0003 behavior rather than claiming 0004–0008 protections exist.

## CLI role finding and cleanup

The earlier CLI initialized **`cli_login_postgres`**, a LOGIN role with NOINHERIT,
NOSUPERUSER, NOBYPASSRLS, NOCREATEROLE and NOCREATEDB. Its membership permits
`SET ROLE postgres` without ADMIN or inheritance. The installed CLI requests
`read_only: false` when obtaining a temporary password without a supplied database
password; its linked-query setup did so even though the SELECT used the
Management API. That initialization was unnecessary for that SELECT.

The role's password validity ended **10 November 2026 at 14:11:30 Phnom Penh time**
(07:11:30 UTC). The inspected state has **zero active sessions and zero owned
relations**. Password expiry does not delete the role. No session termination is
needed, and dropping the role is an optional separate privileged change requiring
review/approval; it was not attempted. Ownership outside the captured scope is not
asserted. No CLI login role was created, renewed, altered or dropped during this
backup: exports used SELECT-only Management API access with existing credentials.
Role definitions were recreated only inside the isolated restore container.

## Next: migration 0004 only, awaiting approval

The exact [apply SQL](apply-0004.sql) remains unchanged, whole-file SHA-256:
`5ea5d5bff15ba8bd2e2d54499193dc015928d895ab05188e7131f9a83cb5975c`.
Its embedded committed migration SHA-256 remains
`db805bd16bb0e6dc2d5afb0b35359f5850a109ac678d4a91e87e523a2919fc9b`.

After separate approval, run only the complete 0004 transaction, then the
[0004-specific read-only verifier](verify-0004.sql) and
[rollout catalog verifier](verify-rollout.sql) separately. Stop on any error,
false flag, timeout or uncertain COMMIT; inspect history before retrying.
Expect only 0004's helper/Storage policy changes and its atomic history row.
Entries, reviewers, photo metadata and bytes must remain intact. Do not continue
to 0005–0008 or deploy without the appropriate approval.

The reflection and Prompt Journal were not edited. Week 12 process-log status
remains pending; nothing is claimed submitted.

Sources: [installed CLI connection behavior](https://github.com/supabase/cli/blob/v2.117.0/apps/cli/src/command-internal/legacy-db-config.layer.ts),
[PostgreSQL password validity](https://www.postgresql.org/docs/17/sql-createrole.html).
