-- =============================================================================
-- Nobody reviews their own entry, after migration 0007 (review finding M4,
-- first half). Tested as reviewers R and S, contributor J and a visitor.
--
-- Runs after 0006-limits.test.sql. R has been a reviewer since 0004's tests
-- added R back; S is a second reviewer added here, and J a fresh contributor,
-- so no earlier file's entries count against the 0006 limits.
--
-- Section 2 is the three ways 0003 let a reviewer publish their own work.
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set R '33333333-3333-4333-8333-333333333333'
\set S 'aaaaaaaa-5555-4555-8555-555555555555'
\set J 'bbbbbbbb-6666-4666-8666-666666666666'
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  (:'S', 'reviewer-s@test.invalid'), (:'J', 'contributor-j@test.invalid');
insert into public.reviewers (user_id) values (:'S');
insert into public.reviewers (user_id) values (:'R') on conflict do nothing;

create function tests.status_of(p_id uuid)
returns text
language sql
volatile
security definer
as $$ select status::text from public.entries where id = p_id $$;


\echo '# 0. 0007 changed no entry'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0007:%') = (select count(*) from public.entries)
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0007:%'
      and s.hash is distinct from (select md5(e::text) from public.entries e where 'before 0007:' || e.id = s.label)
  ),
  'every entry is byte-for-byte unchanged'
);
select tests.ok(
  tests.status_of(tests.id('r_entry')) = 'published',
  'R''s entry, which R published under 0003, is still published'
);


\echo '# 1. Set-up: R submits an entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'R', 'នំ', 'Num (0007 test entry by reviewer R)', 'Dara', 'x', '[TEST] A reviewer''s own entry.', tests.photo_for(:'R'))
  returning id
)
insert into tests.ids (label, id) select 'r_own', id from created;
select tests.ok(tests.status_of(tests.id('r_own')) = 'pending', 'R''s new entry is pending, like anyone''s');
commit;


\echo '# 2. M4: R tries to publish R''s own entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.is_reviewer(), 'R is a reviewer');
select tests.ok(
  public.review_entry(tests.id('r_own'), 'published') = false
  and tests.status_of(tests.id('r_own')) = 'pending',
  'review_entry() on R''s own entry: false, and it stays pending'
);
select tests.ok(
  public.review_entry(tests.id('r_own'), 'returned') = false
  and tests.status_of(tests.id('r_own')) = 'pending',
  'R cannot return R''s own entry either'
);
select tests.throws(
  format($q$update public.entries set status = 'published' where id = %L$q$, tests.id('r_own')),
  '42501', 'a direct update to published: refused'
);
commit;

-- S, a second reviewer, publishes it.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'S', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'S');
select tests.ok(
  public.review_entry(tests.id('r_own'), 'published') = true
  and tests.status_of(tests.id('r_own')) = 'published',
  'another reviewer, S, can publish R''s entry'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.throws(
  format($q$update public.entries set context = 'Rewritten after approval' where id = %L$q$, tests.id('r_own')),
  '42501', 'R editing R''s own published entry and keeping it published: refused'
);
select tests.ok(
  tests.affected(format(
    $q$update public.entries set context = 'Rewritten after approval', status = 'pending' where id = %L$q$,
    tests.id('r_own')
  )) = 1
  and tests.status_of(tests.id('r_own')) = 'pending',
  'the same edit sent for review is accepted: the entry is pending again'
);
commit;

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.ok(
  (select count(*) from public.entries where id = tests.id('r_own')) = 0,
  'so a visitor no longer sees it, rewritten text and all'
);
commit;

-- S returns it; R tries to put it back up without review.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'S', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(public.review_entry(tests.id('r_own'), 'returned') = true, 'S returns R''s entry');
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.throws(
  format($q$update public.entries set status = 'published' where id = %L$q$, tests.id('r_own')),
  '42501', 'R re-publishing R''s returned entry by a direct update: refused'
);
select tests.ok(
  public.review_entry(tests.id('r_own'), 'published') = false
  and tests.status_of(tests.id('r_own')) = 'returned',
  'and through review_entry(): false, still returned'
);
select tests.ok(
  tests.affected(format(
    $q$update public.entries set description = '[TEST] Fixed after return.', status = 'pending' where id = %L$q$,
    tests.id('r_own')
  )) = 1,
  'R resubmits it the normal way: an edit, back to pending'
);
commit;


\echo '# 3. Reviewing other people''s entries still works'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'J');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'J', 'នំ', 'Num (0007 test entry by J)', 'Dara', 'x', '[TEST] A contributor''s entry.', tests.photo_for(:'J'))
  returning id
)
insert into tests.ids (label, id) select 'j_entry', id from created;
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(
  public.review_entry(tests.id('j_entry'), 'published') = true
  and tests.status_of(tests.id('j_entry')) = 'published',
  'R publishes J''s entry'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'J');
select tests.ok(public.review_entry(tests.id('j_entry'), 'returned') = false, 'J, not a reviewer, still gets false');
select tests.throws(
  format($q$update public.entries set context = 'Changed' where id = %L$q$, tests.id('j_entry')),
  '42501', 'J editing J''s published entry without sending it for review: refused, as before'
);
select tests.ok(
  tests.affected(format(
    $q$update public.entries set context = 'Changed', status = 'pending' where id = %L$q$, tests.id('j_entry')
  )) = 1,
  'J''s edit sent for review: accepted, as before'
);
commit;

-- The founder puts a researched seed row, which has no owner, back to pending.
update public.entries set status = 'pending' where id = tests.id('seed_row');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'S', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'S');
select tests.ok(
  public.review_entry(tests.id('seed_row'), 'published') = true
  and tests.status_of(tests.id('seed_row')) = 'published',
  'an entry with no owner can still be reviewed: `is distinct from`, not `<>`'
);
commit;

begin;
set local role anon;
select tests.throws(
  format($q$select public.review_entry(%L, 'published')$q$, tests.id('j_entry')),
  '42501', 'a visitor still cannot call review_entry()'
);
commit;


\echo '# 4. The rules, as written'

select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'UPDATE'
     and qual = '(auth.uid() = contributor_id)'
     and with_check like '%auth.uid() = contributor_id%'
     and with_check like '%photo_url IS NOT NULL%'
     and with_check like '%status = ''pending''%'
     and with_check not like '%is_reviewer%'
     and with_check not like '%published%') = 1,
  'the update policy: own rows, still yours, with a photo, pending; no reviewer exception'
);
select tests.ok(
  (select prosecdef and proconfig = array['search_path=""']
     and prosrc like '%contributor_id is distinct from auth.uid()%'
   from pg_proc where oid = 'public.review_entry(uuid, text)'::regprocedure),
  'review_entry(): SECURITY DEFINER, search_path pinned, and it skips the caller''s own entries'
);
select tests.ok(
  not has_function_privilege('anon', 'public.review_entry(uuid, text)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.review_entry(uuid, text)', 'EXECUTE'),
  'review_entry(): signed-in users only, as before'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 6
  and (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'entries' and cmd = 'INSERT'
         and with_check like '%check_entry_limit()%') = 1,
  'still six policies on entries, and the insert policy still carries 0006''s limit'
);
