import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { NoPhotoPanel } from "@/components/NoPhotoPanel";
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
    /*
     * Narrower than the max-w-6xl the layout gives it. The browse grid wants
     * the full width for its three columns, but this page is mostly prose —
     * a description running the full 1152px would be far past the ~75
     * characters a line can comfortably be read at.
     */
    <article className="mx-auto max-w-3xl space-y-6">
      <Link
        href="/"
        className="inline-block text-sm text-accent hover:underline"
      >
        ← Back to the archive
      </Link>

      <header className="space-y-1">
        {/* leading-[1.7] so Khmer subscripts and vowel signs are not clipped;
            at text-4xl the default heading leading cuts them off. */}
        <h1 className="font-khmer text-4xl leading-[1.7] text-accent">
          {entry.name_khmer}
        </h1>
        <p className="text-lg text-ink">{entry.name_english}</p>
      </header>

      <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-line bg-accent-soft">
        {entry.photo_url ? (
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
        ) : (
          <NoPhotoPanel size="lg" />
        )}
      </div>

      <dl className="grid gap-5 rounded-xl border border-line bg-card p-6 sm:grid-cols-2">
        <div>
          <dt className="text-xs uppercase tracking-wide text-muted">
            When it is made
          </dt>
          <dd className="mt-1 text-ink">{entry.context}</dd>
        </div>

        <div>
          <dt className="text-xs uppercase tracking-wide text-muted">
            Told by
          </dt>
          <dd className="mt-1 text-ink">{entry.told_by}</dd>
        </div>

        <div className="sm:col-span-2">
          <dt className="text-xs uppercase tracking-wide text-muted">
            The story
          </dt>
          {/* `whitespace-pre-line` keeps the line breaks a contributor typed.
              React escapes the text, so a description can never inject HTML. */}
          <dd className="mt-1 whitespace-pre-line text-ink">
            {entry.description}
          </dd>
        </div>
      </dl>
    </article>
  );
}
