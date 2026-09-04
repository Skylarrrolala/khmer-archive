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
 *
 * The page is built as two full-bleed bands rather than one column: a cream
 * sheet carrying the archive's name and the search, and the maroon ground
 * below it carrying the entries. <main> deliberately has no container of its
 * own (see app/layout.tsx) so each band can run edge to edge and centre its
 * own content.
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
  const count = `${entries.length} ${entries.length === 1 ? "entry" : "entries"}`;

  return (
    <>
      <section className="relative overflow-hidden bg-card">
        <div className="relative mx-auto max-w-6xl px-6 py-20 sm:py-28">
          {/*
            The wordmark at poster size, sunk into the cream. Far under the
            4.5:1 the palette holds text to — deliberately, because it is not
            text. `opacity` rather than a `text-accent/8` colour: the alpha form
            compiles to a color-mix() behind an @supports, and its fallback is
            the accent at full strength, which would drop a solid maroon នំ over
            the headline. aria-hidden and unselectable so it stays out of the
            document for a screen reader and out of the way of a cursor.

            Inside the container rather than the full-bleed section, and pinned
            to the content's right edge, so the whole glyph is on the page — off
            the section's edge it was clipped down to a few unreadable curves.

            Only from `xl` up. The headline is capped at max-w-3xl, and the
            clear space beside it is narrower than the glyph until then; below
            that the នំ crosses the type and reads as a smudge rather than a
            watermark behind it.
          */}
          <span
            aria-hidden="true"
            className="pointer-events-none absolute right-6 top-1/2 hidden -translate-y-1/2 select-none font-khmer text-[16rem] leading-none text-accent opacity-[0.08] xl:block"
          >
            នំ
          </span>

          <p className="text-xs uppercase tracking-[0.22em] text-muted">
            The Khmer Living Archive
          </p>

          {/* The tagline that used to sit under the masthead, promoted to the
              headline it always was. Uppercase because the serif carries the
              weight at this size, and Khmer has no case to lose by it. */}
          <h1 className="mt-7 max-w-3xl text-4xl uppercase leading-[1.08] tracking-[0.01em] text-accent sm:text-5xl lg:text-6xl">
            Traditional desserts, remembered and recorded.
          </h1>

          <div className="mt-12 max-w-2xl">
            <SearchBar query={query} />
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-6 py-16">
        <p className="text-xs uppercase tracking-[0.22em] text-muted">
          {query ? `${count} matching “${query}”` : `${count} in the archive`}
        </p>

        {entries.length === 0 ? (
          <p className="mt-8 border border-line bg-card p-8 text-muted">
            {query
              ? "No desserts match that search yet."
              : "No entries have been published yet."}
          </p>
        ) : (
          /* Three columns at the widest breakpoint. The container is max-w-6xl
             now, and a two-column grid there would stretch each card to ~560px,
             which makes the photo slot taller than the text beside it. */
          <ul className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {entries.map((entry, index) => (
              <EntryCard key={entry.id} entry={entry} index={index} />
            ))}
          </ul>
        )}
      </section>
    </>
  );
}

/**
 * Shown when the Supabase environment variables are missing, so a fresh clone
 * gives setup instructions instead of a stack trace.
 */
function SetupNotice() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-16">
      <div className="space-y-2 border border-line bg-card p-8">
        <h2 className="text-xl font-semibold">
          Supabase is not configured yet
        </h2>
        <p className="text-sm text-muted">
          Copy <code>.env.example</code> to <code>.env.local</code>, fill in the
          project URL and anon key from your Supabase dashboard, then restart
          the dev server. See the README for the full setup steps.
        </p>
      </div>
    </section>
  );
}
