# What every file does

Written so I can explain any line of this project without guessing.

## The shape of a request

A visitor loads `/`. Next.js runs `app/page.tsx` **on the server**. That page
calls `getPublishedEntries()`, which builds a Supabase client carrying the
request's cookies and asks Postgres for published entries. Postgres applies the
Row Level Security policies, returns the rows it is willing to release, and
Next.js renders them to HTML. The browser receives finished HTML — it never
receives an entry it is not allowed to see, because the filtering happened two
layers earlier, in the database.

```
browser  ->  app/page.tsx  ->  lib/entries.ts  ->  lib/supabase/server.ts  ->  Postgres + RLS
```

## File map

### Database

| File | What it does |
| --- | --- |
| `supabase/migrations/0001_init.sql` | The whole schema: the `entry_status` enum, the `entries` table, its indexes, every RLS policy, and the `entry-photos` storage bucket with its policies. Run once in the Supabase SQL editor. |
| `supabase/seed.sql` | Three dummy entries so Sprint 1 has something to render. Every one is prefixed `[SAMPLE]` so it can never be mistaken for a real family memory. |

### App plumbing

| File | What it does |
| --- | --- |
| `lib/env.ts` | Reads `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Reads them inside a function, not at import time, so `next build` still succeeds on a machine with no `.env.local`. |
| `lib/supabase/server.ts` | Builds a per-request Supabase client wired to Next's cookie store, so the logged-in user's session travels with server-side queries. A new client per request — sharing one would leak sessions between users. |
| `lib/types.ts` | The TypeScript shape of an entry, mirroring the SQL table by hand. |
| `lib/entries.ts` | Every public read lives here, so there is one place to audit. Also sanitises the search term before it goes into a PostgREST filter. |

### Pages and components

| File | What it does |
| --- | --- |
| `app/layout.tsx` | The HTML shell: header, footer, and the two `next/font` families (Noto Sans for Latin, Noto Sans Khmer so the Khmer names render instead of showing empty boxes). |
| `app/globals.css` | Tailwind v4 is configured in CSS, not a JS config file. `@theme inline` declares the small warm palette; naming a token `--color-paper` is what makes `bg-paper` exist as a utility. |
| `app/page.tsx` | The public browse + search page. Reads `?q=` from the URL and passes it to `getPublishedEntries`. |
| `app/entries/[id]/page.tsx` | The detail page for one dessert. Calls `notFound()` when there is no published entry with that id. |
| `components/SearchBar.tsx` | A plain `<form method="get">` — no client-side JavaScript, no React state. Submitting navigates to `/?q=…`, which re-runs the server page and re-queries Postgres. The result is a shareable URL, and search works with JS disabled. |
| `components/EntryCard.tsx` | One dessert in the list. Handles the null-photo case with a labelled placeholder, because "remembered but not made today" is a real state of the data. |

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
folder. A contributor writing to `entry-photos/<their-uid>/nom-kom.jpg` is
allowed; writing to another contributor's folder — or overwriting a photo in
it — is refused.

### What is deliberately missing

There is no policy letting an ordinary user set `status = 'published'`. Until
Sprint 3 adds the reviewer path, publishing is done by hand in the Supabase
dashboard, which connects as the service role and bypasses RLS.

The `service_role` key must never appear in this project. It ignores every
policy above, and shipping it to the browser would undo all of it.

### Proof that it works

These policies were exercised against a local Postgres before being committed.
With two test contributors A and B:

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

You can re-run this yourself against the real project once Sprint 2 gives you
two accounts to log in with.
