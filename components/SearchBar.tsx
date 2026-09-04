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
        /* `basis-full` below sm so the field takes a row of its own and the
           buttons wrap beneath it — sharing one row at 320px squeezed the
           field until its placeholder truncated mid-word. Longhands rather
           than the `flex-1` shorthand: `flex` would set a basis of its own,
           and which of the two won at sm would come down to the order
           Tailwind happens to emit them in. */
        className="min-w-0 grow basis-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none sm:basis-0"
      />
      <button
        type="submit"
        className="bg-accent px-6 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        Search
      </button>
      {query ? (
        <Link
          href="/"
          className="flex items-center border border-line px-6 py-3 text-xs uppercase tracking-[0.18em] text-muted transition-colors hover:border-accent hover:text-accent"
        >
          Clear
        </Link>
      ) : null}
    </form>
  );
}
