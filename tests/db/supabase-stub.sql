-- =============================================================================
-- A stand-in for the parts of a Supabase project the migrations and tests use.
--
-- Loaded into a throwaway Postgres container by scripts/test-db.sh, before
-- supabase/migrations/0001_init.sql. Never run against a real project.
--
-- What is mirrored, and from where (read from the live project on 16 Oct):
--   * the API roles anon, authenticated and service_role, without superuser,
--     and with BYPASSRLS only on service_role, as in production;
--   * auth.uid(), auth.role() and auth.jwt(), copied from production's
--     definitions — they read the JWT claims PostgREST puts in
--     `request.jwt.claims`, which the tests set the same way;
--   * storage.buckets and storage.objects with RLS on, the grants production
--     gives the API roles, and storage.foldername() as production defines it
--     (the unique name index is from Supabase's storage schema, not read from
--     the live project);
--   * Supabase's default privileges: every table created in `public` is
--     granted in full to anon, authenticated and service_role. That is why
--     production's entries table shows `arwdDxtm` for both API roles, and why
--     0002 has to revoke before it grants.
--
-- What is NOT here: GoTrue (sign-up, JWT signing, email confirmation),
-- PostgREST (HTTP, its error mapping, its role switching from a JWT), and the
-- Storage API service (which enforces a bucket's size and type limits). See
-- the summary printed at the end of tests/db/0002-ownership.test.sql.
-- =============================================================================

create role anon nologin noinherit;
create role authenticated nologin noinherit;
create role service_role nologin noinherit bypassrls;

-- ---------------------------------------------------------------------------
-- auth
-- ---------------------------------------------------------------------------
create schema auth;
grant usage on schema auth to anon, authenticated, service_role;

create table auth.users (
  id    uuid primary key,
  email text
);

-- Copied from production (pg_get_functiondef on 16 Oct 2026).
create or replace function auth.uid()
 returns uuid
 language sql
 stable
as $function$
  select
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$;

create or replace function auth.role()
 returns text
 language sql
 stable
as $function$
  select
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$function$;

create or replace function auth.jwt()
 returns jsonb
 language sql
 stable
as $function$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$;

-- ---------------------------------------------------------------------------
-- storage
-- ---------------------------------------------------------------------------
create schema storage;
grant usage on schema storage to anon, authenticated, service_role;

create table storage.buckets (
  id                 text primary key,
  name               text not null,
  owner              uuid,
  created_at         timestamptz default now(),
  updated_at         timestamptz default now(),
  public             boolean default false,
  file_size_limit    bigint,
  allowed_mime_types text[]
);

create table storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text references storage.buckets (id),
  name       text,
  owner      uuid,
  metadata   jsonb,
  created_at timestamptz default now()
);
alter table storage.objects enable row level security;

-- One file per name in a bucket, as in Supabase's own storage schema
-- (`bucketid_objname`). An upload with upsert is an INSERT ... ON CONFLICT on
-- this index, so the tests of 0004 need it to behave as Storage does.
create unique index bucketid_objname on storage.objects (bucket_id, name);

-- Production's grants on storage.objects (information_schema, 16 Oct).
grant select, insert, update, delete on storage.objects to anon, authenticated;
grant all on storage.objects to service_role;

-- Copied from production.
create or replace function storage.foldername(name text)
 returns text[]
 language plpgsql
 immutable
as $function$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$function$;

-- ---------------------------------------------------------------------------
-- public: Supabase's default privileges for the API roles
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
