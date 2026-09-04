# The Khmer Living Archive — Desserts Edition

A community web archive preserving traditional Khmer desserts (នំ / *nom*) as
made and remembered by my grandparents in **Prey Veng**.

Entries are of two kinds: desserts still actively made (with a photo of the
real thing), and desserts remembered from earlier in life but no longer made
(description only, sometimes with no photo at all). Every entry credits the
person who shared it, by name, with their permission.

Built as a capstone project for a "Vibe Coding with AI" course.

## The four features

| Sprint | Feature | Status |
| --- | --- | --- |
| 1 | Browse & search published entries, plus a detail page. No login. | **Done** |
| 2 | Contributor accounts, submissions with a photo, edit/delete your own entries. | Not started |
| 3 | Review workflow — submissions stay hidden until a reviewer publishes them. | Schema + policies in place; UI not started |

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
2. `supabase/seed.sql` — inserts three **clearly marked dummy entries** so the
   browse page has something to show. Delete these before the archive is
   treated as final:
   ```sql
   delete from public.entries where told_by like '[SAMPLE%';
   ```

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

### 5. Deploy to Vercel

Import the repository at [vercel.com/new](https://vercel.com/new). Add the same
two environment variables under **Settings → Environment Variables**, for the
Production, Preview and Development environments. Vercel detects Next.js and
needs no other configuration.

## How security is enforced

The short version: **in the database, not in the UI.**

`supabase/migrations/0001_init.sql` turns on Row Level Security for the
`entries` table, which makes it deny-by-default, and then grants back exactly
four things:

- anyone may read entries where `status = 'published'`;
- a logged-in contributor may additionally read their own entries, whatever
  the status;
- a logged-in contributor may insert a row only if `contributor_id` is their
  own id and `status` is `pending`;
- a logged-in contributor may update or delete only rows whose
  `contributor_id` is their own id.

Because these run inside Postgres, they hold even if the app forgets a filter,
and even if someone calls the Supabase REST API directly with the anon key.
Storage photos are protected the same way: a contributor can only write into a
folder named after their own user id.

Longer walkthrough, including the file-by-file map:
[`docs/architecture.md`](docs/architecture.md).

## What this is not

No comments, likes, tags, notifications, multi-language toggle, or admin
dashboard beyond the Sprint 3 review queue.
