# Sprint 2 rollout checklist

Moves the live site from the build it runs now (`345dad2`, migration 0001) to
Sprint 2 (migration 0002). Every step that writes to production is done by
hand, in this order. Tick each box; stop at the first one that does not come
out as described.

| | |
| --- | --- |
| Supabase | project `welzetyikwoggygaushf` |
| Vercel | team `lll-skylar` (renamed from `khmer-living-archive`), project `khmer-archive`, production `https://khmer-archive-zeta.vercel.app` |
| GitHub | `Skylarrrolala/khmer-archive`, **private** |
| Shipping branch | `sprint2-integration`, at the commit that contains this file |

**Last read-only check, 19 October 2026.** Supabase was active and healthy.
The live schema (policies, constraints, the `status` default, grants, the
bucket and the four Storage policies) matched 0001 exactly, and the migration
history was empty. All eight rows already pass every rule 0002 adds. Vercel
production was a manual redeploy of `smoother-motion` at `345dad2`, and the
two Supabase environment variables target Production, Preview and
Development. Previews sit behind a Vercel login; production is public.
Re-check all of this on the day.

**Confirmed by the user on 19 October, in the dashboards, not independently
verified:** `jesseorndorff` is a collaborator on the repository; the Supabase
Site URL and the exact `/auth/confirm` redirect are configured; "Confirm
email" is on; and Vercel's production branch is `main`. None of these is
visible to the read-only checks above: the GitHub collaborator list needs the
owner's login, no read-only tool reaches the Auth settings, and the Vercel
connector does not show the production branch.

## 0. What ships, and what does not

- [ ] Ship `sprint2-integration` as it stands. It already contains `345dad2`,
      so nothing that is live today is lost, and `main` (`07d7c51`) can
      fast-forward to it.
- [ ] Do **not** merge `smoother-motion`. Its last two commits are left out
      on purpose: `b012764` hides the "Source pending verification" badge
      (against the sourcing rule in CLAUDE.md), and `0aab375` adds a comment
      about a problem Sprint 2 already fixes, plus a stray
      `supabase/.temp/cli-latest`. Do not promote a `smoother-motion`
      deployment to production either.

## 1. Before anything changes (read-only)

- [ ] **Supabase is active.** The dashboard shows the project running, not
      paused. A free project pauses after about a week without traffic;
      restore it and wait until it is healthy. Check again shortly before
      grading.
- [x] **The professor can see the repository.** The repository is private,
      so `jesseorndorff` must be an accepted collaborator, not a pending
      invitation. *User-confirmed, 19 October: already a collaborator. Not
      independently verified.*
- [ ] **Local checks pass** on the commit being shipped:
      `npm test`, `npm run test:db`, `npx tsc --noEmit`, `npm run lint`,
      `npm run build`.
- [ ] **A backup exists.** `supabase db dump --linked -f backup-schema.sql` and
      `supabase db dump --linked --data-only -f backup-data.sql`. Keep both
      files out of the repository: the data dump contains contributors' rows.
- [x] **Auth settings** (Authentication → URL Configuration, and → Sign In /
      Providers → Email). *All three user-confirmed, 19 October. Not
      independently verified.*
  - [x] Site URL: `https://khmer-archive-zeta.vercel.app` (it was
    `http://localhost:3000` on 22 September, which sent confirmation links to
    localhost).
  - [x] Redirect URLs include exactly `https://khmer-archive-zeta.vercel.app/auth/confirm`.
    No wildcard for previews: previews are login-protected and are not used
    for submitting.
  - [x] "Confirm email" is **on**.
- [x] **Vercel production branch is `main`** (Project → Settings → Git).
      *User-confirmed, 19 October. Not independently verified.* The current
      production deployment was promoted by hand, so a push to `main` is what
      replaces it.

## 2. Reconcile the migration history

0001 was run in the SQL Editor, so the project's migration history is empty,
and `supabase db push` would try to run 0001 again. The live schema matches
0001 exactly (checked 19 October), so recording 0001 as applied is accurate.
These commands were tested against a throwaway local Postgres with Supabase
CLI 2.117.

- [ ] `supabase link --project-ref welzetyikwoggygaushf` (asks for the database password)
- [ ] `supabase migration list` shows `0001` and `0002` locally and nothing remotely
- [ ] `supabase migration repair --status applied 0001`
- [ ] `supabase db push --dry-run` proposes **only** `0002_sprint2_publish_on_submit.sql`.
      Do not run it without `--dry-run`; 0002 is applied in step 3.

## 3. Apply 0002, then deploy the app

The database goes first. Between the two steps, the **old** app's submissions
and edits fail with an error, because it sends `status: 'pending'`, which 0002
refuses. Nothing is wrongly published. The other order would let the new app
tell contributors an entry "is now public" while 0001 kept it hidden. Keep
the gap short: have the push ready before starting.

- [ ] SQL Editor: paste `begin;`, then the whole of
      `supabase/migrations/0002_sprint2_publish_on_submit.sql`, then `commit;`,
      and run. One transaction: if any existing row breaks a new rule, the
      whole migration fails and nothing changes. Read the error, fix the
      row, run again.
- [ ] `supabase migration repair --status applied 0002`, then
      `supabase migration list` shows both versions on both sides.
- [ ] Read-only check, in the SQL Editor:
      ```sql
      select policyname, cmd, with_check from pg_policies where tablename = 'entries';
      select conname from pg_constraint where conrelid = 'public.entries'::regclass order by 1;
      select file_size_limit, allowed_mime_types from storage.buckets where id = 'entry-photos';
      ```
      Expect the insert policy named "…published entries" with
      `status = 'published'`, the `_visible`, `_length`, `published_has_photo`
      and `photo_url_location` constraints, and `4194304` with three image types.
- [ ] Push `sprint2-integration`, then fast-forward `main` to it
      (`git merge --ff-only sprint2-integration` on `main`, then push `main`).
      A fast-forward needs no merge commit; if git refuses, stop and find out why.
- [ ] Vercel shows a **Ready** production deployment of that commit, from
      `main`, serving `https://khmer-archive-zeta.vercel.app`. If it does not
      appear, check the production branch again before promoting anything by hand.

## 4. Live two-account test

`scripts/verify-rls.sh` is historical. It tested 0001, now stops before doing
anything, and its 15 September pass is not evidence for 0002. This test
replaces it. It needs two addresses Supabase accepts (`mailinator.com` works;
`example.com` is refused). Run everything on production, not on a preview:
previews share this live database.

In the app:

- [ ] Signed out: the home page lists published entries only. The older
      pending entry is absent, and `/entries/<its id>` is a 404.
- [ ] A signs up. The email arrives, and its link lands on
      `https://khmer-archive-zeta.vercel.app/auth/confirm`, signed in. If the
      free email limit trips (`Too many attempts…`), wait an hour.
- [ ] A publishes an entry with an ordinary 2–4 MB phone photo. It appears
      on the home page and its detail page straight away.
- [ ] A picks a photo over 4 MB: the message appears at the field and nothing
      is sent. A text file renamed `.jpg`: "Photos must be a JPEG, PNG or WebP image."
- [ ] A edits the entry and replaces the photo. The change is public, and A's
      Storage folder (`entry-photos/<A's id>/`) holds one file, not two.
- [ ] On `/login`, a wrong password and an unknown address give the same message.
- [ ] B signs up and signs in. B's "my entries" does not list A's entry, and
      `/my-entries/<A's id>/edit` and `/delete` are 404s.

Straight at the API, as B (the publishable key is the public one; get B's
token with
`curl -s "$URL/auth/v1/token?grant_type=password" -H "apikey: $KEY" -H "content-type: application/json" -d '{"email":"…","password":"…"}'`,
then send `-H "apikey: $KEY" -H "Authorization: Bearer $TOKEN"` on each request):

- [ ] `PATCH /rest/v1/entries?id=eq.<A's id>` changing `context` → `[]`, nothing changed
- [ ] `DELETE /rest/v1/entries?id=eq.<A's id>` → `[]`, and A's entry is still on the home page
- [ ] `POST /rest/v1/entries` with `contributor_id` = A's id → refused (row-level security)
- [ ] `POST /rest/v1/entries` that includes `"status"` → refused (42501, status cannot be written on insert)
- [ ] `PATCH` B's own entry setting `created_at` or `contributor_id` → refused (42501)
- [ ] Upload to `storage/v1/object/entry-photos/<A's id>/x.jpg` → refused

Then:

- [ ] A deletes the entry: it leaves the home page, and A's Storage folder is empty.
- [ ] Sign out: the header shows signed out, and `/my-entries` asks for a login.
- [ ] Vercel logs show no `[photo-cleanup]`, `[entries]` or `[auth]` lines
      except ones caused on purpose.
- [ ] Clean up: delete both test users in Authentication → Users, and any
      test entries left over.

## 5. Rollback — an emergency option, not a safe reset

Rolling back does not return to a known-good state. It returns to a state
with **known security weaknesses**, all of which are live today and which
Sprint 2 removes. Use it only if Sprint 2 itself is causing harm (data
exposed or lost, or the site unusable) and a forward fix cannot ship in
time. Then roll forward again as soon as possible.

Rolling back the **app** (Vercel → Deployments → the previous production
deployment, `345dad2` → Instant Rollback) brings back:

- the redirect-guard gaps fixed in `3c3c282` (tab, newline and dot-segment forms of `?next=`);
- Supabase's raw error text on the sign-in and sign-up forms, and any text
  put into a crafted `?error=` link shown on the page;
- raw database errors on the delete page, and "deleted" when nothing was;
- confirmation links that do not finish signing in (`ca86047` is not in that build);
- photos typed by what the browser claims, and uploads over 1 MB failing.

Vercel then stops promoting new production builds automatically until one is
promoted by hand. The old app on 0002 fails closed: submissions and edits are
refused, and nothing is wrongly published.

Rolling back the **database** as well (`docs/rollback-0002.sql` in the SQL
Editor, which has its own `begin`/`commit`, then
`supabase migration repair --status reverted 0002`) brings back:

- **a public photo bucket with no size or type limit.** Any signed-in user can
  host any file at the project's public Storage address;
- every table privilege for `anon` and `authenticated`: owners can write `id`
  and `created_at`, and TRUNCATE is granted again (no API route reaches it
  today, but nothing stops one being added);
- no length or visible-text limits, and no rule on where `photo_url` points.
  Under 0001's policies this reaches only an owner's hidden rows.

It was tested locally: afterwards the policies, constraints, default,
privileges and bucket settings are identical to 0001's. It changes no rows.
Entries published under 0002 stay published, uploaded photos stay where they
are, and any edit to such an entry unpublishes it again.

Roll back the app first. The new app on 0001 would tell contributors an entry
is public while it is hidden.

## 6. Afterwards

- [ ] README and CLAUDE.md ("Current sprint focus"): Sprint 2 is live, with
      the date of the two-account test.
- [ ] Supabase → Advisors: review the security warnings. Leaked-password
      protection was still off on 19 October.
- [ ] Before the archive is treated as final: the seven researched entries
      still need a real `told_by`, and every photo in `public/entries/` needs
      its provenance confirmed (see CLAUDE.md).
