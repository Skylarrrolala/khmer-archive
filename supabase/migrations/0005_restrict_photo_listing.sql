-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0005: nobody can list the photo bucket but a file's own contributor.
--
-- Review finding M1. 0001's "entry photos are readable by everyone" lets anyone,
-- signed in or not, read every row of storage.objects in the bucket. Storage's
-- `list()` is exactly that read, so one request returned every file name:
--   * photos of pending and returned entries, which 0003 hides from the public;
--   * files no entry points at any more;
--   * every contributor's user id, since each folder is named after one.
-- Nothing in 0002, 0003 or 0004 changed it.
--
-- The archive never needs that read to show a photo. The bucket is public
-- (0001), so a photo's public URL, /storage/v1/object/public/entry-photos/...,
-- is served by Storage without consulting any SELECT policy, and the app only
-- ever builds those URLs (lib/photos.ts, getPublicUrl, which makes no request).
--
-- What does need it is the contributor's own clean-up. Removing a file is a
-- DELETE that first has to see the row, and Storage reads back what it removed.
-- So the read stays, for signed-in users, on their own folder only.
--
-- Unchanged: the bucket stays public, upload and delete keep 0004's rules, and
-- no row or file is changed.
--
-- tests/db/0005-photo-listing.test.sql exercises every rule below.
-- =============================================================================


drop policy "entry photos are readable by everyone" on storage.objects;

-- The same own-folder test as upload and delete (0001, 0004). A visitor has no
-- SELECT policy at all, so listing the bucket returns nothing; contributor B
-- listing returns only B's files.
create policy "contributors can read photos in their own folder"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
