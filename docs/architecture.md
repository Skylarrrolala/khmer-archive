# What every file does

Written so I can explain any line of this project without guessing.

## The shape of a request

A visitor loads `/`. Next.js runs `app/(browse)/page.tsx` **on the server** —
`(browse)` is a route group, so the parentheses never appear in the URL. That
page calls `getPublishedEntries()`, which builds a Supabase client carrying the
request's cookies and asks Postgres for published entries. Postgres applies the
Row Level Security policies, returns the rows it is willing to release, and
Next.js renders them to HTML. The browser receives finished HTML — it never
receives an entry it is not allowed to see, because the filtering happened two
layers earlier, in the database.

```
browser  ->  app/(browse)/page.tsx  ->  lib/entries.ts  ->  lib/supabase/server.ts  ->  Postgres + RLS
```

## File map

### Database

| File | What it does |
| --- | --- |
| `supabase/migrations/0001_init.sql` | The base schema: the `entry_status` enum, the `entries` table, its indexes, every RLS policy, and the `entry-photos` storage bucket with its policies. Applied to the live project through the SQL Editor. |
| `supabase/migrations/0002_sprint2_publish_on_submit.sql` | Sprint 2. Entries are published on save; the owner check in every policy is unchanged; column privileges protect `id`, `created_at` and `contributor_id`; text, photo and bucket limits. Changes no existing row, and fails as a whole if any row breaks a new rule. Not yet applied live — see `docs/rollout-sprint2.md`. |
| `docs/rollback-0002.sql` | Undoes 0002, back to exactly 0001's rules. Emergency use only: it restores weaknesses 0002 closed (see the rollout checklist, "Rollback"). Kept out of `migrations/` so `supabase db push` never runs it. |
| `supabase/seed.sql` | The seven desserts, with ingredients, method, region and notes folded into `description`. The content is researched, not family testimony: every `told_by` holds `[SOURCE PENDING …]`, which the UI renders as a "Source pending verification" badge, so nothing on the page claims a source it does not have. Re-running the file clears the rows it owns (`contributor_id is null`) first, so it cannot double up. |

### App plumbing

| File | What it does |
| --- | --- |
| `lib/env.ts` | Reads `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Reads them inside a function, not at import time, so `next build` still succeeds on a machine with no `.env.local`. |
| `proxy.ts` | Refreshes the Supabase session on each request. Named `proxy.ts`, not `middleware.ts` — that convention is deprecated in Next.js 16 and renamed. It is **not** an auth gate: Next's own guidance is that a proxy is an optimistic check only, so there is no redirect logic in it. Deleting it would log people out early; it would not expose a row. |
| `lib/auth.ts` | The auth half of the data access layer. `getCurrentUser()` uses `getUser()` (which revalidates the token with Supabase) rather than `getSession()` (which just trusts the cookie), memoised with React `cache`. `requireUser()` redirects to `/login` for pages that make no sense signed out. |
| `app/(auth)/actions.ts` | Sign-up, sign-in and sign-out as Server Actions. Only actions and route handlers may write cookies, which is why session creation lives here. `next` goes through `safeInternalPath()`, so the forms cannot be used as an open redirect. A failure redirects with a message key, never Supabase's wording: a wrong password and an unknown address get the same message, and a sign-up for an address that already has an account ends on the same "check your email" notice as a new one. Unexpected errors, and a sign-out whose server-side revocation failed, are logged as `[auth]`. |
| `app/(auth)/auth/confirm/route.ts` | Where the confirmation email's link lands. Trades the one-time code for a session (PKCE), so a new contributor arrives signed in. A link opened in another browser cannot finish the trade, but the email is confirmed by then, so it says "sign in" rather than showing an error. Never shows Supabase's text from the URL, and re-checks `next`. |
| `app/(auth)/login/page.tsx`, `app/(auth)/signup/page.tsx` | The two auth pages. They read `?error=` (a message key), `?pending=` (where a confirmation stands) and `?next=` from the URL, and show only known keys, so a crafted link cannot put its own words on the page. |
| `lib/safe-path.ts` | `safeInternalPath()`, the redirect guard: only a same-site path, rebuilt from the parsed URL, so protocol-relative, backslash, control-character and dot-segment tricks all end at `/`. |
| `lib/auth-messages.ts` | The fixed messages for the auth forms, and the map from Supabase Auth's error codes to them. None says whether an account exists. |
| `components/AuthForm.tsx` | One form for both sign-up and sign-in. A plain `<form action>` with no client state, so it submits with JavaScript disabled; errors come back as `?error=<key>` on a redirect. |
| `app/submit/page.tsx`, `app/submit/actions.ts` | The submission form and its Server Action. The entry is public as soon as it is saved, so it needs a photo — checked here before anything is uploaded, and again by 0002. `contributor_id` is set server-side and `status` is never sent: under 0002 the database chooses it. A failure returns to the form with the text as typed; the photo has to be chosen again, because no site can refill a file input. |
| `app/my-entries/page.tsx` | The contributor's own entries, public or not. The only page that can show an unpublished row (one sent before Sprint 2), and it is the RLS policy "contributors can read their own entries" that makes that possible — not the `requireUser` call, which only decides whether to render. Shows the notices for saved, deleted, "nothing was changed" and "a photo is still in storage". Does not reuse `EntryCard`, and links "View" only for published rows: an unpublished one has no public page. |
| `app/my-entries/[id]/actions.ts` | Editing and deleting your own entry. Neither checks ownership itself: the update and delete policies do, and a row that is not yours simply does not come back, which ends on "Nothing was changed". Saving publishes. A replaced photo is removed only once the row points at the new one, and a deleted entry's photo only once the row is gone. A database error reaches the delete page as a flag (`?failed=1`) and a fixed sentence. |
| `app/my-entries/[id]/edit/page.tsx`, `.../delete/page.tsx` | Load the entry through `getMyEntry`, so another contributor's id, a nonexistent one and a malformed one are the same 404. Delete is a POST from a page that shows the entry, never a link. |
| `lib/entry-form.ts` | The five text fields' labels, limits and blank-field messages, and `readEntryFields()`: 0002's rules, counted the way Postgres counts. Also the form state that hands the text back after a failure. |
| `lib/photo-check.ts` | The 4 MiB limit and `photoFormat()`, which reads a file's first bytes. No imports, so the server, the browser form and the tests share it. |
| `lib/photo-clean.ts` | `cleanPhoto()`: decodes a photo with `sharp` and encodes it again, upright and with no EXIF, GPS or XMP. Refuses a file that does not decode, or one over 50 megapixels. Imports nothing of the app's own, so the tests load it. |
| `lib/photos.ts` | Uploads to `entry-photos/<user id>/<uuid>.<ext>` — the folder must be the uploader's id because the Storage policy checks it, and the name is a fresh uuid because an uploaded name is untrusted input. Type and extension come from the bytes; the upload is claimed against the contributor's limits before the photo is decoded; what is stored is the re-encoded image, not the file as sent. `deletePhoto()` never throws, reports whether the file is gone, and logs `[photo-cleanup]` with the path when it is not. |
| `lib/limits.ts` | The sentence for each limit's error code (`KA001`–`KA003`, migration 0006). No imports, so it is unit-tested. |
| `lib/save-with-photo.ts` | Upload, then write the row; if the write fails or matches nothing, take the new photo back out, and say if even that failed. Turns a database refusal into a sentence without repeating it. No imports, so its decisions are unit-tested. |
| `components/AccountNav.tsx` | The signed-in state in the masthead. Sign-out is a POST form, not a link, so a prefetch or a third-party `<img>` cannot log someone out. |
| `lib/supabase/server.ts` | Builds a per-request Supabase client wired to Next's cookie store, so the logged-in user's session travels with server-side queries. A new client per request — sharing one would leak sessions between users. |
| `lib/types.ts` | The TypeScript shape of an entry, mirroring the SQL table by hand. |
| `lib/entries.ts` | Every query on `entries` lives here, so there is one place to audit. Sanitises the search term before it goes into a PostgREST filter. The writes carry no ownership check of their own — the policies decide — and log what Postgres said, passing only its code on to the page. |
| `lib/placeholders.ts` | Recognises the bracketed markers (`[SOURCE PENDING …]` and the like) that stand in for values the archive does not have yet, so the UI shows a badge instead of an editing note. |

### Pages and components

| File | What it does |
| --- | --- |
| `app/layout.tsx` | The HTML shell: header (cream, so it reads as the top of the same sheet the hero is printed on), footer, and the three `next/font` families — Kantumruy Pro for body copy (it covers Latin *and* Khmer, so a mixed sentence stays in one typeface), Fraunces and Noto Serif Khmer for the display headings. A font that covers Khmer is required, not cosmetic: without one the names render as empty boxes. `<main>` is wrapped in React's `<ViewTransition>`, so a navigation animates instead of cutting: the layout persists, its contents update, and the `page-fade` rules in `globals.css` raise the new page into place while the header and footer hold still. The gold hairline carries `land-line`, and `<LandingMarker />` ends the landing sequence once it has played. |
| `app/globals.css` | Tailwind v4 is configured in CSS, not a JS config file. `@theme inline` declares the palette; naming a token `--color-card` is what makes `bg-card` exist as a utility. The palette is surface-aware: plain custom properties hold the current surface's colours, `@theme inline` points the tokens at them, and the cream backgrounds re-declare them, so `text-muted` is sand on the maroon ground and brown on a cream card. Motion is set here too. The motion block (`--ease-settle`, `--motion-*`) holds every duration on the site, so the pace is tuned in one place; `--default-transition-duration` and `--default-transition-timing-function` point every `transition-*` utility at it. The page-transition rules and the landing rules (`land`, `land-photo`, `land-line`, ordered by `--i`, scoped to `html:not([data-landed])` so they play on a first load only) sit at the end of the file, and `prefers-reduced-motion` switches all of it off. The old page is hidden rather than faded during a navigation because its snapshot keeps the old scroll position — fading it would sweep the archive up the screen. |
| `app/(browse)/page.tsx` | The public browse + search page, served at `/`. It sits in the `(browse)` route group only so that the `loading.tsx` beside it applies to this page and no other. Reads `?q=` from the URL and passes it to `getPublishedEntries`. Drawn as two full-bleed bands — a cream sheet holding the archive's name, the search and a pair of photographs, the maroon ground below holding the entries — which is why `<main>` in the layout has no container of its own. The hero's two photographs come from the *unfiltered* archive, so they stay put while someone searches; that costs a second query only when a `?q=` is actually in play. They are the two earliest photographed entries rather than the latest, because the grid is newest-first and the latest two would be the same cards sitting directly beneath them. On a first load the page unfolds in order — each piece carries `land` or `land-photo` and its turn as `[--i:N]`. |
| `app/(browse)/loading.tsx` | The home page's loading state: one static line on the hero's cream band, shown while the entries come back from Supabase. It is scoped to the route group rather than placed at the root of `app/` because a root loading file wraps every page. Once a fallback has streamed the status code is fixed at 200, so the detail page's `notFound()` would stop returning a real 404 and `requireUser()`'s redirects would arrive inside the stream. It would also put a fallback between a card and its detail page, where the photo transition needs the two pages to swap in one step. No pulse or spinner: that would be new motion, which CLAUDE.md asks to be approved first. |
| `app/error.tsx` | The error page for every route — most often shown when Supabase cannot be reached, since every query in `lib/entries.ts` throws on a database error. Next.js renders it inside a React error boundary around each page, but not around the root layout, so the header and footer stay in place. The message is generic because one boundary serves every page and form action, so it cannot say what failed. It never prints `error.message`: in production Next replaces a Server Component's message with a generic one anyway, and the real message — which can carry Postgres details — stays in the server log, where the error's `digest` points to it. "Try again" calls `retry()`, which re-fetches the page from the server and renders it again; `reset()` would only re-render what the browser already has, which cannot help when the failure was on the server. `notFound()` and `redirect()` pass straight through, so a missing entry still gets the 404 and a signed-out visitor is still sent to log in. A Client Component, as error boundaries must be. |
| `app/entries/[id]/page.tsx` | The detail page for one dessert. Calls `notFound()` when there is no published entry with that id. Bands run the other way round from the browse page: the name is announced on maroon, the record — photograph, then the numbered fields — sits on cream, where a long description is an easier read. |
| `components/SearchBar.tsx` | A plain `<form method="get">` — no client-side JavaScript, no React state. Submitting navigates to `/?q=…`, which re-runs the server page and re-queries Postgres. The result is a shareable URL, and search works with JS disabled. |
| `components/EntryCard.tsx` | One dessert in the list. Handles a missing photo with `NoPhotoPanel`; since 0002 every published entry has one, so that matters only for rows loaded before it. The photo fills a square tile: the archive's photos range from 0.67 to 1.50 in aspect, so no frame holds all of them uncropped, and a square crops least across that spread. Takes an `index` purely for the printed 01 / 02 / 03, which is `aria-hidden` because it renumbers with every search. |
| `components/FadeInImage.tsx` | `next/image` with a fade-in once the photo has loaded. The only client component among the photos, because `onLoad` is a function. It never hides a photo in the server HTML — only once JavaScript has seen the photo is still loading — so with JavaScript off, or for a photo that arrived before hydration, nothing is ever invisible. A photo that fails is revealed too, so its alt text shows. |
| `components/EntryPhotoTransition.tsx` | Gives a dessert's photo frame the same view-transition name on the card and on the detail page, so the browser carries the photo from one to the other. Both ends render this component, so the name and the `share="morph"` / `default="none"` props cannot drift apart — the pair silently stops animating if one side loses `share`. The photo only travels when both ends are on screen; otherwise it moves with its page. |
| `components/EntryForm.tsx` | The fields of an entry, shared by submit and edit. A Client Component for `useActionState`, so a failure comes back with the text as typed. Checks each field, and the photo's size, as they change — with the words the server would use, through the browser's own validation — and the server checks everything again. |
| `components/SubmitButton.tsx` | A submit button that disables itself while its form's action runs, so a second click does not send a second sign-up or submission. |
| `components/NoPhotoPanel.tsx`, `components/PendingBadge.tsx` | The no-photo panel, and the badge for a field the archive does not have yet. Each is shared by the card and the detail page so it looks the same in both. |
| `components/DriftWall.tsx`, `DriftWall.css` | Unused: a drifting image wall from an earlier design, which CLAUDE.md lists as not approved. |
| `components/LandingMarker.tsx` | Stamps `data-landed` on `<html>` once the landing sequence has had time to finish, which switches the `land*` rules off. CSS cannot tell a first load from a client-side navigation — both insert fresh elements — so without this every return to the home page would replay the whole sequence. Mounted in the root layout, which survives navigations, so it runs once per document load. |

### Config

| File | What it does |
| --- | --- |
| `next.config.ts` | Allowlists the Supabase Storage hostname for `next/image`. Without an allowlist, the image optimiser would happily fetch any URL on the internet, which turns the deployment into an open image proxy. The host is derived from the env var, so the same file works locally and on Vercel. It also raises the Server Action body limit from Next's default of 1 MB to 4.25 MB: a 4 MiB photo plus the text fields. Vercel's own request limit still applies first. |
| `.env.example` | The two variables to copy into `.env.local`. `.gitignore` ignores `.env*` but re-includes this one file. |
| `eslint.config.mjs`, `tsconfig.json`, `postcss.config.mjs` | Stock `create-next-app` output — linting, TypeScript with the `@/*` path alias, and the Tailwind PostCSS plugin. |

### Tests

| File | What it does |
| --- | --- |
| `tests/*.test.ts` | Unit tests, run by `npm test` with Node's built-in runner: the field rules (including a check that the limits still match 0002), photo signatures, photo re-encoding (metadata, orientation, broken and oversized images), the limit messages, auth messages, the photo-cleanup decisions, the redirect guard, the form state. |
| `scripts/test-db.sh`, `tests/db/*.sql` | `npm run test:db`. Loads a Supabase stand-in (roles, `auth.uid()`, Storage, default grants), 0001, the seed, two contributors A and B, and 0002 into a throwaway Postgres container, then runs 133 checks through RLS as each role. Never connects to Supabase. |
| `scripts/verify-rls.sh` | Historical: the 15 September check of the 0001 rules against the live project. It now stops before doing anything — see "Evidence" below. |

## How ownership enforcement actually works

This is the part that is graded, so here it is in full.

### The problem

A Supabase app talks to Postgres from the browser using the **anon key**. That
key is public — it is compiled into the JavaScript bundle, and anyone can read
it out of dev tools and then call the Supabase REST API by hand with `curl`.
So "the button is hidden" and "the app only sends the right query" protect
nothing. Anything the anon key is allowed to do, a determined visitor can do.

### The fix

The anon key is deliberately powerless on its own. All authority comes from
policies attached to the table:

```sql
alter table public.entries enable row level security;
```

That one line flips the table to **deny by default**. From that moment, a
client using the anon key can read and write nothing at all until a policy
explicitly permits it.

Each policy is a SQL condition Postgres bolts onto every query touching the
table. The key helper is `auth.uid()`, which reads the user id out of the JWT
attached to the request. A logged-out request has `auth.uid() = null`, so any
comparison against it fails and the row stays invisible.

### The rules, as of migration 0002

0001 wrote five policies on `entries`. 0002 changes only their status half;
`auth.uid() = contributor_id` stays everywhere 0001 put it.

**1. The public sees only published entries.**

```sql
create policy "published entries are readable by everyone"
  on public.entries for select to anon, authenticated
  using (status = 'published');
```

`lib/entries.ts` *also* writes `.eq("status", "published")`, but that is a
convenience for the query planner, not the guarantee. If someone deleted that
line tomorrow, unpublished entries would still not leak, because Postgres would
refuse to hand them over.

**2. A contributor sees their own entries whatever the status.**

```sql
create policy "contributors can read their own entries"
  on public.entries for select to authenticated
  using (auth.uid() = contributor_id);
```

Postgres ORs the `select` policies together, so a logged-in contributor sees
every published entry *plus* any unpublished one of their own — in practice,
the one entry sent before Sprint 2.

**3. A contributor can only create entries in their own name, and they are published.**

```sql
alter policy "contributors can create their own published entries"
  on public.entries
  with check (auth.uid() = contributor_id and status = 'published');
```

`auth.uid() = contributor_id` stops user A posting an entry credited to user
B. The status half is 0002's change: Sprint 2's brief has a contribution
appear publicly the moment it is saved. Contributors cannot write `status` on
insert at all (see "Protected columns"), so the column's default, now
`'published'`, always applies.

**4. A contributor can only edit or delete their own entries.**

```sql
alter policy "contributors can update their own entries"
  on public.entries
  using (auth.uid() = contributor_id)
  with check (auth.uid() = contributor_id and status = 'published');
```

The two clauses do different jobs, and both are needed:

- `using` decides **which existing rows** the user may touch.
- `with check` decides **what the row is allowed to look like afterwards**.

With only `using`, a contributor could edit their own row and, in the same
statement, hand it to someone else. Saving an edit publishes: for a published
entry that changes nothing, and for the older unpublished one it is what makes
it public — which 0002 allows only once it has a photo. Delete needs only
`using`, since there is no "after" state to constrain.

### Protected columns

RLS decides which **rows** a statement may touch; it cannot see which
**columns** it changes. Supabase grants the API roles every privilege on a new
table, so under 0001 an owner could rewrite their own entry's `created_at` to
sit at the top of the archive, or change its `id` and break every link to it.
0002 revokes everything and grants back only:

| Role | May |
| --- | --- |
| `anon` | read |
| `authenticated` | read and delete; insert `contributor_id`, the five text fields and `photo_url`; update the five text fields, `photo_url` and `status` |

So `id`, `created_at` and `contributor_id` can never be changed, and `status`
cannot be chosen on insert. Postgres refuses such a statement (42501) before
RLS is consulted. TRUNCATE, which RLS does not cover at all, is no longer
granted either.

### Validation

The same rules at three layers:

- **Postgres (0002)** — the one that holds. Each of the five text fields needs
  at least one visible character (not only spaces or invisible marks such as a
  zero-width space), and has a maximum length: `name_khmer` 120,
  `name_english` 150, `told_by` 120, `context` 300, `description` 8,000.
  Lengths are counted by `char_length`, in characters, so a Khmer vowel sign
  counts as one, the same as a Latin letter.
- **Server (`lib/entry-form.ts`)** — checks the same rules before anything is
  uploaded, so a contributor is told which field to fix rather than shown a
  constraint error. It trims, and turns a browser's CRLF line breaks into
  `\n`, which would otherwise count twice against the limit.
- **Browser (`components/EntryForm.tsx`)** — runs the same function as each
  field changes and marks the field invalid, so the form is not sent. It does
  not use `maxLength`, which would silently cut off the end of a pasted story.

`tests/entry-fields.test.ts` reads the limits out of 0002 and fails if the app
and the migration ever disagree.

### Photos

- **Size.** 4 MiB, in the app (`lib/photo-check.ts`) and on the bucket
  (0002's `file_size_limit`). Next's Server Action body limit is raised to
  4.25 MB to carry that photo plus the text (`next.config.ts`). The browser
  refuses an oversized photo before sending anything.
- **Content.** The server reads the first 12 bytes, and they must be a JPEG,
  PNG or WebP signature: a text file renamed `.jpg` is refused. The stored type
  and extension come from those bytes, not from what the browser declared. The
  bucket's `allowed_mime_types` checks only the declared type.
- **Re-encoding (`lib/photo-clean.ts`).** The file as sent is never stored.
  The server decodes it with `sharp` and stores the image encoded again, in
  the same format and at the same resolution (JPEG at quality 80). A phone
  photo's EXIF, GPS and XMP are not copied, so a photo of a grandparent's home
  does not publish where that home is. The EXIF orientation is applied first,
  so a photo taken sideways is stored upright. A file that does not decode is
  refused, and anything appended after a valid image is not part of the
  output. An image over 50 megapixels is refused before it is decoded, and the
  4 MiB limit is checked again on the re-encoded result.
- **Location.** Supabase Storage is itself a Postgres table (`storage.objects`)
  with RLS, so photo permissions are written the same way. Uploads must land in
  a folder named after the uploader's user id:

  ```sql
  with check (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  ```

  `storage.foldername()` splits the object path on `/`, so `[1]` is the first
  folder. 0002 adds the other half: a row's `photo_url` must point into its
  owner's own folder, at a uuid-named file. The ownerless seed rows point at
  the photographs shipped in `public/entries/` instead. A published row must
  have a photo.
- **A photo in use is frozen (0004).** An entry stores its photo as a URL, so
  changing the file behind that URL would change an approved entry without
  sending it back for review. There is no UPDATE policy on photos, so a stored
  file can never be overwritten, upserted over or moved. A file cannot be
  deleted, and its name cannot be uploaded to, while any entry of any status
  points at it (`public.photo_in_use()`). To show a different photo, the
  contributor uploads a new file and edits the entry, which sends it back for
  review. The old file is unused after that edit and can be cleaned up.

### Cleanup, and what reaches the page

- The photo is uploaded first, because the row stores its URL. If the row
  then fails to save, or matches nothing, the photo is removed again
  (`lib/save-with-photo.ts`).
- On an edit, the old photo is removed only once the row points at the new
  one. On a delete, only once the row is gone.
- A removal that fails is logged as `[photo-cleanup]` with its path, and the
  contributor is told that a photo is still in storage. Nothing is claimed to
  be gone that is not.
- No text from Postgres, Storage or Supabase Auth reaches a page. Database
  errors become fixed sentences. Auth errors become message keys looked up in
  `lib/auth-messages.ts`. An edit or delete that matched no row says
  "Nothing was changed" instead of reporting success. What the services said
  goes to the server log.

### Limits (0006)

Every signed-in account, reviewers included, has three limits:

| Limit | Applies to | Refused with |
| --- | --- | --- |
| 5 pending entries | new entries only; an edit that sends an entry back to pending is never refused | `KA001` |
| 20 photo uploads per rolling 24 hours | every upload, for a new entry or an edit | `KA002` |
| 10 photos no entry uses | every upload | `KA003` |

- **Entries.** The entries insert policy calls `check_entry_limit()`, which
  takes a per-user lock, counts and refuses. The lock is held until the
  transaction ends, so of two submissions sent at once the second waits and
  then counts the first.
- **Uploads through the app.** Before decoding a photo, `uploadPhoto()` calls
  `claim_photo_upload()`. Under the same lock it checks the limits (the pending
  one too, for a new entry) and writes one row to `photo_upload_claims`, a log
  no API role can read or write. A file of the wrong type or size is refused
  before the claim, so it uses up nothing. A claim is not given back when a
  later step fails, because by then the photo may have been decoded.
- **Uploads straight to Storage.** Supabase Storage runs the upload policy only
  as a check it rolls back, then writes the file itself with policies off. A
  policy can therefore refuse but not record or lock, so this path is limited
  only by `photo_upload_allowed()`, a read-only count of the user's files:
  fewer than 10 unused and fewer than 20 from the last 24 hours.
- **Messages.** `lib/limits.ts` turns each code into a sentence, and the form
  comes back with the text as typed. If two submissions at once both get past
  the claim and the second entry is then refused, its photo is removed again,
  as for any failed save.

### Review (0007)

- **Nobody reviews their own entry.** `review_entry()` publishes or returns a
  pending entry only if the caller is a reviewer and the entry is someone
  else's. On their own entry a reviewer gets `false`, and nothing changes.
- **Every edit goes back for review**, reviewers' included. The update policy
  accepts only a `pending` row, so no one can set their own entry to
  `published` directly, put back up an entry that was returned, or keep a
  published entry public while changing its text or photo. 0003 allowed all
  three for reviewers, and the last undid 0004's photo lock for them.
- A reviewer's own entry is published by another reviewer, or by the founder in
  the dashboard, which no policy applies to.


There is no review step in Sprint 2, and no policy lets a contributor set any
status but `published`. A reviewer role, and the hiding of new entries until
review, is Sprint 3, and needs a new migration.

The `service_role` key must never appear in this project. It ignores every
policy above, and shipping it to the browser would undo all of it.

### Known limitations

- Photos stored before re-encoding was added still carry their original
  metadata, GPS included. Cleaning those is a separate, one-off task.
- Re-encoding converts colours to sRGB, so a wide-gamut phone photo loses a
  little saturation, and an animated WebP is stored as its first frame.
- An upload sent straight to the Storage API skips the app's checks,
  re-encoding included. The bucket still enforces size and declared type, so
  an owner could store a non-image, or a photo with its metadata, in their own
  folder and point their own entry at it. It would affect their entry only.
- 0004 cannot vouch for files changed before it was applied: a photo swapped
  under an approved entry earlier still shows. Its tests run at the SQL layer;
  which statement each Storage API call sends (upload, upsert, update, move,
  copy, remove) comes from Supabase's documentation and needs the live check.
- `photo_in_use()` lets any signed-in user ask whether a given file name is in
  use. Names are random uuids, and published ones are public anyway.
- The upload limits are best effort for uploads sent straight to the Storage
  API: they stop uploads sent one after another, not a burst sent at once, and
  not uploading and deleting in a loop. That path never reaches the app's image
  processing.
- If photo clean-up keeps failing, a contributor's unused photos can reach 10,
  and they cannot upload until someone removes the strays in the dashboard.
  The app has no way for them to do it themselves.
- With JavaScript off, or for a request sent directly, a photo past the
  4.25 MB body limit (or Vercel's own limit) fails before the action runs.
  That ends on the generic error page, and the typed text is lost. The entry
  form has not been tested with JavaScript disabled.
- A photo whose removal failed stays in the public bucket, attached to
  nothing, until removed by hand. Search the logs for `[photo-cleanup]`.
- If Supabase cannot revoke the session at sign-out, the browser is signed out
  anyway, but the refresh token stays valid until it expires. This is logged
  as `[auth]`.
- With "Confirm email" off, a new address is signed in at once while an
  existing one gets the notice, so the outcome tells them apart. Keep it on.
  Separately, Supabase's per-address resend limit can hint that someone signed
  up with an address in the last minute.
- Whatever a contributor saves is public at once. The credit in `told_by` is
  required but cannot be checked by the app.
- The seven researched entries still carry `[SOURCE PENDING …]`, and the
  provenance of the photos in `public/entries/` is not yet confirmed.
- Vercel previews read and write the live database: the Supabase variables
  target Production, Preview and Development (checked 19 October). Previews
  are behind a Vercel login, and are not used for submitting.

### Evidence

**Local, on this branch (19 October 2026)** — no Supabase involved:

- `npm run test:db`: 133 checks in a throwaway Postgres 17 container, acting
  as a visitor, contributor A and contributor B through RLS. In order: existing
  rows untouched by 0002; a visitor reads published entries and changes
  nothing; a new entry is public at once; on insert, a contributor cannot
  choose the owner, status, id or date; B's edits and deletes of A's entry
  change nothing, and a read-back proves it; A cannot change an entry's owner
  or dates; the older pending entry cannot be published without a photo;
  visible text in every field; Khmer, single names and the length limits; a
  published photo must be the owner's own; A deletes A's own entry; Storage
  folders; the rules that must never loosen.
- `npm test`: 41 unit tests.
- `docs/rollback-0002.sql`, applied after 0002 and a Sprint 2-style insert,
  leaves the policies, constraints, default, privileges and bucket settings
  identical to 0001's.
- The migration-history commands in the rollout checklist, run against a
  throwaway Postgres with Supabase CLI 2.117.
- Simulated end to end, during development: the dev server against a
  stand-in for Supabase on localhost, driven by headless Chrome and by plain
  form posts. It covered uploads (2.56 MiB to exactly 4 MiB accepted; 4 MiB
  plus one byte and a renamed text file refused; a PNG named `.jpg` stored as
  PNG); field limits (Khmer at 120, a story of 8,000 characters with line
  breaks); delete outcomes (success, zero rows, a database error, and five
  ways photo cleanup can fail); and 23 auth cases (sign-in, sign-up, the
  confirmation link, sign-out, the redirect guard, crafted `?error=` links).
  That harness was not committed. It shows what the app does with the
  responses Supabase is documented to send; it is not Supabase.

**Live, still pending** — the checklist in `docs/rollout-sprint2.md`:
0002 on the live database; the bucket enforcing its limits; Vercel's request
limit on a real upload; PostgREST's error codes; Supabase Auth's real error
codes, confirmation emails and redirect URLs; and the two-account test.

**Live, earlier:** `scripts/verify-rls.sh` passed 14 of 14 against the live
project on 15 September — the 0001 rules, not the current ones. It expects a
new entry to land pending and inserts without a photo, so it fails by design
after 0002; it now stops before doing anything, and the rollout checklist's
two-account test replaces it. A read-only
check on 25 September found the live schema matching 0001 exactly, with an
empty migration history.
