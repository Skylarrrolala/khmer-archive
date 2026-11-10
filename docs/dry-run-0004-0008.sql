-- REVIEW COPY ONLY: no SQL has been executed to prepare this file.
-- Source commit: 14a5c29fab3ae096c62c45006c75dcea330484d3
-- The marked migration blocks are exact committed bytes, not rewritten SQL.
-- See docs/prepare-0004-0008.md before requesting execution approval.
-- Run the COMPLETE file in ONE fresh administrative connection. Never select
-- just a migration block. There is no COMMIT, history repair, ownership change,
-- role grant, Storage API call, test-user insert or review decision here.
-- PostgreSQL 17 only. On any error: ROLLBACK, stop, and inspect the error.

BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '60s';
SET LOCAL idle_in_transaction_session_timeout = '30s';

DO $preflight$
declare
  storage_owner oid;
  versions text[];
begin
  if current_setting('server_version_num')::integer / 10000 <> 17 then
    raise exception 'This review script targets PostgreSQL 17. Stop and review the actual server version.';
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
    execute 'select array_agg(version::text order by version) from supabase_migrations.schema_migrations'
      into versions;
    raise notice 'Recorded migration versions: %', coalesce(versions, array[]::text[]);
    if exists (select 1 from unnest(versions) v where v not in ('0001', '0002', '0003')) then
      raise exception 'Migration history contains unexpected versions. Review it before this dry-run.';
    end if;
  else
    raise notice 'No migration-history table. Compare schema baseline separately; this dry-run does not create or repair history.';
  end if;
end
$preflight$;

-- PG17 total-transaction bound. All settings disappear at ROLLBACK.
SET LOCAL transaction_timeout = '120s';

-- BEFORE: save this JSON. Policy names are guarded above; inspect expressions
-- against committed 0001-0003 as well. Names alone do not prove an exact match.
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

-- BEGIN EXACT COMMITTED FILE: supabase/migrations/0004_prevent_approved_photo_changes.sql
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

-- END EXACT COMMITTED FILE: supabase/migrations/0004_prevent_approved_photo_changes.sql

-- BEGIN EXACT COMMITTED FILE: supabase/migrations/0005_restrict_photo_listing.sql
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

-- END EXACT COMMITTED FILE: supabase/migrations/0005_restrict_photo_listing.sql

-- BEGIN EXACT COMMITTED FILE: supabase/migrations/0006_contributor_limits.sql
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

-- END EXACT COMMITTED FILE: supabase/migrations/0006_contributor_limits.sql

-- BEGIN EXACT COMMITTED FILE: supabase/migrations/0007_review_separation.sql
-- SHA256: 546013b87bf83686a65f73ed9b04a1bc0187c35a4ed99798ae2bbf392a0441d8
-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0007: nobody reviews their own entry.
--
-- Review finding M4, first half. 0003 let a reviewer publish their own work
-- three ways:
--   * review_entry() on their own pending entry: it checked that the caller
--     was a reviewer and the entry pending, never whose entry it was;
--   * a direct update setting their own entry to 'published', from any status:
--     the update policy accepted 'published' from a reviewer. That included an
--     entry another reviewer had returned, which review_entry() would refuse;
--   * an edit to their own published entry, which stayed published, so any new
--     text or photo went public unreviewed. That last one also undid H1 (0004)
--     for reviewers: 0004 relies on "a new photo means an edit, and an edit
--     goes back for review".
--
-- After this file, an edit by anyone comes out 'pending', and the only way to
-- publish or return an entry through the API is review_entry() on somebody
-- else's. A reviewer's own entry needs a second reviewer, or the founder
-- working in the dashboard, which no policy applies to.
--
-- Unchanged: who may edit (the owner, `using`), the column privileges, every
-- CHECK constraint, the SELECT, INSERT and DELETE policies, and the reviewers
-- table. No row is changed: entries published before this stay published.
--
-- tests/db/0007-review-separation.test.sql exercises every rule below.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. review_entry() refuses the caller's own entries.
--
-- Same signature, so 0003's grants carry over: signed-in users may call it,
-- visitors may not. A refusal is `false`, like its other refusals, and changes
-- nothing. `is distinct from` rather than `<>` so an entry with no owner (the
-- researched seed rows) can still be reviewed: `<>` with a null is never true.
-- -----------------------------------------------------------------------------
create or replace function public.review_entry(entry_id uuid, decision text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_reviewer() then
    return false;
  end if;

  if decision is null or decision not in ('published', 'returned') then
    return false;
  end if;

  update public.entries
  set status = decision::public.entry_status
  where id = entry_id
    and status = 'pending'
    and contributor_id is distinct from auth.uid();

  return found;
end
$$;


-- -----------------------------------------------------------------------------
-- 2. Every edit goes back for review.
--
-- 0003's reviewer branch, `status = 'published' and is_reviewer()`, is gone.
-- The owner half is identical: you reach only your own rows (`using`) and they
-- are still yours afterwards (`with check`).
-- -----------------------------------------------------------------------------
alter policy "contributors can update their own entries"
  on public.entries
  using (auth.uid() = contributor_id)
  with check (
    auth.uid() = contributor_id
    and photo_url is not null
    and status = 'pending'
  );

-- END EXACT COMMITTED FILE: supabase/migrations/0007_review_separation.sql

-- BEGIN EXACT COMMITTED FILE: supabase/migrations/0008_review_history.sql
-- SHA256: a27246536fd2fc4ea133f997c19754ef5ab8980bd3c79bb86643ce5966f6e91e
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

-- END EXACT COMMITTED FILE: supabase/migrations/0008_review_history.sql

-- AFTER DDL, STILL UNCOMMITTED: inspect this transient state, not as evidence
-- of a permanent rollout. No new function below is invoked to change data.
DO $postflight$
begin
  if to_regclass('public.photo_upload_claims') is null
     or to_regclass('public.review_history') is null
     or not (select relrowsecurity from pg_class where oid = 'public.photo_upload_claims'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.review_history'::regclass)
     or exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
       and (cmd in ('UPDATE', 'ALL') or policyname = 'entry photos are readable by everyone'))
     or not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'contributors can read photos in their own folder' and cmd = 'SELECT') then
    raise exception 'Unexpected transient table/Storage policy state.';
  end if;

  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('limits_lock', 'pending_entry_count', 'unused_photo_count', 'record_status_change')
      and (has_function_privilege('anon', p.oid, 'EXECUTE')
        or has_function_privilege('authenticated', p.oid, 'EXECUTE')))
     or has_function_privilege('anon', 'public.review_entry(uuid,text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.review_entry(uuid,text)', 'EXECUTE') then
    raise exception 'Unexpected transient function grants.';
  end if;

  if has_table_privilege('anon', 'public.photo_upload_claims', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or has_table_privilege('authenticated', 'public.photo_upload_claims', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or has_table_privilege('anon', 'public.review_history', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or has_table_privilege('authenticated', 'public.review_history', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or (select count(*) from public.photo_upload_claims) <> 0
     or (select count(*) from public.review_history) <> 0 then
    raise exception 'Transient private tables have unexpected privileges or data.';
  end if;

  if not exists (select 1 from pg_trigger where tgrelid = 'public.entries'::regclass
    and tgname = 'entries_record_status_change' and tgenabled = 'O'
    and tgfoid = to_regprocedure('public.record_status_change()')) then
    raise exception 'Expected review history trigger is missing or disabled.';
  end if;
end
$postflight$;
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

-- Deliberately discard ALL migration DDL, grants, triggers and local settings.
-- After this completes, run docs/check-0004-0008.sql separately and compare
-- its result with BEFORE. New objects must be absent; baseline policies,
-- review_entry definition/ACL, ownership, data and history must be unchanged.
ROLLBACK;
