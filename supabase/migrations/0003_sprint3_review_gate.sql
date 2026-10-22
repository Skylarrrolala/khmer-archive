-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0003: Sprint 3 — the reviewer gate.
--
-- Sprint 3's brief: an entry stays `pending`, hidden from the public, until a
-- reviewer publishes or returns it, and its contributor can see where it
-- stands. 0002 published on submit; this puts the gate back without loosening
-- anything 0002 tightened.
--
-- Unchanged from 0002: the owner half of every policy
-- (`auth.uid() = contributor_id`), the column privileges on public.entries,
-- every CHECK constraint, the SELECT and DELETE policies, and the photo
-- bucket. No row is updated: entries published under Sprint 2 stay
-- published, and the one older pending entry stays pending.
--
-- tests/db/0003-review-gate.test.sql exercises every rule below.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. `rejected` becomes `returned`.
--
-- Sprint 3 calls an entry sent back to its contributor `returned`. Renaming
-- the value keeps every row that holds it: a row stores a reference to the
-- enum value, not its label, so a row that was `rejected` reads `returned`
-- without being updated. (Adding `returned` beside it instead would leave
-- `rejected` in the type for good: an enum value cannot be dropped.)
-- -----------------------------------------------------------------------------
alter type public.entry_status rename value 'rejected' to 'returned';


-- -----------------------------------------------------------------------------
-- 2. Who is a reviewer.
--
-- One row per reviewer account, added and removed by hand in the SQL editor,
-- which runs as the table owner:
--   insert into public.reviewers (user_id)
--   select id from auth.users where email = '<the reviewer''s address>';
-- -----------------------------------------------------------------------------
create table public.reviewers (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.reviewers enable row level security;

-- No policies and no privileges for either API role: the table cannot be read
-- or written through the API at all. Supabase grants every API role every
-- privilege on a new table (see 0002, section 3), and TRUNCATE ignores RLS, so
-- this revoke is what makes that true.
revoke all on table public.reviewers from anon, authenticated;

-- The one way to ask "am I a reviewer?". SECURITY DEFINER, so it can read a
-- table the caller cannot. It takes no arguments and answers only for
-- auth.uid(), so nobody can use it to ask about another account. The pinned
-- search_path means nothing the caller sets can change what the names inside
-- it refer to. Removing a reviewer's row takes effect on their next request;
-- nothing is cached in their login token.
create function public.is_reviewer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.reviewers where user_id = auth.uid())
$$;

-- Supabase grants EXECUTE on new functions to anon as well.
revoke execute on function public.is_reviewer() from public, anon;
grant execute on function public.is_reviewer() to authenticated;


-- -----------------------------------------------------------------------------
-- 3. New entries wait for review.
--
-- Contributors still cannot write `status` on insert (0002's column
-- privileges, unchanged), so every new row takes this default.
-- -----------------------------------------------------------------------------
alter table public.entries alter column status set default 'pending';

alter policy "contributors can create their own published entries"
  on public.entries
  rename to "contributors can create their own pending entries";

-- A new row must carry its creator's own id, be pending, and have a photo.
-- `status = 'pending'` is the second lock behind the column privilege.
-- `photo_url is not null` keeps Sprint 2's "text plus at least one photo" in
-- the database: 0002 got that from entries_published_has_photo, which no
-- longer reaches a new row now that new rows are pending.
alter policy "contributors can create their own pending entries"
  on public.entries
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
    and photo_url is not null
  );


-- -----------------------------------------------------------------------------
-- 4. An edit goes back for review, unless a reviewer makes it.
--
-- The owner half is identical to 0002: you reach only your own rows (`using`)
-- and they are still yours afterwards (`with check`).
--
-- The status half: a contributor's edited row comes out `pending`, so an
-- approved entry cannot be rewritten in place and stay public, and a returned
-- one is resubmitted by editing it. A reviewer's own row may also come out
-- `published`: their published entry stays published when they edit it, and
-- they may publish their own pending entry. Nobody's own edit can leave a row
-- `returned`; returning is review_entry()'s job (section 5).
--
-- `photo_url is not null`: as in 0002, an edit cannot strip an entry's photo.
-- -----------------------------------------------------------------------------
alter policy "contributors can update their own entries"
  on public.entries
  using (auth.uid() = contributor_id)
  with check (
    auth.uid() = contributor_id
    and photo_url is not null
    and (
      status = 'pending'
      or (status = 'published' and (select public.is_reviewer()))
    )
  );


-- -----------------------------------------------------------------------------
-- 5. Reviewers read every entry, and decide pending ones.
--
-- `(select public.is_reviewer())` rather than a bare call: Postgres then runs
-- it once per statement, not once per row.
--
-- Reading: permissive SELECT policies are OR'd, so a reviewer sees every
-- entry on top of what every contributor sees. The review queue needs it.
-- -----------------------------------------------------------------------------
create policy "reviewers can read every entry"
  on public.entries
  for select
  to authenticated
  using ((select public.is_reviewer()));

-- Deciding: the only way to publish or return somebody else's entry. There is
-- no reviewer UPDATE or DELETE policy on entries, so a reviewer's own UPDATE
-- reaches only their own rows, under section 4.
--
-- SECURITY DEFINER: it runs as the table owner, which RLS does not apply to,
-- so the checks below are the whole gate. Each one that fails returns false
-- and changes nothing:
--   * the caller is not a reviewer;
--   * the decision is not 'published' or 'returned';
--   * the entry does not exist or is not pending. A decision already made
--     cannot be overwritten, and of two reviewers deciding the same entry at
--     once only the first lands.
-- True means the entry's status changed. Only `status` is written, so a
-- reviewer cannot change anyone's text, credit, photo or ownership. The CHECK
-- constraints still apply: publishing an entry with no photo raises 23514.
create function public.review_entry(entry_id uuid, decision text)
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
    and status = 'pending';

  return found;
end
$$;

-- Visitors cannot call it at all; a signed-in non-reviewer gets false.
revoke execute on function public.review_entry(uuid, text) from public, anon;
grant execute on function public.review_entry(uuid, text) to authenticated;

-- Column privileges are 0002's, untouched. `status` stays writable on update
-- for a contributor's own rows, which section 4 limits to 'pending' ('published'
-- too, for a reviewer). review_entry() needs no privilege of the caller's: it
-- runs as the table owner.
