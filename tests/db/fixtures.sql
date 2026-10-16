-- =============================================================================
-- Test fixtures, loaded after 0001_init.sql and supabase/seed.sql and before
-- 0002, as the table owner. Throwaway test database only.
--
-- The seven researched entries come from the real supabase/seed.sql, so the
-- migration is checked against the archive's actual historical rows rather
-- than invented ones. One more row is added here in the shape of the only
-- other row production holds: a contributor's submission from before 0002,
-- still pending, with no photo. Its text is marked as a fixture; it is not a
-- copy of the production row.
-- =============================================================================

\set A '11111111-1111-4111-8111-111111111111'
\set B '22222222-2222-4222-8222-222222222222'

-- Two separate contributor accounts. `.invalid` addresses cannot exist.
insert into auth.users (id, email) values
  (:'A', 'contributor-a@test.invalid'),
  (:'B', 'contributor-b@test.invalid');

insert into public.entries
  (id, contributor_id, name_khmer, name_english, told_by, context, description, status, created_at)
values (
  'aaaaaaaa-0000-4000-8000-00000000000a',
  :'A',
  'នំ',
  '[TEST FIXTURE] older pending submission',
  'Fixture',
  'Fixture',
  '[TEST FIXTURE] Stands in for the one pending row in production: owned, pending, no photo.',
  'pending',
  now() - interval '21 days'
);
insert into tests.ids (label, id) values ('legacy_pending', 'aaaaaaaa-0000-4000-8000-00000000000a');

-- One seed row, by name, to aim attacks at.
insert into tests.ids (label, id)
select 'seed_row', id from public.entries where contributor_id is null order by created_at limit 1;

-- Every row as it stands before 0002, to prove afterwards that the
-- migration changed none of them.
insert into tests.snapshots (label, hash)
select 'before:' || e.id, md5(e::text) from public.entries e;
