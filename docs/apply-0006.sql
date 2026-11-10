-- PERMANENT SQL FOR REVIEW. Execute only after explicit owner approval and a verified backup.
-- Target: production welzetyikwoggygaushf, PostgreSQL 17; migration 0006 ONLY.
-- 0004-0007 bodies are exact committed 14a5c29 files; 0008 adds only the tested sequence revoke.
-- Run the COMPLETE file in one fresh postgres session. On error: ROLLBACK and STOP.
-- After COMMIT, run docs/verify-rollout.sql separately; never proceed on a failed check.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '60s';
SET LOCAL idle_in_transaction_session_timeout = '30s';
SET LOCAL transaction_timeout = '120s';

DO $preflight$
begin
  if current_setting('server_version_num')::integer / 10000 <> 17 or current_user <> 'postgres'
     or row_security_active('public.entries'::regclass)
     or row_security_active('public.reviewers'::regclass)
     or row_security_active('storage.objects'::regclass) then
    raise exception 'Wrong PostgreSQL version or execution role; stop without changing grants.';
  end if;
  if (select array_agg(version::text order by version) from supabase_migrations.schema_migrations)
       is distinct from array['0001','0002','0003','0004','0005']::text[] then
    raise exception 'Wrong migration history for 0006; never repair, skip or overwrite a version here.';
  end if;
end
$preflight$;

-- Compare the reviewed security catalog and the independently verified data baseline.
DO $before$
begin
  if md5((jsonb_build_object(
  'functions', (select jsonb_agg(jsonb_build_object(
    'signature', p.oid::regprocedure::text, 'definition_md5', md5(pg_get_functiondef(p.oid)),
    'owner', pg_get_userbyid(p.proowner), 'definer', p.prosecdef, 'settings', p.proconfig,
    'anon_execute', has_function_privilege('anon', p.oid, 'EXECUTE'),
    'authenticated_execute', has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    order by p.oid::regprocedure::text)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('is_reviewer','review_entry','photo_in_use','limits_lock','pending_entry_count',
       'unused_photo_count','check_entry_limit','claim_photo_upload','photo_upload_allowed','record_status_change')),
  'policies', (select jsonb_agg(to_jsonb(p) order by p.schemaname,p.tablename,p.policyname)
    from pg_policies p where (schemaname = 'public' and tablename in
      ('entries','reviewers','photo_upload_claims','review_history'))
      or (schemaname = 'storage' and tablename = 'objects')),
  'entry_triggers', (select jsonb_agg(jsonb_build_object('name',t.tgname,
    'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid)) order by t.tgname)
    from pg_trigger t where t.tgrelid = 'public.entries'::regclass and not t.tgisinternal),
  'relations', (select jsonb_agg(jsonb_build_object('name',c.relname,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
    'anon_grants',(select jsonb_object_agg(privilege,has_table_privilege('anon',c.oid,privilege))
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) privilege),
    'authenticated_grants',(select jsonb_object_agg(privilege,has_table_privilege('authenticated',c.oid,privilege))
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) privilege)) order by c.relname)
    from pg_class c where c.relnamespace = 'public'::regnamespace
    and c.relname in ('entries','reviewers','photo_upload_claims','review_history')),
  'sequence', (select jsonb_build_object('owner',pg_get_userbyid(c.relowner),
    'anon_grants',has_sequence_privilege('anon',c.oid,'SELECT,UPDATE,USAGE'),
    'authenticated_grants',has_sequence_privilege('authenticated',c.oid,'SELECT,UPDATE,USAGE'),
    'public_grants',exists(select 1 from aclexplode(coalesce(c.relacl,acldefault('S',c.relowner))) a where a.grantee = 0))
    from pg_class c where c.oid = to_regclass('public.review_history_id_seq')),
  'storage_relations',(select jsonb_agg(jsonb_build_object('name',c.relname,
    'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity) order by c.relname)
    from pg_class c where c.relnamespace = 'storage'::regnamespace and c.relname in ('objects','buckets')),
  'entry_columns', (select jsonb_agg(jsonb_build_object('column',a.attname,
    'anon_insert',has_column_privilege('anon',a.attrelid,a.attnum,'INSERT'),
    'anon_update',has_column_privilege('anon',a.attrelid,a.attnum,'UPDATE'),
    'authenticated_insert',has_column_privilege('authenticated',a.attrelid,a.attnum,'INSERT'),
    'authenticated_update',has_column_privilege('authenticated',a.attrelid,a.attnum,'UPDATE')) order by a.attnum)
    from pg_attribute a where a.attrelid = 'public.entries'::regclass and a.attnum > 0 and not a.attisdropped),
  'pending_default', (select pg_get_expr(d.adbin,d.adrelid) from pg_attrdef d
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where a.attrelid = 'public.entries'::regclass and a.attname = 'status'),
  'bucket', (select jsonb_build_object('public',public,'file_size_limit',file_size_limit,
    'allowed_mime_types',allowed_mime_types) from storage.buckets where id = 'entry-photos')
))::text) is distinct from '970e27762cb7b3f2dfe7e603ffdce0fc' then
    raise exception 'Pre-0006 security catalog differs from the reviewed predecessor. Stop and inspect.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Pre-0006 archive data changed since the approved baseline. Stop and inspect.';
  end if;
end
$before$;

-- BEGIN EXACT MIGRATION FILE: supabase/migrations/0006_contributor_limits.sql
-- SHA256: edf560f01f5e76d4534993040bceaa2c2cfb4faa3d5739c316705434af579bff
-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0006: how much one contributor can submit and upload.
--
-- Review finding M3. Nothing limited how many entries or photos one account
-- could send, through the app or straight to Supabase's API. Three limits, the
-- same for every signed-in account, reviewers included:
--
--   5   pending entries at a time      new entries only; an edit never counts
--   20  photo uploads per rolling 24 h
--   10  photos no entry uses
--
-- Where each is enforced, and how far that holds:
--
--   * Entries are written through PostgREST in an ordinary transaction, so
--     the entries insert policy can lock, count and refuse (section 3). That
--     holds when several requests arrive at once.
--
--   * Photo uploads are counted by claim_photo_upload() (section 4), which
--     the app calls before it processes a photo (lib/photos.ts). One call is
--     one row in photo_upload_claims, in its own transaction.
--
--   * An upload sent straight to the Storage API never calls it. Storage
--     runs this project's upload policy only as a probe that it rolls back,
--     then writes the row itself with policies off (supabase/storage,
--     src/storage/uploader.ts, read 6 Nov 2026). So the upload policy can
--     refuse, but it cannot record anything, and a lock taken inside it is
--     released before the real write. Section 5 is therefore best effort: it
--     stops uploads sent one after another, not a burst sent at once, and not
--     uploading and deleting in a loop. That path costs the app nothing: it
--     never reaches the image processing.
--
-- Refusals use their own error codes, so the app can say which limit:
--   KA001  pending entries     KA002  uploads in 24 h     KA003  unused photos
--
-- A request with no user id — the founder in the SQL editor — is not limited.
-- Nothing here changes a row or a file.
--
-- tests/db/0006-limits.test.sql exercises every rule below, including two
-- connections racing each other.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. The upload log.
--
-- One row per photo upload the app was allowed to start. Only the functions
-- below write it; no API role can read or write it. A row is never removed
-- when an upload later fails: the photo may already have been decoded by then,
-- and a refund would let someone run the decoder without limit.
-- -----------------------------------------------------------------------------
create table public.photo_upload_claims (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  claimed_at timestamptz not null default now()
);

create index photo_upload_claims_user_time_idx
  on public.photo_upload_claims (user_id, claimed_at);

alter table public.photo_upload_claims enable row level security;
revoke all on table public.photo_upload_claims from anon, authenticated;


-- -----------------------------------------------------------------------------
-- 2. Shared helpers. Internal: no API role may call them.
--
-- limits_lock() makes one user's limited writes wait for each other, until the
-- transaction that holds it ends. Other users never wait. After it returns,
-- each statement in these plpgsql functions takes a fresh snapshot, so a count
-- made after the lock sees the row the previous holder committed.
--
-- unused_photo_count() is 0004's "in use" test turned round: files in the
-- user's folder that no entry, of any status, points at.
-- -----------------------------------------------------------------------------
create function public.limits_lock(user_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('khmer-archive:limits:' || user_id::text, 0))
$$;

create function public.pending_entry_count(user_id uuid)
returns bigint
language sql
volatile
security definer
set search_path = ''
as $$
  select count(*) from public.entries e
  where e.contributor_id = pending_entry_count.user_id and e.status = 'pending'
$$;

create function public.unused_photo_count(user_id uuid)
returns bigint
language sql
volatile
security definer
set search_path = ''
as $$
  select count(*) from storage.objects o
  where o.bucket_id = 'entry-photos'
    and (storage.foldername(o.name))[1] = unused_photo_count.user_id::text
    and not exists (
      select 1 from public.entries e
      where split_part(e.photo_url, '/storage/v1/object/public/entry-photos/', 2) = o.name
    )
$$;

revoke execute on function public.limits_lock(uuid)         from public, anon, authenticated;
revoke execute on function public.pending_entry_count(uuid) from public, anon, authenticated;
revoke execute on function public.unused_photo_count(uuid)  from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- 3. Five pending entries.
--
-- Called from the entries insert policy. Only inserts are limited: an edit
-- that sends a published or returned entry back to pending creates nothing
-- new, so it is never refused. The row being inserted is not counted: a
-- policy is checked before the row is written. It refuses by raising KA001
-- rather than returning false, so the app can tell this from any other
-- refusal; otherwise it returns true.
-- -----------------------------------------------------------------------------
create function public.check_entry_limit()
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return true;
  end if;

  perform public.limits_lock(uid);

  if public.pending_entry_count(uid) >= 5 then
    raise exception 'pending entry limit reached' using errcode = 'KA001';
  end if;

  return true;
end
$$;

revoke execute on function public.check_entry_limit() from public, anon;
grant execute on function public.check_entry_limit() to authenticated;

alter policy "contributors can create their own pending entries"
  on public.entries
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
    and photo_url is not null
    and public.check_entry_limit()
  );


-- -----------------------------------------------------------------------------
-- 4. Claiming an upload: what the app calls before processing a photo.
--
-- Checks, in order, under the user's lock: the pending limit (only for a
-- photo that will become a new entry, so a contributor is told before the
-- upload rather than after it), the 24-hour limit, the unused-photo limit.
-- Then records the claim. It returns nothing; a refusal is an error with its
-- code, and a refused claim records nothing.
-- -----------------------------------------------------------------------------
create function public.claim_photo_upload(for_new_entry boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  perform public.limits_lock(uid);

  if for_new_entry and public.pending_entry_count(uid) >= 5 then
    raise exception 'pending entry limit reached' using errcode = 'KA001';
  end if;

  if (select count(*) from public.photo_upload_claims c
      where c.user_id = uid and c.claimed_at > now() - interval '24 hours') >= 20 then
    raise exception 'daily upload limit reached' using errcode = 'KA002';
  end if;

  if public.unused_photo_count(uid) >= 10 then
    raise exception 'unused photo limit reached' using errcode = 'KA003';
  end if;

  insert into public.photo_upload_claims (user_id) values (uid);
end
$$;

revoke execute on function public.claim_photo_upload(boolean) from public, anon;
grant execute on function public.claim_photo_upload(boolean) to authenticated;


-- -----------------------------------------------------------------------------
-- 5. The upload policy: best effort for uploads that skip the app.
--
-- Read-only, no lock, returns false rather than raising, so Storage answers
-- with its ordinary "not allowed". It counts the files themselves, since
-- Storage never lets the policy record anything: fewer than 10 unused, and
-- fewer than 20 created in the last 24 hours. An upload through the app has
-- already passed claim_photo_upload(), which allows no more than that, so
-- this does not refuse it.
-- -----------------------------------------------------------------------------
create function public.photo_upload_allowed()
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.unused_photo_count(auth.uid()) < 10
    and (select count(*) from storage.objects o
         where o.bucket_id = 'entry-photos'
           and (storage.foldername(o.name))[1] = auth.uid()::text
           and o.created_at > now() - interval '24 hours') < 20
$$;

revoke execute on function public.photo_upload_allowed() from public, anon;
grant execute on function public.photo_upload_allowed() to authenticated;

alter policy "contributors can upload photos to their own folder"
  on storage.objects
  with check (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.photo_in_use(name)
    and public.photo_upload_allowed()
  );
-- END EXACT MIGRATION FILE: supabase/migrations/0006_contributor_limits.sql

DO $after$
begin
  if md5((jsonb_build_object(
  'functions', (select jsonb_agg(jsonb_build_object(
    'signature', p.oid::regprocedure::text, 'definition_md5', md5(pg_get_functiondef(p.oid)),
    'owner', pg_get_userbyid(p.proowner), 'definer', p.prosecdef, 'settings', p.proconfig,
    'anon_execute', has_function_privilege('anon', p.oid, 'EXECUTE'),
    'authenticated_execute', has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    order by p.oid::regprocedure::text)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('is_reviewer','review_entry','photo_in_use','limits_lock','pending_entry_count',
       'unused_photo_count','check_entry_limit','claim_photo_upload','photo_upload_allowed','record_status_change')),
  'policies', (select jsonb_agg(to_jsonb(p) order by p.schemaname,p.tablename,p.policyname)
    from pg_policies p where (schemaname = 'public' and tablename in
      ('entries','reviewers','photo_upload_claims','review_history'))
      or (schemaname = 'storage' and tablename = 'objects')),
  'entry_triggers', (select jsonb_agg(jsonb_build_object('name',t.tgname,
    'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid)) order by t.tgname)
    from pg_trigger t where t.tgrelid = 'public.entries'::regclass and not t.tgisinternal),
  'relations', (select jsonb_agg(jsonb_build_object('name',c.relname,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
    'anon_grants',(select jsonb_object_agg(privilege,has_table_privilege('anon',c.oid,privilege))
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) privilege),
    'authenticated_grants',(select jsonb_object_agg(privilege,has_table_privilege('authenticated',c.oid,privilege))
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) privilege)) order by c.relname)
    from pg_class c where c.relnamespace = 'public'::regnamespace
    and c.relname in ('entries','reviewers','photo_upload_claims','review_history')),
  'sequence', (select jsonb_build_object('owner',pg_get_userbyid(c.relowner),
    'anon_grants',has_sequence_privilege('anon',c.oid,'SELECT,UPDATE,USAGE'),
    'authenticated_grants',has_sequence_privilege('authenticated',c.oid,'SELECT,UPDATE,USAGE'),
    'public_grants',exists(select 1 from aclexplode(coalesce(c.relacl,acldefault('S',c.relowner))) a where a.grantee = 0))
    from pg_class c where c.oid = to_regclass('public.review_history_id_seq')),
  'storage_relations',(select jsonb_agg(jsonb_build_object('name',c.relname,
    'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity) order by c.relname)
    from pg_class c where c.relnamespace = 'storage'::regnamespace and c.relname in ('objects','buckets')),
  'entry_columns', (select jsonb_agg(jsonb_build_object('column',a.attname,
    'anon_insert',has_column_privilege('anon',a.attrelid,a.attnum,'INSERT'),
    'anon_update',has_column_privilege('anon',a.attrelid,a.attnum,'UPDATE'),
    'authenticated_insert',has_column_privilege('authenticated',a.attrelid,a.attnum,'INSERT'),
    'authenticated_update',has_column_privilege('authenticated',a.attrelid,a.attnum,'UPDATE')) order by a.attnum)
    from pg_attribute a where a.attrelid = 'public.entries'::regclass and a.attnum > 0 and not a.attisdropped),
  'pending_default', (select pg_get_expr(d.adbin,d.adrelid) from pg_attrdef d
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where a.attrelid = 'public.entries'::regclass and a.attname = 'status'),
  'bucket', (select jsonb_build_object('public',public,'file_size_limit',file_size_limit,
    'allowed_mime_types',allowed_mime_types) from storage.buckets where id = 'entry-photos')
))::text) is distinct from 'c2d6c6960dd05d7fea65bce1d436973f' then
    raise exception 'Post-0006 security catalog differs from the reviewed result. Transaction must roll back.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Post-0006 archive data changed. Transaction must roll back.';
  end if;
  if exists(select 1 from public.photo_upload_claims) then raise exception 'New upload log is not empty'; end if;
end
$after$;

-- History is written only after the DDL and all checks succeed, in this SAME transaction.
-- shortcut: version-only history; populate optional name/statements if remote migration fetch is needed.
INSERT INTO supabase_migrations.schema_migrations(version) VALUES ('0006');
COMMIT;
