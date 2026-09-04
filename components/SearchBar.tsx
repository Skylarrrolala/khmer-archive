import Link from "next/link";

/**
 * The search box.
 *
 * Deliberately a plain HTML <form method="get"> with no `"use client"` and no
 * React state. Submitting it navigates to `/?q=whatever`, which re-runs the
 * server component in app/page.tsx and re-queries Postgres.
 *
 * That means: the search runs in the database, the result is a real URL a
 * visitor can bookmark or share, and it works with JavaScript disabled.
 */
export function SearchBar({ query }: { query: string }) {
  return (
    <form method="get" action="/" className="flex flex-wrap gap-2">
      <label htmlFor="q" className="sr-only">
        Search desserts by name or occasion
      </label>
      <input
        id="q"
        name="q"
        type="search"
        defaultValue={query}
        placeholder="Search by name or occasion…"
        className="min-w-0 flex-1 rounded-lg border border-line bg-card px-4 py-2.5 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none"
      />
      <button
        type="submit"
        className="rounded-lg bg-accent px-5 py-2.5 font-medium text-white transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        Search
      </button>
      {query ? (
        <Link
          href="/"
          className="flex items-center rounded-lg border border-line px-5 py-2.5 text-muted transition-colors hover:border-accent hover:text-accent"
        >
          Clear
        </Link>
      ) : null}
    </form>
  );
}
