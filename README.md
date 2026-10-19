# The Khmer Living Archive — Desserts Edition

A community web archive preserving traditional Khmer desserts (នំ / *nom*) as
made and remembered by my grandparents in **Prey Veng**.

Entries are of two kinds: desserts still actively made, and desserts
remembered from earlier in life but no longer made. Every entry credits the
person who shared it, by name, with their permission. Since Sprint 2 a new
entry is public as soon as it is saved, and it needs a photograph to be saved
at all (the brief asks for text plus at least one photo).

Built as a capstone project for a "Vibe Coding with AI" course.

## The four features

| Sprint | Feature | Status |
| --- | --- | --- |
| 1 | Browse & search published entries, plus a detail page. No login. | **Done** |
| 2 | Contributor accounts, submissions with a photo, edit/delete your own entries. | **Built and tested locally**; live rollout pending — [`docs/rollout-sprint2.md`](docs/rollout-sprint2.md) |
| 3 | Review workflow — submissions stay hidden until a reviewer publishes them. | Not started. Sprint 2 publishes on save, so Sprint 3 needs a new migration to bring the review step back |

Nothing outside these three sprints is in scope.

## Stack

- [Next.js](https://nextjs.org/) 16 (App Router) with TypeScript
- [Supabase](https://supabase.com/) — Postgres, Auth, and Storage for photos
- [Tailwind CSS](https://tailwindcss.com/) v4
- Deployed on [Vercel](https://vercel.com/)

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Create a Supabase project

At [supabase.com](https://supabase.com/dashboard) create a free project, then
open **SQL Editor** and run, in this order:

1. `supabase/migrations/0001_init.sql` — creates the `entries` table, the Row
   Level Security policies, and the `entry-photos` storage bucket.
2. `supabase/seed.sql` — inserts seven **researched** dessert entries. Their
   `told_by` holds `[SOURCE PENDING …]`, shown as "Source pending
   verification", until a real person is credited. To list them:
   ```sql
   select name_english from public.entries where told_by like '[SOURCE PENDING%';
   ```
3. `supabase/migrations/0002_sprint2_publish_on_submit.sql`, wrapped in
   `begin;` … `commit;` so it applies completely or not at all. It publishes
   entries on save, protects the owner, id and date columns, and adds the
   text, photo and bucket limits.

Under **Authentication → URL Configuration**, add
`http://localhost:3000/auth/confirm` to the Redirect URLs, or the link in a
confirmation email goes to the Site URL instead.

### 3. Add your environment variables

```bash
cp .env.example .env.local
```

Fill in the two values from **Project Settings → API** in the Supabase
dashboard. Only the *anon* (publishable) key belongs here — never the
`service_role` key, which bypasses every security policy in this project.

### 4. Run it

```bash
npm run dev
```

Open <http://localhost:3000>.

### 5. Run the tests

```bash
npm test          # unit tests: validation, photo checks, auth messages, cleanup
npm run test:db   # the RLS and constraint tests, in a throwaway local Postgres (needs Docker)
```

`npm run test:db` never connects to Supabase. `scripts/verify-rls.sh` is
historical: it tested the 0001 rules against the live project, and now stops
before doing anything. The live test that replaces it is in the rollout
checklist.

### 6. Deploy to Vercel

Import the repository at [vercel.com/new](https://vercel.com/new). Add the same
two environment variables under **Settings → Environment Variables**, for the
Production, Preview and Development environments. Vercel detects Next.js and
needs no other configuration.

## How security is enforced

The short version: **in the database, not in the UI.**

`supabase/migrations/0001_init.sql` turns on Row Level Security for the
`entries` table, which makes it deny-by-default, and grants back a few things.
Migration 0002 changes only the status half of those rules:

- anyone may read entries where `status = 'published'`;
- a logged-in contributor may additionally read their own entries, whatever
  the status;
- a logged-in contributor may insert a row only with their own id as
  `contributor_id`, and it comes out `published`;
- a logged-in contributor may update or delete only rows whose
  `contributor_id` is their own id, and an edited row stays theirs.

0002 also limits which **columns** a request may write: no API request can
change an entry's `id`, `created_at` or `contributor_id`, or choose its
`status` on insert. CHECK constraints refuse blank or over-long text, a
published entry without a photo, and a photo that is not in the owner's own
Storage folder. The bucket refuses files over 4 MiB and any declared type but
JPEG, PNG and WebP; the app also checks the file's bytes.

Because these run inside Postgres, they hold even if the app forgets a filter,
and even if someone calls the Supabase REST API directly with the anon key.
Storage photos are protected the same way: a contributor can only write into a
folder named after their own user id.

Longer walkthrough, including the file-by-file map, the validation and photo
rules, and the known limitations:
[`docs/architecture.md`](docs/architecture.md).

## What this is not

No comments, likes, tags, notifications, multi-language toggle, or admin
dashboard beyond the Sprint 3 review queue.