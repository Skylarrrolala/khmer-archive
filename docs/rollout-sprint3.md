# Sprint 3 rollout checkpoint — 10 November 2026

**Production database rollout completed and verified on 10 November 2026.**
History is exactly 0001–0008, one record each. After the initial 0004 execution-role
mismatch, the owner explicitly approved unchanged verification as postgres and
sequential 0005–0008 application on success. All checks passed. See
[actual rollout results](rollout-results-0004-0008.md). GitHub push/deployment is
not approved. The application files below are already applied; do not rerun them.
These files replace the earlier 0004-only application draft for this rollout; the
old dry-run files remain historical evidence and embed the original, unhardened 0008.

## Exact reviewed permanent SQL

Run one complete application file, then the [read-only verifier](verify-rollout.sql)
in a separate fresh SQL Editor query as `postgres`. Require every `rollout_checks`
flag to be true and history to contain exactly 0001 through the stage just applied.
Save the full catalog/data result. Stop immediately on any error, false flag, timeout
or uncertain COMMIT; inspect history before any retry. Do not run all five files as
one batch. Each file contains one transaction and records its version only after
its internal checks succeed; an existing version is refused, never silently skipped.
Earlier committed stages remain applied if a later stage fails; stop and do not
deploy the app or attempt an automatic restore.

| Stage | Exact application file | SHA-256 of complete application file |
| --- | --- | --- |
| 0004 | [apply-0004.sql](apply-0004.sql) | `5ea5d5bff15ba8bd2e2d54499193dc015928d895ab05188e7131f9a83cb5975c` |
| 0005 | [apply-0005.sql](apply-0005.sql) | `2bae680f255a20df613d77a674e123d4db8c81fcce1e3bdbddfd059f193e681a` |
| 0006 | [apply-0006.sql](apply-0006.sql) | `3e093d0cbe54742065122bbeb3c6f98a19d9cfd11909dd83115898802e625833` |
| 0007 | [apply-0007.sql](apply-0007.sql) | `b544f0ab8046edbf0d1b137f03541462b57ac3a7accecb7f773fdd330ad3dfde` |
| 0008 | [apply-0008.sql](apply-0008.sql) | `085805634594a47e80eb1fa0b844f20e2ff46020503c27ad0c6ce5271f21f582` |

The embedded 0004–0007 files are byte-for-byte from `14a5c29`. Applied 0008 is
that same committed file plus only this separately tested permission fix:

```sql
-- Identity sequences have separate grants; only the definer needs this one.
revoke all on sequence public.review_history_id_seq from public, anon, authenticated;
```

Supabase default sequence grants are independent of table grants. The old grants
allowed API roles to advance/reset the audit counter if they obtained a SQL path;
a reset/exhaustion could make a future audit insert and its parent entry write fail.
No public exploitable RPC path was demonstrated. The table remains RLS-enabled,
without API privileges or policies; the owner/definer still writes the audit log.

Dependencies: 0004 creates photo-in-use protection; 0005 restricts listing; 0006
adds limits and uses 0004 in the upload policy; 0007 restricts review/edit behavior;
0008 installs status history after those final rules. None rewrites or deletes
existing entries, reviewers or photos. History starts empty without a backfill.
The wrappers enforce the saved data fingerprints before and after DDL. A legitimate
concurrent archive write may cause a safe abort; inspect rather than changing the
expected fingerprints to force passage. Transaction-local timeouts are 3s for lock
waits, 60s per statement, 30s idle and 120s total. Policy DDL can briefly block requests.
Migration history uses the existing version primary key; optional name/statements
metadata remains unset, so remote migration-file fetching is not supplied by it.

## Evidence and recovery gate

**Recovery verified on 10 November 2026.** See [recovery-0003.md](recovery-0003.md)
for scope, hashes, comparisons and the CLI-role explanation. A private logical
backup of public/Auth/Storage/history schemas was restored twice in a no-network
PostgreSQL 17.6 container, including a standard PostgreSQL artifact plus explicit
schema permissions. All 40 table fingerprints and captured security metadata
match; all 10 archive baseline checks pass. At that recovery checkpoint,
production's complete baseline and role-name inventory were unchanged, with
history exactly 0001–0003. The later rollout state is recorded below.

The two existing photo backups remain separate and untouched. Database exports
used SELECT-only Management API access; the earlier proposed CLI dump commands
were not used, and no production role was created or renewed. The existing
`cli_login_postgres` password is expired with zero active sessions; its definition
was not dropped or altered. Private backups contain Auth data and stay outside Git.

The owner subsequently approved all five reviewed application scripts. The first
run stopped after 0004 on a verifier-role mismatch. With explicit resume approval,
unchanged 0004 verification passed as postgres, then 0005–0008 committed and passed
verification sequentially. 0004 was not reapplied. Original archive fingerprints,
bucket settings, role metadata and sequence privacy passed final checks. No
application/verifier SQL was edited, and no role was created or renewed for the
checks. No push or deployment is approved.

## Local validation and remaining delivery work

- Unit tests: 67 passed. PostgreSQL 17 stand-in database assertions: 483 passed.
  The seven new sequence assertions failed against the original 0008 and passed
  with the revoke; the existing audit lifecycle still passes.
- All five wrappers passed local rehearsal: exact embedded source/hash checks,
  wrong-baseline rejection, forced post-DDL failure rolling back DDL/history,
  successful apply followed by read-only verification, and duplicate rejection.
  Verifier regressions detect added anon TRUNCATE, disabled Storage RLS, and an
  extra sequence grant. Local fixture fingerprints replace production constants
  only in temporary test copies; no hosted application was executed.
- The isolated release worktree now uses Next.js/eslint-config-next 16.4.1
  (`7abefaf`) and Sharp 0.35.5 (`65f34d8`), in separate AI-assisted security
  commits. The Next patch passed 67 unit tests, lint, TypeScript and the production
  build with `/review`; the Sharp patch passed 67 unit tests, lint and TypeScript,
  and reports patched librsvg 2.63.2. Full release checks follow after documentation.
- The earlier npm EALLOWREMOTE failure affected the lock-only resolver's handling
  of a bundled registry dependency. A normal `npm install --save-exact
  --ignore-scripts` resolved it without changing npm's remote-fetch restrictions
  or adding project configuration. No broad `npm audit fix` was used.
- The post-Sharp production audit has one high advisory for transitive
  source-map-js 1.2.1 (GHSA-68fv-2mgg-jv7q), requiring untrusted indexed source maps.
  Final dependency triage remains separate from the completed Next/Sharp patches.

- GitHub connector confirms `jesseorndorff` has write access. Current remote main
  is 892b8ac and local 14a5c29 descends from it; recheck immediately before push.
  Tracked files plus reachable/reflog/dangling local Git objects were scanned for
  credential patterns, with no private credential matches. This is not proof
  against every unknown secret format or unseen remote-only history.
- README/architecture now describe Sprint 3 and distinguish code from deployment.
  `.agents/` and `.codex/` remain outside the release worktree. Release preparation
  commits are separate logical changes. No merge, push or deployment was performed.
- The student's supplied reflection covers all three questions; it was not edited
  or saved on their behalf. Week 12 process log remains pending. Existing Sprint 3
  journal entries contain exact prompts/techniques/responses, but acceptance/change
  sections still marked Pending need the student's own review. Neither journal nor
  reflection was rewritten in this checkpoint. Nothing is claimed submitted.
- Authenticated hosted workflow, five Lab 10 attacks, partner findings and actual
  deployed commit remain to be checked after approved deployment. Known
  limits remain public known photo URLs, best-effort direct-Storage upload limits,
  reviewer decisions without a content-version check, and source/photo provenance.
- Fresh unauthenticated HTTP reads returned 200 for home, search, login and signup;
  `/review` returned 404, consistent with the queue not being deployed. These were
  HTTP checks, not private-browser interaction or authenticated workflow tests.

References: [Supabase backup/restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore),
[Storage bytes excluded from database backups](https://supabase.com/docs/guides/platform/backups),
[Next Server Actions advisory](https://github.com/vercel/next.js/security/advisories/GHSA-p3m5-59mp-jv5r),
[Next image advisory](https://github.com/vercel/next.js/security/advisories/GHSA-2464-fhr4-w9xw),
[Sharp advisory](https://github.com/lovell/sharp/security/advisories/GHSA-wq5f-xc86-pv6w).
