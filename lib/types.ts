/**
 * Shared TypeScript shapes for the archive.
 *
 * These mirror the migrations in `supabase/migrations/` by hand. Keeping them in
 * one file means that if the table changes, there is exactly one place in the
 * app to change with it.
 */

/** Matches the `entry_status` enum in Postgres, as migration 0003 left it. */
export type EntryStatus = "pending" | "published" | "returned";

/** One dessert — one row of `public.entries`. */
export type Entry = {
  id: string;
  name_khmer: string;
  name_english: string;
  told_by: string;
  context: string;
  description: string;
  /**
   * null only on a row saved before Sprint 2 required a photograph. A
   * published row always has one (migration 0002 refuses it otherwise).
   */
  photo_url: string | null;
  status: EntryStatus;
  /** null on the dummy seed rows, which nobody owns. */
  contributor_id: string | null;
  created_at: string;
};
