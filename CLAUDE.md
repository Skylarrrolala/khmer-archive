# Project: The Khmer Living Archive — Desserts Edition

## Goal
A community archive digitally preserving traditional Khmer desserts (នំ /
*num*) as made and remembered by the founder's grandparents in
Prey Veng. Entries mix desserts they still actively make
(photographed) and desserts they remember from earlier in life but no
longer make (description only, sometimes no photo). Capstone project for
a "Vibe Coding with AI" course. Deployed to Vercel via Next.js.

This is a food-and-memory preservation archive. It is NOT a recipe site,
NOT a general Khmer cookbook, NOT a social platform, NOT a blog.

> Note: this project began as a Prey Veng dialect-vocabulary archive. It
> was re-scoped to desserts. The four-feature skeleton, the security
> rules and the sourcing rules carried over unchanged; only the subject
> matter and the entry fields differ.

## The skeleton — this IS the whole scope
Nothing outside these four features is in scope, ever, unless told
explicitly that the professor approved a stretch feature by name.

1. **Browse & search** (Sprint 1) — public, no login needed. Anyone can
   browse and search published dessert entries, and open a detail page.
2. **Contributor accounts** (Sprint 2) — sign up / log in (Supabase Auth,
   email + password) to submit entries (text + at least one photo
   upload), plus a "my entries" view.
3. **Ownership** (Sprint 2) — contributors edit/delete ONLY their own
   entries, enforced with RLS. No admin panel, no cross-user editing.
4. **Review workflow** (Sprint 3) — entries are created `pending` and
   hidden from the public until a reviewer publishes them. Contributors
   can see the status of their own submissions.

## Hard rule: NO SCOPE ADDITIONS
Do not suggest, scaffold, or build anything beyond the 4 features above
— no comments, likes, tagging/categorization beyond simple search,
notifications, email, admin dashboards beyond the review queue, social
sharing, audio/video, multi-language UI toggle, recommendation engines,
gamification, or design/animation polish beyond clean and readable —
even if it seems like a natural improvement. If something seems like it
would genuinely help, name it and ask first. Do not build it
preemptively "while you're in there."

## Data model (confirm before changing)
`public.entries`, defined in `supabase/migrations/0001_init.sql`:
- `name_khmer` — Khmer name of the dessert
- `name_english` — English/transliterated name or description
- `told_by` — which grandparent shared it (or both)
- `context` — when/why it's made (festival, daily life, special occasion)
- `description` — the story or memory, ingredients/method if known
- `photo_url` — nullable; present if the dessert is still made and
  photographed
- `status` — `pending` / `published` / `rejected`
- `contributor_id` — who submitted it
- `created_at`

Do not add extra fields (audio, video, ingredient lists as structured
data, ratings, etc.) without asking first — the skeleton is deliberately
minimal.

## Stack (locked)
- Next.js 16 (App Router, TypeScript), deployed to Vercel
- Auth: Supabase Auth (email + password)
- Database: Supabase (Postgres, with Supabase Storage for photos)
- Styling: Tailwind CSS v4
- Do not add new dependencies without asking first.

## Data rules (this is graded on security, not just looks)
- Every edit/delete must check the entry's owner against the logged-in
  user in the database via RLS — not just hide the button in the UI.
- Unreviewed/unpublished entries must be excluded from public queries
  at the database level (RLS), not filtered client-side after fetching.
- The `service_role` key must never appear in this project. Only the
  anon/publishable key.
- Be ready to explain every line shipped. See `docs/architecture.md`.

## Sourcing & credit rules
- Every entry must credit its source by name, with their permission
  (`told_by` is `not null`).
- Don't fabricate example entries or placeholder "sample data" that
  looks real.
- **Never write first-person testimony attributed to a real person
  unless they actually said it.** Researched facts about a dessert are
  fine and belong in `description`. A passage like "Grandmother recalls
  wrapping these before Pchum Ben" is a quote, and a quote that was
  composed rather than transcribed puts invented words in a real
  person's mouth in a public archive. If prose arrives already written
  in that voice — from a document, a generator, anywhere — strip the
  first-person framing and keep the facts.
- The seven rows in `supabase/seed.sql` are researched, not sourced.
  Their `told_by` holds `[SOURCE PENDING …]`, which `lib/placeholders.ts`
  renders as a "Source pending verification" badge, so the page states
  the gap instead of claiming a source. Replace each marker with a real
  person only after actually speaking to them — and add the memory they
  tell you to `description` at the same time. To see what is still
  outstanding:
  `select name_english from public.entries where told_by like '[SOURCE PENDING%';`
- Photo provenance is not established for every image in
  `public/entries/`. Before the archive is treated as final, confirm
  each is a family photograph or licensed and credited.

## Current sprint focus
Sprint 1 is complete: browse page, keyword search, and entry detail page,
all reading published entries only. Next up is Sprint 2 — Supabase Auth
sign-up/log-in, the submission form with photo upload, and the "my
entries" view. No review-queue UI yet; that is Sprint 3.

## Files AI can touch this session
Sprint 2 will need: `/app/(auth)`, `/app/submit`, `/app/my-entries`,
`/lib/auth.ts`, `proxy.ts`, and `/components/*`.
Note two corrections to the original list: `middleware.ts` is deprecated in
Next.js 16 and renamed to `proxy.ts`, and `/lib/supabase/client.ts` (a
browser client) turned out not to be needed — the auth forms are Server
Actions, so nothing authenticates from the browser.
Do not modify `supabase/migrations/0001_init.sql` in place — add a new
numbered migration instead, so an already-deployed database can catch up.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
