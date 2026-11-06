-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0004: a photo an entry points at cannot be changed or removed.
--
-- Review finding H1. An entry stores its photo as a URL. 0003 sends an entry
-- back to `pending` whenever its row is edited, but a photo can change without
-- the row changing at all: 0001's Storage policies let a contributor update,
-- rename or delete any file in their own folder, and nothing in 0002 or 0003
-- touched them. So the bytes behind an approved entry's URL could be swapped
-- for unreviewed ones while the entry stayed published:
--   * overwrite it in place (Storage `update`, or `upload` with upsert);
--   * move another file onto its name, or move it away;
--   * delete it, then upload a different file under the same name.
--
-- After this file, the only way to change what an entry shows is to point the
-- entry at a new file, which is a row edit, which 0003 sends back for review.
--
-- Unchanged: the entries table, its policies and privileges, the public read
-- policy on photos, the bucket's limits, and the own-folder rule on upload and
-- delete. No row and no file is changed.
--
-- tests/db/0004-photo-lock.test.sql exercises every rule below.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. "Is any entry using this file?"
--
-- An entry's photo_url is the file's public URL, and 0002's
-- entries_photo_url_location makes everything after `/entry-photos/` exactly
-- the file's name in the bucket. split_part compares that text as it is: no
-- pattern characters, no partial matches.
--
-- SECURITY DEFINER, so it sees every entry whatever its status and whoever is
-- asking. Run as the caller it would see only what that caller's SELECT
-- policies allow, and a row it could not see would read as "not in use" —
-- failing open. Pinned search_path for the same reason as is_reviewer() (0003).
-- It returns only true or false, never the entry.
-- -----------------------------------------------------------------------------
create function public.photo_in_use(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.entries
    where split_part(photo_url, '/storage/v1/object/public/entry-photos/', 2) = object_name
  )
$$;

-- The Storage policies below call it as the signed-in user, so they need
-- EXECUTE. Visitors have no insert or delete policy, so they do not.
revoke execute on function public.photo_in_use(text) from public, anon;
grant execute on function public.photo_in_use(text) to authenticated;


-- -----------------------------------------------------------------------------
-- 2. No changing a stored file, at all.
--
-- Storage needs UPDATE permission to overwrite a file (`update`, or `upload`
-- with upsert) and to `move` one. The app does neither: a new photo always gets
-- a new uuid name (lib/photos.ts, upsert: false). With no UPDATE policy, RLS
-- refuses every update, so a stored file keeps its name and its bytes.
-- -----------------------------------------------------------------------------
drop policy "contributors can update photos in their own folder" on storage.objects;


-- -----------------------------------------------------------------------------
-- 3. No deleting a file an entry still uses.
--
-- Own folder, as in 0001, and no entry of any status points at it. Pending,
-- published and returned are all covered: a pending or returned entry is still
-- what a reviewer will look at.
--
-- The app's clean-ups all run once nothing points at the file any more: a
-- replaced photo after the row has the new URL, a deleted entry's photo after
-- the row is gone, and a photo whose row failed to save. Those still work.
-- -----------------------------------------------------------------------------
alter policy "contributors can delete photos in their own folder"
  on storage.objects
  using (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.photo_in_use(name)
  );


-- -----------------------------------------------------------------------------
-- 4. No uploading under a name an entry already uses.
--
-- Section 3 stops the file being deleted, but a file can also be missing for
-- other reasons: removed before this migration, removed in the dashboard, or
-- never uploaded (the URL check in 0002 tests the URL's shape, not that the
-- file exists). Uploading under that name would put new bytes behind a URL an
-- entry already shows. A Storage `copy` is an insert at its destination, so
-- this covers copying onto that name too.
--
-- Every upload from the app uses a fresh uuid name, which nothing uses yet.
-- -----------------------------------------------------------------------------
alter policy "contributors can upload photos to their own folder"
  on storage.objects
  with check (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.photo_in_use(name)
  );

-- "entry photos are readable by everyone" (0001) is not touched: published
-- entries' photos still load for visitors.
