# Project: Prey Veng Khmer Dialect Archive

## Goal
A community archive digitally preserving disappearing dialect vocabulary
and phrases from Prey Veng Khmer — words and sayings passed down
through the founder's grandparents and parents that don't exist, or mean
something different, in standard Khmer. Built for ICT 340 capstone.
Deployed to Vercel via Next.js.

This is a language-preservation archive. It is NOT a general Khmer
dictionary, NOT a translation tool, NOT a social platform, NOT a blog.

## The skeleton — this IS the whole scope
Nothing outside these four features is in scope, ever, unless told
explicitly that the professor approved a stretch feature by name.

1. **Browse & search** (Sprint 1) — public, no login needed. Anyone can
   browse and search dialect entries.
2. **Contributor accounts** (Sprint 2) — sign up / log in to submit
   entries (text + at least 1 photo per entry — e.g. a photo tied to
   the word's context, or of the person who taught it).
3. **Ownership** (Sprint 2) — contributors edit/delete ONLY their own
   entries. No admin panel, no cross-user editing, unless specified.
4. **Review workflow** (Sprint 3) — submitted entries are hidden from
   the public until reviewed and published.

## Hard rule: NO SCOPE ADDITIONS
Do not suggest, scaffold, or build anything beyond the 4 features above
— no comments, likes, tags/categories beyond what's needed for search,
notifications, admin dashboards, social sharing, audio recording,
multi-language toggle, recommendation engines, gamification, etc. —
even if it seems like a natural improvement. If something seems like it
would genuinely help, name it and ask first. Do not build it
preemptively "while you're in there."

## Data model (dialect-specific — confirm before changing)
Each entry should capture, at minimum:
- Dialect word or phrase
- Standard Khmer equivalent (if one exists)
- Meaning / definition
- Usage note or example sentence
- Who it was learned from (credited by name, with permission)
- Status: still commonly used / rare / mostly forgotten
- At least one photo

Do not add extra fields (audio, video, pronunciation IPA, etc.) without
asking first — the skeleton is deliberately minimal.

## Stack (locked)
- Next.js (App Router), deployed to Vercel
- Auth: Supabase Auth
- Database: Supabase (Postgres, with Supabase Storage for photos)
- Styling: Tailwind CSS
- Do not add new dependencies without asking first.

## Data rules (this is graded on security, not just looks)
- Every edit/delete must check the entry's owner against the logged-in
  user server-side — not just hide the button in the UI.
- Unreviewed/unpublished entries must be excluded from public queries
  at the database/query level, not filtered client-side after fetching.
- Be ready to explain every line shipped — no code nobody understands,
  even if the AI wrote it.

## Sourcing & credit rules
- Every entry must credit its source by name, with their permission.
- Don't fabricate example entries or placeholder "sample data" that
  looks real — use clearly marked dummy data during dev, swap for real
  entries before anything is treated as final.

## Current sprint focus
[Update this every session — e.g. "Sprint 1: build the entry list page
and search bar. No auth yet, no submission form yet — that's Sprint 2."]

## Files AI can touch this session
[Update per task — e.g. "/app/archive and /components/entry-* only."]
