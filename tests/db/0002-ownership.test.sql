-- =============================================================================
-- Ownership and input rules after migration 0002, tested as the people who
-- would actually send the requests: an anonymous visitor, contributor A and
-- contributor B.
--
-- Each scenario switches identity the way PostgREST does for a real API
-- request: it puts the user's id in `request.jwt.claims`, which is what
-- auth.uid() reads, and then `set local role` to anon or authenticated. Each
-- one then calls tests.acting_as() to prove it is not a superuser, not
-- BYPASSRLS and not the table owner — any of those would skip RLS and make a
-- passing test meaningless.
--
-- Read-back is done as the table owner, comparing a hash of the whole row
-- before and after, plus as the visitor who would see the page.
--
-- Run by scripts/test-db.sh. Throwaway test database only.
-- =============================================================================

\set A '11111111-1111-4111-8111-111111111111'
\set B '22222222-2222-4222-8222-222222222222'
\set ON_ERROR_STOP on


\echo '# 0. The tests run through RLS, not around it'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
commit;

begin;
set local role anon;
select tests.acting_as('anon', null);
commit;


\echo '# 1. 0002 left every existing row exactly as it was'

select tests.ok(
  (select count(*) from tests.snapshots where label like 'before:%') = 8,
  'eight rows existed before 0002: the seven researched entries and one older pending submission'
);
select tests.ok(
  not exists (
    select 1 from tests.snapshots s
    where s.label like 'before:%'
      and s.hash is distinct from (
        select md5(e::text) from public.entries e where 'before:' || e.id = s.label
      )
  ),
  'every one of those rows is byte-for-byte unchanged after 0002'
);
select tests.ok(
  (select status from public.entries where id = tests.id('legacy_pending')) = 'pending',
  'the older pending submission was not published by the migration'
);
select tests.ok(
  (select count(*) from public.entries where contributor_id is null and status = 'published' and photo_url like '/entries/%') = 7,
  'the seven researched entries are published, with their photographs, under the new photo rules'
);


\echo '# 2. A visitor can read published entries and change nothing'

begin;
set local role anon;
select tests.acting_as('anon', null);
select tests.ok((select count(*) from public.entries) = 7, 'a visitor sees the seven published entries');
select tests.ok(
  (select count(*) from public.entries where id = tests.id('legacy_pending')) = 0,
  'a visitor cannot see the pending submission'
);
select tests.throws(
  $q$insert into public.entries (name_khmer, name_english, told_by, context, description) values ('នំ', 'x', 'x', 'x', 'x')$q$,
  '42501', 'a visitor cannot insert'
);
select tests.throws($q$update public.entries set context = 'x'$q$, '42501', 'a visitor cannot update');
select tests.throws($q$delete from public.entries$q$, '42501', 'a visitor cannot delete');
select tests.throws($q$truncate public.entries$q$, '42501', 'a visitor cannot truncate');
commit;


\echo '# 3. A new entry is public the moment it is saved'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'A', 'នំកង', 'Num Kong (test entry by A)', 'Dara', 'Everyday snack', '[TEST] A''s entry.', tests.photo_for(:'A'))
  returning id
)
insert into tests.ids (label, id) select 'a_entry', id from created;
select tests.ok(
  (select status from public.entries where id = tests.id('a_entry')) = 'published',
  'A''s new entry is published without A asking for it'
);
select tests.ok(
  (select created_at > now() - interval '1 minute' from public.entries where id = tests.id('a_entry')),
  'its created_at was set by the database'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
with created as (
  insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url)
  values (:'B', 'នំអន្សម', 'Num Ansorm (test entry by B)', 'សុខា', 'Festival', '[TEST] B''s entry.', tests.photo_for(:'B', 'webp'))
  returning id
)
insert into tests.ids (label, id) select 'b_entry', id from created;
select tests.ok(
  (select status from public.entries where id = tests.id('b_entry')) = 'published',
  'B can contribute too, also published at once'
);
commit;

begin;
set local role anon;
select tests.ok(
  (select count(*) from public.entries where id in (tests.id('a_entry'), tests.id('b_entry'))) = 2,
  'a signed-out visitor sees both new entries immediately'
);
commit;


\echo '# 4. On insert, a contributor cannot choose the owner, status, id or date'

insert into tests.snapshots (label, hash)
select 'count_b_rows', count(*)::text from public.entries where contributor_id = :'B';

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, 'នំ', 'Forged', 'x', 'x', 'x', %L)$q$,
    :'B', tests.photo_for(:'B')
  ),
  '42501', 'A cannot create an entry in B''s name (forged contributor_id)'
);
select tests.throws(
  format(
    $q$insert into public.entries (name_khmer, name_english, told_by, context, description, photo_url) values ('នំ', 'Ownerless', 'x', 'x', 'x', %L)$q$,
    tests.photo_for(:'A')
  ),
  '42501', 'A cannot create an entry with no owner'
);
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url, status) values (%L, 'នំ', 'x', 'x', 'x', 'x', %L, 'pending')$q$,
    :'A', tests.photo_for(:'A')
  ),
  '42501', 'A cannot choose a status on insert, not even pending'
);
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url, created_at) values (%L, 'នំ', 'x', 'x', 'x', 'x', %L, '2030-01-01')$q$,
    :'A', tests.photo_for(:'A')
  ),
  '42501', 'A cannot backdate or postdate an entry with created_at'
);
select tests.throws(
  format(
    $q$insert into public.entries (id, contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (gen_random_uuid(), %L, 'នំ', 'x', 'x', 'x', 'x', %L)$q$,
    :'A', tests.photo_for(:'A')
  ),
  '42501', 'A cannot choose an entry''s id'
);
commit;

select tests.ok(
  (select count(*)::text from public.entries where contributor_id = :'B')
    = (select hash from tests.snapshots where label = 'count_b_rows'),
  'B still owns exactly the entries B created'
);


\echo '# 5. B attacks A''s entry: nothing changes, and read-back proves it'

select tests.snapshot('a_entry', tests.id('a_entry'));
select tests.snapshot('legacy_pending', tests.id('legacy_pending'));
select tests.snapshot('seed_row', tests.id('seed_row'));

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  (select count(*) from public.entries where id = tests.id('a_entry')) = 1,
  'B can see A''s entry, as any visitor can, so the attempts below are aimed at a real row'
);
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'B was here' where id = %L$q$, tests.id('a_entry'))) = 0,
  'B''s update of A''s entry changes 0 rows'
);
select tests.ok(
  tests.affected(format($q$update public.entries set description = 'B was here', status = 'published' where id = %L$q$, tests.id('a_entry'))) = 0,
  'B''s update of A''s entry changes 0 rows even with a status the policy would accept'
);
select tests.throws(
  format($q$update public.entries set contributor_id = %L where id = %L$q$, :'B', tests.id('a_entry')),
  '42501', 'B cannot take A''s entry by rewriting its owner'
);
select tests.ok(
  tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('a_entry'))) = 0,
  'B''s delete of A''s entry deletes 0 rows'
);
select tests.ok(
  (select count(*) from public.entries where id = tests.id('legacy_pending')) = 0,
  'B cannot see A''s pending submission'
);
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'B was here' where id = %L$q$, tests.id('legacy_pending'))) = 0
  and tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('legacy_pending'))) = 0,
  'B cannot update or delete A''s pending submission'
);
select tests.ok(
  tests.affected(format($q$update public.entries set context = 'B was here' where id = %L$q$, tests.id('seed_row'))) = 0
  and tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('seed_row'))) = 0,
  'B cannot update or delete a researched entry that has no owner'
);
select tests.throws($q$truncate public.entries$q$, '42501', 'a contributor cannot truncate the table');
commit;

-- Read-back, as the table owner: whole-row hashes.
select tests.ok(tests.unchanged('a_entry', tests.id('a_entry')), 'read-back: A''s entry is byte-for-byte unchanged');
select tests.ok(tests.unchanged('legacy_pending', tests.id('legacy_pending')), 'read-back: the pending submission is unchanged');
select tests.ok(tests.unchanged('seed_row', tests.id('seed_row')), 'read-back: the researched entry is unchanged');
select tests.ok((select count(*) from public.entries where contributor_id is null) = 7, 'read-back: all seven researched entries still exist');

-- Read-back, as the public sees it.
begin;
set local role anon;
select tests.ok(
  (select context from public.entries where id = tests.id('a_entry')) = 'Everyday snack',
  'read-back: a visitor still sees A''s original text'
);
commit;


\echo '# 6. A on A''s own entry: ownership and dates are fixed, status only publishes'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format($q$update public.entries set contributor_id = %L where id = %L$q$, :'B', tests.id('a_entry')),
  '42501', 'A cannot hand A''s own entry to B (ownership reassignment)'
);
select tests.throws(
  format($q$update public.entries set created_at = '2030-01-01' where id = %L$q$, tests.id('a_entry')),
  '42501', 'A cannot move A''s entry to the top by rewriting created_at'
);
select tests.throws(
  format($q$update public.entries set id = gen_random_uuid() where id = %L$q$, tests.id('a_entry')),
  '42501', 'A cannot change an entry''s id and break links to it'
);
select tests.throws(
  format($q$update public.entries set status = 'pending' where id = %L$q$, tests.id('a_entry')),
  '42501', 'A cannot set an entry back to pending'
);
select tests.throws(
  format($q$update public.entries set status = 'rejected' where id = %L$q$, tests.id('a_entry')),
  '42501', 'A cannot set an entry to rejected'
);
select tests.throws(
  format($q$update public.entries set photo_url = null where id = %L$q$, tests.id('a_entry')),
  '23514', 'A cannot strip the photo from a published entry'
);
select tests.throws(
  format($q$update public.entries set photo_url = %L where id = %L$q$, tests.photo_for(:'B'), tests.id('a_entry')),
  '23514', 'A cannot point A''s entry at a photo in B''s folder'
);
commit;

select tests.ok(tests.unchanged('a_entry', tests.id('a_entry')), 'read-back: every refused change left A''s entry unchanged');

insert into tests.snapshots (label, hash)
select 'a_entry_created_at', created_at::text from public.entries where id = tests.id('a_entry');

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(
  tests.affected(format(
    $q$update public.entries set context = 'Edited by A', photo_url = %L, status = 'published' where id = %L$q$,
    tests.photo_for(:'A', 'png'), tests.id('a_entry')
  )) = 1,
  'A can edit A''s own entry, including replacing its photo with another of A''s'
);
commit;

select tests.ok(
  (select status = 'published'
          and contributor_id = :'A'
          and created_at::text = (select hash from tests.snapshots where label = 'a_entry_created_at')
   from public.entries where id = tests.id('a_entry')),
  'after the edit it is still published, still A''s, with its original date'
);

begin;
set local role anon;
select tests.ok(
  (select context from public.entries where id = tests.id('a_entry')) = 'Edited by A',
  'a visitor sees the edit immediately'
);
commit;


\echo '# 7. The older pending submission cannot be published without a photo'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format($q$update public.entries set context = 'x', status = 'published' where id = %L$q$, tests.id('legacy_pending')),
  '23514', 'publishing it by editing, with no photo, is refused'
);
select tests.throws(
  format($q$update public.entries set context = 'x' where id = %L$q$, tests.id('legacy_pending')),
  '42501', 'editing it while leaving it pending is refused: an edit must publish'
);
commit;

select tests.ok(
  tests.unchanged('legacy_pending', tests.id('legacy_pending'))
  and (select status from public.entries where id = tests.id('legacy_pending')) = 'pending',
  'read-back: it is untouched and still unpublished'
);


\echo '# 8. Required text means visible text, in every field'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, %L, %L, %L, %L, %L, %L)$q$,
    :'A',
    case when f.col = 'name_khmer'   then b.v else 'នំ'   end,
    case when f.col = 'name_english' then b.v else 'Num'  end,
    case when f.col = 'told_by'      then b.v else 'Dara' end,
    case when f.col = 'context'      then b.v else 'x'    end,
    case when f.col = 'description'  then b.v else 'x'    end,
    tests.photo_for(:'A')
  ),
  '23514',
  format('%s made only of %s is refused', f.col, b.label)
)
from (values ('name_khmer'), ('name_english'), ('told_by'), ('context'), ('description')) as f(col)
cross join (values
  ('',                   'nothing'),
  ('   ',                'spaces'),
  (E'\t\n',              'a tab and a newline'),
  (U&'\00A0',            'a non-breaking space'),
  (U&'\200B',            'a zero-width space'),
  (U&'\3000\200D\2060',  'an ideographic space, a joiner and a word joiner'),
  (U&'\FEFF',            'a byte-order mark')
) as b(v, label);
commit;


\echo '# 9. Khmer, single names and the length limits'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(
  tests.affected(format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, 'នំកង', 'នំកង', 'សុខា', 'ពិធីបុណ្យភ្ជុំបិណ្ឌ', 'នំនេះធ្វើពីម្សៅអង្ករ។', %L)$q$,
    :'A', tests.photo_for(:'A')
  )) = 1,
  'Khmer is accepted in all five text fields'
);
select tests.ok(
  tests.affected(format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, %L, 'Num', 'Dara', 'x', 'x', %L)$q$,
    :'A', U&'\1793\17C6\200B\1780\1784', tests.photo_for(:'A')
  )) = 1,
  'a zero-width space between Khmer words is accepted'
);
select tests.ok(
  tests.affected(format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, 'នំ', 'Num', 'Son', 'x', 'x', %L)$q$,
    :'A', tests.photo_for(:'A')
  )) = 1,
  'a single-word name is a complete told_by'
);
rollback;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.ok(
  tests.affected(format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, %L, %L, %L, %L, %L, %L)$q$,
    :'A',
    case when l.col = 'name_khmer'   then repeat('ក', l.max) else 'នំ'   end,
    case when l.col = 'name_english' then repeat('ក', l.max) else 'Num'  end,
    case when l.col = 'told_by'      then repeat('ក', l.max) else 'Dara' end,
    case when l.col = 'context'      then repeat('ក', l.max) else 'x'    end,
    case when l.col = 'description'  then repeat('ក', l.max) else 'x'    end,
    tests.photo_for(:'A')
  )) = 1,
  format('%s of exactly %s Khmer characters is accepted', l.col, l.max)
)
from (values ('name_khmer', 120), ('name_english', 150), ('told_by', 120), ('context', 300), ('description', 8000)) as l(col, max);
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, %L, %L, %L, %L, %L, %L)$q$,
    :'A',
    case when l.col = 'name_khmer'   then repeat('ក', l.max + 1) else 'នំ'   end,
    case when l.col = 'name_english' then repeat('ក', l.max + 1) else 'Num'  end,
    case when l.col = 'told_by'      then repeat('ក', l.max + 1) else 'Dara' end,
    case when l.col = 'context'      then repeat('ក', l.max + 1) else 'x'    end,
    case when l.col = 'description'  then repeat('ក', l.max + 1) else 'x'    end,
    tests.photo_for(:'A')
  ),
  '23514',
  format('%s of %s characters is refused', l.col, l.max + 1)
)
from (values ('name_khmer', 120), ('name_english', 150), ('told_by', 120), ('context', 300), ('description', 8000)) as l(col, max);
rollback;


\echo '# 10. A published entry needs a photo, and it must be the owner''s own'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.throws(
  format(
    $q$insert into public.entries (contributor_id, name_khmer, name_english, told_by, context, description, photo_url) values (%L, 'នំ', 'Num', 'Dara', 'x', 'x', %L)$q$,
    :'A', p.url
  ),
  '23514',
  format('a new entry with %s is refused', p.label)
)
from (values
  (null::text, 'no photo'),
  (tests.photo_for('22222222-2222-4222-8222-222222222222'), 'a photo from B''s folder'),
  ('https://evil.example/cat.jpg', 'a photo from another website'),
  ('https://test-project.supabase.co/storage/v1/object/public/entry-photos/11111111-1111-4111-8111-111111111111/cat.jpg', 'a photo whose filename the app did not generate'),
  (replace(tests.photo_for('11111111-1111-4111-8111-111111111111'), '.jpg', '.gif'), 'a GIF'),
  (replace(tests.photo_for('11111111-1111-4111-8111-111111111111'), '/entry-photos/', '/other-bucket/'), 'a photo from another bucket'),
  ('/entries/num-kong.jpg', 'one of the app''s own researched photographs')
) as p(url, label);
commit;


\echo '# 11. A deletes A''s own entry'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format($q$delete from public.entries where id = %L$q$, tests.id('a_entry'))) = 1,
  'A''s delete of A''s own entry deletes exactly 1 row'
);
commit;

begin;
set local role anon;
select tests.ok(
  (select count(*) from public.entries where id = tests.id('a_entry')) = 0
  and (select count(*) from public.entries where id = tests.id('b_entry')) = 1,
  'a visitor no longer sees A''s entry, and B''s is still there'
);
commit;


\echo '# 12. Storage folders (0001''s Storage policies, unchanged, at the SQL layer only)'

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'A', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'A');
select tests.ok(
  tests.affected(format(
    $q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$,
    :'A' || '/aaaaaaaa-1111-4111-8111-000000000001.jpg'
  )) = 1,
  'A can store a photo in A''s own folder'
);
select tests.throws(
  format($q$insert into storage.objects (bucket_id, name) values ('entry-photos', %L)$q$, :'B' || '/x.jpg'),
  '42501', 'A cannot store a photo in B''s folder'
);
commit;

begin;
select set_config('request.jwt.claims', json_build_object('sub', :'B', 'role', 'authenticated')::text, true);
set local role authenticated;
select tests.acting_as('authenticated', :'B');
select tests.ok(
  tests.affected(format($q$delete from storage.objects where name = %L$q$, :'A' || '/aaaaaaaa-1111-4111-8111-000000000001.jpg')) = 0
  and tests.affected(format($q$update storage.objects set name = 'stolen.jpg' where name = %L$q$, :'A' || '/aaaaaaaa-1111-4111-8111-000000000001.jpg')) = 0,
  'B cannot delete or rename A''s photo'
);
commit;

begin;
set local role anon;
select tests.throws(
  $q$insert into storage.objects (bucket_id, name) values ('entry-photos', 'anon/x.jpg')$q$,
  '42501', 'a visitor cannot store a photo'
);
commit;

select tests.ok(
  (select count(*) from storage.objects where name = '11111111-1111-4111-8111-111111111111/aaaaaaaa-1111-4111-8111-000000000001.jpg') = 1,
  'read-back: A''s photo object is still there under its own name'
);
select tests.ok(
  (select file_size_limit = 4194304 and allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
   from storage.buckets where id = 'entry-photos'),
  'the photo bucket now records a 4 MiB limit and the three image types'
);


\echo '# 13. The rules that must never loosen are still in place'

select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'INSERT'
     and with_check like '%auth.uid() = contributor_id%') = 1,
  'INSERT WITH CHECK still requires auth.uid() = contributor_id'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'UPDATE'
     and qual like '%auth.uid() = contributor_id%'
     and with_check like '%auth.uid() = contributor_id%') = 1,
  'UPDATE USING and UPDATE WITH CHECK both still require auth.uid() = contributor_id'
);
select tests.ok(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'entries' and cmd = 'DELETE'
     and qual like '%auth.uid() = contributor_id%') = 1,
  'DELETE USING still requires auth.uid() = contributor_id'
);
select tests.ok(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'entries') = 5,
  'there are still exactly five policies on entries, so none was added beside them'
);
select tests.ok(
  (select relrowsecurity from pg_class where oid = 'public.entries'::regclass),
  'row level security is still on'
);
select tests.ok(
  has_table_privilege('anon', 'public.entries', 'SELECT')
  and not has_table_privilege('anon', 'public.entries', 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN'),
  'a visitor''s only privilege is SELECT'
);
select tests.ok(
  not has_table_privilege('authenticated', 'public.entries', 'TRUNCATE, REFERENCES, TRIGGER, MAINTAIN'),
  'a contributor has no TRUNCATE, REFERENCES, TRIGGER or MAINTAIN'
);
select tests.ok(
  not has_column_privilege('authenticated', 'public.entries', 'contributor_id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.entries', 'created_at', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.entries', 'id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.entries', 'created_at', 'INSERT')
  and not has_column_privilege('authenticated', 'public.entries', 'id', 'INSERT')
  and not has_column_privilege('authenticated', 'public.entries', 'status', 'INSERT'),
  'owner, id and date cannot be written by a contributor; status cannot be chosen on insert'
);


\echo '# Not verified here — the simulated environment has no:'
\echo '#   - Storage API service: whether it enforces the bucket''s 4 MiB limit and image types on upload'
\echo '#   - PostgREST: HTTP requests, its JWT-to-role switching, and how it maps 42501/23514 to HTTP errors'
\echo '#   - GoTrue: sign-up, sign-in, email confirmation and the JWTs themselves'
\echo '#   - Supabase''s exact platform setup: event triggers, extensions, ownership by supabase_admin'
\echo '# Those need the live two-account test in scripts/verify-rls.sh, run after rollout.'
