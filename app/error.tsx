"use client";

/**
 * What a visitor sees when a page fails to render — most likely because
 * Supabase could not be reached, since every query in lib/entries.ts throws on
 * a database error.
 *
 * Next.js wraps each route segment in a React error boundary and renders this
 * file as its fallback (node_modules/next/dist/docs/01-app/03-api-reference/
 * 03-file-conventions/error.md). At the root of `app/` it covers every page,
 * but not app/layout.tsx itself, so the header, the footer and the account
 * links stay in place around it. `notFound()` and `redirect()` pass straight
 * through: the boundary re-throws them to their own handlers, so a missing
 * entry still gets the 404 page and a signed-out visitor is still sent to log
 * in.
 *
 * The message is generic on purpose. This one boundary serves the browse page,
 * the detail page, "my entries" and the submission form, so it cannot say what
 * failed. It never prints `error.message` either: in production Next replaces
 * a Server Component's message with a generic one anyway, and the real message
 * — which can carry Postgres details — belongs in the server log, where the
 * error's `digest` points to it.
 *
 * `retry` re-fetches the page from the server and renders it again. `reset`
 * would only re-render what the browser already has, which cannot help when
 * the failure happened on the server. Error boundaries have to be Client
 * Components, hence "use client".
 *
 * Styled as SetupNotice in app/(browse)/page.tsx — the archive's other
 * "the archive cannot be shown" state — with the search button's classes on
 * the retry.
 */
export default function ErrorPage({
  retry,
}: {
  error: Error & { digest?: string };
  retry: () => void;
}) {
  return (
    <section className="mx-auto max-w-6xl px-6 py-16">
      <div className="border border-line bg-card p-8">
        {/* role="alert" so a screen reader announces the failure when it
            replaces a page mid-visit. The button sits outside it: an alert is
            read out as a message, and should not contain controls. */}
        <div role="alert" className="space-y-2">
          <h1 className="text-xl font-semibold">Something went wrong</h1>
          <p className="text-sm text-muted">
            The archive could not be reached just now. Please try again in a
            moment.
          </p>
        </div>

        <button
          type="button"
          onClick={() => retry()}
          className="mt-6 bg-accent px-6 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          Try again
        </button>
      </div>
    </section>
  );
}
