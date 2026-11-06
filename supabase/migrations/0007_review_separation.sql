-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0007: nobody reviews their own entry.
--
-- Review finding M4, first half. 0003 let a reviewer publish their own work
-- three ways:
--   * review_entry() on their own pending entry: it checked that the caller
--     was a reviewer and the entry pending, never whose entry it was;
--   * a direct update setting their own entry to 'published', from any status:
--     the update policy accepted 'published' from a reviewer. That included an
--     entry another reviewer had returned, which review_entry() would refuse;
--   * an edit to their own published entry, which stayed published, so any new
--     text or photo went public unreviewed. That last one also undid H1 (0004)
--     for reviewers: 0004 relies on "a new photo means an edit, and an edit
--     goes back for review".
--
-- After this file, an edit by anyone comes out 'pending', and the only way to
-- publish or return an entry through the API is review_entry() on somebody
-- else's. A reviewer's own entry needs a second reviewer, or the founder
-- working in the dashboard, which no policy applies to.
--
-- Unchanged: who may edit (the owner, `using`), the column privileges, every
-- CHECK constraint, the SELECT, INSERT and DELETE policies, and the reviewers
-- table. No row is changed: entries published before this stay published.
--
-- tests/db/0007-review-separation.test.sql exercises every rule below.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. review_entry() refuses the caller's own entries.
--
-- Same signature, so 0003's grants carry over: signed-in users may call it,
-- visitors may not. A refusal is `false`, like its other refusals, and changes
-- nothing. `is distinct from` rather than `<>` so an entry with no owner (the
-- researched seed rows) can still be reviewed: `<>` with a null is never true.
-- -----------------------------------------------------------------------------
create or replace function public.review_entry(entry_id uuid, decision text)
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
    and status = 'pending'
    and contributor_id is distinct from auth.uid();

  return found;
end
$$;


-- -----------------------------------------------------------------------------
-- 2. Every edit goes back for review.
--
-- 0003's reviewer branch, `status = 'published' and is_reviewer()`, is gone.
-- The owner half is identical: you reach only your own rows (`using`) and they
-- are still yours afterwards (`with check`).
-- -----------------------------------------------------------------------------
alter policy "contributors can update their own entries"
  on public.entries
  using (auth.uid() = contributor_id)
  with check (
    auth.uid() = contributor_id
    and photo_url is not null
    and status = 'pending'
  );
