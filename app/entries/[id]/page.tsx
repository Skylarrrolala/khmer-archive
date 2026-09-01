import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { getPublishedEntry } from "@/lib/entries";

export const dynamic = "force-dynamic";

/**
 * The detail page for a single dessert.
 *
 * `params` is a Promise in the App Router and is awaited. `id` comes straight
 * from the URL, so it is untrusted input — it is passed to Supabase as a bound
 * parameter (never string-concatenated into SQL), and `getPublishedEntry`
 * turns a malformed uuid into a 404.
 *
 * `notFound()` renders Next's 404 with a 404 status. A pending entry takes the
 * same path as a nonexistent one, so the URL reveals nothing about entries
 * still awaiting review.
 */
export default async function EntryPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const entry = await getPublishedEntry(id);

  if (!entry) notFound();

  return (
    <article className="space-y-6">
      <Link href="/" className="text-sm text-accent">
        ← Back to the archive
      </Link>

      <header className="space-y-1">
        <h1 className="font-khmer text-3xl text-ink">{entry.name_khmer}</h1>
        <p className="text-lg text-ink">{entry.name_english}</p>
      </header>

      {entry.photo_url ? (
        <div className="relative aspect-[4/3] overflow-hidden rounded-lg border border-line bg-card">
          <Image
            src={entry.photo_url}
            alt={`${entry.name_english} (${entry.name_khmer})`}
            fill
            sizes="(max-width: 768px) 100vw, 768px"
            className="object-cover"
            /* This is the largest image on the page, so it is loaded eagerly
               rather than lazily to keep the page from popping in. */
            priority
          />
        </div>
      ) : (
        <p className="rounded-lg border border-line bg-card p-6 text-sm text-muted">
          No photo — this dessert is remembered but is not made today.
        </p>
      )}

      <dl className="space-y-4">
        <div>
          <dt className="text-sm font-medium text-muted">When it is made</dt>
          <dd className="text-ink">{entry.context}</dd>
        </div>

        <div>
          <dt className="text-sm font-medium text-muted">Told by</dt>
          <dd className="text-ink">{entry.told_by}</dd>
        </div>

        <div>
          <dt className="text-sm font-medium text-muted">The story</dt>
          {/* `whitespace-pre-line` keeps the line breaks a contributor typed.
              React escapes the text, so a description can never inject HTML. */}
          <dd className="whitespace-pre-line text-ink">{entry.description}</dd>
        </div>
      </dl>
    </article>
  );
}
