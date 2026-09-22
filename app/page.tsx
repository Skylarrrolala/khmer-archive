import { EntryCard } from "@/components/EntryCard";
import { FadeInImage } from "@/components/FadeInImage";
import { SearchBar } from "@/components/SearchBar";
import { getPublishedEntries } from "@/lib/entries";
import { isSupabaseConfigured } from "@/lib/env";
import type { Entry } from "@/lib/types";

/**
 * `force-dynamic` renders this page per request instead of caching it at build
 * time. Two reasons: the results depend on `?q=`, and a newly published entry
 * should appear immediately rather than after a redeploy.
 */
export const dynamic = "force-dynamic";

/** An entry that is known to carry a photograph. */
type Photographed = Entry & { photo_url: string };

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
 * sheet carrying the archive's name, the search and a pair of photographs, and
 * the maroon ground below it carrying the entries. <main> deliberately has no
 * container of its own (see app/layout.tsx) so each band can run edge to edge
 * and centre its own content.
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

  /*
   * The hero's photographs are the archive's front matter, not search results,
   * so they come from the unfiltered archive and do not change as someone
   * types. With no query in play the browse query already IS the unfiltered
   * set, so the common path costs nothing extra.
   */
  const archive = query ? await getPublishedEntries("") : entries;

  /*
   * The two *earliest* photographs, not the latest. `getPublishedEntries`
   * returns newest first, so the latest two would be the same pair of cards
   * sitting directly underneath the hero. Taken from the end and flipped, so
   * they read left to right in the order they entered the archive.
   */
  const heroPhotos = archive
    .filter((entry): entry is Photographed => Boolean(entry.photo_url))
    .slice(-2)
    .reverse();

  return (
    <>
      <section className="relative overflow-hidden bg-card">
        <div className="relative mx-auto max-w-6xl px-6 pb-20 pt-14 sm:pb-24 sm:pt-16">
          {/*
            The Latin half of the wordmark at poster size, sunk into the cream.
            It sits behind the headline on purpose — at this strength it reads
            as a watermark in the paper rather than as type, so the headline
            stays the only thing here you actually read.

            `opacity` rather than a `text-accent/6` colour: the alpha form
            compiles to a color-mix() behind an @supports, and its fallback is
            the accent at full strength, which would drop a solid maroon word
            across the headline. aria-hidden and unselectable so it stays out
            of the document for a screen reader and out of a cursor's way.
          */}
          <span
            aria-hidden="true"
            className="land [--i:0] pointer-events-none absolute left-4 top-16 select-none whitespace-nowrap font-display text-[9rem] italic leading-none tracking-tight text-accent opacity-[0.05] sm:top-20 sm:text-[16rem] lg:text-[26rem]"
          >
            Num
          </span>

          {/* The headline takes the width; the standing description sits in a
              narrow column beside it, dropped to the headline's last line. */}
          <div className="relative grid gap-x-12 gap-y-8 lg:grid-cols-[minmax(0,1fr)_19rem]">
            <div>
              <p className="land [--i:1] text-xs uppercase tracking-[0.22em] text-muted">
                The Khmer Living Archive
              </p>

              {/* The tagline that used to sit under the masthead, promoted to
                  the headline it always was. Uppercase because the serif
                  carries the weight at this size, and Khmer has no case to
                  lose by it. */}
              <h1 className="land [--i:2] mt-6 text-4xl uppercase leading-[1.08] tracking-[0.01em] text-accent sm:text-5xl lg:text-6xl">
                Traditional desserts, remembered and recorded.
              </h1>
            </div>

            <p className="land [--i:3] text-sm leading-relaxed text-muted lg:self-end">
              Entries are of two kinds: desserts still actively made (with a
              photo of the real thing), and desserts remembered from earlier in
              life but no longer made (description only, sometimes with no photo
              at all).
            </p>
          </div>

          {/* Search sits where the reference puts its buttons — bottom left,
              on the baseline of the photographs beside it. */}
          <div className="relative mt-14 grid gap-x-12 gap-y-12 lg:mt-20 lg:grid-cols-[minmax(0,1fr)_minmax(0,32rem)] lg:items-end">
            <div className="land [--i:4]">
              <SearchBar query={query} />
            </div>

            {/*
              Two photographs from the archive, as an overture. `alt=""` and
              aria-hidden because they are decorative here and nothing else:
              both entries appear as cards in the grid below with their names,
              occasion and source attached, so announcing them twice would only
              make a screen reader repeat itself.
            */}
            {heroPhotos.length === 2 ? (
              <div aria-hidden="true" className="grid grid-cols-2 gap-5">
                {heroPhotos.map((entry, i) => (
                  <div
                    key={entry.id}
                    /* Unveiled alongside the search, the second a beat after
                       the first. Both class names are written out in full so
                       Tailwind can find them. */
                    className={`land-photo ${i === 0 ? "[--i:4]" : "[--i:5]"} relative aspect-[3/4] overflow-hidden bg-accent-soft`}
                  >
                    <FadeInImage
                      src={entry.photo_url}
                      alt=""
                      fill
                      sizes="(max-width: 1024px) 45vw, 250px"
                      className="object-cover"
                    />
                  </div>
                ))}
              </div>
            ) : null}
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-6 py-16">
        <p className="land [--i:6] text-xs uppercase tracking-[0.22em] text-muted">
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
          project URL and publishable key from your Supabase dashboard, then
          restart the dev server. See the README for the full setup steps.
        </p>
      </div>
    </section>
  );
}
