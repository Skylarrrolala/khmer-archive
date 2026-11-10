-- PERMANENT SQL FOR REVIEW. Execute only after explicit owner approval and a verified backup.
-- Target: production welzetyikwoggygaushf, PostgreSQL 17; migration 0004 ONLY.
-- 0004-0007 bodies are exact committed 14a5c29 files; 0008 adds only the tested sequence revoke.
-- Run the COMPLETE file in one fresh postgres session. On error: ROLLBACK and STOP.
-- After COMMIT, run docs/verify-rollout.sql separately; never proceed on a failed check.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '60s';
SET LOCAL idle_in_transaction_session_timeout = '30s';
SET LOCAL transaction_timeout = '120s';

DO $preflight$
declare
  storage_owner oid;
  versions text[];
begin
  if current_setting('server_version_num')::integer / 10000 <> 17 then
    raise exception 'This 0004 rollout draft targets PostgreSQL 17. Stop and review the actual server version.';
  end if;

  if to_regclass('public.entries') is null or to_regclass('public.reviewers') is null
     or to_regclass('auth.users') is null or to_regclass('storage.objects') is null
     or to_regclass('storage.buckets') is null
     or to_regprocedure('auth.uid()') is null
     or to_regprocedure('storage.foldername(text)') is null
     or to_regprocedure('public.is_reviewer()') is null
     or to_regprocedure('public.review_entry(uuid,text)') is null then
    raise exception 'Required 0001-0003 or Supabase objects are missing. No migration should run.';
  end if;

  if (select array_agg(enumlabel::text order by enumsortorder) from pg_enum
      where enumtypid = to_regtype('public.entry_status'))
      is distinct from array['pending', 'published', 'returned'] then
    raise exception 'Expected the 0003 entry_status enum. Stop and inspect baseline drift.';
  end if;

  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in
      ('photo_upload_claims', 'photo_upload_claims_user_time_idx', 'review_history',
       'review_history_entry_idx', 'review_history_id_seq'))
    or exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('photo_in_use', 'limits_lock', 'pending_entry_count', 'unused_photo_count',
       'check_entry_limit', 'claim_photo_upload', 'photo_upload_allowed', 'record_status_change'))
    or exists (select 1 from pg_trigger where tgrelid = 'public.entries'::regclass
      and tgname = 'entries_record_status_change') then
    raise exception 'Objects from 0004-0008 already exist. This file must not be rerun over partial/applied migrations.';
  end if;

  if (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects') <> 4
    or (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects'
      and policyname in ('entry photos are readable by everyone',
        'contributors can upload photos to their own folder',
        'contributors can update photos in their own folder',
        'contributors can delete photos in their own folder')) <> 4
    or (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') <> 6
    or (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries'
      and policyname in ('published entries are readable by everyone',
        'contributors can read their own entries', 'contributors can create their own pending entries',
        'contributors can update their own entries', 'contributors can delete their own entries',
        'reviewers can read every entry')) <> 6 then
    raise exception 'Unexpected policy inventory. Review the read-only policy definitions; do not drop extra policies to make this pass.';
  end if;

  if not has_schema_privilege(current_user, 'public', 'USAGE')
     or not has_schema_privilege(current_user, 'public', 'CREATE')
     or not has_column_privilege(current_user, 'auth.users', 'id', 'REFERENCES')
     or not (select pg_has_role(current_user, relowner, 'USAGE')
             from pg_class where oid = 'public.entries'::regclass)
     or not (select pg_has_role(current_user, proowner, 'USAGE')
             from pg_proc where oid = to_regprocedure('public.review_entry(uuid,text)')) then
    raise exception 'Execution role lacks required public-schema, FK, entries-owner or function-owner authority. Do not change ownership as a workaround.';
  end if;

  select relowner into storage_owner from pg_class where oid = 'storage.objects'::regclass;
  if not pg_has_role(current_user, storage_owner, 'USAGE') and not coalesce(
    (nullif(current_setting('supautils.policy_grants', true), '')::jsonb -> current_user::text)
      ? 'storage.objects', false) then
    raise exception 'No Storage table ownership or explicit supautils policy grant for this role. Stop; do not SET ROLE or ALTER OWNER.';
  end if;

  if row_security_active('public.entries'::regclass)
     or row_security_active('public.reviewers'::regclass)
     or row_security_active('storage.objects'::regclass) then
    raise exception 'Use the approved administrative role: RLS-limited counts cannot verify the baseline or definer-function reads.';
  end if;

  if not (select relrowsecurity from pg_class where oid = 'public.entries'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.reviewers'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass)
     or has_column_privilege('authenticated', 'public.entries', 'status', 'INSERT')
     or has_column_privilege('authenticated', 'public.entries', 'contributor_id', 'UPDATE')
     or has_table_privilege('anon', 'public.reviewers', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or has_table_privilege('authenticated', 'public.reviewers', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or has_function_privilege('anon', 'public.review_entry(uuid,text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.review_entry(uuid,text)', 'EXECUTE') then
    raise exception 'Baseline security settings differ from 0001-0003. Stop and inspect.';
  end if;

  if to_regclass('supabase_migrations.schema_migrations') is not null then
    if not has_column_privilege(current_user,
      'supabase_migrations.schema_migrations', 'version', 'INSERT') then
      raise exception 'Execution role cannot record the applied migration. Stop without changing grants.';
    end if;
    execute 'select array_agg(version::text order by version) from supabase_migrations.schema_migrations'
      into versions;
    raise notice 'Recorded migration versions: %', coalesce(versions, array[]::text[]);
    if versions is distinct from array['0001', '0002', '0003']::text[] then
      raise exception 'Migration history contains unexpected versions. Review it before this rollout.';
    end if;
  else
    raise exception 'Migration history is missing. Stop and review; this draft never creates or repairs history.';
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
))::text) is distinct from 'fa57a4513c4f0fe6452761fe2a9bc8ce' then
    raise exception 'Pre-0004 security catalog differs from the reviewed predecessor. Stop and inspect.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Pre-0004 archive data changed since the approved baseline. Stop and inspect.';
  end if;
end
$before$;

-- BEGIN EXACT MIGRATION FILE: supabase/migrations/0004_prevent_approved_photo_changes.sql
-- SHA256: db805bd16bb0e6dc2d5afb0b35359f5850a109ac678d4a91e87e523a2919fc9b
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
-- END EXACT MIGRATION FILE: supabase/migrations/0004_prevent_approved_photo_changes.sql

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
))::text) is distinct from '3426f5eeb517a2ce14a48426b506e203' then
    raise exception 'Post-0004 security catalog differs from the reviewed result. Transaction must roll back.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Post-0004 archive data changed. Transaction must roll back.';
  end if;
end
$after$;

-- History is written only after the DDL and all checks succeed, in this SAME transaction.
-- shortcut: version-only history; populate optional name/statements if remote migration fetch is needed.
INSERT INTO supabase_migrations.schema_migrations(version) VALUES ('0004');
COMMIT;
