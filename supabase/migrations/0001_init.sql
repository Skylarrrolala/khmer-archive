-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0001: entries table, Row Level Security, photo storage bucket.
--
-- Run this once against your Supabase project:
--   Supabase Dashboard -> SQL Editor -> paste -> Run
--   (or `supabase db push` if you use the Supabase CLI)
--
-- Everything below is written so that the SECURITY RULES LIVE IN THE DATABASE.
-- The web app cannot bypass them, because the browser and the Next.js server
-- both connect with the anon key, and Postgres applies these policies to every
-- single query made with that key.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Status type
--
-- An entry is either waiting for review (`pending`), publicly visible
-- (`published`), or was sent back by the reviewer (`rejected`).
-- A dedicated enum type means Postgres itself rejects any other value —
-- we can never end up with a typo'd status like 'publish' that would
-- silently hide (or leak) an entry.
-- -----------------------------------------------------------------------------
create type entry_status as enum ('pending', 'published', 'rejected');


-- -----------------------------------------------------------------------------
-- 2. The entries table — one row per dessert
-- -----------------------------------------------------------------------------
create table public.entries (
  -- Primary key. gen_random_uuid() is built into Postgres 13+, so entry URLs
  -- are unguessable instead of sequential (/entries/1, /entries/2, ...).
  id uuid primary key default gen_random_uuid(),

  -- The dessert itself.
  name_khmer   text not null check (length(trim(name_khmer)) > 0),
  name_english text not null check (length(trim(name_english)) > 0),

  -- Which grandparent shared it. Required: every entry credits its source
  -- by name, with their permission.
  told_by      text not null check (length(trim(told_by)) > 0),

  -- When/why it is made — festival, daily life, special occasion.
  -- Also the second field the public search looks at.
  context      text not null check (length(trim(context)) > 0),

  -- The story or memory behind it, plus ingredients/method if known.
  description  text not null check (length(trim(description)) > 0),

  -- Nullable on purpose. Desserts they still make get a real photo;
  -- desserts they only remember may have no photo at all.
  photo_url    text,

  -- Review workflow. New rows are `pending` and therefore invisible to the
  -- public until a reviewer flips them to `published` (Sprint 3).
  status       entry_status not null default 'pending',

  -- Who submitted it. References Supabase Auth's user table.
  -- `on delete cascade`: if a contributor's account is deleted, their entries
  -- go with it, so we never have orphan rows nobody can edit.
  -- Nullable so that seed/demo rows can exist with no owner.
  contributor_id uuid references auth.users(id) on delete cascade,

  created_at timestamptz not null default now()
);

-- Indexes that match the queries the app actually runs.
-- The public list page always filters on status and orders by created_at.
create index entries_status_created_at_idx
  on public.entries (status, created_at desc);

-- The "my entries" page (Sprint 2) always filters on contributor_id.
create index entries_contributor_id_idx
  on public.entries (contributor_id);


-- -----------------------------------------------------------------------------
-- 3. Row Level Security
--
-- THIS IS THE PART THAT ACTUALLY ENFORCES OWNERSHIP.
--
-- `enable row level security` switches the table to deny-by-default: once it
-- is on, a client using the anon key can see and change NOTHING until a
-- policy explicitly allows it. Hiding a button in React changes nothing here.
--
-- In every policy below, `auth.uid()` is a Supabase helper that reads the
-- user id out of the JWT attached to the request. A logged-out request has
-- auth.uid() = null, so any policy comparing against it fails closed.
-- -----------------------------------------------------------------------------
alter table public.entries enable row level security;

-- READ: anyone at all (logged in or not) may read PUBLISHED entries only.
-- Because this is a policy and not an app-level `.eq('status','published')`,
-- a pending entry can never leak — not through a forgotten filter, not
-- through someone hand-crafting a request to the Supabase REST API.
create policy "published entries are readable by everyone"
  on public.entries
  for select
  to anon, authenticated
  using (status = 'published');

-- READ: a logged-in contributor may additionally read their OWN entries,
-- whatever the status. This is what powers the "my entries" page and lets
-- contributors see whether their submission is pending or published.
create policy "contributors can read their own entries"
  on public.entries
  for select
  to authenticated
  using (auth.uid() = contributor_id);

-- INSERT: a logged-in user may create a row ONLY if they stamp it with their
-- own id and leave it pending.
--   - `auth.uid() = contributor_id` stops user A submitting an entry
--     attributed to user B.
--   - `status = 'pending'` stops a contributor self-publishing straight to
--     the public page, which is the whole point of the review workflow.
create policy "contributors can create their own pending entries"
  on public.entries
  for insert
  to authenticated
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
  );

-- UPDATE: a logged-in user may edit ONLY their own rows.
--   `using`      -> which existing rows they are allowed to touch.
--   `with check` -> what the row is allowed to look like afterwards.
-- Both are needed. Without `with check`, a contributor could edit their own
-- row and, in the same statement, hand it to someone else or set
-- status = 'published'. The `status = 'pending'` in the check means an edit
-- sends the entry back through review, exactly as Sprint 3 requires.
create policy "contributors can update their own entries"
  on public.entries
  for update
  to authenticated
  using (auth.uid() = contributor_id)
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
  );

-- DELETE: a logged-in user may delete ONLY their own rows.
create policy "contributors can delete their own entries"
  on public.entries
  for delete
  to authenticated
  using (auth.uid() = contributor_id);

-- Note on the reviewer: there is deliberately NO policy here that lets a
-- normal logged-in user set status = 'published'. Sprint 3 adds the reviewer
-- path. Until then, publishing is done by hand in the Supabase dashboard,
-- which uses the service role key and bypasses RLS.


-- -----------------------------------------------------------------------------
-- 4. Photo storage
--
-- Supabase Storage is itself a Postgres table (`storage.objects`) with RLS,
-- so photo permissions are written the same way as row permissions.
-- `public => true` means files can be read over a plain URL, which is what
-- lets <Image> render them on the public browse page without a signed URL.
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('entry-photos', 'entry-photos', true)
on conflict (id) do nothing;

-- Anyone may read the photos (the archive is public).
create policy "entry photos are readable by everyone"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'entry-photos');

-- A logged-in contributor may upload only INTO A FOLDER NAMED AFTER THEIR
-- OWN USER ID, e.g. `entry-photos/<uid>/num-ansom.jpg`.
-- `storage.foldername(name)` splits the object path on '/', so
-- `(storage.foldername(name))[1]` is that first folder. Comparing it to
-- auth.uid() is the storage equivalent of the ownership check above:
-- it stops one contributor writing into, or overwriting, another's folder.
create policy "contributors can upload photos to their own folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "contributors can update photos in their own folder"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "contributors can delete photos in their own folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
