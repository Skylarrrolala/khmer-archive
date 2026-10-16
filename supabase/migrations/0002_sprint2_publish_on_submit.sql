-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0002: Sprint 2 — publish on submit, without loosening ownership.
--
-- Sprint 2's brief: a contribution appears publicly the moment it is saved.
-- Review before publication is Sprint 3. 0001 built that review gate early
-- (every new or edited row had to be `pending`), so nothing a contributor
-- submitted could ever reach the public archive. This migration removes the
-- gate and tightens everything around ownership at the same time.
--
-- 0001 is not edited: a database that already ran it catches up by running
-- this file once. Nothing here changes an existing row — every statement is
-- a policy, a privilege, a constraint, a default or the photo bucket's
-- settings. The constraints are checked against existing rows as they are
-- added, so if any existing row broke a rule the whole migration would fail
-- and change nothing.
--
-- tests/db/0002-ownership.test.sql exercises every rule below as an
-- anonymous visitor and as two separate contributors.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. New entries are published, and the database decides that.
--
-- Contributors are not allowed to write `status` on insert (section 3), so a
-- new row always takes this default. Without it, every insert would come out
-- `pending` and fail the insert policy below.
-- -----------------------------------------------------------------------------
alter table public.entries alter column status set default 'published';


-- -----------------------------------------------------------------------------
-- 2. Policies: only the status half changes. The owner half is identical.
--
-- `auth.uid() = contributor_id` stays in every place 0001 put it:
--   INSERT  with check — you can only create rows in your own name
--   UPDATE  using      — you can only reach your own rows
--   UPDATE  with check — a row you edit must still be yours afterwards
--   DELETE  using      — you can only delete your own rows
-- Remove any one of them and a contributor can write as, or over, someone
-- else. The SELECT and DELETE policies are not touched by this file.
-- -----------------------------------------------------------------------------

alter policy "contributors can create their own pending entries"
  on public.entries
  rename to "contributors can create their own published entries";

-- What it does: a new row must carry the creator's own id and be published.
-- Without `auth.uid() = contributor_id`, user A could post an entry credited
-- to user B's account. Without `status = 'published'`, a direct request
-- could create rows in states the Sprint 2 app never shows.
alter policy "contributors can create their own published entries"
  on public.entries
  with check (
    auth.uid() = contributor_id
    and status = 'published'
  );

-- What it does: you can edit only your own rows (`using`), the row must
-- still be yours afterwards (`with check`), and an edited row is published.
-- Without the `with check` owner test, A could edit their own row and in the
-- same statement hand it to B. Section 3 refuses that even earlier, by not
-- letting anyone write `contributor_id` at all, so the two layers back each
-- other up.
alter policy "contributors can update their own entries"
  on public.entries
  using (auth.uid() = contributor_id)
  with check (
    auth.uid() = contributor_id
    and status = 'published'
  );


-- -----------------------------------------------------------------------------
-- 3. Privileges: which columns a request may write at all.
--
-- Supabase grants every API role every privilege on every new table in
-- `public` (production shows `arwdDxtm` for both anon and authenticated), and
-- leaves it to RLS to say no. RLS decides which ROWS a statement may touch;
-- it has no idea which COLUMNS a statement changes. So an owner could rewrite
-- their own row's `created_at` to sit at the top of the newest-first archive,
-- or change its `id` and break every link to it. Column privileges close
-- that: the database refuses the statement before RLS is even consulted.
--
-- REVOKE ALL on a table also removes any column-level grants, so what
-- follows is the complete list of what each role can do.
-- -----------------------------------------------------------------------------
revoke all on table public.entries from anon, authenticated;

-- Visitors read. The SELECT policy still limits them to published rows.
grant select on table public.entries to anon;

-- Contributors read and delete; the policies decide which rows.
grant select, delete on table public.entries to authenticated;

-- On insert, the server decides `id`, `created_at` and `status`. The
-- contributor supplies only content, plus their own id, which the insert
-- policy checks against the logged-in user.
grant insert (
  contributor_id,
  name_khmer, name_english, told_by, context, description,
  photo_url
) on table public.entries to authenticated;

-- On update, `id`, `created_at` and `contributor_id` can never change: who
-- owns an entry, and when it arrived, are facts rather than content. `status`
-- is writable only so that an edit can publish an entry; the update policy
-- accepts no value but 'published'.
grant update (
  name_khmer, name_english, told_by, context, description,
  photo_url,
  status
) on table public.entries to authenticated;

-- Not granted to anyone through the API any more: TRUNCATE (which RLS does
-- not apply to at all), REFERENCES, TRIGGER and MAINTAIN.


-- -----------------------------------------------------------------------------
-- 4. Text: "required" means visible text, and nothing is unbounded.
--
-- 0001 checked `length(trim(x)) > 0`. Postgres's trim() strips ordinary
-- spaces only, so a value of one tab, one non-breaking space or one
-- zero-width space passed, and printed on the page as nothing. The new test
-- asks for at least one character that is not whitespace or an invisible
-- formatting mark.
--
-- The invisible marks are listed explicitly rather than left to the
-- locale's idea of [:space:], so the rule means the same thing on any
-- database. U+200B (zero-width space) is used *between* Khmer words, and
-- that is unaffected: this only refuses a value that has nothing else in it.
--
-- Lengths are counted in characters (code points), so Khmer and Latin
-- names are measured the same way. Existing rows are far inside them (on
-- 16 Oct the longest were 12, 63, 60, 57 and 1,166).
-- -----------------------------------------------------------------------------
alter table public.entries
  drop constraint entries_name_khmer_check,
  drop constraint entries_name_english_check,
  drop constraint entries_told_by_check,
  drop constraint entries_context_check,
  drop constraint entries_description_check;

alter table public.entries
  add constraint entries_name_khmer_visible
    check (name_khmer ~ '[^[:space:]\u00a0\u1680\u180e\u2000-\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]'),
  add constraint entries_name_english_visible
    check (name_english ~ '[^[:space:]\u00a0\u1680\u180e\u2000-\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]'),
  add constraint entries_told_by_visible
    check (told_by ~ '[^[:space:]\u00a0\u1680\u180e\u2000-\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]'),
  add constraint entries_context_visible
    check (context ~ '[^[:space:]\u00a0\u1680\u180e\u2000-\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]'),
  add constraint entries_description_visible
    check (description ~ '[^[:space:]\u00a0\u1680\u180e\u2000-\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]'),

  -- A single word is a complete name: `told_by` is one field, never split
  -- into first and last name, and these limits are the only shape rule.
  add constraint entries_name_khmer_length   check (char_length(name_khmer)   <= 120),
  add constraint entries_name_english_length check (char_length(name_english) <= 150),
  add constraint entries_told_by_length      check (char_length(told_by)      <= 120),
  add constraint entries_context_length      check (char_length(context)      <= 300),
  add constraint entries_description_length  check (char_length(description)  <= 8000);


-- -----------------------------------------------------------------------------
-- 5. Photos.
--
-- Published means photographed. Sprint 2 asks for text plus at least one
-- photo. `photo_url` stays nullable, so the one older row without a photo is
-- still valid, but no row can be published without one. That applies to
-- edits too, so an edit cannot quietly strip a published entry's photo.
--
-- A photo must be the entry owner's own. A contributor's photo must live in
-- that contributor's own Storage folder, `entry-photos/<their id>/<uuid>`,
-- which is the only place the Storage policies let them upload. Without this,
-- a direct request could point an entry at another contributor's photo, or at
-- any address on the internet. The rows with no owner — the seven researched
-- entries — use the photographs shipped in the app under /entries/.
-- -----------------------------------------------------------------------------
alter table public.entries
  add constraint entries_published_has_photo
    check (status <> 'published' or photo_url is not null),

  add constraint entries_photo_url_location
    check (
      photo_url is null
      or (
        contributor_id is null
        and photo_url ~ '^/entries/[a-z0-9-]+\.(jpg|jpeg|png|webp)$'
      )
      or (
        contributor_id is not null
        and photo_url ~ (
          '^https?://[^/]+/storage/v1/object/public/entry-photos/'
          || contributor_id::text
          || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
        )
      )
    );


-- -----------------------------------------------------------------------------
-- 6. The photo bucket enforces its own limits.
--
-- The app checks size and file content before uploading, but a request sent
-- straight to the Storage API skips the app. These two settings are checked
-- by the Storage service itself on every upload: at most 4 MiB, and only the
-- three image types the app accepts.
--
-- 4 MiB rather than more because Vercel refuses any request body over
-- 4.5 MB before it reaches the app, and the upload shares that body with the
-- text fields and the form encoding. The app's own limit is set to match.
--
-- The declared type is still not proof the bytes are an image; the app
-- checks the bytes themselves. This is the floor under that check, not a
-- replacement for it.
-- -----------------------------------------------------------------------------
update storage.buckets
set
  file_size_limit    = 4194304,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'entry-photos';
