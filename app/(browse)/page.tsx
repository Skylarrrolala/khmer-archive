import { EntryCard } from "@/components/EntryCard";
import { HomepageExhibition } from "@/components/HomepageExhibition";
import { SearchBar } from "@/components/SearchBar";
import { getPublishedEntries } from "@/lib/entries";
import { isSupabaseConfigured } from "@/lib/env";

export const dynamic = "force-dynamic";

export default async function BrowsePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string | string[] }>;
}) {
  const { q } = await searchParams;
  const query = (Array.isArray(q) ? q[0] : q) ?? "";
  const configured = isSupabaseConfigured();
  const entries = configured ? await getPublishedEntries(query) : [];
  const count = `${entries.length} ${entries.length === 1 ? "entry" : "entries"}`;

  return (
    <>
      {!query ? <HomepageExhibition entries={entries} /> : null}

      <section
        id="collection"
        aria-labelledby="browse-title"
        className="gallery-shell collection-section scroll-mt-6 pb-8 sm:pb-10"
      >
        <div aria-hidden="true" className="collection-cornice"><span className="kbach-frieze ornament-divider" /></div>
        <div className="collection-title-row flex flex-wrap items-end justify-between gap-3">
          <div>
            {query ? (
              <>
                <p className="mb-3 text-sm text-muted">
                  <span lang="km" className="font-khmer">នំខ្មែរ</span> · Khmer Traditional Cakes &amp; Snacks
                </p>
                <h1 id="browse-title" className="collection-heading text-accent">
                  <span aria-hidden="true" className="heading-flower" />
                  <span lang="km" className="block font-khmer">ស្វែងរកក្នុងបណ្ដុំ</span>
                  <span className="collection-english">Search the collection</span>
                </h1>
              </>
            ) : (
              <h2 id="browse-title" className="collection-heading text-accent">
                <span aria-hidden="true" className="heading-flower" />
                <span lang="km" className="block font-khmer">បណ្ដុំ</span>
                <span className="collection-english">Inside the collection</span>
              </h2>
            )}
          </div>
          {configured ? (
            <p className="collection-count text-sm text-muted">
              {query ? `${count} matching “${query}”` : count}
            </p>
          ) : null}
        </div>

        <div className="mt-4 sm:mt-6">
          <SearchBar query={query} />
        </div>
        <p className="mt-4 max-w-prose text-sm leading-relaxed text-muted">
          The collection follows the Khmer word num (<span lang="km" className="font-khmer">នំ</span>), which
          covers cakes and snacks, both sweet and savoury. Each record states
          its published references, its oral source if one
          is recorded, and what is still unverified. Publication alone does
          not establish provenance.
        </p>

        {!configured ? (
          <div className="mt-8 border border-line bg-card p-6">
            <h2 className="text-xl text-accent">Supabase is not configured yet</h2>
            <p className="mt-2 text-sm leading-relaxed text-muted">
              Follow the README setup instructions and restart the development server.
            </p>
          </div>
        ) : entries.length === 0 ? (
          <p className="mt-8 border-y border-line py-10 text-muted">
            {query ? "Nothing in the collection matches that search yet." : "No entries have been published yet."}
          </p>
        ) : (
          <ul className="collection-grid mt-8">
            {entries.map((entry, index) => (
              <EntryCard key={entry.id} entry={entry} index={index} />
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
