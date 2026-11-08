# Prompt Journal — Sprint 1

Golden rule from Chapter 3: share and reuse effective prompts.
Three entries, one per work session.

> **One thing left to do.** Each entry's part 1 is a single blank line marked
> `PROMPT:`. Open the session named above it, copy the prompt, paste it in.
> Everything else is written. The technique labels in part 2 are the standard
> names — if Chapter 3's checklist words them differently, swap the label; the
> line underneath describes what you actually did and shouldn't need changing.

---

## Entry 1 — Tuesday 1 September

*Session: "Khmer Living Archive Desserts". Shipped `f742cad`.*

**1. Prompt**

PROMPT:

*(The kick-off prompt — top of that session. It's the one that produced browse,
search, the detail page and `0001_init.sql` in a single pass.)*

**2. Technique** — Context-setting with explicit constraints

I wrote the project rules into `CLAUDE.md` before asking for any code: locked
stack, four numbered features, a hard "nothing outside this" rule, and the
security requirements. So the constraints arrived as context, not as
corrections afterwards.

**3. What came back**

All of Sprint 1 in one pass — browse, search, detail page, and a migration
whose RLS policies it actually exercised against a local Postgres rather than
just asserting they worked.

**4. What I changed or rejected**

It had written "nom" throughout and the correct transliteration is "num"; I
sent it back that evening to fix all four files, and it flagged that one of
them was the migration — which is the file that must not be edited in place
once deployed.

---

## Entry 2 — Friday 4 September (lab)

*Sessions: "Git 22425 changes", then "Design rework color and typography".
Shipped `dff1beb`, `2ea800e`, `c1c0e03`, `0c210e9`, `cd61dfc`, `fbda8ec`,
`0021689`, `b2bcd81`.*

**1. Prompt**

PROMPT:

*(The seed-data prompt — the one that added five desserts. If the design prompt
felt like the one that mattered more, use that instead and swap parts 3 and 4
for the design notes at the bottom of this entry.)*

**2. Technique** — Constraining uncertainty

I told it what to do when it *didn't* know something — flag the gap with a
bracketed marker, don't guess — instead of only telling it what to produce.

**3. What came back**

Five real desserts with every unknown left visible: `[KHMER SCRIPT NOT
CONFIRMED]` where I hadn't supplied a spelling, `[NOT RECORDED]` where I
hadn't given an occasion, and `[SOURCE PENDING]` on every `told_by`.

**4. What I changed or rejected**

Three things it couldn't have known — Num Akor has no filling (it's a steamed
palm sugar sponge with grated coconut), the Khmer spellings for three
desserts, and dropping the Bobor row — and one thing it got structurally
wrong: the markers were printing raw on the live page, so a visitor read "Told
by [SOURCE PENDING - internet reference…]". I kept the markers in the database
and had only the rendering changed, to a "Source pending verification" badge.

> *Design half of the same session, if you'd rather use that prompt:* I gave it
> a reference layout to work from (reference-driven prompting). What came back
> was the maroon-and-cream palette with contrast ratios measured rather than
> eyeballed — but the composition took four more passes to land: the photos
> were cropped in half by a fixed 4:3 frame, the watermark was smudged across
> the headline at narrow widths and clipped off the edge at wide ones, and the
> search field truncated to "Search by na…" at 320px. The palette prompt
> worked first time; the layout prompt didn't.

---

## Entry 3 — Sunday 6 September (weekend)

*Same design session, continued. Shipped `9999625`, `4278461`, `16629d1`.*

**1. Prompt**

PROMPT:

*(Whatever you sent along with the source document holding the seven desserts.
This is the prompt that surfaced the problem in part 4.)*

**2. Technique** — Grounding in supplied source material

Rather than letting it research the desserts itself, I gave it a source
document and asked it to work from that.

**3. What came back**

The seven entries with ingredients, preparation, region and notes folded into
`description` instead of new columns, so the data model stayed minimal — plus
a fix I hadn't asked for, since `now()` is constant inside a transaction and
every seeded row had been getting an identical `created_at`.

**4. What I changed or rejected**

I rejected the testimony: the source document carried first-person passages
attributed to a named relative — "Grandmother recalls sitting under the stilt
house…" — that were composed, not transcribed, so I had the voice stripped and
the facts kept, left every `told_by` as a `[SOURCE PENDING]` marker, and wrote
the rule into `CLAUDE.md` the same session so it can't come back.

---

# Prompt Journal — Sprint 2

*Section opened on Friday 16 October 2026.*

How these entries were sourced, so nothing here reads as more than it is:

- **Entries R1–R4 are retrospective.** They were written on 16 October from
  the local Claude Code session transcripts in `~/.claude/projects/…` and
  the Codex session files in `~/.codex/sessions/…`. Each prompt is copied
  verbatim from those files. Parts 3 and 4 say only what the transcripts
  and commits record.
- **Entries 5 and 6 were written on the day**, as the work happened. Anything
  that has not happened yet is marked *pending*.
- **Technique labels** were suggested by Claude on 16 October. Each needs
  checking against Chapter 3's list and changing if the course names it
  differently.
- **Missing originals.** The prompts behind the core Sprint 2 code are not
  on this machine. For 6 September (`684f55d` accounts, `35c402b`
  submission form) they are in the cloud session
  `session_016oevNtsMMF2B7QjC38kJ1a`. For 15 September (`4951961`
  edit/delete, `8093518`, `07d7c51` the RLS script) no session is recorded.
  These entries can only be written once that text is recovered from
  claude.ai. Do not reconstruct them from memory.

---

## Entry R1 — Tuesday 22 September (retrospective, written 16 October)

*Claude Code session `2d502356`, 14:43 Cambodia time. Shipped `ca86047` on the
branch `fix-signup-confirmation`.*

**1. Prompt**

```text
i think the problem is still with the signup, it is not yet working properly
```

**2. Technique** — Reporting an observed failure *(suggested label)*

No diagnosis was offered and no fix requested: the prompt states what
happened when the feature was used for real, and leaves the cause open.

**3. What came back**

A diagnosis from the Supabase auth logs rather than from the code. Sign-up had
actually worked, but the button gave no sign it was busy, so it was clicked
about ten times and the repeats hit `over_email_send_rate_limit`. The address
typed had an underscore, so the confirmation email went nowhere. The Auth
"Site URL" was `http://localhost:3000`, and nothing in the app handled the
link's code. The code fix came with it: a self-disabling submit button,
`emailRedirectTo`, and an `/auth/confirm` route.

**4. What I changed or rejected**

As recorded in the session: I asked for the mistyped account to be removed
("aight remove the account"), then for the fix to be committed and pushed
before creating my real account ("let's push and commit first and then i'll
create the account"). It went onto its own branch and was not merged into
`main`, so the live site never got it. It was merged into the integration
branch on 16 October (`1b3e622`).

---

## Entry R2 — Friday 25 September, Lab 6 (retrospective, written 16 October)

*Prompt drafted with Codex (`gpt-6-luna`) acting as a planning partner, then
pasted into Claude Code session `1095852e` at 14:28. Shipped in `345dad2`.*

**1. Prompt**

```text
Implement only a generic error boundary for the app using a new `app/error.tsx` file.

Before editing, check the project’s instructions and installed Next.js version to confirm the supported error-boundary props and retry method. Do not assume a particular Next.js API version.

Requirements:
- Keep the existing Supabase data layer, schema, RLS policies, and contributor + pending/published/rejected review workflow unchanged.
- Show a short, friendly, generic message and a retry button, using the existing archive styling.
- Do not display `error.message` or other internal error details.
- Preserve the existing layout, header, and footer around the error UI.
- Do not add `loading.tsx`, move or rename `app/page.tsx`, change route groups, or alter motion behavior.
- Do not install packages or run database commands.
- Do not run tests unless I ask.

After editing, report the exact diff and explain how the error boundary works with this installed Next.js version.
```

**2. Technique** — Negative constraints that fence the scope *(suggested label)*

Most of the prompt says what must *not* change, and one line asks the model
to check the installed version's docs before assuming an API.

**3. What came back**

`app/error.tsx`, a Client Component that uses the installed version's
`retry()` (which re-fetches from the server) rather than `reset()`, and
never prints `error.message`.

**4. What I changed or rejected**

Two follow-up prompts, both in the transcript. The first (14:37) fixed a
comment still pointing at the old home-page path. The second (14:42) wrapped
that comment and added an `app/error.tsx` row to `docs/architecture.md`.
Codex then committed the result as `345dad2`. That commit carries no
AI-assistance line, though both models worked on it.

---

## Entry R3 — Tuesday 29 September (retrospective, written 16 October)

*Codex, VS Code extension, sessions `01a0ec08` and `01a0ec0b`, 14:20–14:28.
Nothing was committed.*

**1. Prompt** — three messages in a row, as typed:

```text
write the ruls for my entrues table
```

```text
generate me with the culumn name, rule, wrong looks like in this chat, dont implement it yet
```

```text
i wanna add characther limit too, how many character for each one, and also file format accepted when upload the photo
```

**2. Technique** — Iterative refinement behind a "don't implement yet" gate *(suggested label)*

**3. What came back**

A table of each column's rule and what a wrong value looks like. Then
proposed limits (`name_khmer` and `name_english` 100, `told_by` 120,
`context` 500, `description` 5,000 characters) and photo rules (JPEG, PNG
or WebP up to 5 MB; refuse SVG, GIF, HEIC and PDF). It also pointed out
that the database did not stop a client supplying its own `created_at`.

**4. What I changed or rejected**

Nothing at the time. The limits were not implemented in September. What was
implemented on 16 October is recorded in Entry 6.

---

## Entry R4 — Tuesday 29 September (retrospective, written 16 October)

*Codex, VS Code extension, session `01a0ebfe`, 14:09. Shipped `b012764` on
`smoother-motion`.*

**1. Prompt**

```text
remove the source pending tag from every entries
```

**2. Technique** — Direct instruction, no constraints *(suggested label)*

**3. What came back**

`b012764`. Rather than removing the marker, it hid the whole "Told by" line
whenever the source was unconfirmed. So the seven researched entries showed
no credit at all, while the footer still said every entry was credited.

**4. What I changed or rejected**

Nothing at the time ("commit"). On 16 October the integration branch left
`b012764` out, because hiding a missing source breaks the sourcing rule in
`CLAUDE.md`. The badge stays until a real person can be named.

---

## Entry 5 — Friday 16 October: the Sprint 2 audit

*Claude Code (`claude-opus-5-5`), this machine. Read-only; no files changed.*

**1. Prompt**

```text
Audit my Khmer Living Archive for Sprint 2. Reconstruct the work completed across Weeks 5–8, then assess current submission readiness. Do not implement fixes yet.

Repository: https://github.com/Skylarrrolala/khmer-archive
Live URL: https://khmer-archive-zeta.vercel.app/
Professor’s GitHub username: jesseorndorff
Deadline: October 19, 2026, 11:59 PM, Cambodia time.

Read AGENTS.md, CLAUDE.md, and project documentation first. For this audit, the Sprint 2 requirements below are authoritative over conflicting project instructions. Report those conflicts.

AUDIT RULES

- Read-only: no file changes, commits, pushes, deployments, migrations, database writes, package installs, or security-setting changes.
- Preserve uncommitted work.
- Fetch remote refs if available without changing the working tree.
- Never expose credentials, tokens, or secret values.
- Label evidence clearly: observed now, documented historical result, inferred, or unverified.
- Do not treat a commit message, screenshot, or old report as proof the current deployment passes.
- Do not invent prompts, dates, test results, personal decisions, or AI mistakes.

PART 1 — RECONSTRUCT THE SPRINT

Inspect all available local and remote branches, Git history, diffs, project notes, journals, lab documents, and review findings.

Build a chronological account of actual work, grouped by:
- Week 5: signup, login, logout, managed authentication.
- Week 6: database schema, ownership model, database integration.
- Week 7: contribution forms, photo uploads, owner edit/delete, validation, direct-request attacks.
- Week 8: partner review, fixes, regression testing, submission preparation.

Use actual commit dates; do not force work into a week if the evidence does not support it.

For each meaningful change, report:
- Date and commit.
- Problem or requirement.
- What changed.
- Test evidence recorded at the time.
- Remaining limitation.
- AI attribution, if present.

Compare local HEAD, working tree, remote main, other relevant branches, and deployed version if identifiable. GPT previously inspected main at 07d7c51; determine whether newer work exists locally or elsewhere.

Inspect available historical session records only if accessible and relevant. Do not claim to have reviewed chats you cannot access.

PART 2 — AUDIT AGAINST THE ACTUAL BRIEF

Important scope clarification:
Sprint 2 has NO review workflow. A new contribution must appear publicly immediately. Submit-review-publish belongs to Sprint 3. No roles, admin screens, notifications, or profile pages.

Check:

Visitors
- Live site loads; browsing, English/Khmer search, and detail pages work.
- Sprint 1 behavior has not regressed.
- Khmer titles, entry text, and search results render correctly.
- Photos load reasonably on a phone; state whether measured or untested.
- No visible junk, lorem ipsum, placeholder entries, or unresolved source markers.

Contributors
- Signup, confirmation if enabled, login, and logout.
- Helpful messages without account enumeration or technical leakage.
- Text plus at least one photo required for a new contribution.
- New entry immediately appears publicly with correct credit.
- A single name is accepted; do not require a Western-style first/last name.
- Khmer text accepted in every applicable text field.
- Empty fields, whitespace-only titles, .txt uploads, and oversized photos refused.
- Validation exists at the appropriate server/database/storage layers, not just HTML controls.

Ownership
- A cannot edit/delete B’s entries through the interface.
- A direct authenticated update/delete against B’s entry changes zero rows.
- The app does not misleadingly report zero-row mutations as successful.
- Reload/read-back proves the target entry remains unchanged.
- Test evidence uses two distinct accounts, not only an ownerless seed row.
- Inspect RLS USING and WITH CHECK, table grants, constraints, and storage policies.
- Check forged contributor_id, ownership reassignment, and modification of protected fields.
- Explain how ownership protection must remain intact when immediate publication replaces the premature pending-only workflow.

Repository and operations
- jesseorndorff has collaborator access.
- Small commits and AI-assisted attribution.
- No secrets in current files or available Git history, including reverted work.
- Redact all secret findings. Distinguish public Supabase publishable keys from privileged secrets.
- State scan coverage and limits.
- Verify Supabase dashboard project status if accessible; otherwise mark unverified.
- Check README and architecture docs against actual implementation.

Known leads to investigate, not assume:
- GPT observed seven public entries, all showing “Source pending verification.”
- Live signup says submissions remain unpublished until reviewed.
- submitEntry previously uploaded a photo before inserting the row without cleanup on insert failure.
- Historical RLS verification used one account and an ownerless seed row.
- README previously said Sprint 2 was not started despite existing auth/contribution code.

Do not run existing test scripts blindly. Read them first. Tests requiring writes, account creation, credential access, or configuration changes should be reported as pending with precise instructions.

PART 3 — JOURNAL AND REFLECTION EVIDENCE

Locate at least three genuine Sprint 2 Prompt Journal entries across the sprint. Each needs:
1. Exact prompt as sent.
2. Technique by name.
3. What came back.
4. What I changed before accepting.

Map available prompts to commits or session evidence. Identify missing original wording. Clearly label retrospective reconstruction; never backdate it.

Find evidence for the reflection:
1. What I built and a security decision I made beyond the brief.
2. Where AI got security wrong and how I caught it.
3. An unresolved worry and what fixing it would take.

Separate my documented choices from AI suggestions. Do not invent an AI security mistake just to fill paragraph two.

PART 4 — DELIVER THE REPORT

Return:
1. Current version and deployment summary.
2. Evidence-backed sprint timeline.
3. Rubric table using Verified / Partial / Missing / Unverified:
   - Works for visitors and contributors.
   - Ownership holds under attack.
   - Real collection and Khmer support.
   - Process and explainability.
   - Reflection.
4. Conflicts between project instructions and the Sprint 2 brief.
5. Journal/reflection evidence available and missing.
6. Exact remaining live/manual tests.
7. The three most useful findings, ordered by submission impact.

Finish with the single best next task. Discuss the code, never judge the coder. Do not fix anything yet.
```

**2. Technique** — Read-only audit with ranked authority and required evidence labels *(suggested label)*

The prompt names which source wins when two disagree (the brief over the
project files), bans writes, and makes every claim carry a label: observed,
documented, inferred or unverified.

**3. What came back**

A report covering seven areas. Its three findings ranked by submission impact:

1. RLS forced every new and edited entry to `pending`, so nothing a
   contributor submitted could appear publicly. The one real submission had
   been hidden since 25 September. The photo was optional.
2. No photo had ever been stored through the live app. Next's default 1 MB
   Server Action limit sat below the advertised 5 MB, and the storage bucket
   had no size or type limits.
3. What was live, what was merged and what was proven did not line up.
   Production served a build matching `345dad2`; `main` was `07d7c51`. The
   sign-up fix and the Sprint 1 journal were unmerged. Ownership had only
   been tested with one account against an ownerless seed row. A zero-row
   delete reported "The entry was deleted."

**4. What I changed or rejected**

*Pending — my review of the audit, in my own words.*

---

## Entry 6 — Friday 16 October: the integration and implementation pass

*Claude Code (`claude-opus-5-5`), this machine, on the branch
`sprint2-integration` in a separate worktree. Nothing pushed, merged or
deployed, and no production SQL run.*

**1. Prompt**

```text
Proceed from the Sprint 2 audit with a focused integration and implementation pass. Work incrementally: implement, check, and commit one logical change before starting the next.

Repository: https://github.com/Skylarrrolala/khmer-archive
Live URL: https://khmer-archive-zeta.vercel.app/
Professor’s GitHub username: jesseorndorff
Deadline: October 19, 2026, 11:59 PM, Cambodia time.

GOAL

Prepare one reviewable Sprint 2 version:
- Visitors can browse and search in English and Khmer.
- A stranger can sign up, log in, and contribute text with at least one photo.
- New contributions appear publicly immediately.
- Contributors can edit/delete only their own entries, enforced by the database.
- Genuine sources are credited by name, with permission.

Read applicable AGENTS.md, CLAUDE.md, and the audit first. The supplied Sprint 2 brief overrides conflicting project instructions: review workflows belong to Sprint 3.

COMMIT WORKFLOW — REQUIRED

Before implementation, show the proposed commit sequence, then proceed.

For each logical change:
1. Explain the change and why it is needed.
2. Implement only that change.
3. Run relevant checks and inspect the diff.
4. Stage only its files or hunks.
5. Commit with an accurate message and clear AI-assistance attribution.
6. Report the commit hash, changes, and validation before continuing.

Do not implement the entire fix list and split it into artificial commits afterward. The history must reflect the work as it happens.

Keep commits coherent and understandable. Closely dependent changes may belong together; do not knowingly leave the project broken just to make commits smaller.

Avoid blanket `git add .`. Keep unrelated cleanup, formatting, and existing uncommitted work out of your commits.

Preserve existing history. Do not squash everything into one integration commit, rewrite old commits, backdate work, or force-push.

1. ESTABLISH THE INTEGRATION BRANCH

- Inspect branches, remote refs, HEAD, and working-tree changes.
- Preserve the uncommitted Apollo comment without including it in unrelated commits.
- Create an isolated integration branch/worktree from current origin/main.
- Inspect the newer smoother-motion commits and ca86047 individually.
- Integrate relevant completed work while resolving dependencies deliberately. Preserve existing commits where practical.
- Do not include b012764’s concealment of missing source credits.
- Do not discard any existing branch or work.

2. IMPLEMENT SPRINT 2 CORRECTIONS

Publication and ownership:
- Add a new numbered migration; never edit 0001 in place.
- Make new and edited entries published for Sprint 2.
- Preserve owner checks in INSERT WITH CHECK, UPDATE USING/WITH CHECK, and DELETE USING.
- Protect ownership and immutable metadata against direct authenticated requests.
- Inspect existing table/column grants before choosing the grants or trigger design.
- Add appropriate database constraints for required text and reasonable length limits, checking compatibility with existing data first.
- Support single-word names and Khmer text.
- Revalidate the public archive after relevant mutations.
- Do not automatically publish the existing pending row without inspecting its content and obtaining my decision.

Photos and failure handling:
- Require a photo for new contributions without invalidating legitimate historical records.
- Align application upload limits, Server Action request limits, and storage bucket restrictions. Account for hosting request limits and multipart overhead.
- Validate uploads server-side. Do not treat browser-declared MIME types, extensions, or bucket MIME restrictions as proof that file bytes form a valid image.
- Use existing capabilities where practical; do not add dependencies without asking.
- Clean up an uploaded photo if inserting the entry fails.
- Handle cleanup failure explicitly.
- Preserve entered text where practical and explain any need to reselect a photo.

Auth and mutations:
- Integrate and inspect ca86047’s signup-confirmation fix.
- Check redirect validation and safe authentication error messages.
- Fix zero-row deletes so they do not claim an entry was deleted.
- Ensure failed edits also avoid misleading success messages.
- Keep credentials and tokens out of output, logs, commits, and journal entries.

Copy and documentation:
- Remove premature moderation/review language.
- Update README, architecture notes, and conflicting project instructions to match the implemented Sprint 2 behavior.
- Keep unresolved source credits visible.
- Do not fabricate source names, interviews, testimony, permission, or photo provenance.

3. VALIDATE AS YOU WORK

- Run relevant checks for each change.
- Run lint, TypeScript, and production build before declaring the integrated version ready.
- Add focused, meaningful tests for changed security rules, validation, upload failures, and mutation outcomes.
- Update the ownership test approach for immediate publication and TWO distinct accounts.
- Check UI access restrictions and direct authenticated requests.
- Verify rejected attacks leave the target entry unchanged through read-back.
- Include forged ownership on insert and ownership reassignment on update.
- Never disable email confirmation or weaken security to run tests.
- Do not run scripts blindly: inspect their prerequisites and side effects first.
- Use isolated local/test infrastructure where available. Do not create live test accounts or mutate production during this pass.
- Clearly distinguish tests run successfully from tests still pending.

4. RECORD THE PROCESS HONESTLY

- Record this actual prompt and today’s work as it happens.
- For journal entries, include the exact prompt, technique name, what came back, and what I actually changed before accepting.
- If my review or changes have not happened yet, mark that section pending.
- Label reconstructed historical entries as retrospective and use the real writing date.
- Do not invent missing prompts, dates, personal decisions, AI mistakes, or test results.
- Explain each security change plainly so I can answer: what does this rule do, why is it here, and what breaks without it?

5. PREPARE THE PRODUCTION ROLLOUT

Do not push, merge, deploy, apply production SQL, run migration repair, or alter live settings during this pass.

- Inspect the migration-history mismatch rather than assuming repair is safe.
- Prepare the exact rollout sequence, including current schema/policy/grant checks, compatibility between application and database versions, and rollback.
- Identify any hosting or Supabase configuration changes required.
- Do not expose secret values.

FINAL REPORT

Return:
- Integration branch and ordered commit hashes.
- What each commit changed and how it was checked.
- Final lint, TypeScript, build, and focused test results.
- Proposed production migration and rollout sequence.
- Remaining live two-account, signup, upload, and phone tests.
- Collaborator-access status for jesseorndorff, if readable.
- The specific genuine source names, permissions, and photo information needed from me.
- Remaining blockers and known limitations.

Continue through all authorized local work. Stop only at a concrete blocker or the production rollout boundary above.
```

**2. Technique** — Incremental workflow with a hard stop boundary *(suggested label)*

Each change is implemented, checked and committed before the next one
starts. The prompt states exactly where the work must stop: no push, no
merge, no deploy, no production SQL.

**3. What came back**

*Pending — filled in at the end of the session from the commits it
produced.*

**4. What I changed or rejected**

*Pending — my review of the branch, in my own words.*

---

*Continues through Sprint 3.*

---

# Prompt Journal — Sprint 3

## Entry 1 — Sunday 8 November 2026: Codex handoff and inspection

*Recorded during this session. This entry describes inspection, not an
implementation or deployment. Earlier Claude Code prompts have not been
recovered or reconstructed.*

**1. Prompt** — copied from the request in this conversation:

```text
Hey Codex, I need help finishing Sprint 3 of my Khmer Living Archive project for ICT 340. The deadline is tonight, November 8.

We previously worked on this using Claude Code, but I can't access it anymore. Please pick up from the existing repository instead of starting over.

Our Sprint 3 requirements are:

- Visitors can browse and search published entries only.
- Contributors can submit entries that start as pending.
- Reviewers can see pending entries in a review queue and publish or return them.
- Strangers cannot publish their own entries or change another contributor's entries, including through the browser console.
- The live site must work, and we need to keep our Git history and Prompt Journal.

Our latest security fixes are on `claude/practical-hawking-cn165u`, ending at commit `39f57b0`. Local main was fast-forwarded, but GitHub main hasn't been pushed yet.

Supabase production currently has migrations 0001–0003. Migrations 0004–0008 are committed but not applied. Pushing main triggers a Vercel production deployment, so don't push it before the database is ready.

First, please inspect the project and compare it with the Sprint 3 requirements. I'm especially concerned that we might not have a working reviewer queue with Publish and Return buttons.

Tell me what's already done, what's missing, and what we need to prioritize for submission.

If something is missing, we'll fix it one small chunk at a time. Run the tests, show me the changes, and wait for my approval before committing.

Don't modify production, apply migrations, merge, push, or deploy anything without asking me first.

Also, please keep track of the prompts and changes so I can document them honestly in my Sprint 3 Prompt Journal.
```

**2. Technique** — Requirements checklist and incremental handoff
*(suggested label; confirm the course's terminology).* The request asks for
evidence from the existing repository before making changes, and reserves
commits and production work for explicit approval.

**3. What came back**

- The actual checkout was `b2d2f5e` on `claude/practical-hawking-cn165u`,
  four commits behind its stored remote-tracking branch at `39f57b0`.
  Local `main` and stored `origin/main` were both `892b8ac`, six commits
  behind `39f57b0`. No fetch or branch update was made; these observations
  describe this workspace's refs, not a fresh query of GitHub.
- Codex inspected `39f57b0` using `git archive` in a temporary directory,
  leaving the checkout and Git history untouched.
- Public queries explicitly request published rows. Database policies
  restrict anonymous reads to published entries, enforce ownership, and
  default new entries to pending. Contributor pages show pending, published
  and returned statuses, and edits resubmit entries for review.
- The review backend exists: `is_reviewer()` and `review_entry()` in 0003,
  with self-review blocked by 0007 and status history added by 0008.
  However, there is no reviewer route, queue, Publish/Return UI, application
  call to `review_entry()`, or reviewer navigation link at `39f57b0`.
- Migrations 0004–0008 contain photo protection, listing restrictions,
  contributor limits, review separation and review history. Production's
  migration state (0001–0003) was supplied by the user, not independently
  checked. The latest upload code calls `claim_photo_upload()` from 0006;
  deploying that code before applying 0006 would break photo uploads.
- Checks against the `39f57b0` snapshot: `npm test` passed 56/56;
  `npm run lint` passed; TypeScript (`tsc --noEmit --incremental false`)
  passed; `npm run build` passed. The initial build could not find the
  local native Next.js compiler, so the repository's locked dependencies
  were installed with `npm ci --ignore-scripts --no-audit --no-fund` only
  in the temporary snapshot, then the build succeeded. No project
  dependency or lockfile was changed.
- `npm run test:db` was attempted against its disposable local Docker
  setup, but stopped with `Docker is not running.` No SQL assertions ran
  and no Supabase connection was made. Database security tests exist for
  migrations 0002–0008, but this session has not proved they pass.
- Read-only HTTP checks of `https://khmer-archive-zeta.vercel.app` returned
  200 for the homepage, `/?q=Kroch`, one published entry, login and signup;
  `/review` returned 404. Search included Num Kroch and excluded Num Korm.
  These were HTTP checks, not browser interaction or authenticated tests.
- README, project instructions and parts of the architecture document still
  describe Sprint 2 behavior. The prior journal ends in Sprint 2 with
  pending sections. Those historical sections were preserved.
- Recommended order: reconcile the checkout with the intended baseline;
  implement the missing reviewer queue using the existing database
  functions; run local database and authenticated workflow tests; prepare
  accurate documentation and rollout steps; ask for approval before
  production migrations, then before pushing/deploying.
- Repository change in this inspection: this journal entry only. No
  application code, migrations, branches, commits or production state were
  changed. Pre-existing untracked `.agents/` and `.codex/` were left alone.

**4. What I changed or rejected**

*Pending — the student's own review of these findings and decision about
the next small chunk. Codex has not written that reflection on their behalf.*

---

## Entry 2 — Sunday 8 November 2026: the reviewer queue

**1. Prompt** — copied from the next request in this conversation:

```text
Alright, let's fix the missing reviewer queue first since it's required for Sprint 3.
Before making changes, please reconcile the checkout with the latest feature branch `claude/practical-hawking-cn165u` at `39f57b0`. Preserve the existing uncommitted Prompt Journal changes and don't overwrite anything.
Then implement a simple `/review` page where authorized reviewers can see pending entries, view enough information to review them, and Publish or Return them using our existing database review function.
Make sure contributors and logged-out users can't access reviewer actions. Handle loading, errors, and empty states, but don't spend time redesigning the UI.
Keep the changes limited to the reviewer workflow. Run the available tests, lint, TypeScript checks, and build. Add relevant tests for the reviewer actions.
Show me the changes and test results before committing. Don't apply migrations, push, deploy, or modify production yet.
```

**2. Technique** — A small, test-first implementation
*(suggested label; confirm the course's terminology).* The plan was to
preserve the checkout, test reviewer authorization and decisions, add the
queue using the existing database functions and UI patterns, then verify
the whole change before requesting commit approval.

**3. What came back**

- Backed up the existing journal and uncommitted patch in a temporary
  directory. Fast-forwarded only `claude/practical-hawking-cn165u` from
  `b2d2f5e` to `39f57b0`, as requested. A SHA-256 check confirmed that the
  uncommitted journal was identical after that update. No merge commit was
  created, and `main` was left at `892b8ac`.
- Added `isCurrentUserReviewer()` and `requireReviewer()` to `lib/auth.ts`.
  Membership is read using the signed-in session and `is_reviewer()`.
  Visitors go to login with `/review` as the return destination;
  contributors receive a 404. A failed membership lookup denies access.
- Added `getPendingEntries()` and `reviewEntry()` to `lib/entries.ts`.
  The queue asks for pending entries oldest first. Decisions call the
  existing `review_entry(entry_id, decision)` function using the session;
  the database remains the security boundary. No migration or privileged
  key was added.
- Added `/review` with the stored names, photograph, source, context and
  full description. Reviewers have a navigation link. Their own entries
  explain that another reviewer is needed, and have no decision buttons.
  An older entry without a photo can be returned but has no Publish button.
- Added Server Actions for Publish and Return. Each action independently
  authorizes the caller and validates the id and decision. Success refreshes
  the queue, public browse/detail pages and contributor list. A refused or
  stale decision is reported as unchanged; database and connection failures
  use a fixed message rather than exposing service details.
- Reused `SubmitButton` for pending feedback and `FadeInImage` for photos.
  Loading starts after authorization, using Suspense inside the page so
  denied requests retain their redirect or 404. Empty state is explicit;
  unexpected page errors use the existing root error boundary. No design
  system, motion, dependency, schema or production setting changed.
- Added 11 tests in `tests/review-actions.test.ts`. They execute the actual
  auth, data and action modules, replacing only framework/network imports.
  The first runnable test pass failed because the action module was missing;
  the completed implementation passed. An earlier test-harness run stopped
  on a Node-unsupported TypeScript parameter property; that test syntax was
  corrected before implementation.
- Verification: `npm test` passed 67/67; `npm run lint` passed; TypeScript
  (`tsc --noEmit --incremental false`) passed; production build passed and
  listed `/review`. The build used a temporary copy containing the changed
  source and the locked dependencies installed during Entry 1, because this
  checkout's existing dependency installation lacks the native Next compiler.
  No dependency or lockfile in the project was changed.
- Database tests initially stopped because Docker was off. Codex started
  the installed local Docker Desktop engine and reran `npm run test:db`:
  all 476 SQL assertions passed across migrations 0002–0008. The script
  used and removed its throwaway Postgres container. These were local
  migration applications, not changes to Supabase or production.
- A temporary assert-based HTTP harness ran the actual production build
  against a localhost Supabase stand-in. It verified visitor redirects,
  contributor 404s, denial of direct form POSTs by both, reviewer content,
  own-entry and missing-photo controls, Publish/Return RPC payloads and
  redirects, loading/empty states, and no raw database error in the response.
  This simulated the backend; it was not an authenticated live-site test
  or a visual browser test. The temporary servers were stopped afterward.
- A separate code-review agent inspected the uncommitted reviewer workflow
  and ran the 11 new tests. It reported no findings. That review did not
  inspect production or change files.
- All changes remain uncommitted for the student's review. No production
  request, production migration, push or deployment was made in this chunk.
  The existing untracked `.agents/` and `.codex/` were left alone. Production
  still needs the approved migration rollout before this code is deployed,
  and the intended reviewer account needs confirmation.

**4. What I changed or rejected**

*Pending — the student's own review of the implementation and test results.
Commit approval has not been given.*

**Commit approval — 8 November 2026**

The student subsequently approved committing this chunk with this prompt:

```text
Looks good. Let's commit the reviewer queue as one separate AI-assisted commit.
Before committing, check the final diff for unrelated changes, secrets, and anything that might break the existing reviewer permissions.
Stage only the reviewer queue implementation, navigation changes, related tests, and the new Prompt Journal entry. Preserve all earlier journal content.
Use a clear commit message that marks it as AI-assisted.
After committing, show me the commit hash, files changed, and git status.
Don't push, merge, deploy, or apply any Supabase migrations yet.
```

The final review found no unrelated changes or credential patterns in the
seven intended files. The page and actions still require reviewer access,
and decisions still use the existing database function. Database policies,
migrations, dependencies and project instructions are unchanged. The 11
reviewer tests passed again before committing. Earlier committed journal
content and this session's previous journal entries were preserved exactly.
Only the seven reviewer-workflow and journal files are selected for the
AI-assisted commit; the machine-specific `.agents/` and `.codex/` directories
remain untracked. This approval covers the local commit only.
