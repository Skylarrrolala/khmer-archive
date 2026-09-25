/**
 * What the home page shows while its entries are on their way from Supabase.
 *
 * Next.js wraps the page in this folder in a Suspense boundary with this file
 * as the fallback (node_modules/next/dist/docs/01-app/03-api-reference/
 * 03-file-conventions/loading.md). The folder is the `(browse)` route group:
 * the parentheses keep it out of the URL, so the page is still served at `/`,
 * and the only page inside it is the home page — so this is the only page
 * that gets the fallback.
 *
 * It is deliberately not `app/loading.tsx`. A loading file at the root would
 * wrap every page, and once a fallback has streamed the status code is fixed
 * at 200: the detail page's `notFound()` would stop answering with a real 404,
 * and `requireUser()`'s redirects would arrive inside the stream instead of as
 * a redirect. It would also drop a fallback between a card and its detail
 * page, where the photo transition needs the two pages to swap in one step.
 *
 * Static on purpose — no pulse, no spinner. Either would be new motion, which
 * CLAUDE.md asks to be approved first. The band and container are the hero's
 * own (the first <section> in page.tsx), so the header's cream carries on down
 * the screen the way it will once the page arrives, and the line is set like
 * the hero's eyebrow. `role="status"` lets a screen reader announce it.
 */
export default function BrowseLoading() {
  return (
    <section className="bg-card">
      <div className="mx-auto max-w-6xl px-6 pb-20 pt-14 sm:pb-24 sm:pt-16">
        <p
          role="status"
          className="text-xs uppercase tracking-[0.22em] text-muted"
        >
          Loading the archive…
        </p>
      </div>
    </section>
  );
}
