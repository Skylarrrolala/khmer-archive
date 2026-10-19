-- =============================================================================
-- Rollback for supabase/migrations/0002_sprint2_publish_on_submit.sql
--
-- NOT a migration. It lives in docs/ so that `supabase db push` never runs it.
-- Run it only to undo 0002, and only after the app has been rolled back to a
-- build that expects 0001 (see docs/rollout-sprint2.md, "Rollback").
--
-- It returns the schema to exactly what 0001 created and changes no row:
-- entries published under 0002 stay published, and photos stay where they
-- are. It also reopens what 0002 closed: contributors can again write `id`,
-- `created_at` and `contributor_id`, and text and photos lose their limits.
-- A forward fix is usually the better choice.
--
-- Tested on a local copy of the schema: after 0002 and then this file, the
-- policies, constraints, default, privileges and bucket settings are the same
-- as after 0001 alone.
-- =============================================================================

begin;

-- 6. The photo bucket: no size or type limit, as 0001 left it.
update storage.buckets
set file_size_limit = null, allowed_mime_types = null
where id = 'entry-photos';

-- 4 and 5. Constraints: drop 0002's, restore 0001's.
alter table public.entries
  drop constraint entries_published_has_photo,
  drop constraint entries_photo_url_location,
  drop constraint entries_name_khmer_visible,
  drop constraint entries_name_english_visible,
  drop constraint entries_told_by_visible,
  drop constraint entries_context_visible,
  drop constraint entries_description_visible,
  drop constraint entries_name_khmer_length,
  drop constraint entries_name_english_length,
  drop constraint entries_told_by_length,
  drop constraint entries_context_length,
  drop constraint entries_description_length;

alter table public.entries
  add constraint entries_name_khmer_check   check (length(trim(name_khmer)) > 0),
  add constraint entries_name_english_check check (length(trim(name_english)) > 0),
  add constraint entries_told_by_check      check (length(trim(told_by)) > 0),
  add constraint entries_context_check      check (length(trim(context)) > 0),
  add constraint entries_description_check  check (length(trim(description)) > 0);

-- 3. Privileges: back to Supabase's default of everything for both API roles.
-- The revoke clears 0002's column-level grants first.
revoke all on table public.entries from anon, authenticated;
grant all on table public.entries to anon, authenticated;

-- 2. Policies: new and edited rows must be pending again.
alter policy "contributors can create their own published entries"
  on public.entries
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
  );

alter policy "contributors can create their own published entries"
  on public.entries
  rename to "contributors can create their own pending entries";

alter policy "contributors can update their own entries"
  on public.entries
  using (auth.uid() = contributor_id)
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
  );

-- 1. New rows default to pending again.
alter table public.entries alter column status set default 'pending';

commit;
