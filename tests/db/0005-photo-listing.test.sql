-- =============================================================================
-- Listing the photo bucket after migration 0005 (review finding M1), tested as
-- an anonymous visitor, contributors A and B, and reviewer R.
--
-- Runs after 0004-photo-lock.test.sql, on the rows, files and accounts that
-- file left behind, and switches identity the same way.
--
-- Storage's `list()` is a SELECT on storage.objects, so "who can list" is
-- "whose SELECT returns rows". Fetching a photo by its public URL is not tested
-- here: Storage serves a public bucket's files without a SELECT policy, and the
-- Storage service is not in this environment.
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set A '11111111-1111-4111-8111-111111111111'
\set B '22222222-2222-4222-8222-222222222222'
\set R '33333333-3333-4333-8333-333333333333'
\set ON_ERROR_STOP on

-- Files in A's folder: W is in use (0004's tests), Q is not.
\set W    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000003.jpg'
\set Q    '11111111-1111-4111-8111-111111111111/44444444-0000-4000-8000-000000000007.jpg'
\set V    '11111111-1111-4111-8111-111111111111/55555555-0000-4000-8000-000000000001.jpg'
\set T    '11111111-1111-4111-8111-111111111111/55555555-0000-4000-8000-000000000002.jpg'
\set BF   '22222222-2222-4222-8222-222222222222/55555555-0000-4000-8000-000000000003.jpg'
\set BASE 'https://test-project.supabase.co/storage/v1/object/public/entry-photos/'


\echo '# 0. 0005 changed no entry and no file'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0005:%') = (select count(*) from public.entries)
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0005:%'
      and s.hash is distinct from (select md5(e::text) from public.entries e where 'before 0005:' || e.id = s.label)
  ),
  'every entry is byte-for-byte unchanged'
);
select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0005 file:%') = (select count(*) from storage.objects)
  and (select count(*) from storage.objects) > 0
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0005 file:%'
      and s.hash is distinct from (select md5(o::text) from storage.objects o where 'before 0005 file:' || o.id = s.label)
  ),
  'every stored file is byte-for-byte unchanged'
);
select tests.ok(
  (select public from storage.buckets where id = 'entry-photos'),
  'the bucket is still public, so public photo URLs are still served'
);


\echo '# 1. Set-up: B stores a file; A has a published entry with a photo'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'BF')) = 1,
  'B uploads a photo to B''s own folder'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
-- With RETURNING, as Storage reads back what it stored: the new row must also
-- pass a SELECT policy, so this fails if A could not read A's own folder.
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L) returning name$q$, :'V')) = 1,
  'A uploads a new photo, and reads back the stored row'
);
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'A', 'នំ', 'Num (0005 test entry by A)', 'Dara', 'x', '[TEST] Published entry with a stored photo.', :'BASE' || :'V')
  returning id
)
insert into tests.ids (label, id) select 'listing_entry', id from created;
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.review_entry(tests.id('listing_entry'), 'published'), 'R publishes it');
commit;


\echo '# 2. M1: a visitor tries to list the bucket'

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.ok(
  (select count(*) from storage.objects) = 0,
  'listing the whole bucket returns nothing'
);
select tests.ok(
  (select count(*) from storage.objects where name like :'A' || '/%') = 0
  and (select count(*) from storage.objects where name = :'Q') = 0,
  'listing A''s folder, or asking for one file by name, returns nothing'
);
select tests.ok(
  (select photo_url from public.entries where id = tests.id('listing_entry')) = :'BASE' || :'V',
  'the published entry, and the public URL of its photo, are still readable'
);
select tests.ok(
  (select count(*) from public.entries where id = tests.id('locked_entry')) = 0,
  'A''s pending entry is still hidden, and now so is its photo''s name'
);
commit;


\echo '# 3. Contributors list their own folder and nobody else''s'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  (select count(*) from storage.objects where name in (:'W', :'Q', :'V')) = 3,
  'A sees A''s own files, in use or not'
);
select tests.ok(
  not exists (select 1 from storage.objects where (storage.foldername(name))[1] <> :'A'),
  'everything A can list is in A''s folder'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  (select count(*) from storage.objects where name like :'A' || '/%') = 0,
  'B cannot list A''s folder'
);
select tests.ok(
  (select count(*) from storage.objects) = 1
  and (select name from storage.objects) = :'BF',
  'B lists exactly B''s own file'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(
  (select count(*) from storage.objects) = 0,
  'a reviewer cannot list contributors'' folders either'
);
commit;


\echo '# 4. Upload, clean-up and the 0004 lock still work'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'T')) = 1,
  'A uploads a photo'
);
-- With RETURNING, as Storage's remove() reads back what it deleted.
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L returning name$q$, :'T')) = 1
  and tests.affected(format($q$delete from storage.objects where name = %L returning name$q$, :'Q')) = 1,
  'A removes unused photos, a fresh one and an older one'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L returning name$q$, :'W')) = 0
  and tests.affected(format($q$delete from storage.objects where name = %L returning name$q$, :'V')) = 0,
  'A still cannot remove a photo an entry uses, pending or published'
);
select tests.ok(
  tests.affected(format($q$update storage.objects set metadata = '{}' where name = %L$q$, :'V')) = 0,
  'A still cannot overwrite a photo an entry uses'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'V')) = 0
  and tests.affected(format($q$update storage.objects set name = %L where name = %L$q$, :'B' || '/stolen.jpg', :'V')) = 0,
  'B still cannot remove or move A''s photo'
);
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'A' || '/b-was-here.jpg'),
  '42501', 'B still cannot upload into A''s folder'
);
commit;

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.throws(
  $q$insert into storage.objects (bucket_id, name) values ('entry-photos', 'anon/x.jpg')$q$,
  '42501', 'a visitor still cannot upload'
);
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'V')) = 0,
  'a visitor still cannot delete'
);
commit;

select tests.ok(
  (select count(*) from storage.objects where name in (:'W', :'V', :'BF') and metadata is null) = 3
  and (select count(*) from storage.objects where name in (:'T', :'Q')) = 0,
  'read-back: the files in use and B''s file are there, unchanged; the removed ones are gone'
);


\echo '# 5. The rules, as written'

select tests.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (roles && array['anon', 'public']::name[])
  ),
  'no policy on storage.objects applies to visitors'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'storage' and tablename = 'objects' and cmd = 'SELECT'
     and roles = array['authenticated']::name[]
     and qual like '%foldername(name)%' and qual like '%auth.uid()%') = 1
  and (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and cmd = 'SELECT') = 1,
  'one SELECT policy on storage.objects: signed-in users, own folder only'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects') = 3
  and not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and cmd in ('UPDATE', 'ALL'))
  and (select count(*) from pg_policies
       where schemaname = 'storage' and tablename = 'objects'
         and ((cmd = 'INSERT' and with_check like '%photo_in_use(name)%')
           or (cmd = 'DELETE' and qual like '%photo_in_use(name)%'))) = 2,
  'still three policies: read, upload and delete; 0004''s upload and delete rules untouched; no UPDATE'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 6,
  'the six policies on entries are unchanged'
);


\echo '# Not verified here — the Storage service is not in this environment. The'
\echo '# live check after rollout: as a visitor, list() the bucket and get nothing;'
\echo '# open a published entry and see its photo; as a contributor, remove() an'
\echo '# unused photo of their own and see it go.'
