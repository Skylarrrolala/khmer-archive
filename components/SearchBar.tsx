import Link from "next/link";

/** A GET form keeps search in the database and usable without JavaScript. */
export function SearchBar({ query }: { query: string }) {
  return (
    <form method="get" action="/#collection" className="collection-search">
      <label htmlFor="q" className="search-label mb-2 block text-sm text-ink">
        <span lang="km" className="font-khmer">ស្វែងរក</span>
        <span>Search by Khmer name, English name or occasion</span>
      </label>
      <div className="flex flex-wrap gap-3">
        <div className="search-field relative min-w-0 grow basis-32 sm:basis-0">
          <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none">
            <circle cx="10.5" cy="10.5" r="6.5" stroke="currentColor" strokeWidth="1.5" />
            <path d="m16 16 4.5 4.5" stroke="currentColor" strokeWidth="1.5" />
          </svg>
          <input
            id="q"
            name="q"
            type="search"
            defaultValue={query}
            placeholder="ឈ្មោះ ឬឱកាស · Name or occasion…"
            className="min-h-12 w-full min-w-0 border-b border-muted bg-transparent py-3 pr-4 pl-12 text-base text-ink placeholder:text-muted focus:border-accent focus:outline-2 focus:outline-offset-2 focus:outline-accent"
          />
        </div>
        <button
          type="submit"
          className="min-h-12 bg-accent px-4 py-3 sm:px-7 text-sm text-on-accent transition-opacity hover:opacity-90"
        >
          <span lang="km" className="font-khmer">ស្វែងរក</span> Search
        </button>
        {query ? (
          <Link
            href="/#collection"
            className="inline-flex min-h-12 items-center border border-muted px-6 py-3 text-sm text-accent hover:underline"
          >
            Clear search
          </Link>
        ) : null}
      </div>
    </form>
  );
}
