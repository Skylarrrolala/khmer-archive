import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Entry } from "@/lib/types";

/**
 * Every read the public pages make goes through this file, so there is exactly
 * one place to check when asking "can an unpublished entry leak?".
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
 * unreviewed entry exists.
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
