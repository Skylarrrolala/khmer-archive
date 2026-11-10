# The Khmer Living Archive — Desserts Edition

A community web archive preserving traditional Khmer desserts (នំ / *nom*) as
made and remembered by my grandparents in **Prey Veng**.

Entries are of two kinds: desserts still actively made, and desserts
remembered from earlier in life but no longer made. Every entry credits the
person who shared it, by name, with their permission. New entries need text
and a photograph. Under Sprint 3, submissions and edits stay `pending`,
hidden from the public archive, until another authorized reviewer publishes
them. Contributors can see Pending, Published or Returned in "Your entries"
and edit a returned entry to submit it for review again.

Built as a capstone project for a "Vibe Coding with AI" course.

## The four features

| Sprint | Feature | Status |
| --- | --- | --- |
| 1 | Browse & search published entries, plus a detail page. No login. | **Done** |
| 2 | Contributor accounts and photo submissions. | Built |
| 2 | Ownership — edit/delete only your own entries, enforced by RLS. | Built |
| 3 | Review workflow — pending submissions, reviewer Publish/Return queue, contributor status. | Database applied and verified; reviewer queue deployment and authenticated live checks pending |

Nothing outside these four features is in scope.

This describes the repository after migrations 0001–0008, not a verified live
deployment. Production migrations 0001–0008 are applied and verified as of
10 November 2026; reviewer queue deployment and authenticated live checks remain
pending. See [`docs/rollout-results-0004-0008.md`](docs/rollout-results-0004-0008.md). Current SQL,
validation and approval checkpoints: [`docs/rollout-sprint3.md`](docs/rollout-sprint3.md).
[`docs/prepare-0004-0008.md`](docs/prepare-0004-0008.md) prepares a rollback
dry-run only, not permanent application. The older
[`docs/rollout-sprint2.md`](docs/rollout-sprint2.md) records the Sprint 2 rollout
and is not a complete Sprint 3 deployment plan.

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
4. Apply migrations `0003` through `0008` in numeric order, each in one
   transaction. They restore pending review, protect photos in use, restrict
   photo listing, add contributor limits, prevent self-review, and record
   status changes. Sprint 2's publish-on-save behavior is historical.

These are fresh-project setup instructions. For an existing production
project, verify its actual schema and migration history first; do not rerun
files blindly. Reviewer membership is assigned by the founder in
`public.reviewers`, outside the app. Contributors cannot grant themselves
that role.

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
npm test          # unit tests, including reviewer authorization and decisions
npm run test:db   # the RLS and constraint tests, in a throwaway local Postgres (needs Docker)
```

`npm run test:db` never connects to Supabase. `scripts/verify-rls.sh` is
historical: it tested the 0001 rules against the live project, and now stops
before doing anything. Sprint 3 still needs authenticated live checks for
visitor, contributor and reviewer permissions, publish/return/resubmit, and
real Storage behavior.

### 6. Deploy to Vercel

Import the repository at [vercel.com/new](https://vercel.com/new). Add the same
two environment variables under **Settings → Environment Variables**, for the
Production, Preview and Development environments. Vercel detects Next.js and
needs no other configuration. Apply and verify the required database
migrations before deploying this checkout. Pushing `main` triggers the
production deployment; a local test pass does not mean production is ready.

## How security is enforced

The short version: **in the database, not in the UI.**

`supabase/migrations/0001_init.sql` turns on Row Level Security for the
`entries` table. After migrations 0002–0008:

- visitors may read published entries only;
- contributors may also read their own entries at every status;
- a new entry must belong to its contributor, include a photo and start pending;
- contributors may edit/delete only their own entries; every edit returns to pending;
- reviewers may read the queue, but can publish or return only another
  contributor's pending entry, through `review_entry()`;
- neither a forged browser request nor a direct API request can grant a
  reviewer role or bypass these database checks.

`/review` and each decision action also check the signed-in reviewer's
membership. Signed-out visitors are sent to login; contributors receive a 404.
The database checks the role again when the decision is made.

0002 also limits which **columns** a request may write: no API request can
change an entry's `id`, `created_at` or `contributor_id`, or choose its
`status` on insert. CHECK constraints refuse blank or over-long text, a
published entry without a photo, and a photo that is not in the owner's own
Storage folder. The bucket refuses files over 4 MiB and any declared type but
JPEG, PNG and WebP; the app also checks the file's bytes.

Because these run inside Postgres, they hold even if the app forgets a filter,
and even if someone calls the Supabase REST API directly with the anon key.
Storage photos are protected the same way: a contributor can only upload into
a folder named after their own user id. Files referenced by an entry cannot
be replaced or deleted; bucket listing is limited to the owner's folder.
The bucket remains public: a known photo URL still works while its entry is
pending. Unpublished entry text is protected by RLS; photo URL access is a
known limitation. Status history is private to the database owner and is not
an app feature.

Longer walkthrough, including the file-by-file map, the validation and photo
rules, and the known limitations:
[`docs/architecture.md`](docs/architecture.md).

## What this is not

No comments, likes, tags, notifications, multi-language toggle, or admin
dashboard beyond the Sprint 3 review queue.
