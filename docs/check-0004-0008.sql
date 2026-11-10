-- READ ONLY. Run before the dry-run and again AFTER its ROLLBACK, in the same
-- administrative role. Save both JSON results and compare them. No entry text,
-- photo filenames, account emails or passwords are returned.
-- Counts/digests can change if real users write concurrently; do not mistake
-- normal activity for a migration effect. RLS must be inactive for this role.

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
) as database_state;

-- Also run this read-only query if migration_history_table above is NOT null.
-- Save/compare these version rows before and after; the dry-run never writes it.
-- If it is missing or empty, schema state and recorded history are different
-- questions. Do not create/repair history as part of this dry-run.
-- select version from supabase_migrations.schema_migrations order by version;
