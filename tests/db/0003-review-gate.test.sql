-- =============================================================================
-- The reviewer gate after migration 0003, tested as an anonymous visitor,
-- contributors A and B, and reviewer R.
--
-- Runs after 0002-ownership.test.sql, on the rows that file left behind, and
-- switches identity the same way: `request.jwt.claims` for auth.uid(), then
-- `set local role`, then tests.acting_as() to prove RLS is really applied.
-- review_entry() and is_reviewer() are SECURITY DEFINER, but they are called
-- from inside those switched sessions, so auth.uid() is still the caller's.
--
-- Sections 2 to 6 are the five Lab 10 attacks:
--   1. a contributor inserts a published entry
--   2. a contributor updates their own pending entry to published
--   3. a contributor calls review_entry() — and gets false
--   4. a contributor inserts themselves into public.reviewers
--   5. an anonymous visitor reads pending entries
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set A '11111111-1111-4111-8111-111111111111'
\set B '22222222-2222-4222-8222-222222222222'
\set R '33333333-3333-4333-8333-333333333333'
\set ON_ERROR_STOP on


\echo '# 0. 0003 left every existing row exactly as it was'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before 0003:%') > 0
  and (select count(*) from tests.snapshots where label like 'before 0003:%') = (select count(*) from public.entries),
  'the same rows exist before and after 0003'
);
select tests.ok(
  not exists (
    select 1 from tests.snapshots s
    where s.label like 'before 0003:%'
      and s.hash is distinct from (
        select md5(e::text) from public.entries e where 'before 0003:' || e.id = s.label
      )
  ),
  'every one of them is byte-for-byte unchanged'
);
select tests.ok(
  (select status from public.entries where id = tests.id('b_entry')) = 'published',
  'B''s entry, published under Sprint 2, is still published'
);
select tests.ok(
  (select array_agg(enumlabel::text order by enumsortorder) from pg_enum where enumtypid = 'public.entry_status'::regtype)
    = array['pending', 'published', 'returned'],
  'the statuses are pending, published and returned: rejected was renamed in place, not added beside'
);

-- The founder adds a reviewer in the SQL editor, as the table owner.
insert into auth.users (id, email) values (:'R', 'reviewer-r@test.invalid');
insert into public.reviewers (user_id) values (:'R');


\echo '# 1. A new entry waits for review'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'A', 'នំគម', 'Num Kom (test entry by A)', 'Dara', 'Pchum Ben', '[TEST] A''s Sprint 3 entry.', tests.photo_for(:'A'))
  returning id
)
insert into tests.ids (label, id) select 'a_new', id from created;
select tests.ok(
  (select status from public.entries where id = tests.id('a_new')) = 'pending',
  'A''s new entry is pending without A asking for it'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok((select count(*) from public.entries where id = tests.id('a_new')) = 0, 'B cannot see it');
commit;


\echo '# 2. Attack 1 — a contributor inserts a published entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url, status) values (%L, 'នំ', 'Self-published', 'Dara', 'x', 'x', %L, 'published')$q$,
    :'A', tests.photo_for(:'A')
  ),
  '42501', 'A cannot insert an entry as published'
);
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url, status) values (%L, 'នំ', 'Self-returned', 'Dara', 'x', 'x', %L, 'returned')$q$,
    :'A', tests.photo_for(:'A')
  ),
  '42501', 'A cannot choose any status on insert'
);
select tests.throws(
  $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description) values ('11111111-1111-4111-8111-111111111111', 'នំ', 'No photo', 'Dara', 'x', 'x')$q$,
  '42501', 'A cannot insert an entry without a photo, even a pending one'
);
commit;

select tests.ok(
  (select count(*) from public.entries where contributor_id = :'A' and status = 'published') = 0,
  'read-back: A has no published entry'
);


\echo '# 3. Attack 2 — a contributor updates their own pending entry to published'

select tests.snapshot('a_new', tests.id('a_new'));

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format($q$update public.entries set status = 'published' where id = %L$q$, tests.id('a_new')),
  '42501', 'A cannot publish A''s own pending entry'
);
select tests.throws(
  format($q$update public.entries set context = 'x', status = 'published' where id = %L$q$, tests.id('a_new')),
  '42501', 'A cannot publish it by slipping status into an edit'
);
select tests.throws(
  format($q$update public.entries set status = 'returned' where id = %L$q$, tests.id('a_new')),
  '42501', 'A cannot mark it returned either'
);
commit;

select tests.ok(tests.unchanged('a_new', tests.id('a_new')), 'read-back: A''s entry is unchanged and still pending');


\echo '# 4. Attack 3 — a contributor calls review_entry()'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(not public.is_reviewer(), 'A is not a reviewer');
select tests.ok(
  public.review_entry(tests.id('a_new'), 'published') = false,
  'A gets false when publishing A''s own entry through review_entry()'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  public.review_entry(tests.id('a_new'), 'published') = false
  and public.review_entry(tests.id('a_new'), 'returned') = false,
  'B gets false when publishing or returning A''s entry through review_entry()'
);
commit;

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.throws(
  format($q$select public.review_entry(%L, 'published')$q$, tests.id('a_new')),
  '42501', 'a visitor cannot call review_entry() at all'
);
commit;

select tests.ok(tests.unchanged('a_new', tests.id('a_new')), 'read-back: A''s entry is unchanged and still pending');


\echo '# 5. Attack 4 — a contributor inserts themselves into reviewers'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.throws(
  format($q$insert into public.reviewers (user_id) values (%L)$q$, :'B'),
  '42501', 'B cannot insert B into reviewers'
);
select tests.throws($q$select * from public.reviewers$q$, '42501', 'B cannot read who the reviewers are');
select tests.throws(
  format($q$update public.reviewers set user_id = %L$q$, :'B'),
  '42501', 'B cannot take over a reviewer''s row'
);
select tests.throws($q$delete from public.reviewers$q$, '42501', 'B cannot remove reviewers');
select tests.throws($q$truncate public.reviewers$q$, '42501', 'B cannot truncate the reviewer list');
commit;

-- A token that claims a reviewer role changes nothing: the gate reads
-- public.reviewers, not the token. (B could not get such a token from
-- Supabase anyway; app_metadata is not writable by users.)
begin;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', :'B', 'role', 'authenticated', 'app_metadata', json_build_object('role', 'reviewer'))::text,
  true
);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(not public.is_reviewer(), 'a token claiming a reviewer role does not make B one');
select tests.ok(
  public.review_entry(tests.id('a_new'), 'published') = false,
  'and review_entry() still returns false'
);
commit;

select tests.ok(
  (select array_agg(user_id) from public.reviewers) = array[:'R'::uuid],
  'read-back: R is still the only reviewer'
);


\echo '# 6. Attack 5 — an anonymous visitor reads pending entries'

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.ok(
  (select count(*) from public.entries where status <> 'published') = 0,
  'a visitor can read no unpublished row, whatever the filter'
);
select tests.ok(
  (select count(*) from public.entries where id in (tests.id('a_new'), tests.id('legacy_pending'))) = 0,
  'not even by asking for a pending entry''s id'
);
select tests.throws($q$select * from public.reviewers$q$, '42501', 'a visitor cannot read the reviewer list');
select tests.throws($q$select public.is_reviewer()$q$, '42501', 'a visitor cannot call is_reviewer()');
commit;


\echo '# 7. A reviewer''s invalid decisions return false and change nothing'

select tests.snapshot('a_new', tests.id('a_new'));

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.is_reviewer(), 'R is a reviewer');
select tests.ok(
  (select count(*) from public.entries where id in (tests.id('a_new'), tests.id('legacy_pending'))) = 2,
  'R can read other contributors'' pending entries'
);
select tests.ok(
  public.review_entry(tests.id('a_new'), d.decision) = false,
  format('decision %s returns false', coalesce(quote_literal(d.decision), 'null'))
)
from (values ('pending'), ('rejected'), ('PUBLISHED'), (' published'), (''), (null)) as d(decision);
select tests.ok(public.review_entry(null, 'published') = false, 'a null entry id returns false');
select tests.ok(public.review_entry(gen_random_uuid(), 'published') = false, 'an entry id that does not exist returns false');
commit;

select tests.ok(tests.unchanged('a_new', tests.id('a_new')), 'read-back: A''s entry is unchanged and still pending');


\echo '# 8. A reviewer publishes a pending entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.review_entry(tests.id('a_new'), 'published') = true, 'R publishes A''s entry and gets true');
select tests.ok(
  public.review_entry(tests.id('a_new'), 'returned') = false,
  'a decided entry cannot be decided again: returning it now gets false'
);
commit;

select tests.ok(
  (select status = 'published'
          and contributor_id = :'A'
          and context = 'Pchum Ben'
          and description = '[TEST] A''s Sprint 3 entry.'
   from public.entries where id = tests.id('a_new')),
  'read-back: published, still A''s, with A''s text untouched'
);

begin;
set local role anon;
select tests.ok(
  (select context from public.entries where id = tests.id('a_new')) = 'Pchum Ben',
  'a visitor now sees it, as A wrote it'
);
commit;


\echo '# 9. Editing an approved entry sends it back for review'

select tests.snapshot('a_new', tests.id('a_new'));

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format($q$update public.entries set context = 'Rewritten after approval' where id = %L$q$, tests.id('a_new')),
  '42501', 'A cannot rewrite A''s published entry and leave it published'
);
select tests.throws(
  format($q$update public.entries set photo_url = %L where id = %L$q$, tests.photo_for(:'A', 'png'), tests.id('a_new')),
  '42501', 'A cannot swap only the photo and leave it published'
);
commit;

select tests.ok(tests.unchanged('a_new', tests.id('a_new')), 'read-back: the published entry is byte-for-byte unchanged');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'Edited by A', status = 'pending' where id = %L$q$, tests.id('a_new'))) = 1,
  'A can edit it by sending it back for review'
);
commit;

begin;
set local role anon;
select tests.ok(
  (select count(*) from public.entries where id = tests.id('a_new')) = 0,
  'the edited entry has left the public archive until a reviewer decides again'
);
commit;


\echo '# 10. Ownership: a reviewer cannot change anyone else''s entry directly'

select tests.snapshot('a_new', tests.id('a_new'));
select tests.snapshot('b_entry', tests.id('b_entry'));

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(
  tests.affected(format($q$update public.entries set status = 'published' where id = %L$q$, tests.id('a_new'))) = 0,
  'R''s direct UPDATE of A''s status changes 0 rows: deciding goes through review_entry()'
);
select tests.ok(
  tests.affected(format($q$update public.entries set description = 'R was here' where id = %L$q$, tests.id('a_new'))) = 0,
  'R''s direct UPDATE of A''s story changes 0 rows'
);
select tests.ok(
  tests.affected(format($q$update public.entries set photo_url = %L where id = %L$q$, tests.photo_for(:'B'), tests.id('b_entry'))) = 0,
  'R''s direct UPDATE of B''s photo changes 0 rows'
);
select tests.throws(
  format($q$update public.entries set contributor_id = %L where id = %L$q$, :'R', tests.id('a_new')),
  '42501', 'R cannot take ownership of A''s entry'
);
select tests.ok(
  tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('b_entry'))) = 0,
  'R''s delete of B''s entry deletes 0 rows'
);
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url, status) values (%L, 'នំ', 'x', 'Dara', 'x', 'x', %L, 'published')$q$,
    :'R', tests.photo_for(:'R')
  ),
  '42501', 'R cannot insert an entry as published either'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'B was here', status = 'pending' where id = %L$q$, tests.id('a_new'))) = 0
  and tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('a_new'))) = 0,
  'B still cannot update or delete A''s entry'
);
commit;

select tests.ok(tests.unchanged('a_new', tests.id('a_new')), 'read-back: A''s entry is unchanged');
select tests.ok(tests.unchanged('b_entry', tests.id('b_entry')), 'read-back: B''s entry is unchanged');


\echo '# 11. Returned: hidden from the public, shown to its owner, resubmitted by editing'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(public.review_entry(tests.id('a_new'), 'returned') = true, 'R returns A''s entry and gets true');
select tests.throws(
  format($q$select public.review_entry(%L, 'published')$q$, tests.id('legacy_pending')),
  '23514', 'R cannot publish an entry that has no photo: the CHECK constraint still applies'
);
select tests.ok(
  public.review_entry(tests.id('legacy_pending'), 'returned') = true,
  'R can return the photo-less entry instead'
);
commit;

begin;
set local role anon;
select tests.ok(
  (select count(*) from public.entries where id in (tests.id('a_new'), tests.id('legacy_pending'))) = 0,
  'a visitor cannot see a returned entry'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  (select status from public.entries where id = tests.id('a_new')) = 'returned'
  and (select status from public.entries where id = tests.id('legacy_pending')) = 'returned',
  'A can see that both entries were returned'
);
select tests.throws(
  format($q$update public.entries set context = 'x' where id = %L$q$, tests.id('a_new')),
  '42501', 'A cannot edit it and leave it returned'
);
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'Fixed by A', status = 'pending' where id = %L$q$, tests.id('a_new'))) = 1,
  'A resubmits it by editing it'
);
commit;

select tests.ok(
  (select status from public.entries where id = tests.id('a_new')) = 'pending',
  'it is waiting for review again'
);


\echo '# 12. A reviewer''s own entry: pending when new, may be published, may stay published when edited'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'R', 'នំល្ពៅ', 'Num Lpov (test entry by R)', 'សុខា', 'Everyday snack', '[TEST] R''s entry.', tests.photo_for(:'R'))
  returning id
)
insert into tests.ids (label, id) select 'r_entry', id from created;
select tests.ok(
  (select status from public.entries where id = tests.id('r_entry')) = 'pending',
  'R''s own new entry is pending too'
);
select tests.ok(public.review_entry(tests.id('r_entry'), 'published') = true, 'R may publish R''s own entry');
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'Edited by R' where id = %L$q$, tests.id('r_entry'))) = 1,
  'R''s edit to R''s own published entry keeps it published'
);
select tests.throws(
  format($q$update public.entries set status = 'returned' where id = %L$q$, tests.id('r_entry')),
  '42501', 'R cannot mark R''s own entry returned by a direct update'
);
commit;

begin;
set local role anon;
select tests.ok(
  (select context from public.entries where id = tests.id('r_entry')) = 'Edited by R',
  'a visitor sees the reviewer''s edit at once'
);
commit;


\echo '# 13. Removing a reviewer takes effect on their next request'

delete from public.reviewers where user_id = :'R';

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'R', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'R');
select tests.ok(not public.is_reviewer(), 'R is no longer a reviewer');
select tests.ok(
  (select count(*) from public.entries where id = tests.id('a_new')) = 0,
  'R can no longer see A''s pending entry'
);
select tests.ok(public.review_entry(tests.id('a_new'), 'published') = false, 'review_entry() now returns false for R');
select tests.throws(
  format($q$update public.entries set context = 'After removal' where id = %L$q$, tests.id('r_entry')),
  '42501', 'R''s own published entry now goes back for review when edited, like anyone''s'
);
commit;

select tests.ok(
  (select status from public.entries where id = tests.id('a_new')) = 'pending',
  'read-back: A''s entry is still pending'
);


\echo '# 14. What 0003 must not loosen'

select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'INSERT'
     and with_check like '%auth.uid() = contributor_id%'
     and with_check like '%''pending''%'
     and with_check like '%photo_url IS NOT NULL%') = 1
  and (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries' and cmd = 'INSERT') = 1,
  'one INSERT policy: own id, pending, with a photo'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'UPDATE'
     and qual like '%auth.uid() = contributor_id%'
     and with_check like '%auth.uid() = contributor_id%'
     and with_check like '%photo_url IS NOT NULL%') = 1
  and (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries' and cmd = 'UPDATE') = 1,
  'one UPDATE policy, the owner''s: auth.uid() = contributor_id in USING and WITH CHECK'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'DELETE'
     and qual like '%auth.uid() = contributor_id%') = 1
  and (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries' and cmd = 'DELETE') = 1,
  'one DELETE policy, the owner''s: reviewers cannot delete'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 6,
  'six policies on entries: 0002''s five plus "reviewers can read every entry"'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'reviewers') = 0,
  'no policies on reviewers'
);
select tests.ok(
  (select relrowsecurity from pg_class where oid = 'public.entries'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.reviewers'::regclass),
  'row level security is on for entries and reviewers'
);
select tests.ok(
  not exists (select 1 from pg_trigger where tgrelid = 'public.entries'::regclass and not tgisinternal),
  'no trigger on entries'
);
select tests.ok(
  (select count(*) from pg_constraint
   where conrelid = 'public.entries'::regclass and contype = 'c'
     and conname in (
       'entries_name_khmer_visible', 'entries_name_english_visible', 'entries_told_by_visible',
       'entries_context_visible', 'entries_description_visible',
       'entries_name_khmer_length', 'entries_name_english_length', 'entries_told_by_length',
       'entries_context_length', 'entries_description_length',
       'entries_published_has_photo', 'entries_photo_url_location'
     )) = 12,
  'all twelve of 0002''s CHECK constraints are still there'
);
select tests.ok(
  has_table_privilege('anon', 'public.entries', 'SELECT')
  and not has_table_privilege('anon', 'public.entries', 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN'),
  'a visitor''s only privilege on entries is still SELECT'
);
select tests.ok(
  not has_table_privilege('authenticated', 'public.entries', 'TRUNCATE, REFERENCES, TRIGGER, MAINTAIN')
  and not has_column_privilege('authenticated', 'public.entries', 'contributor_id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.entries', 'created_at', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.entries', 'id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.entries', 'created_at', 'INSERT')
  and not has_column_privilege('authenticated', 'public.entries', 'id', 'INSERT')
  and not has_column_privilege('authenticated', 'public.entries', 'status', 'INSERT'),
  'entries column privileges are 0002''s: owner, id and date fixed; status not chosen on insert'
);
select tests.ok(
  not has_table_privilege('anon', 'public.reviewers', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN')
  and not has_table_privilege('authenticated', 'public.reviewers', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN'),
  'reviewers: no privilege at all for either API role'
);
select tests.ok(
  (select bool_and(prosecdef and proconfig = array['search_path=""'])
   from pg_proc where oid in ('public.is_reviewer()'::regprocedure, 'public.review_entry(uuid, text)'::regprocedure)),
  'is_reviewer() and review_entry() are SECURITY DEFINER with search_path pinned to empty'
);
select tests.ok(
  not has_function_privilege('anon', 'public.is_reviewer()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.review_entry(uuid, text)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.is_reviewer()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.review_entry(uuid, text)', 'EXECUTE'),
  'both functions: signed-in users only'
);
select tests.ok(
  (select column_default from information_schema.columns
   where table_schema = 'public' and table_name = 'entries' and column_name = 'status') like '''pending''%',
  'a new entry defaults to pending'
);


\echo '# Not verified here — the simulated environment has no PostgREST, GoTrue or'
\echo '# Storage service (see the end of 0002-ownership.test.sql). The live check'
\echo '# after rollout: a second account made reviewer, and the attacks above sent'
\echo '# as real API requests with each account''s token. Data carried over by the'
\echo '# rejected -> returned rename is not exercised here: the fixtures hold no'
\echo '# rejected row.'
