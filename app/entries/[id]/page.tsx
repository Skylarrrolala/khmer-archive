import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { NoPhotoPanel } from "@/components/NoPhotoPanel";
import { PendingBadge } from "@/components/PendingBadge";
import { getPublishedEntry } from "@/lib/entries";
import {
  descriptionNotes,
  descriptionProse,
  isPlaceholder,
} from "@/lib/placeholders";

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
 *
 * Fields that hold an editing marker rather than a value are rendered as
 * badges, using the same predicate as the browse card so the two pages agree
 * about what counts as a gap. See lib/placeholders.ts.
 */
export default async function EntryPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const entry = await getPublishedEntry(id);

  if (!entry) notFound();

  const khmerPending = isPlaceholder(entry.name_khmer);
  const contextPending = isPlaceholder(entry.context);
  const sourcePending = isPlaceholder(entry.told_by);

  /* The description is the one field whose markers are appended to real prose
     instead of replacing it, so it is split rather than swapped: the prose is
     shown as written, and each marker becomes a note underneath. */
  const prose = descriptionProse(entry.description);
  const notes = descriptionNotes(entry.description);

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
        {khmerPending ? (
          /* English is promoted into the <h1> when there is no confirmed
             Khmer spelling, so the page's heading is still the name of the
             dessert rather than a status message. */
          <>
            <h1 className="text-4xl text-accent">{entry.name_english}</h1>
            <PendingBadge>Khmer name pending</PendingBadge>
          </>
        ) : (
          <>
            {/* leading-[1.7] so Khmer subscripts and vowel signs are not
                clipped; at text-4xl the default heading leading cuts them
                off. */}
            <h1 className="font-khmer text-4xl leading-[1.7] text-accent">
              {entry.name_khmer}
            </h1>
            <p className="text-lg text-ink">{entry.name_english}</p>
          </>
        )}
      </header>

      {/* Mounted rather than cropped, the same as the browse card: padding
          for an even margin, `object-contain` so nothing is cut off. The frame
          stays 4:3 here where the card's is square — a square at this width
          would push the story itself below the fold on a laptop. */}
      <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-line bg-accent-soft p-5">
        {entry.photo_url ? (
          <Image
            src={entry.photo_url}
            /* The marker is kept out of the alt text — see EntryCard. */
            alt={
              khmerPending
                ? entry.name_english
                : `${entry.name_english} (${entry.name_khmer})`
            }
            fill
            sizes="(max-width: 768px) 100vw, 768px"
            className="object-contain"
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
          <dd className="mt-1 text-ink">
            {contextPending ? (
              <PendingBadge>Occasion not recorded</PendingBadge>
            ) : (
              entry.context
            )}
          </dd>
        </div>

        <div>
          <dt className="text-xs uppercase tracking-wide text-muted">
            Told by
          </dt>
          <dd className="mt-1 text-ink">
            {sourcePending ? (
              <PendingBadge>Source pending verification</PendingBadge>
            ) : (
              entry.told_by
            )}
          </dd>
        </div>

        <div className="sm:col-span-2">
          <dt className="text-xs uppercase tracking-wide text-muted">
            The story
          </dt>
          <dd className="mt-1 space-y-3">
            {/* `whitespace-pre-line` keeps the line breaks a contributor typed.
                React escapes the text, so a description can never inject
                HTML. */}
            {prose ? (
              <p className="whitespace-pre-line text-ink">{prose}</p>
            ) : null}

            {notes.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {notes.map((note) => (
                  <PendingBadge key={note}>{note}</PendingBadge>
                ))}
              </div>
            ) : null}
          </dd>
        </div>
      </dl>
    </article>
  );
}
