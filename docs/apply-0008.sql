-- PERMANENT SQL FOR REVIEW. Execute only after explicit owner approval and a verified backup.
-- Target: production welzetyikwoggygaushf, PostgreSQL 17; migration 0008 ONLY.
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
       is distinct from array['0001','0002','0003','0004','0005','0006','0007']::text[] then
    raise exception 'Wrong migration history for 0008; never repair, skip or overwrite a version here.';
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
))::text) is distinct from '60fbbfcabc87724b7f90ae07b6bea26c' then
    raise exception 'Pre-0008 security catalog differs from the reviewed predecessor. Stop and inspect.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Pre-0008 archive data changed since the approved baseline. Stop and inspect.';
  end if;
end
$before$;

-- BEGIN EXACT MIGRATION FILE: supabase/migrations/0008_review_history.sql
-- SHA256: df79c88341d0da8d07140ce71b7ba7626eca7011fc64910ecb9693e2097142b9
-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0008: a history of every entry's status.
--
-- Review finding M4, second half. review_entry() changed an entry's status and
-- kept no record of who did it or when, and neither did anything else.
--
-- A trigger on public.entries records every status an entry is given, however
-- it got it:
--   * a new entry (from nothing to pending);
--   * a reviewer's decision through review_entry() (pending to published or
--     returned);
--   * a contributor's edit that sends an entry back for review (published or
--     returned to pending);
--   * a change the founder makes in the dashboard.
-- Each row says who: the signed-in user, or nobody for the founder's dashboard
-- and SQL editor, which run as the database owner without a user.
--
-- Only the founder reads it, in the dashboard: no API role can read, add to,
-- change or delete it. It holds ids, statuses and times, never an entry's
-- text, credit or photo. It is kept when an entry or an account is deleted, so
-- there are no foreign keys to cascade through it.
--
-- History starts here: entries that existed before this migration have no
-- rows until their status next changes. Nothing else is changed.
--
-- tests/db/0008-review-history.test.sql exercises every rule below.
-- =============================================================================


create table public.review_history (
  id             bigint generated always as identity primary key,
  entry_id       uuid               not null,
  contributor_id uuid,
  old_status     public.entry_status,          -- null when the entry was created
  new_status     public.entry_status not null,
  changed_by     uuid,                         -- null: the founder, in the dashboard
  changed_at     timestamptz        not null default now()
);

create index review_history_entry_idx on public.review_history (entry_id, changed_at);

alter table public.review_history enable row level security;
revoke all on table public.review_history from anon, authenticated;
-- Identity sequences have separate grants; only the definer needs this one.
revoke all on sequence public.review_history_id_seq from public, anon, authenticated;


-- SECURITY DEFINER, because it writes a table the person making the change may
-- not. auth.uid() still names that person: it reads the request's login token,
-- which a definer function does not change, including inside review_entry().
create function public.record_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.review_history (entry_id, contributor_id, old_status, new_status, changed_by)
    values (
      new.id,
      new.contributor_id,
      case when tg_op = 'UPDATE' then old.status end,
      new.status,
      auth.uid()
    );
  end if;
  return null;
end
$$;

revoke execute on function public.record_status_change() from public, anon, authenticated;

-- AFTER, so only a change that actually happened is recorded: an insert or
-- update refused by a policy or a constraint never reaches it, and anything
-- rolled back takes its history row with it. `update of status` skips edits
-- that leave status out; an edit that sets the same status again records
-- nothing, by the check above.
create trigger entries_record_status_change
  after insert or update of status on public.entries
  for each row
  execute function public.record_status_change();
-- END EXACT MIGRATION FILE: supabase/migrations/0008_review_history.sql

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
))::text) is distinct from '98809b8b68eb7241597a090e72d3f86d' then
    raise exception 'Post-0008 security catalog differs from the reviewed result. Transaction must roll back.';
  end if;
  if jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) is distinct from '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb then
    raise exception 'Post-0008 archive data changed. Transaction must roll back.';
  end if;
  if exists(select 1 from public.review_history) then raise exception 'New audit history is not empty'; end if;
end
$after$;

-- History is written only after the DDL and all checks succeed, in this SAME transaction.
-- shortcut: version-only history; populate optional name/statements if remote migration fetch is needed.
INSERT INTO supabase_migrations.schema_migrations(version) VALUES ('0008');
COMMIT;
