# Sprint 2 rollout checklist

Moves the live site from Sprint 1 + migration 0001 to Sprint 2 + migration
0002. Every step that writes to production is done by hand, in this order.
Tick each box; stop at the first one that does not come out as described.

Live project: Supabase `welzetyikwoggygaushf`, Vercel project `khmer-archive`
(production `https://khmer-archive-zeta.vercel.app`), repository
`Skylarrrolala/khmer-archive`.

## 1. Before anything changes (read-only)

- [ ] **Supabase is active.** Dashboard → project home shows it running, not
      paused. A free project pauses after about a week without traffic;
      restore it from the dashboard and wait until it is healthy. Check again
      shortly before grading.
- [ ] **The professor can see the repository.** GitHub → Settings →
      Collaborators lists `jesseorndorff` as a collaborator, not only as a
      pending invitation. (`gh api repos/Skylarrrolala/khmer-archive/collaborators/jesseorndorff`
      answers 204 when access is in place.)
- [ ] **Local checks pass** on the commit being shipped:
      `npm test`, `npm run test:db`, `npx tsc --noEmit`, `npm run lint`,
      `npm run build`.
- [ ] **A backup exists.** `supabase db dump --linked -f backup-schema.sql` and
      `supabase db dump --linked --data-only -f backup-data.sql`. Keep both
      files out of the repository: the data dump contains contributors' rows.
- [ ] **Auth settings** (Authentication → URL Configuration and → Sign In /
      Providers → Email), changed only if they differ:
  - Site URL: `https://khmer-archive-zeta.vercel.app`
  - Redirect URLs: `https://khmer-archive-zeta.vercel.app/auth/confirm`,
    `http://localhost:3000/auth/confirm`, and for previews
    `https://khmer-archive-*-khmer-living-archive.vercel.app/**` (check the
    preview domain in Vercel; Supabase silently falls back to the Site URL
    for any address not listed).
  - "Confirm email" is **on**.

## 2. Reconcile the migration history

0001 was run in the SQL Editor, so the project's migration history is empty
(last checked 25 September). `supabase db push` would try to run 0001 again.
Record it as already applied first. Commands tested against a throwaway local
Postgres with Supabase CLI 2.117.

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
the gap short: have the merge ready before starting.

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
- [ ] Merge the Sprint 2 branch into `main`. Vercel builds production from
      `main`; wait for the deployment to be **Ready** and serve the
      production domain.

## 4. Live two-account test

`scripts/verify-rls.sh` was written for 0001. It expects a new entry to "land
pending" and inserts without a photo, so after 0002 it reports failures by
design. Its last pass (15 September) proves 0001, not 0002. Use this test
instead. It needs two addresses Supabase accepts (`mailinator.com` works;
`example.com` is refused). Note that previews use this same live database.

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

## 5. Rollback

Roll back the **app first**. The old app on 0002 fails closed; the new app on
0001 would claim entries are public when they are not.

- [ ] Vercel → Deployments → the previous production deployment → Instant
      Rollback. Vercel then stops promoting new `main` builds automatically
      until one is promoted by hand.
- [ ] Only if the database must go back too: run `docs/rollback-0002.sql` in
      the SQL Editor (it has its own `begin`/`commit`), then
      `supabase migration repair --status reverted 0002`. Tested locally:
      afterwards the policies, constraints, default, privileges and bucket
      settings are identical to 0001's. It changes no rows. Entries published
      under 0002 stay published, and it reopens the column and text limits
      0002 added. A forward fix is usually better.

## 6. Afterwards

- [ ] README: mark Sprint 2 done, with the date of the live test.
- [ ] Supabase → Advisors: review the security warnings. Leaked-password
      protection was off on 25 September.
- [ ] Before the archive is treated as final: the seven researched entries
      still need a real `told_by`, and every photo in `public/entries/` needs
      its provenance confirmed (see CLAUDE.md).
