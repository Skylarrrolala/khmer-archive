-- PERMANENT SQL FOR REVIEW. Execute only after explicit owner approval and a verified backup.
-- Target: production welzetyikwoggygaushf, PostgreSQL 17; migration 0005 ONLY.
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
       is distinct from array['0001','0002','0003','0004']::text[] then
    raise exception 'Wrong migration history for 0005; never repair, skip or overwrite a version here.';
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
))::text) is distinct from '3426f5eeb517a2ce14a48426b506e203' then
    raise exception 'Pre-0005 security catalog differs from the reviewed predecessor. Stop and inspect.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Pre-0005 archive data changed since the approved baseline. Stop and inspect.';
  end if;
end
$before$;

-- BEGIN EXACT MIGRATION FILE: supabase/migrations/0005_restrict_photo_listing.sql
-- SHA256: 76f0b3b71e03960472946ef6000b0e66b90f60144a53e531046c7f226204fe1a
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
-- END EXACT MIGRATION FILE: supabase/migrations/0005_restrict_photo_listing.sql

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
))::text) is distinct from '970e27762cb7b3f2dfe7e603ffdce0fc' then
    raise exception 'Post-0005 security catalog differs from the reviewed result. Transaction must roll back.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Post-0005 archive data changed. Transaction must roll back.';
  end if;
end
$after$;

-- History is written only after the DDL and all checks succeed, in this SAME transaction.
-- shortcut: version-only history; populate optional name/statements if remote migration fetch is needed.
INSERT INTO supabase_migrations.schema_migrations(version) VALUES ('0005');
COMMIT;
