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
    <form method="get" action="/" className="flex gap-2">
      <label htmlFor="q" className="sr-only">
        Search desserts by name or occasion
      </label>
      <input
        id="q"
        name="q"
        type="search"
        defaultValue={query}
        placeholder="Search by name or occasion…"
        className="w-full rounded border border-line bg-card px-3 py-2 text-ink placeholder:text-muted focus:border-accent focus:outline-none"
      />
      <button
        type="submit"
        className="rounded bg-accent px-4 py-2 font-medium text-white"
      >
        Search
      </button>
      {query ? (
        <Link
          href="/"
          className="flex items-center rounded border border-line px-4 py-2 text-muted"
        >
          Clear
        </Link>
      ) : null}
    </form>
  );
}
