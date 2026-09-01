/**
 * Shared TypeScript shapes for the archive.
 *
 * These mirror `supabase/migrations/0001_init.sql` by hand. Keeping them in
 * one file means that if the table changes, there is exactly one place in the
 * app to change with it.
 */

/** Matches the `entry_status` enum in Postgres. */
export type EntryStatus = "pending" | "published" | "rejected";

/** One dessert — one row of `public.entries`. */
export type Entry = {
  id: string;
  name_khmer: string;
  name_english: string;
  told_by: string;
  context: string;
  description: string;
  /** null when the dessert is remembered but was never photographed. */
  photo_url: string | null;
  status: EntryStatus;
  /** null on the dummy seed rows, which nobody owns. */
  contributor_id: string | null;
  created_at: string;
};
