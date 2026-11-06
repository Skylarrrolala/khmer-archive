-- =============================================================================
-- Contributor limits after migration 0006 (review finding M3).
--
-- Runs after 0005-photo-listing.test.sql. Each limit gets a fresh account of
-- its own, so its counts start at zero whatever earlier files left behind:
--   C  pending entries          F  files uploaded in the last 24 h
--   D  upload claims            G  two connections racing for entry 5
--   E  unused photos            H  two connections racing for claim 20
-- B, from 0002, stands for "someone else".
--
-- Sections 1-5 switch identity the way the earlier files do. Section 6 opens
-- two more connections with dblink, so two transactions really are in flight
-- at once, and checks that the second one waits for the first and then counts
-- what it committed.
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set B '22222222-2222-4222-8222-222222222222'
\set C '44444444-4444-4444-8444-444444444444'
\set D '55555555-5555-4555-8555-555555555555'
\set E '66666666-6666-4666-8666-666666666666'
\set F '77777777-7777-4777-8777-777777777777'
\set G '88888888-8888-4888-8888-888888888888'
\set H '99999999-9999-4999-8999-999999999999'
\set E1   '66666666-6666-4666-8666-666666666666/66666666-0000-4000-8000-000000000001.jpg'
\set BASE 'https://test-project.supabase.co/storage/v1/object/public/entry-photos/'
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  (:'C', 'contributor-c@test.invalid'), (:'D', 'contributor-d@test.invalid'),
  (:'E', 'contributor-e@test.invalid'), (:'F', 'contributor-f@test.invalid'),
  (:'G', 'contributor-g@test.invalid'), (:'H', 'contributor-h@test.invalid');

-- Counting helpers are VOLATILE so they see rows written earlier in the same
-- statement: a STABLE function reads the snapshot the outer query started with.

-- The statement a contributor sends to submit one entry, with a well-formed
-- photo URL in their own folder.
create function tests.submit_sql(owner uuid)
returns text
language sql
volatile
as $$
  select format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
       values (%L, 'នំ', 'Num (0006 limit test)', 'Dara', 'x', '[TEST] Limit test entry.', %L)$q$,
    owner, tests.photo_for(owner)
  )
$$;

-- Reads the log as its owner: no API role may read it (section 2 checks that).
create function tests.claims(owner uuid)
returns bigint
language sql
volatile
security definer
as $$ select count(*) from public.photo_upload_claims where user_id = owner $$;

create function tests.pending(owner uuid)
returns bigint
language sql
volatile
as $$ select count(*) from public.entries where contributor_id = owner and status = 'pending' $$;


\echo '# 0. 0006 changed no entry and no file'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0006:%') = (select count(*) from public.entries)
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0006:%'
      and s.hash is distinct from (select md5(e::text) from public.entries e where 'before 0006:' || e.id = s.label)
  ),
  'every entry is byte-for-byte unchanged'
);
select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0006 file:%') = (select count(*) from storage.objects)
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0006 file:%'
      and s.hash is distinct from (select md5(o::text) from storage.objects o where 'before 0006 file:' || o.id = s.label)
  ),
  'every stored file is byte-for-byte unchanged'
);


\echo '# 1. Five pending entries (C)'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'C', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'C');
select tests.ok(
  (select sum(tests.affected(tests.submit_sql(:'C'))) from generate_series(1, 5)) = 5
  and tests.pending(:'C') = 5,
  'C submits five entries'
);
select tests.throws(tests.submit_sql(:'C'), 'KA001', 'a sixth is refused with KA001');
select tests.ok(tests.pending(:'C') = 5, 'read-back: still five');
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(tests.affected(tests.submit_sql(:'B')) = 1, 'B can still submit while C is at the limit');
commit;

-- A reviewer publishes one of C's five, as the table owner.
update public.entries set status = 'published'
where id = (select id from public.entries where contributor_id = :'C' order by created_at, id limit 1);

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'C', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'C');
select tests.ok(
  tests.pending(:'C') = 4 and tests.affected(tests.submit_sql(:'C')) = 1,
  'once one is published, C can submit again'
);
select tests.ok(
  tests.affected(format(
    $q$update public.entries set description = '[TEST] Edited.', status = 'pending' where id = %L$q$,
    (select id from public.entries where contributor_id = '44444444-4444-4444-8444-444444444444' and status = 'published' limit 1)
  )) = 1
  and tests.pending(:'C') = 6,
  'editing the published one sends it back to pending even past five: edits are not limited'
);
select tests.throws(tests.submit_sql(:'C'), 'KA001', 'a new entry is still refused');
select tests.ok(
  tests.affected(format(
    $q$delete from public.entries where id in (
         select id from public.entries where contributor_id = %L and status = 'pending' limit 2)$q$,
    :'C'
  )) = 2,
  'C deletes two pending entries'
);
select tests.ok(tests.affected(tests.submit_sql(:'C')) = 1, 'which frees a place: C can submit again');
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'C', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'C');
select tests.throws(
  'select public.claim_photo_upload(true)', 'KA001',
  'at the limit, claiming an upload for a new entry is refused before any photo is sent'
);
select tests.ok(tests.claims(:'C') = 0, 'and that refusal recorded nothing');
select tests.ok(
  tests.affected('select public.claim_photo_upload(false)') = 1 and tests.claims(:'C') = 1,
  'claiming an upload for an edit is still allowed, and recorded once'
);
commit;


\echo '# 2. Twenty uploads per rolling 24 hours, counted once each (D)'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'D', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'D');
select tests.ok(
  tests.affected('select public.claim_photo_upload(true)') = 1 and tests.claims(:'D') = 1,
  'one claim, one row'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'D', 'role', 'authenticated')::text, true);
set local role authenticated;
select public.claim_photo_upload(true);
rollback;

select tests.ok(tests.claims(:'D') = 1, 'a claim whose transaction rolled back left no row');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'D', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'D');
select tests.ok(
  (select count(*) from generate_series(2, 20) as n, lateral (select public.claim_photo_upload(n % 2 = 0)) as c) = 19
  and tests.claims(:'D') = 20,
  'D claims nineteen more: twenty in all'
);
select tests.throws('select public.claim_photo_upload(false)', 'KA002', 'the twenty-first is refused with KA002');
select tests.throws('select public.claim_photo_upload(true)', 'KA002', 'whether for a new entry or an edit');
select tests.ok(tests.claims(:'D') = 20, 'and the refusals recorded nothing');
select tests.throws('select * from public.photo_upload_claims', '42501', 'D cannot read the log');
select tests.throws(format($q$delete from public.photo_upload_claims where user_id = %L$q$, :'D'), '42501', 'or delete from it');
select tests.throws(format($q$insert into public.photo_upload_claims (user_id) values (%L)$q$, :'D'), '42501', 'or write to it');
commit;

-- A day passes for one claim.
update public.photo_upload_claims set claimed_at = now() - interval '25 hours'
where ctid = (select ctid from public.photo_upload_claims where user_id = :'D' limit 1);

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'D', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'D');
select tests.ok(
  tests.affected('select public.claim_photo_upload(false)') = 1,
  'a claim older than 24 hours no longer counts: the window rolls'
);
select tests.throws('select public.claim_photo_upload(false)', 'KA002', 'and the next is refused again');
commit;

begin;
set local role anon;
select tests.throws('select public.claim_photo_upload(false)', '42501', 'a visitor cannot claim at all');
commit;


\echo '# 3. Ten unused photos (E)'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'E', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'E');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'E1')) = 1
  and (select sum(tests.affected(format(
        $q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$,
        format('%s/%s.jpg', '66666666-6666-4666-8666-666666666666', gen_random_uuid())
      ))) from generate_series(2, 10)) = 9,
  'E uploads ten photos straight to Storage, attached to nothing'
);
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'E' || '/eleventh.jpg'),
  '42501', 'an eleventh straight to Storage is refused by the upload policy'
);
select tests.throws('select public.claim_photo_upload(false)', 'KA003', 'and through the app, with KA003');
select tests.ok(tests.claims(:'E') = 0, 'the refusal recorded nothing');
select tests.ok(
  tests.affected(format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
       values (%L, 'នំ', 'Num (0006 limit test)', 'Dara', 'x', '[TEST] Uses one of E''s photos.', %L)$q$,
    :'E', :'BASE' || :'E1'
  )) = 1
  and tests.affected('select public.claim_photo_upload(false)') = 1,
  'once an entry uses one of them, E can claim an upload again'
);
select tests.ok(
  tests.affected(format(
    $q$delete from storage.objects where name = (
         select name from storage.objects where name like %L and name <> %L limit 1)$q$,
    :'E' || '/%', :'E1'
  )) = 1,
  'and E can still remove an unused photo'
);
commit;


\echo '# 4. Uploads straight to Storage: at most twenty files from the last 24 hours (F)'

-- Twenty of F's files, each used by a published entry, all from today: none
-- unused, so only the 24-hour count can refuse. Set up as the table owner.
insert into storage.objects (bucket_id, name)
select 'entry-photos', format('%s/77777777-0000-4000-8000-%s.jpg', :'F', lpad(n::text, 12, '0'))
from generate_series(1, 20) as n;
insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url, status)
select :'F', 'នំ', 'Num (0006 limit test)', 'Dara', 'x', '[TEST] Uses one of F''s photos.',
       :'BASE' || format('%s/77777777-0000-4000-8000-%s.jpg', :'F', lpad(n::text, 12, '0')), 'published'
from generate_series(1, 20) as n;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'F', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'F');
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'F' || '/twenty-first.jpg'),
  '42501', 'with twenty files from today, another straight to Storage is refused'
);
commit;

update storage.objects set created_at = now() - interval '25 hours'
where name = format('%s/77777777-0000-4000-8000-%s.jpg', :'F', lpad('1', 12, '0'));

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'F', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'F');
select tests.ok(
  tests.affected(format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'F' || '/next-day.jpg')) = 1,
  'once one of them is older than 24 hours, the upload is allowed'
);
commit;


\echo '# 5. The app''s path is never refused by the best-effort check'

-- Ten claims, each followed by the upload it allowed, the way lib/photos.ts
-- does it: claim, then insert the file. All ten must pass the upload policy.
create function tests.claim_then_upload(owner uuid)
returns bigint
language plpgsql
as $$
begin
  perform public.claim_photo_upload(false);
  return tests.affected(format(
    $q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$,
    format('%s/%s.jpg', owner, gen_random_uuid())
  ));
end
$$;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'H', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'H');
select tests.ok(
  (select sum(tests.claim_then_upload(:'H')) from generate_series(1, 10)) = 10,
  'ten claims, ten uploads: every upload the app claimed is accepted'
);
select tests.throws('select public.claim_photo_upload(false)', 'KA003', 'and the eleventh claim is refused before any upload');
commit;

-- Clear H's ten files and claims, as the table owner, for the race below.
delete from storage.objects where name like :'H' || '/%';
delete from public.photo_upload_claims where user_id = :'H';


\echo '# 6. Two requests at once (two more connections, through dblink)'

create extension if not exists dblink;

create function tests.connect(conn text, who uuid)
returns void
language plpgsql
as $$
begin
  perform dblink_connect(conn, format(
    'host=%s port=%s dbname=%s user=%s',
    split_part(current_setting('unix_socket_directories'), ',', 1),
    current_setting('port'), current_database(), current_user
  ));
  perform dblink_exec(conn, format(
    'set request.jwt.claims = %L',
    json_build_object('sub', who, 'role', 'authenticated')::text
  ));
  perform dblink_exec(conn, 'set role authenticated');
end
$$;

-- Starts `sql` on `conn` without waiting, gives it 0.5 s, and reports whether
-- it is still running: blocked behind the other connection's lock.
create function tests.still_waiting(conn text, sql text)
returns boolean
language plpgsql
as $$
begin
  perform dblink_send_query(conn, sql);
  perform pg_sleep(0.5);
  return dblink_is_busy(conn) = 1;
end
$$;

-- Collects the result of a query sent with dblink_send_query: 'ok', or the
-- error it ended with.
create function tests.outcome(conn text)
returns text
language plpgsql
as $$
declare
  failed text;
begin
  perform * from dblink_get_result(conn, false) as t(result text);
  failed := dblink_error_message(conn);
  perform * from dblink_get_result(conn, false) as t(result text);
  return case when failed = 'OK' then 'ok' else failed end;
end
$$;

-- G has four pending entries; set up as the table owner.
insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
select :'G', 'នំ', 'Num (0006 race test)', 'Dara', 'x', '[TEST] Race test entry.', tests.photo_for(:'G')
from generate_series(1, 4);

select tests.connect('one', :'G');
select tests.connect('two', :'G');
select tests.ok(
  (select who from dblink('one', 'select current_user::text || '' '' || auth.uid()::text') as t(who text))
    = 'authenticated ' || :'G',
  'both connections act as G through RLS, not as the table owner'
);
select dblink_exec('one', 'begin');
select dblink_exec('two', 'begin');
select tests.ok(dblink_exec('one', tests.submit_sql(:'G')) = 'INSERT 0 1', 'connection one submits entry five, and has not committed');
select tests.ok(
  tests.still_waiting('two', tests.submit_sql(:'G')),
  'connection two, submitting entry six at the same moment, waits for connection one'
);
select dblink_exec('one', 'commit');
select tests.ok(
  tests.outcome('two') like '%pending entry limit reached%',
  'once connection one commits, connection two counts its entry and is refused'
);
select dblink_exec('two', 'rollback');
select tests.ok(tests.pending(:'G') = 5, 'read-back: G has five pending entries, not six');

-- H has nineteen claims from today.
insert into public.photo_upload_claims (user_id) select :'H' from generate_series(1, 19);

select tests.connect('three', :'H');
select tests.connect('four', :'H');
select dblink_exec('three', 'begin');
select dblink_exec('four', 'begin');
select * from dblink('three', 'select public.claim_photo_upload(false)::text') as t(result text);
select tests.ok(
  tests.still_waiting('four', 'select public.claim_photo_upload(false)'),
  'two claims for H at once: the second waits for the first'
);
select dblink_exec('three', 'commit');
select tests.ok(tests.outcome('four') like '%daily upload limit reached%', 'and is refused once the first, the twentieth, commits');
select dblink_exec('four', 'rollback');
select tests.ok(tests.claims(:'H') = 20, 'read-back: twenty claims, not twenty-one');

-- The same race, but the first request fails and rolls back.
delete from public.photo_upload_claims where ctid = (select ctid from public.photo_upload_claims where user_id = :'H' limit 1);
select dblink_exec('three', 'begin');
select dblink_exec('four', 'begin');
select * from dblink('three', 'select public.claim_photo_upload(false)::text') as t(result text);
select tests.ok(tests.still_waiting('four', 'select public.claim_photo_upload(false)'), 'again the second waits');
select dblink_exec('three', 'rollback');
select tests.ok(tests.outcome('four') = 'ok', 'the first rolls back, so the second takes the twentieth place');
select dblink_exec('four', 'commit');
select tests.ok(tests.claims(:'H') = 20, 'read-back: twenty claims; the rolled-back one left nothing');

-- Another user is never held up by H's lock: C claims while H holds it.
select tests.connect('five', :'C');
select dblink_exec('three', 'begin');
select * from dblink('three', 'select pg_advisory_xact_lock(hashtextextended(''khmer-archive:limits:'' || auth.uid()::text, 0))::text') as t(result text);
select tests.ok(
  not tests.still_waiting('five', 'select public.claim_photo_upload(false)')
  and tests.outcome('five') = 'ok',
  'while H''s lock is held, C''s claim runs straight through'
);
select dblink_exec('three', 'rollback');

select dblink_disconnect(c) from unnest(array['one', 'two', 'three', 'four', 'five']) as c;


\echo '# 7. The rules, as written'

select tests.ok(
  (select relrowsecurity from pg_class where oid = 'public.photo_upload_claims'::regclass)
  and not has_table_privilege('anon', 'public.photo_upload_claims', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
  and not has_table_privilege('authenticated', 'public.photo_upload_claims', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'),
  'the upload log: RLS on, and no privilege at all for either API role'
);
select tests.ok(
  (select bool_and(prosecdef and proconfig = array['search_path=""']) from pg_proc
   where oid in ('public.limits_lock(uuid)'::regprocedure, 'public.pending_entry_count(uuid)'::regprocedure,
                 'public.unused_photo_count(uuid)'::regprocedure, 'public.check_entry_limit()'::regprocedure,
                 'public.claim_photo_upload(boolean)'::regprocedure, 'public.photo_upload_allowed()'::regprocedure)),
  'all six functions are SECURITY DEFINER with search_path pinned to empty'
);
select tests.ok(
  not has_function_privilege('authenticated', 'public.limits_lock(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.pending_entry_count(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.unused_photo_count(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.unused_photo_count(uuid)', 'EXECUTE'),
  'the helpers that take a user id cannot be called through the API, so nobody can count someone else''s'
);
select tests.ok(
  has_function_privilege('authenticated', 'public.claim_photo_upload(boolean)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.check_entry_limit()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.photo_upload_allowed()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.claim_photo_upload(boolean)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.check_entry_limit()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.photo_upload_allowed()', 'EXECUTE'),
  'the three the policies and the app call: signed-in users only'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'INSERT'
     and with_check like '%auth.uid() = contributor_id%'
     and with_check like '%status = ''pending''%'
     and with_check like '%photo_url IS NOT NULL%'
     and with_check like '%check_entry_limit()%') = 1,
  'the entries insert policy keeps 0003''s three rules and adds the limit'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'storage' and tablename = 'objects' and cmd = 'INSERT'
     and with_check like '%foldername(name)%' and with_check like '%auth.uid()%'
     and with_check like '%photo_in_use(name)%' and with_check like '%photo_upload_allowed()%') = 1,
  'the upload policy keeps the own-folder and in-use rules and adds the limits'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 6
  and (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects') = 3
  and not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and cmd in ('UPDATE', 'ALL')),
  'still six policies on entries and three on storage.objects, and still no UPDATE on storage'
);


\echo '# Not verified here — Supabase''s Storage service and PostgREST are not in this'
\echo '# environment. The live checks after rollout: an upload through the app adds'
\echo '# exactly one row to photo_upload_claims; uploads straight to Storage past the'
\echo '# limits are refused; a limit refusal reaches the app as KA001, KA002 or KA003.'
