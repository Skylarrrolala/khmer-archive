-- READ ONLY. Run separately after EACH approved migration, as postgres.
-- All checks must be true. Save full catalog_state and data for comparison.
-- This checks definitions, effective API permissions, column grants, policies, RLS,
-- trigger, sequence ACL, bucket settings and archive fingerprints without calling a write function.
with observed as (
  select jsonb_build_object(
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
) as catalog_state,
    jsonb_build_object(
  'entries',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' order by e.id),''))) from public.entries e),
  'reviewers',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' order by r.user_id),''))) from public.reviewers r),
  'entry_photo_objects',(select jsonb_build_object('count',count(*),'md5',md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' order by o.id),''))) from storage.objects o where o.bucket_id = 'entry-photos')
) as data,
    (select array_agg(version::text order by version) from supabase_migrations.schema_migrations) as versions
), checked as (
  select *, case versions
    when array['0001','0002','0003','0004']::text[] then '3426f5eeb517a2ce14a48426b506e203'
    when array['0001','0002','0003','0004','0005']::text[] then '970e27762cb7b3f2dfe7e603ffdce0fc'
    when array['0001','0002','0003','0004','0005','0006']::text[] then 'c2d6c6960dd05d7fea65bce1d436973f'
    when array['0001','0002','0003','0004','0005','0006','0007']::text[] then '60fbbfcabc87724b7f90ae07b6bea26c'
    when array['0001','0002','0003','0004','0005','0006','0007','0008']::text[] then '98809b8b68eb7241597a090e72d3f86d'
    else null end as expected_catalog_md5
  from observed
)
select versions as migration_versions, catalog_state, data,
  jsonb_build_object(
    'known_complete_migration_prefix',expected_catalog_md5 is not null,
    'security_catalog_matches_reviewed_stage',coalesce(md5(catalog_state::text) = expected_catalog_md5,false),
    'archive_matches_verified_baseline',data = '{"entries":{"count":10,"md5":"38ec0562e30bac68e96107d3f4ccf272"},"entry_photo_objects":{"count":2,"md5":"971e5099367f4c7852edbcab3fb8211f"},"reviewers":{"count":1,"md5":"5fc749c633b6ae1a0650ebd453f7e099"}}'::jsonb,
    'admin_reads_unrestricted',current_user = 'postgres'
      and not row_security_active('public.entries'::regclass)
      and not row_security_active('public.reviewers'::regclass)
      and not row_security_active('storage.objects'::regclass),
    'storage_rls_enabled',(select relrowsecurity from pg_class where oid = 'storage.objects'::regclass),
    'private_logs_have_no_policies',not exists(select 1 from pg_policies where schemaname = 'public'
      and tablename in ('photo_upload_claims','review_history'))
  ) as rollout_checks
from checked;
