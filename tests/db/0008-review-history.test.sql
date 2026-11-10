-- =============================================================================
-- The review history after migration 0008 (review finding M4, second half).
-- Tested as contributor J, reviewers R and S, a visitor, and the founder
-- working as the database owner.
--
-- Runs after 0007-review-separation.test.sql. One new entry, K, is followed
-- through its whole life, and after each step its history is read back as the
-- table owner and compared with exactly what should be there: one row per
-- change, in order, with the right person.
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set R '33333333-3333-4333-8333-333333333333'
\set S 'aaaaaaaa-5555-4555-8555-555555555555'
\set J 'bbbbbbbb-6666-4666-8666-666666666666'
\set ON_ERROR_STOP on

-- An entry's history in one line, read as the table owner:
--   "-> pending by J; pending -> published by R; ..." ("founder": no user).
create function tests.history(p_id uuid)
returns text
language sql
volatile
security definer
as $$
  select coalesce(string_agg(
    concat_ws(' ', h.old_status::text, '->', h.new_status::text, 'by',
      case h.changed_by
        when '33333333-3333-4333-8333-333333333333' then 'R'
        when 'aaaaaaaa-5555-4555-8555-555555555555' then 'S'
        when 'bbbbbbbb-6666-4666-8666-666666666666' then 'J'
        else coalesce(h.changed_by::text, 'founder')
      end),
    '; ' order by h.id), '(none)')
  from public.review_history h
  where h.entry_id = p_id
$$;


\echo '# 0. History starts empty, and 0008 changed no entry'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0008:%') = (select count(*) from public.entries)
  and not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0008:%'
      and s.hash is distinct from (select md5(e::text) from public.entries e where 'before 0008:' || e.id = s.label)
  ),
  'every entry is byte-for-byte unchanged'
);
select tests.ok((select count(*) from public.review_history) = 0, 'the history is empty: it starts with this migration');

\echo '# 0a. API roles cannot manipulate the private identity sequence'

begin;
set local role authenticated;
select tests.throws($q$select nextval('public.review_history_id_seq')$q$, '42501', 'authenticated cannot advance the history sequence');
select tests.throws($q$select setval('public.review_history_id_seq', 1, false)$q$, '42501', 'authenticated cannot reset the history sequence');
select tests.throws($q$select last_value from public.review_history_id_seq$q$, '42501', 'authenticated cannot read sequence state');
commit;

begin;
set local role anon;
select tests.throws($q$select nextval('public.review_history_id_seq')$q$, '42501', 'anon cannot advance the history sequence');
select tests.throws($q$select setval('public.review_history_id_seq', 1, false)$q$, '42501', 'anon cannot reset the history sequence');
select tests.throws($q$select last_value from public.review_history_id_seq$q$, '42501', 'anon cannot read sequence state');
commit;

select tests.ok(
  not has_sequence_privilege('anon', 'public.review_history_id_seq', 'SELECT,UPDATE,USAGE')
  and not has_sequence_privilege('authenticated', 'public.review_history_id_seq', 'SELECT,UPDATE,USAGE')
  and not exists (
    select 1 from pg_class c,
      lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) a
    where c.oid = 'public.review_history_id_seq'::regclass and a.grantee = 0
  ),
  'history sequence has no API-role or PUBLIC grants'
);


\echo '# 1. Each status change is recorded once, with who made it'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'J');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'J', 'នំ', 'Num (0008 test entry K by J)', 'Dara', 'x', '[TEST] Followed through its history.', tests.photo_for(:'J'))
  returning id
)
insert into tests.ids (label, id) select 'k', id from created;
commit;

select tests.ok(tests.history(tests.id('k')) = '-> pending by J', 'J submits K: one row, nothing to pending, by J');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.review_entry(tests.id('k'), 'published'), 'R publishes K through review_entry()');
commit;

select tests.ok(
  tests.history(tests.id('k')) = '-> pending by J; pending -> published by R',
  'recorded as R''s, not the function''s owner''s'
);

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'J');
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'Edited', status = 'pending' where id = %L$q$, tests.id('k'))) = 1,
  'J edits K, which sends it back for review'
);
commit;

select tests.ok(
  tests.history(tests.id('k')) = '-> pending by J; pending -> published by R; published -> pending by J',
  'recorded: published to pending, by J'
);

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'Edited again', status = 'pending' where id = %L$q$, tests.id('k'))) = 1,
  'J edits K again while it is pending'
);
commit;

select tests.ok(
  tests.history(tests.id('k')) = '-> pending by J; pending -> published by R; published -> pending by J',
  'nothing recorded: the status did not change'
);

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'S', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(public.review_entry(tests.id('k'), 'returned'), 'S returns K');
commit;

select tests.ok(
  tests.history(tests.id('k')) = '-> pending by J; pending -> published by R; published -> pending by J; pending -> returned by S',
  'recorded: pending to returned, by S'
);


\echo '# 2. A change that did not happen leaves no row'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(public.review_entry(tests.id('k'), 'published') = false, 'R tries to publish K, which is returned, not pending: false');
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.throws(
  format($q$update public.entries set status = 'published' where id = %L$q$, tests.id('k')),
  '42501', 'J tries to publish K directly: refused'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.affected(format($q$update public.entries set status = 'pending' where id = %L$q$, tests.id('k')));
rollback;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.throws(
  format($q$update public.entries set status = 'pending', name_english = '' where id = %L$q$, tests.id('k')),
  '23514', 'J resubmits K with an empty name: refused by a CHECK constraint'
);
commit;

select tests.ok(
  tests.history(tests.id('k')) = '-> pending by J; pending -> published by R; published -> pending by J; pending -> returned by S',
  'none of those four left a row: the false, the refusal, the rollback, the failed check'
);


\echo '# 3. The founder, in the dashboard'

-- As the table owner, with no user signed in: the dashboard and SQL editor.
update public.entries set context = 'Tidied by the founder' where id = tests.id('k');
select tests.ok(
  tests.history(tests.id('k')) like '%pending -> returned by S',
  'a text-only change records nothing'
);
update public.entries set status = 'published' where id = tests.id('k');
select tests.ok(
  tests.history(tests.id('k')) like '%pending -> returned by S; returned -> published by founder',
  'a status change is recorded, by nobody signed in: the founder'
);
select tests.ok(
  (select count(*) from public.review_history where entry_id = tests.id('k')) = 5
  and (select bool_and(contributor_id = 'bbbbbbbb-6666-4666-8666-666666666666') from public.review_history where entry_id = tests.id('k')),
  'five changes, five rows, each naming J as the contributor'
);


\echo '# 4. Only the founder can see it'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'J');
select tests.throws('select * from public.review_history', '42501', 'J cannot read it, even for J''s own entry');
select tests.throws(
  format($q$insert into public.review_history (entry_id, new_status) values (%L, 'published')$q$, tests.id('k')),
  '42501', 'J cannot add a row'
);
select tests.throws('update public.review_history set changed_by = null', '42501', 'J cannot change a row');
select tests.throws('delete from public.review_history', '42501', 'J cannot delete a row');
select tests.throws('select public.record_status_change()', '42501', 'J cannot call the trigger''s function');
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.throws('select * from public.review_history', '42501', 'a reviewer cannot read it either');
select tests.throws('delete from public.review_history', '42501', 'or delete from it');
commit;

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.throws('select * from public.review_history', '42501', 'nor can a visitor');
commit;


\echo '# 5. History outlives the entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'J', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'J');
select tests.ok(
  tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('k'))) = 1,
  'J deletes K'
);
commit;

select tests.ok(
  (select count(*) from public.entries where id = tests.id('k')) = 0
  and (select count(*) from public.review_history where entry_id = tests.id('k')) = 5,
  'K is gone; its five history rows are not'
);


\echo '# 6. The rules, as written'

select tests.ok(
  (select relrowsecurity from pg_class where oid = 'public.review_history'::regclass)
  and not has_table_privilege('anon', 'public.review_history', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
  and not has_table_privilege('authenticated', 'public.review_history', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
  and not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'review_history'),
  'review_history: RLS on, no policy, and no privilege at all for either API role'
);
select tests.ok(
  not exists (select 1 from pg_constraint where conrelid = 'public.review_history'::regclass and contype = 'f'),
  'no foreign keys, so deleting an entry or an account cannot cascade into it'
);
select tests.ok(
  (select prosecdef and proconfig = array['search_path=""'] from pg_proc
   where oid = 'public.record_status_change()'::regprocedure)
  and not has_function_privilege('authenticated', 'public.record_status_change()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.record_status_change()', 'EXECUTE'),
  'record_status_change(): SECURITY DEFINER, search_path pinned, not callable through the API'
);
select tests.ok(
  (select count(*) from pg_trigger where tgrelid = 'public.entries'::regclass and not tgisinternal) = 1
  and (select pg_get_triggerdef(oid) from pg_trigger
       where tgrelid = 'public.entries'::regclass and not tgisinternal)
      like 'CREATE TRIGGER entries_record_status_change AFTER INSERT OR UPDATE OF status ON public.entries FOR EACH ROW EXECUTE FUNCTION record_status_change()',
  'exactly one trigger on entries: after insert, or an update of status, for each row'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 6
  and (select count(*) from pg_policies
       where schemaname = 'public' and tablename = 'entries' and cmd = 'UPDATE'
         and with_check not like '%is_reviewer%') = 1,
  'the six entries policies are unchanged, 0007''s update rule included'
);
