-- =============================================================================
-- Khmer Living Archive — Desserts Edition
-- Migration 0006: how much one contributor can submit and upload.
--
-- Review finding M3. Nothing limited how many entries or photos one account
-- could send, through the app or straight to Supabase's API. Three limits, the
-- same for every signed-in account, reviewers included:
--
--   5   pending entries at a time      new entries only; an edit never counts
--   20  photo uploads per rolling 24 h
--   10  photos no entry uses
--
-- Where each is enforced, and how far that holds:
--
--   * Entries are written through PostgREST in an ordinary transaction, so
--     the entries insert policy can lock, count and refuse (section 3). That
--     holds when several requests arrive at once.
--
--   * Photo uploads are counted by claim_photo_upload() (section 4), which
--     the app calls before it processes a photo (lib/photos.ts). One call is
--     one row in photo_upload_claims, in its own transaction.
--
--   * An upload sent straight to the Storage API never calls it. Storage
--     runs this project's upload policy only as a probe that it rolls back,
--     then writes the row itself with policies off (supabase/storage,
--     src/storage/uploader.ts, read 6 Nov 2026). So the upload policy can
--     refuse, but it cannot record anything, and a lock taken inside it is
--     released before the real write. Section 5 is therefore best effort: it
--     stops uploads sent one after another, not a burst sent at once, and not
--     uploading and deleting in a loop. That path costs the app nothing: it
--     never reaches the image processing.
--
-- Refusals use their own error codes, so the app can say which limit:
--   KA001  pending entries     KA002  uploads in 24 h     KA003  unused photos
--
-- A request with no user id — the founder in the SQL editor — is not limited.
-- Nothing here changes a row or a file.
--
-- tests/db/0006-limits.test.sql exercises every rule below, including two
-- connections racing each other.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. The upload log.
--
-- One row per photo upload the app was allowed to start. Only the functions
-- below write it; no API role can read or write it. A row is never removed
-- when an upload later fails: the photo may already have been decoded by then,
-- and a refund would let someone run the decoder without limit.
-- -----------------------------------------------------------------------------
create table public.photo_upload_claims (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  claimed_at timestamptz not null default now()
);

create index photo_upload_claims_user_time_idx
  on public.photo_upload_claims (user_id, claimed_at);

alter table public.photo_upload_claims enable row level security;
revoke all on table public.photo_upload_claims from anon, authenticated;


-- -----------------------------------------------------------------------------
-- 2. Shared helpers. Internal: no API role may call them.
--
-- limits_lock() makes one user's limited writes wait for each other, until the
-- transaction that holds it ends. Other users never wait. After it returns,
-- each statement in these plpgsql functions takes a fresh snapshot, so a count
-- made after the lock sees the row the previous holder committed.
--
-- unused_photo_count() is 0004's "in use" test turned round: files in the
-- user's folder that no entry, of any status, points at.
-- -----------------------------------------------------------------------------
create function public.limits_lock(user_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('khmer-archive:limits:' || user_id::text, 0))
$$;

create function public.pending_entry_count(user_id uuid)
returns bigint
language sql
volatile
security definer
set search_path = ''
as $$
  select count(*) from public.entries e
  where e.contributor_id = pending_entry_count.user_id and e.status = 'pending'
$$;

create function public.unused_photo_count(user_id uuid)
returns bigint
language sql
volatile
security definer
set search_path = ''
as $$
  select count(*) from storage.objects o
  where o.bucket_id = 'entry-photos'
    and (storage.foldername(o.name))[1] = unused_photo_count.user_id::text
    and not exists (
      select 1 from public.entries e
      where split_part(e.photo_url, '/storage/v1/object/public/entry-photos/', 2) = o.name
    )
$$;

revoke execute on function public.limits_lock(uuid)         from public, anon, authenticated;
revoke execute on function public.pending_entry_count(uuid) from public, anon, authenticated;
revoke execute on function public.unused_photo_count(uuid)  from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- 3. Five pending entries.
--
-- Called from the entries insert policy. Only inserts are limited: an edit
-- that sends a published or returned entry back to pending creates nothing
-- new, so it is never refused. The row being inserted is not counted: a
-- policy is checked before the row is written. It refuses by raising KA001
-- rather than returning false, so the app can tell this from any other
-- refusal; otherwise it returns true.
-- -----------------------------------------------------------------------------
create function public.check_entry_limit()
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return true;
  end if;

  perform public.limits_lock(uid);

  if public.pending_entry_count(uid) >= 5 then
    raise exception 'pending entry limit reached' using errcode = 'KA001';
  end if;

  return true;
end
$$;

revoke execute on function public.check_entry_limit() from public, anon;
grant execute on function public.check_entry_limit() to authenticated;

alter policy "contributors can create their own pending entries"
  on public.entries
  with check (
    auth.uid() = contributor_id
    and status = 'pending'
    and photo_url is not null
    and public.check_entry_limit()
  );


-- -----------------------------------------------------------------------------
-- 4. Claiming an upload: what the app calls before processing a photo.
--
-- Checks, in order, under the user's lock: the pending limit (only for a
-- photo that will become a new entry, so a contributor is told before the
-- upload rather than after it), the 24-hour limit, the unused-photo limit.
-- Then records the claim. It returns nothing; a refusal is an error with its
-- code, and a refused claim records nothing.
-- -----------------------------------------------------------------------------
create function public.claim_photo_upload(for_new_entry boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  perform public.limits_lock(uid);

  if for_new_entry and public.pending_entry_count(uid) >= 5 then
    raise exception 'pending entry limit reached' using errcode = 'KA001';
  end if;

  if (select count(*) from public.photo_upload_claims c
      where c.user_id = uid and c.claimed_at > now() - interval '24 hours') >= 20 then
    raise exception 'daily upload limit reached' using errcode = 'KA002';
  end if;

  if public.unused_photo_count(uid) >= 10 then
    raise exception 'unused photo limit reached' using errcode = 'KA003';
  end if;

  insert into public.photo_upload_claims (user_id) values (uid);
end
$$;

revoke execute on function public.claim_photo_upload(boolean) from public, anon;
grant execute on function public.claim_photo_upload(boolean) to authenticated;


-- -----------------------------------------------------------------------------
-- 5. The upload policy: best effort for uploads that skip the app.
--
-- Read-only, no lock, returns false rather than raising, so Storage answers
-- with its ordinary "not allowed". It counts the files themselves, since
-- Storage never lets the policy record anything: fewer than 10 unused, and
-- fewer than 20 created in the last 24 hours. An upload through the app has
-- already passed claim_photo_upload(), which allows no more than that, so
-- this does not refuse it.
-- -----------------------------------------------------------------------------
create function public.photo_upload_allowed()
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.unused_photo_count(auth.uid()) < 10
    and (select count(*) from storage.objects o
         where o.bucket_id = 'entry-photos'
           and (storage.foldername(o.name))[1] = auth.uid()::text
           and o.created_at > now() - interval '24 hours') < 20
$$;

revoke execute on function public.photo_upload_allowed() from public, anon;
grant execute on function public.photo_upload_allowed() to authenticated;

alter policy "contributors can upload photos to their own folder"
  on storage.objects
  with check (
    bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.photo_in_use(name)
    and public.photo_upload_allowed()
  );
