import { EntryCard } from "@/components/EntryCard";
import { SearchBar } from "@/components/SearchBar";
import { getPublishedEntries } from "@/lib/entries";
import { isSupabaseConfigured } from "@/lib/env";

/**
 * `force-dynamic` renders this page per request instead of caching it at build
 * time. Two reasons: the results depend on `?q=`, and a newly published entry
 * should appear immediately rather than after a redeploy.
 */
export const dynamic = "force-dynamic";

/**
 * The public browse + search page. No login required — this whole route talks
 * to Supabase as an anonymous client, and the RLS policies limit it to
 * published entries.
 *
 * In the App Router, `searchParams` arrives as a Promise and is awaited. A
 * value can be a string or an array of strings (`?q=a&q=b`), so it is narrowed
 * to a single string before use.
 */
export default async function BrowsePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string | string[] }>;
}) {
  const { q } = await searchParams;
  const query = (Array.isArray(q) ? q[0] : q) ?? "";

  if (!isSupabaseConfigured()) return <SetupNotice />;

  const entries = await getPublishedEntries(query);

  return (
    <div className="space-y-6">
      <SearchBar query={query} />

      <p className="text-sm text-muted">
        {query
          ? `${entries.length} ${entries.length === 1 ? "entry" : "entries"} matching “${query}”`
          : `${entries.length} ${entries.length === 1 ? "entry" : "entries"} in the archive`}
      </p>

      {entries.length === 0 ? (
        <p className="rounded-lg border border-line bg-card p-6 text-muted">
          {query
            ? "No desserts match that search yet."
            : "No entries have been published yet."}
        </p>
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2">
          {entries.map((entry) => (
            <EntryCard key={entry.id} entry={entry} />
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * Shown when the Supabase environment variables are missing, so a fresh clone
 * gives setup instructions instead of a stack trace.
 */
function SetupNotice() {
  return (
    <div className="space-y-2 rounded-lg border border-line bg-card p-6">
      <h2 className="font-semibold">Supabase is not configured yet</h2>
      <p className="text-sm text-muted">
        Copy <code>.env.example</code> to <code>.env.local</code>, fill in the
        project URL and anon key from your Supabase dashboard, then restart the
        dev server. See the README for the full setup steps.
      </p>
    </div>
  );
}
