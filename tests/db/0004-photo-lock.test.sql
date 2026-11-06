-- =============================================================================
-- Photos in use are locked after migration 0004 (review finding H1), tested as
-- an anonymous visitor, contributors A and B, and reviewer R.
--
-- Runs after 0003-review-gate.test.sql, on the rows and accounts that file
-- left behind, and switches identity the same way: `request.jwt.claims` for
-- auth.uid(), then `set local role`, then tests.acting_as().
--
-- These run at the SQL layer, as statements on storage.objects. The Storage
-- API turns each operation into one of them: upload is an INSERT, upload with
-- upsert an INSERT ... ON CONFLICT DO UPDATE, update and move an UPDATE, copy
-- an INSERT at the destination, remove a DELETE. The API itself is not here.
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set A '11111111-1111-4111-8111-111111111111'
\set B '22222222-2222-4222-8222-222222222222'
\set R '33333333-3333-4333-8333-333333333333'
\set ON_ERROR_STOP on

-- Files in A's folder, uuid-named as lib/photos.ts names them.
\set X    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000001.jpg'
\set Y    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000002.jpg'
\set W    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000003.jpg'
\set Z    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000004.jpg'
\set P    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000005.jpg'
\set M    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000006.jpg'
\set Q    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000007.jpg'
\set BASE 'https://test-project.supabase.co/storage/v1/object/public/entry-photos/'


\echo '# 0. 0004 left every existing row exactly as it was'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0004:%') > 0
  and (select count(*) from tests.snapshots where label like 'before 0004:%') = (select count(*) from public.entries)
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0004:%'
      and s.hash is distinct from (
        select md5(e::text) from public.entries e where 'before 0004:' || e.id = s.label
      )
  ),
  'the same entries exist before and after 0004, byte-for-byte unchanged'
);


\echo '# 1. Uploading a new photo, and submitting an entry with it, still work'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'X')) = 1,
  'A uploads a new photo to A''s own folder'
);
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'A', 'នំគម', 'Num Kom (0004 test entry by A)', 'Dara', 'Pchum Ben', '[TEST] Entry whose photo is locked.', :'BASE' || :'X')
  returning id
)
insert into tests.ids (label, id) select 'locked_entry', id from created;
select tests.ok(
  (select status from public.entries where id = tests.id('locked_entry')) = 'pending',
  'A submits an entry pointing at it, and it waits for review'
);
commit;

-- R approves it, through the only door 0003 gives a reviewer. 0003's tests
-- end with R removed, so the founder adds R back, as the table owner.
insert into public.reviewers (user_id) values (:'R') on conflict do nothing;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.review_entry(tests.id('locked_entry'), 'published'), 'R publishes A''s entry');
commit;

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.ok(
  (select count(*) from public.entries where id = tests.id('locked_entry')) = 1
  and (select count(*) from storage.objects where bucket_id = 'entry-photos' and name = :'X') = 1,
  'a visitor sees the published entry and can read its photo'
);
commit;


\echo '# 2. H1: A tries to change the photo of A''s own approved entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');

select tests.ok(
  tests.affected(format($q$update storage.objects set metadata = '{"replaced": true}' where name = %L$q$, :'X')) = 0,
  'overwrite in place (Storage update): changes nothing'
);
select tests.throws(
  format(
    $q$insert into storage.objects (bucket_id, name, metadata) values ('entry-photos', %L, '{"replaced": true}')
       on conflict (bucket_id, name) do update set metadata = excluded.metadata$q$,
    :'X'
  ),
  '42501', 'overwrite by upload with upsert: refused'
);
select tests.ok(
  tests.affected(format($q$update storage.objects set name = %L where name = %L$q$, :'Y', :'X')) = 0,
  'move the approved photo away to another name: changes nothing'
);
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'Y')) = 1
  and tests.affected(format($q$update storage.objects set name = %L where name = %L$q$, :'X', :'Y')) = 0,
  'move a different file onto the approved photo''s name: changes nothing'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'X')) = 0,
  'delete the approved photo: deletes nothing'
);
commit;

-- Delete then re-upload, in one go. The delete removes nothing, so the upload
-- collides with the file still there.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format(
    $q$with gone as (delete from storage.objects where name = %1$L returning 1)
       insert into storage.objects (bucket_id, name, metadata) values ('entry-photos', %1$L, '{"replaced": true}')$q$,
    :'X'
  ),
  '42501', 'delete then re-upload under the same name: refused'
);
commit;

select tests.ok(
  (select count(*) from storage.objects where name = :'X' and metadata is null) = 1
  and (select photo_url from public.entries where id = tests.id('locked_entry')) = :'BASE' || :'X'
  and (select status from public.entries where id = tests.id('locked_entry')) = 'published',
  'read-back: the approved photo is still there, unchanged, and the entry still points at it'
);


\echo '# 3. The lock holds for every status, not only published'

-- Statuses set by the table owner, standing in for review_entry() and A's
-- own edit, so the same row and file are tested under each.
update public.entries set status = 'pending' where id = tests.id('locked_entry');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'X')) = 0
  and tests.affected(format($q$update storage.objects set metadata = '{}' where name = %L$q$, :'X')) = 0,
  'pending: A cannot delete or overwrite the photo'
);
commit;

update public.entries set status = 'returned' where id = tests.id('locked_entry');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'X')) = 0
  and tests.affected(format($q$update storage.objects set metadata = '{}' where name = %L$q$, :'X')) = 0,
  'returned: A cannot delete or overwrite the photo'
);
commit;

update public.entries set status = 'published' where id = tests.id('locked_entry');


\echo '# 4. A name an entry uses cannot be uploaded to, even when its file is missing'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
-- 0002 checks the URL's shape, not that the file exists, so this row is valid.
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'A', 'នំ', 'Num (0004 test entry with a missing file)', 'Dara', 'x', '[TEST] Points at a file never uploaded.', :'BASE' || :'M')
  returning id
)
insert into tests.ids (label, id) select 'missing_file_entry', id from created;
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'M'),
  '42501', 'upload (or copy) into the name of an entry''s missing photo: refused'
);
commit;


\echo '# 5. Photos nothing points at can still be cleaned up'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'Z')) = 1
  and tests.affected(format($q$delete from storage.objects where name = %L$q$, :'Z')) = 1,
  'a photo whose entry failed to save: A uploads it and removes it again'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'Y')) = 1,
  'a stray photo nothing points at: A removes it'
);
commit;

-- Replacing a photo, the way saveEntry() does: upload, point the row at it,
-- then remove the old one.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'W')) = 1,
  'edit: A uploads the replacement photo'
);
select tests.ok(
  tests.affected(format(
    $q$update public.entries set photo_url = %L, status = 'pending' where id = %L$q$,
    :'BASE' || :'W', tests.id('locked_entry')
  )) = 1,
  'edit: A points the entry at it, which sends the entry back for review'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'X')) = 1,
  'edit: the old photo, now unused, is removed'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'W')) = 0,
  'edit: the new photo is now the one in use, so it is locked in turn'
);
commit;

-- Deleting an entry, the way removeEntry() does: the row, then its photo.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'P')) = 1,
  'entry delete: A uploads a photo'
);
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'A', 'នំ', 'Num (0004 test entry to delete)', 'Dara', 'x', '[TEST] Deleted with its photo.', :'BASE' || :'P')
  returning id
)
insert into tests.ids (label, id) select 'deleted_entry', id from created;
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'P')) = 0,
  'entry delete: while the entry exists, its photo is locked'
);
select tests.ok(
  tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('deleted_entry'))) = 1
  and tests.affected(format($q$delete from storage.objects where name = %L$q$, :'P')) = 1,
  'entry delete: once the row is gone, its photo is removed'
);
commit;


\echo '# 6. B still cannot touch A''s photos'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'Q')) = 1,
  'A uploads a photo nothing points at'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'Q')) = 0
  and tests.affected(format($q$delete from storage.objects where name = %L$q$, :'W')) = 0,
  'B cannot delete A''s photos, whether in use or not'
);
select tests.ok(
  tests.affected(format($q$update storage.objects set metadata = '{}' where name = %L$q$, :'Q')) = 0
  and tests.affected(format($q$update storage.objects set name = %L where name = %L$q$, :'B' || '/stolen.jpg', :'W')) = 0,
  'B cannot overwrite or move A''s photos'
);
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'A' || '/b-was-here.jpg'),
  '42501', 'B cannot upload into A''s folder'
);
select tests.throws(
  format(
    $q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)
       on conflict (bucket_id, name) do update set metadata = '{}'$q$,
    :'Q'
  ),
  '42501', 'B cannot upsert over A''s photo'
);
commit;

select tests.ok(
  (select count(*) from storage.objects where name in (:'Q', :'W') and metadata is null) = 2,
  'read-back: both of A''s photos are still there, unchanged'
);


\echo '# 7. Visitors'

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.ok(
  (select count(*) from storage.objects where bucket_id = 'entry-photos') > 0,
  'a visitor can still read photos'
);
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, 'anon/x.jpg'),
  '42501', 'a visitor still cannot upload'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'Q')) = 0,
  'a visitor still cannot delete'
);
commit;


\echo '# 8. The rules, as written'

select tests.ok(
  not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and cmd in ('UPDATE', 'ALL')),
  'there is no UPDATE policy on storage.objects'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects') = 3,
  'storage.objects has exactly three policies: read, upload, delete'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and ((cmd = 'INSERT' and with_check like '%auth.uid()%' and with_check like '%photo_in_use(name)%')
       or (cmd = 'DELETE' and qual like '%auth.uid()%' and qual like '%photo_in_use(name)%'))) = 2,
  'upload and delete both keep the own-folder check and add the in-use check'
);
select tests.ok(
  (select prosecdef and proconfig = array['search_path=""'] from pg_proc where oid = 'public.photo_in_use(text)'::regprocedure),
  'photo_in_use() is SECURITY DEFINER with search_path pinned to empty'
);
select tests.ok(
  not has_function_privilege('anon', 'public.photo_in_use(text)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.photo_in_use(text)', 'EXECUTE'),
  'photo_in_use(): signed-in users only'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 6,
  'the six policies on entries are 0003''s, none added or removed'
);


\echo '# Not verified here — the Storage API service is not in this environment.'
\echo '# Which SQL statement each Storage operation sends is taken from Supabase''s'
\echo '# access-control documentation. The live check after rollout: as a contributor,'
\echo '# try update, upload with upsert, move and remove on the photo of a published'
\echo '# entry, and expect each to be refused.'
