-- READ ONLY. Run separately AFTER the approved 0004 transaction completes.
-- Inspect full policy expressions in database_state, not just the summary flags.
-- Compare database_state with the saved complete post-rollback baseline.
-- This script intentionally does not call photo_in_use(), nextval(), setval()
-- or a write RPC; it reads catalogs and row fingerprints only.
with observed as (
select jsonb_build_object(
  'database', current_database(),
  'server_version', current_setting('server_version'),
  'session_user', session_user,
  'current_user', current_user,
  'role', (select jsonb_build_object('superuser', rolsuper, 'bypassrls', rolbypassrls)
           from pg_roles where rolname = current_user),
  'supautils_version', current_setting('supautils.version', true),
  'storage_policy_grants', current_setting('supautils.policy_grants', true),
  'migration_history_table', to_regclass('supabase_migrations.schema_migrations'),
  'entry_status_labels', (select jsonb_agg(e.enumlabel order by e.enumsortorder)
    from pg_enum e where e.enumtypid = to_regtype('public.entry_status')),
  'entry_status_default', (select pg_get_expr(d.adbin, d.adrelid)
    from pg_attrdef d join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where a.attrelid = 'public.entries'::regclass and a.attname = 'status'),
  'public_create', has_schema_privilege(current_user, 'public', 'CREATE'),
  'auth_users_id_references', has_column_privilege(current_user, 'auth.users', 'id', 'REFERENCES'),
  'relations', (select jsonb_agg(jsonb_build_object(
      'schema', n.nspname, 'name', c.relname, 'owner', pg_get_userbyid(c.relowner),
      'kind', c.relkind, 'rls', c.relrowsecurity, 'force_rls', c.relforcerowsecurity,
      'acl', c.relacl, 'effective_owner', pg_has_role(current_user, c.relowner, 'USAGE'))
      order by n.nspname, c.relname)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where (n.nspname = 'public' and c.relname in
      ('entries', 'reviewers', 'photo_upload_claims', 'review_history', 'review_history_id_seq'))
      or (n.nspname = 'storage' and c.relname in ('objects', 'buckets'))),
  'policies', (select jsonb_agg(to_jsonb(p) order by p.schemaname, p.tablename, p.policyname)
    from pg_policies p where (p.schemaname = 'public' and p.tablename in
      ('entries', 'reviewers', 'photo_upload_claims', 'review_history'))
      or (p.schemaname = 'storage' and p.tablename = 'objects')),
  'functions', (select jsonb_agg(jsonb_build_object(
      'signature', p.oid::regprocedure::text, 'owner', pg_get_userbyid(p.proowner),
      'security_definer', p.prosecdef, 'settings', p.proconfig, 'acl', p.proacl,
      'definition_md5', md5(pg_get_functiondef(p.oid)),
      'anon_execute', has_function_privilege('anon', p.oid, 'EXECUTE'),
      'authenticated_execute', has_function_privilege('authenticated', p.oid, 'EXECUTE'))
      order by p.oid::regprocedure::text)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('is_reviewer', 'review_entry', 'photo_in_use', 'limits_lock', 'pending_entry_count',
       'unused_photo_count', 'check_entry_limit', 'claim_photo_upload',
       'photo_upload_allowed', 'record_status_change')),
  'review_entry_definition', (select pg_get_functiondef(to_regprocedure('public.review_entry(uuid,text)'))),
  'entry_triggers', (select jsonb_agg(jsonb_build_object(
      'name', t.tgname, 'enabled', t.tgenabled, 'definition', pg_get_triggerdef(t.oid)) order by t.tgname)
    from pg_trigger t where t.tgrelid = 'public.entries'::regclass and not t.tgisinternal),
  'bucket', (select jsonb_build_object('id', id, 'public', public,
      'file_size_limit', file_size_limit, 'allowed_mime_types', allowed_mime_types)
    from storage.buckets where id = 'entry-photos'),
  'row_security_active', jsonb_build_object(
      'entries', row_security_active('public.entries'::regclass),
      'reviewers', row_security_active('public.reviewers'::regclass),
      'storage_objects', row_security_active('storage.objects'::regclass)),
  'data', jsonb_build_object(
    'entries', (select jsonb_build_object('count', count(*),
      'md5', md5(coalesce(string_agg(md5(to_jsonb(e)::text), '' order by e.id), '')))
      from public.entries e),
    'reviewers', (select jsonb_build_object('count', count(*),
      'md5', md5(coalesce(string_agg(md5(to_jsonb(r)::text), '' order by r.user_id), '')))
      from public.reviewers r),
    'entry_photo_objects', (select jsonb_build_object('count', count(*),
      'md5', md5(coalesce(string_agg(md5(to_jsonb(o)::text), '' order by o.id), '')))
      from storage.objects o where o.bucket_id = 'entry-photos')
  )
) as database_state
), state_with_history as (
  select database_state,
    (select coalesce(jsonb_agg(version::text order by version), '[]'::jsonb)
     from supabase_migrations.schema_migrations) as migration_versions
  from observed
)
select database_state, migration_versions,
  jsonb_build_object(
    'photo_in_use_function_ready', coalesce((
      select p.prosecdef and p.provolatile = 's'
        and p.proconfig @> array['search_path=""']::text[]
        and not has_function_privilege('anon', p.oid, 'EXECUTE')
        and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      from pg_proc p where p.oid = to_regprocedure('public.photo_in_use(text)')), false),
    'storage_policy_count_is_three', (select count(*) = 3 from pg_policies
      where schemaname = 'storage' and tablename = 'objects'),
    'no_storage_update_policy', not exists (select 1 from pg_policies
      where schemaname = 'storage' and tablename = 'objects' and cmd in ('UPDATE', 'ALL')),
    'public_photo_read_policy_preserved', exists (select 1 from pg_policies
      where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'entry photos are readable by everyone' and cmd = 'SELECT'),
    'upload_uses_photo_lock', exists (select 1 from pg_policies
      where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'contributors can upload photos to their own folder'
      and cmd = 'INSERT' and position('photo_in_use' in with_check) > 0),
    'delete_uses_photo_lock', exists (select 1 from pg_policies
      where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'contributors can delete photos in their own folder'
      and cmd = 'DELETE' and position('photo_in_use' in qual) > 0),
    '0005_own_folder_read_not_applied', not exists (select 1 from pg_policies
      where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'contributors can read photos in their own folder'),
    '0006_to_0008_tables_absent', to_regclass('public.photo_upload_claims') is null
      and to_regclass('public.review_history') is null
      and to_regclass('public.review_history_id_seq') is null,
    '0006_to_0008_functions_absent', not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname in
        ('limits_lock', 'pending_entry_count', 'unused_photo_count', 'check_entry_limit',
         'claim_photo_upload', 'photo_upload_allowed', 'record_status_change')),
    'history_trigger_absent', not exists (select 1 from pg_trigger
      where tgrelid = 'public.entries'::regclass and tgname = 'entries_record_status_change'),
    'migration_history_is_0001_to_0004', (select array_agg(version::text order by version)
      = array['0001','0002','0003','0004'] from supabase_migrations.schema_migrations),
    'data_matches_verified_baseline', database_state -> 'data' = '{
      "entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},
      "reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"},
      "entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"}
    }'::jsonb
  ) as migration_0004_checks
from state_with_history;
