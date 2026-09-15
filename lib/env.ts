/**
 * Reads the two Supabase environment variables the app needs.
 *
 * Both are prefixed `NEXT_PUBLIC_`, which tells Next.js to inline them into
 * the browser bundle. That is safe and intended: the URL is public, and the
 * publishable key is meant to ship to the browser. It grants no privileges of
 * its own — every request it makes is still filtered by the Row Level Security
 * policies in `supabase/migrations/0001_init.sql`.
 *
 * Supabase used to call this the "anon" key and now calls it the publishable
 * key; the variable follows the current name, and the value it holds is an
 * `sb_publishable_…` key.
 *
 * The service role key, which DOES bypass RLS, must never appear in this
 * project.
 *
 * These are read through a function rather than at module load so that
 * `next build` succeeds on a machine with no .env.local — the error only
 * fires when a page actually tries to talk to Supabase.
 */
export function supabaseEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !publishableKey) {
    throw new Error(
      "Missing Supabase environment variables. Copy .env.example to " +
        ".env.local and fill in NEXT_PUBLIC_SUPABASE_URL and " +
        "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY from your Supabase project " +
        "settings.",
    );
  }

  return { url, publishableKey };
}

/** True when Supabase is configured — used to show a friendly setup notice. */
export function isSupabaseConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}
