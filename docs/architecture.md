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
| `supabase/migrations/0001_init.sql` | The whole schema: the `entry_status` enum, the `entries` table, its indexes, every RLS policy, and the `entry-photos` storage bucket with its policies. Run once in the Supabase SQL editor. |
| `supabase/seed.sql` | The seven desserts, with ingredients, method, region and notes folded into `description`. The content is researched, not family testimony: every `told_by` holds `[SOURCE PENDING …]`, which the UI renders as a "Source pending verification" badge, so nothing on the page claims a source it does not have. Re-running the file clears the rows it owns (`contributor_id is null`) first, so it cannot double up. |

### App plumbing

| File | What it does |
| --- | --- |
| `lib/env.ts` | Reads `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Reads them inside a function, not at import time, so `next build` still succeeds on a machine with no `.env.local`. |
| `proxy.ts` | Refreshes the Supabase session on each request. Named `proxy.ts`, not `middleware.ts` — that convention is deprecated in Next.js 16 and renamed. It is **not** an auth gate: Next's own guidance is that a proxy is an optimistic check only, so there is no redirect logic in it. Deleting it would log people out early; it would not expose a row. |
| `lib/auth.ts` | The auth half of the data access layer. `getCurrentUser()` uses `getUser()` (which revalidates the token with Supabase) rather than `getSession()` (which just trusts the cookie), memoised with React `cache`. `requireUser()` redirects to `/login` for pages that make no sense signed out. |
| `app/(auth)/actions.ts` | Sign-up, sign-in and sign-out as Server Actions. Only actions and route handlers may write cookies, which is why session creation lives here. `safeNext()` rejects any `next` that is not a same-site path, so the login form cannot be used as an open redirect. Supabase's identical error for a bad email and a bad password is passed through unchanged, so the form cannot be used to enumerate accounts. |
| `components/AuthForm.tsx` | One form for both sign-up and sign-in. No `"use client"` and no `useActionState`, so it submits with JavaScript disabled; the cost is that errors come back as `?error=` on a redirect. |
| `app/submit/page.tsx`, `app/submit/actions.ts` | The submission form and its Server Action. Photos upload to `entry-photos/<user id>/<uuid>.<ext>` — the first folder must be the uploader's id because the Storage policy checks it, and the filename is a fresh uuid because an uploaded name is untrusted input that can collide or carry separators. Type and size are re-checked on the server; `accept` is only a hint. `contributor_id` and `status: 'pending'` are set server-side, so a contributor cannot self-publish or attribute an entry to someone else. |
| `app/my-entries/page.tsx` | The contributor's own submissions with their review status. The only page that shows unpublished rows, and it is the RLS policy "contributors can read their own entries" that makes that possible — not the `requireUser` call, which only decides whether to render. Does not reuse `EntryCard`: a pending entry has no public detail page to link to. |
| `components/AccountNav.tsx` | The signed-in state in the masthead. Sign-out is a POST form, not a link, so a prefetch or a third-party `<img>` cannot log someone out. |
| `lib/supabase/server.ts` | Builds a per-request Supabase client wired to Next's cookie store, so the logged-in user's session travels with server-side queries. A new client per request — sharing one would leak sessions between users. |
| `lib/types.ts` | The TypeScript shape of an entry, mirroring the SQL table by hand. |
| `lib/entries.ts` | Every public read lives here, so there is one place to audit. Also sanitises the search term before it goes into a PostgREST filter. |

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
| `components/EntryCard.tsx` | One dessert in the list. Handles the null-photo case with a labelled placeholder, because "remembered but not made today" is a real state of the data. The photo fills a square tile: the archive's photos range from 0.67 to 1.50 in aspect, so no frame holds all of them uncropped, and a square crops least across that spread. Takes an `index` purely for the printed 01 / 02 / 03, which is `aria-hidden` because it renumbers with every search. |
| `components/FadeInImage.tsx` | `next/image` with a fade-in once the photo has loaded. The only client component among the photos, because `onLoad` is a function. It never hides a photo in the server HTML — only once JavaScript has seen the photo is still loading — so with JavaScript off, or for a photo that arrived before hydration, nothing is ever invisible. A photo that fails is revealed too, so its alt text shows. |
| `components/EntryPhotoTransition.tsx` | Gives a dessert's photo frame the same view-transition name on the card and on the detail page, so the browser carries the photo from one to the other. Both ends render this component, so the name and the `share="morph"` / `default="none"` props cannot drift apart — the pair silently stops animating if one side loses `share`. The photo only travels when both ends are on screen; otherwise it moves with its page. |
| `components/LandingMarker.tsx` | Stamps `data-landed` on `<html>` once the landing sequence has had time to finish, which switches the `land*` rules off. CSS cannot tell a first load from a client-side navigation — both insert fresh elements — so without this every return to the home page would replay the whole sequence. Mounted in the root layout, which survives navigations, so it runs once per document load. |

### Config

| File | What it does |
| --- | --- |
| `next.config.ts` | Allowlists the Supabase Storage hostname for `next/image`. Without an allowlist, the image optimiser would happily fetch any URL on the internet, which turns the deployment into an open image proxy. The host is derived from the env var, so the same file works locally and on Vercel. |
| `.env.example` | The two variables to copy into `.env.local`. `.gitignore` ignores `.env*` but re-includes this one file. |
| `eslint.config.mjs`, `tsconfig.json`, `postcss.config.mjs` | Stock `create-next-app` output — linting, TypeScript with the `@/*` path alias, and the Tailwind PostCSS plugin. |

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

### The four rules

**1. The public sees only published entries.**

```sql
create policy "published entries are readable by everyone"
  on public.entries for select to anon, authenticated
  using (status = 'published');
```

`lib/entries.ts` *also* writes `.eq("status", "published")`, but that is a
convenience for the query planner, not the guarantee. If someone deleted that
line tomorrow, pending entries would still not leak, because Postgres would
refuse to hand them over.

**2. A contributor sees their own entries whatever the status.**

```sql
create policy "contributors can read their own entries"
  on public.entries for select to authenticated
  using (auth.uid() = contributor_id);
```

Postgres OR's the `select` policies together, so a logged-in contributor sees
every published entry *plus* their own pending ones. This is what makes the
Sprint 2 "my entries" page, and the pending/published badge on it, possible
with no extra query.

**3. A contributor can only create entries in their own name, and only pending.**

```sql
create policy "contributors can create their own pending entries"
  on public.entries for insert to authenticated
  with check (auth.uid() = contributor_id and status = 'pending');
```

`auth.uid() = contributor_id` stops user A submitting an entry attributed to
user B. `status = 'pending'` stops a contributor skipping the review queue and
publishing straight to the front page.

**4. A contributor can only edit or delete their own entries.**

```sql
create policy "contributors can update their own entries"
  on public.entries for update to authenticated
  using (auth.uid() = contributor_id)
  with check (auth.uid() = contributor_id and status = 'pending');
```

The two clauses do different jobs, and both are needed:

- `using` decides **which existing rows** the user may touch.
- `with check` decides **what the row is allowed to look like afterwards**.

With only `using`, a contributor could edit their own row and, in the same
statement, set `contributor_id` to someone else's id or set
`status = 'published'`. The `with check` clause closes both. It also means an
edit resets the entry to `pending`, sending it back through review — exactly
what Sprint 3 asks for.

Delete needs only `using`, since there is no "after" state to constrain.

### Photos

Supabase Storage is itself a Postgres table (`storage.objects`) with RLS, so
photo permissions are written the same way. Uploads must land in a folder named
after the uploader's user id:

```sql
with check (
  bucket_id = 'entry-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
```

`storage.foldername()` splits the object path on `/`, so `[1]` is the first
folder. A contributor writing to `entry-photos/<their-uid>/num-kom.jpg` is
allowed; writing to another contributor's folder — or overwriting a photo in
it — is refused.

### What is deliberately missing

There is no policy letting an ordinary user set `status = 'published'`. Until
Sprint 3 adds the reviewer path, publishing is done by hand in the Supabase
dashboard, which connects as the service role and bypasses RLS.

The `service_role` key must never appear in this project. It ignores every
policy above, and shipping it to the browser would undo all of it.

### Proof that it works

`scripts/verify-rls.sh` exercises every policy below against the real Supabase
project and prints a pass or fail line for each. It talks to PostgREST with a
real access token rather than clicking through the app, which is the only way
the claim means anything: a rule that lived in React would pass a UI test and
fail this one.

    ./scripts/verify-rls.sh

Read the header before running it — it needs "Confirm email" turned off for the
length of the run, and leaves one throwaway account to delete by hand.

Last run: 14 of 14 checks passed against the live project, with the seven seed
entries intact afterwards. The same policies were exercised against a local
Postgres before being committed, with two test contributors A and B:

| Attempt | Result |
| --- | --- |
| A submits an entry | inserted, `status = pending` |
| A submits with `status = 'published'` | rejected — RLS violation |
| A submits with B's `contributor_id` | rejected — RLS violation |
| A publishes their own entry | rejected — RLS violation |
| A edits their own entry | succeeds |
| Logged-out visitor lists entries | sees the 3 published rows, 0 pending |
| B edits A's entry | 0 rows changed |
| B deletes A's entry | 0 rows deleted |
| B reads A's pending entry | 0 rows |
| B uploads into A's photo folder | rejected — RLS violation |
| B uploads into their own folder | succeeds |
| A deletes their own entry | succeeds |

The script covers the same ground with one account rather than two: a seed row
stands in for "an entry that is not mine", since its `contributor_id` is null
and `auth.uid() = contributor_id` fails the `USING` clause exactly as another
contributor's row would. The forged-`contributor_id` insert covers the
cross-contributor case directly.
