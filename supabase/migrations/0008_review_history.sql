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
