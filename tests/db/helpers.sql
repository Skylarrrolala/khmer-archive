-- =============================================================================
-- Assertion helpers for the database tests. Loaded by scripts/test-db.sh, after
-- 0001_init.sql (the helpers refer to public.entries), into
-- the throwaway test database only.
--
-- Every helper is SECURITY INVOKER (the default), so a statement run through
-- one of them runs as whoever the scenario has switched to. A test written as
-- "B updates A's entry" really is B, under B's privileges and B's RLS. Each
-- scenario proves that with tests.acting_as() before it attacks anything.
-- =============================================================================

create schema tests;
grant usage on schema tests to anon, authenticated;

create sequence tests.n;
grant usage on sequence tests.n to anon, authenticated;

-- Pass: print "ok N - description". Fail: stop the whole run.
create function tests.ok(cond boolean, description text)
returns void
language plpgsql
as $$
begin
  if cond is distinct from true then
    raise exception 'not ok - %', description;
  end if;
  raise notice 'ok % - %', nextval('tests.n'), description;
end
$$;

-- Runs `statement` and passes only if it is refused with `expected` SQLSTATE.
-- 42501 is "insufficient privilege" (a missing grant, or a row-level security
-- policy refusing a row); 23514 is a CHECK constraint. A statement that
-- succeeds fails the test. The refused statement is rolled back by the
-- exception block, so it leaves nothing behind.
create function tests.throws(statement text, expected text, description text)
returns void
language plpgsql
as $$
declare
  got text;
  msg text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics got = returned_sqlstate, msg = message_text;
    if got = expected then
      raise notice 'ok % - % (refused: %)', nextval('tests.n'), description, msg;
      return;
    end if;
    raise exception 'not ok - %: expected SQLSTATE %, got % (%)', description, expected, got, msg;
  end;
  raise exception 'not ok - %: expected SQLSTATE %, but the statement succeeded', description, expected;
end
$$;

-- Runs `statement` and returns how many rows it changed. An UPDATE or DELETE
-- that RLS filters out is not an error: it changes 0 rows.
create function tests.affected(statement text)
returns bigint
language plpgsql
as $$
declare
  n bigint;
begin
  execute statement;
  get diagnostics n = row_count;
  return n;
end
$$;

-- Proves a scenario is not quietly running with powers that skip RLS.
create function tests.acting_as(expected_role text, expected_uid uuid)
returns void
language plpgsql
as $$
begin
  perform tests.ok(
    current_user = expected_role
    and auth.uid() is not distinct from expected_uid
    and not (select rolsuper or rolbypassrls from pg_roles where rolname = current_user)
    and (select tableowner from pg_tables where schemaname = 'public' and tablename = 'entries') <> current_user,
    format(
      'acting as %s%s — not a superuser, not BYPASSRLS, not the table owner',
      expected_role,
      coalesce(' ' || expected_uid::text, '')
    )
  );
end
$$;

-- Rows named by the tests, so a scenario can refer to "A's entry".
create table tests.ids (label text primary key, id uuid not null);
grant select, insert on tests.ids to anon, authenticated;

create function tests.id(p_label text)
returns uuid
language sql
stable
as $$ select id from tests.ids where label = p_label $$;

-- Snapshots of whole rows, for read-back. Taken and compared as the table
-- owner, so they see every column of every row regardless of RLS.
create table tests.snapshots (label text primary key, hash text);

create function tests.snapshot(p_label text, p_id uuid)
returns void
language sql
as $$
  insert into tests.snapshots (label, hash)
  values (p_label, (select md5(e::text) from public.entries e where e.id = p_id))
  on conflict (label) do update set hash = excluded.hash
$$;

create function tests.unchanged(p_label text, p_id uuid)
returns boolean
language sql
stable
as $$
  select coalesce(
    (select md5(e::text) from public.entries e where e.id = p_id)
      = (select hash from tests.snapshots where label = p_label),
    false
  )
$$;

-- A well-formed public URL for a photo in `owner`'s own Storage folder, the
-- shape lib/photos.ts produces.
create function tests.photo_for(owner uuid, ext text default 'jpg')
returns text
language sql
volatile
as $$
  select format(
    'https://test-project.supabase.co/storage/v1/object/public/entry-photos/%s/%s.%s',
    owner, gen_random_uuid(), ext
  )
$$;
