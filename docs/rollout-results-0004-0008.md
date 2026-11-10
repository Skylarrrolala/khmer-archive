# Production database rollout complete — 10 November 2026

Migrations **0004–0008 are committed and verified** using the exact reviewed
application files. Final history is **0001, 0002, 0003, 0004, 0005, 0006, 0007,
0008**, each with exactly one record. No history repair, skipped migration,
automatic migration retry or duplicate application occurred.

## Application and verification

| Migration | Result |
| --- | --- |
| 0004 | Previously committed once; unchanged verification rerun as postgres passed all 6 rollout checks and all 12 stage-specific checks before 0005. Migration was not rerun. |
| 0005 | Exact guarded transaction committed; all 6 immediate rollout checks passed as postgres. |
| 0006 | Exact guarded transaction committed; all 6 immediate rollout checks passed as postgres. |
| 0007 | Exact guarded transaction committed; all 6 immediate rollout checks passed as postgres. |
| 0008 | Exact guarded transaction, including sequence revoke, committed; all 6 immediate rollout checks and explicit audit-privacy checks passed as postgres. |

Each file retained its reviewed SHA-256. Each application used its own BEGIN,
preflight guards, unchanged migration body, postchecks, migration-history INSERT
and COMMIT. The next migration was dispatched only after the preceding stage's
separate verification succeeded. Final independent SELECT checks confirmed the
complete ledger, archive integrity, bucket settings and sequence permissions.

The verified recovery backup remains private and available outside Git; all 16
recovery-input checksums matched before resumption and after rollout. Existing
photo-byte backups remain separate and unchanged. Private audit evidence retains
request hashes, responses, verification snapshots and the owner's resume approval.

## Original archive preserved

| Data | Count | MD5 |
| --- | --- | --- |
| Entries | 10 | `38ec0562e30bac68e96107d3f4ccf272` |
| Reviewers | 1 | `5fc749c633b6ae1a0650ebd453f7e099` |
| Entry-photo metadata | 2 | `971e5099367f4c7852edbcab3fb8211f` |

The bucket remains `entry-photos`, public=true, file_size_limit=4194304, with
image/jpeg, image/png and image/webp allowed. No existing entry/status, reviewer
assignment, photo metadata or bucket setting changed. No photo bytes were
uploaded, replaced or deleted by this workflow.

`review_history` is RLS-enabled, has no API policies and grants no table privilege
to anon or authenticated. Its identity sequence has **no SELECT, UPDATE or USAGE
privilege** for either role, and no PUBLIC grant. The new history and upload-claim
tables are empty: no historical rows were backfilled or test entries inserted.
No production role was created or renewed; the final CLI-role metadata and complete
role-name inventory match the start of the authorized resume. No role cleanup or
permission workaround was used to make verification pass.

## Execution context and preserved stop evidence

The first rollout stopped after 0004, exactly as instructed, when its read-only
API connection ran as `supabase_read_only_user` rather than the verifier's required
`postgres`. Five checks passed, but the named execution-role guard was false.
That role already existed in the verified backup. The original failed verification
and STOP record remain intact in the earlier private audit.

The owner then explicitly approved rerunning the unchanged SELECT-only verifiers
in the existing postgres context and, only on success, continuing 0005–0008. The
resume used the regular Management API context with SELECT-only verification SQL;
no migration/verifier SQL, role definition or permission was changed for this.
0004 passed before continuation, and no migration was rerun. Both the initial stop
and successful authorized resume remain part of the record.

## Remaining delivery work

- Production database readiness is verified; the reviewer queue code has not yet
  been pushed/deployed or tested with authenticated accounts on the live site.
- Next.js/eslint-config-next 16.4.1 and Sharp 0.35.5 are now committed separately
  in the isolated release worktree. Final full checks and dependency triage are
  still required before pushing; see [the rollout checkpoint](rollout-sprint3.md).
- Live permission/Storage/workflow tests, the five Lab 10 attacks and relevant
  partner findings remain to be rechecked after approved deployment.
- The student's reflection and Prompt Journal were not edited. Journal acceptance
  sections and the Week 12 process log remain pending; nothing is claimed submitted.
- Known limitations remain public known photo URLs, best-effort direct-Storage
  upload limits, review decisions without a content-version check, and unresolved
  source/photo provenance. No optional feature or UI redesign was introduced.

No Git commit, branch merge, GitHub push, Vercel deployment or unrelated database
change was performed in this rollout checkpoint. GitHub/deployment approval remains
separate from the now-completed production database approval.
