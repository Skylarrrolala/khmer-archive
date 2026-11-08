import { EntryWriteError } from "@/lib/save-with-photo";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Entry } from "@/lib/types";

/**
 * Every query against `public.entries` goes through this file, so there is
 * exactly one place to check when asking "can an unpublished entry leak?".
 *
 * Sprint 2 adds a contributor's own reads and the one write. They are here for
 * the same reason the public reads are: a single auditable surface. Note what
 * none of these functions do — none of them checks ownership in JavaScript.
 * The RLS policies in supabase/migrations/0001_init.sql do that, inside
 * Postgres, on every statement. The filters below say what this app is asking
 * for; the policies decide what it is allowed to have.
 */

/**
 * PostgREST's `or(...)` filter is a comma-separated list, and its pattern
 * matching treats `%` and `*` as wildcards. If a visitor typed a comma or a
 * parenthesis into the search box, it would be parsed as filter syntax rather
 * than as text, and the query would break (or match more than intended).
 *
 * So the search term is reduced to plain text: the characters that carry
 * meaning in a filter are dropped, and the length is capped so nobody can send
 * a megabyte-long pattern.
 *
 * Note this is not the app's security boundary — RLS is. This is about the
 * query doing what the visitor meant.
 */
function sanitizeSearchTerm(raw: string) {
  return raw.replace(/[,()%*\\"']/g, " ").trim().slice(0, 80);
}

/**
 * Fetches the published entries for the public browse page.
 *
 * @param search optional keyword; matches the Khmer name, the English name,
 *               or the context, case-insensitively.
 *
 * Two things guarantee that pending entries never appear here:
 *   1. `.eq("status", "published")` below, and
 *   2. far more importantly, the RLS policy
 *      "published entries are readable by everyone", which means Postgres
 *      would refuse to return a pending row to an anonymous client even if
 *      this filter were deleted by accident.
 *
 * The filtering happens in Postgres. Nothing unpublished is ever sent to the
 * browser and hidden afterwards.
 */
export async function getPublishedEntries(search?: string): Promise<Entry[]> {
  const supabase = await createSupabaseServerClient();

  let query = supabase
    .from("entries")
    .select("*")
    .eq("status", "published")
    .order("created_at", { ascending: false });

  const term = search ? sanitizeSearchTerm(search) : "";
  if (term) {
    // `ilike` is case-insensitive LIKE. `%term%` matches the term anywhere in
    // the field. The three conditions are OR'd together so one search box
    // covers name and context, which is all Sprint 1 asks for.
    query = query.or(
      `name_khmer.ilike.%${term}%,` +
        `name_english.ilike.%${term}%,` +
        `context.ilike.%${term}%`,
    );
  }

  const { data, error } = await query;
  if (error) throw new Error(`Could not load entries: ${error.message}`);

  return data ?? [];
}

/**
 * Fetches one published entry for its detail page.
 *
 * `.maybeSingle()` returns null instead of throwing when there is no match,
 * which is exactly what we want: a pending entry and a nonexistent entry look
 * identical from the outside, so the detail page shows the same 404 for both.
 * That is deliberate — it means a URL cannot be used to confirm that an
 * unpublished entry exists.
 */
export async function getPublishedEntry(id: string): Promise<Entry | null> {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("entries")
    .select("*")
    .eq("id", id)
    .eq("status", "published")
    .maybeSingle();

  // Postgres rejects a malformed uuid with error code 22P02. A visitor typing
  // /entries/nonsense should get a 404 page, not a crash.
  if (error) {
    if (error.code === "22P02") return null;
    throw new Error(`Could not load entry: ${error.message}`);
  }

  return data;
}

/**
 * Every entry the logged-in contributor has submitted, whatever its status.
 *
 * The `contributor_id` filter is what makes this "mine" rather than
 * "everything I am allowed to see". Two RLS policies grant SELECT —
 * "published entries are readable by everyone" and "contributors can read
 * their own entries" — and Postgres ORs them together, so without the filter
 * this would return the contributor's rows *plus* the entire published
 * archive.
 *
 * Filtering on status instead would be wrong in a subtler way: it would hide
 * either the contributor's published entries or the older unpublished one,
 * when this page exists to show them all.
 *
 * Passing the id in is not the security check. A caller who lied about it
 * would get nothing back, because the policies still limit the rows Postgres
 * is willing to release to the session that asked.
 */
export async function getMyEntries(contributorId: string): Promise<Entry[]> {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("entries")
    .select("*")
    .eq("contributor_id", contributorId)
    .order("created_at", { ascending: false });

  if (error) throw new Error(`Could not load your entries: ${error.message}`);

  return data ?? [];
}

/**
 * Creates one entry, owned by the contributor who submitted it. It waits,
 * hidden from the public, until a reviewer publishes it.
 *
 * `contributor_id` is set here rather than taken from the form. That is belt
 * and braces: the insert policy's `with check` already refuses any row whose
 * contributor_id is not `auth.uid()`, so a forged one would be rejected by
 * Postgres.
 *
 * `status` is not sent at all, and must not be. Migration 0002 gives
 * contributors no privilege to write it on insert, so the column's default,
 * 'pending' since migration 0003, always applies. Sending it, even as
 * 'pending', would be refused. The same goes for `id` and `created_at`: the
 * database sets them.
 */
export async function createEntry(input: {
  contributorId: string;
  nameKhmer: string;
  nameEnglish: string;
  toldBy: string;
  context: string;
  description: string;
  photoUrl: string | null;
}): Promise<Entry> {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("entries")
    .insert({
      contributor_id: input.contributorId,
      name_khmer: input.nameKhmer,
      name_english: input.nameEnglish,
      told_by: input.toldBy,
      context: input.context,
      description: input.description,
      photo_url: input.photoUrl,
    })
    .select()
    .single();

  if (error) {
    // What Postgres said stays in the server log; the page gets the code only.
    console.error(`[entries] insert refused (${error.code}): ${error.message}`);
    throw new EntryWriteError(error.code);
  }

  return data;
}

/**
 * One of the contributor's own entries, whatever its status.
 *
 * The counterpart to `getPublishedEntry`. That one adds
 * `.eq("status","published")` so the public can only reach published rows;
 * this one does not, because a contributor's own entries may be pending or
 * returned, and they have to be able to load them to edit or delete them.
 *
 * What keeps that from becoming a hole is that nothing here checks ownership
 * either. The SELECT policies apply to this query — Postgres ORs them — so
 * the rows it can return are "published" plus "mine" (plus everything, for a
 * reviewer). The `contributor_id` filter narrows that to "mine", so even a
 * reviewer opens only their own entries for editing, and a contributor asking
 * for an id that is pending and someone else's gets null: Postgres never
 * releases it. The edit page turns that null into a 404, which is the same
 * 404 a nonexistent id gets.
 */
export async function getMyEntry(
  id: string,
  contributorId: string,
): Promise<Entry | null> {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("entries")
    .select("*")
    .eq("id", id)
    .eq("contributor_id", contributorId)
    .maybeSingle();

  // 22P02 is Postgres rejecting a malformed uuid — /my-entries/nonsense/edit
  // should be a 404, not a crash. Same handling as the public detail page.
  if (error) {
    if (error.code === "22P02") return null;
    throw new Error(`Could not load your entry: ${error.message}`);
  }

  return data;
}

/**
 * Rewrites one entry, with the status the caller asks for.
 *
 * There is no ownership check in this function, and that is the point. The
 * only thing standing between this update and somebody else's row is the
 * policy `auth.uid() = contributor_id` in
 * supabase/migrations/0001_init.sql, applied by Postgres to the statement
 * itself. Filtering on `contributor_id` here as well would read like a second
 * lock while adding none — and would quietly teach a later reader that the
 * app is where ownership is decided. Ask for the row by id; let the database
 * say whether it is yours.
 *
 * `status` is likewise not decided here. Since migration 0003 the update
 * policy's `with check` accepts only 'pending' from a contributor, so an edit
 * goes back for review; a reviewer's own entry may stay 'published'. The
 * caller asks for one or the other, and Postgres refuses anything else.
 * `contributor_id`, `id` and `created_at` are never written: 0002 gives
 * contributors no privilege to, and the safest column is the one no
 * statement touches.
 *
 * Returns null when no row matched — someone else's entry, or one already
 * deleted. Those are indistinguishable from out here, deliberately.
 */
export async function updateEntry(
  id: string,
  fields: {
    nameKhmer: string;
    nameEnglish: string;
    toldBy: string;
    context: string;
    description: string;
    photoUrl: string | null;
    status: "pending" | "published";
  },
): Promise<Entry | null> {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("entries")
    .update({
      name_khmer: fields.nameKhmer,
      name_english: fields.nameEnglish,
      told_by: fields.toldBy,
      context: fields.context,
      description: fields.description,
      photo_url: fields.photoUrl,
      status: fields.status,
    })
    .eq("id", id)
    .select()
    .maybeSingle();

  if (error) {
    if (error.code === "22P02") return null;
    // What Postgres said stays in the server log; the page gets the code
    // only, and saveFailureMessage turns that into a sentence.
    console.error(`[entries] update refused (${error.code}): ${error.message}`);
    throw new EntryWriteError(error.code);
  }

  return data;
}

/**
 * Deletes one entry.
 *
 * Ownership is the delete policy's job, for the same reason as above: one
 * policy, `auth.uid() = contributor_id`, enforced inside Postgres on the
 * statement. A contributor asking for an id that is not theirs deletes
 * nothing, and gets the same null as one asking for an id that no longer
 * exists.
 *
 * The deleted row comes back because it is the last chance to read its
 * `photo_url` — afterwards there is nothing left to ask, and the file would
 * stay in Storage with nothing pointing at it.
 *
 * Any other database error throws an EntryWriteError carrying only the
 * Postgres code, like createEntry and updateEntry.
 */
export async function deleteEntry(id: string): Promise<Entry | null> {
  const supabase = await createSupabaseServerClient();

  const { data, error } = await supabase
    .from("entries")
    .delete()
    .eq("id", id)
    .select()
    .maybeSingle();

  if (error) {
    if (error.code === "22P02") return null;
    // What Postgres said stays in the server log; the page gets the code only.
    console.error(`[entries] delete refused (${error.code}): ${error.message}`);
    throw new EntryWriteError(error.code);
  }

  return data;
}

/** The review page checks reviewer access before asking; RLS also limits this read. */
export async function getPendingEntries(): Promise<Entry[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("entries")
    .select("*")
    .eq("status", "pending")
    .order("created_at", { ascending: true });

  if (error) throw new Error(`Could not load the review queue: ${error.message}`);
  return data ?? [];
}

/** The existing RPC checks reviewer membership, pending status and separation of ownership. */
export async function reviewEntry(id: string, decision: "published" | "returned"): Promise<boolean> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("review_entry", { entry_id: id, decision });
  if (error) {
    console.error(`[review] decision refused (${error.code}): ${error.message}`);
    throw new EntryWriteError(error.code);
  }
  return data === true;
}
