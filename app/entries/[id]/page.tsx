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
 *
 * The page runs as two bands, the inverse of the browse page's: the name is
 * announced on the maroon ground, and the record itself — photograph, then
 * the numbered fields — sits on cream, where a long description is a kinder
 * read.
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
    <article>
      {/*
       * Narrower than the max-w-6xl the browse grid uses. That page wants the
       * full width for its three columns; this one is mostly prose, and a
       * description running the full 1152px would be far past the ~75
       * characters a line can comfortably be read at.
       */}
      <div className="mx-auto max-w-4xl px-6 pb-16 pt-10">
        <Link
          href="/"
          className="text-xs uppercase tracking-[0.22em] text-accent hover:underline"
        >
          ← Back to the archive
        </Link>

        <header className="mt-12">
          {khmerPending ? (
            /* English is promoted into the <h1> when there is no confirmed
               Khmer spelling, so the page's heading is still the name of the
               dessert rather than a status message. */
            <>
              <h1 className="text-4xl uppercase leading-[1.08] tracking-[0.01em] text-accent sm:text-5xl">
                {entry.name_english}
              </h1>
              <div className="mt-5">
                <PendingBadge>Khmer name pending</PendingBadge>
              </div>
            </>
          ) : (
            <>
              {/* leading-[1.6] so Khmer subscripts and vowel signs are not
                  clipped; the larger the type, the further a descender like
                  the one under ក្រ reaches below the baseline. */}
              <h1 className="font-khmer text-4xl leading-[1.6] text-accent sm:text-5xl lg:text-6xl">
                {entry.name_khmer}
              </h1>
              <p className="mt-4 text-sm uppercase tracking-[0.22em] text-ink">
                {entry.name_english}
              </p>
            </>
          )}
        </header>
      </div>

      <div className="bg-card">
        <div className="mx-auto max-w-4xl px-6 py-16">
          <div className="relative aspect-[4/3] overflow-hidden bg-accent-soft">
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
                sizes="(max-width: 896px) 100vw, 896px"
                className="object-cover"
                /* This is the largest image on the page, so it is loaded
                   eagerly rather than lazily to keep the page from popping
                   in. */
                priority
              />
            ) : (
              <NoPhotoPanel size="lg" />
            )}
          </div>

          {/*
            The fields as a numbered list: a hairline between each, the label
            in a wide-tracked uppercase, and the value given the width. The
            01 / 02 / 03 above each label comes from a CSS counter in
            app/globals.css, so no field has to be told its own position.
          */}
          <dl className="mt-16 border-t border-line">
            <div className="grid gap-x-10 gap-y-3 border-b border-line py-8 sm:grid-cols-[14rem_1fr]">
              <dt className="text-xs uppercase tracking-[0.22em] text-muted">
                When it is made
              </dt>
              <dd className="text-lg text-ink">
                {contextPending ? (
                  <PendingBadge>Occasion not recorded</PendingBadge>
                ) : (
                  entry.context
                )}
              </dd>
            </div>

            <div className="grid gap-x-10 gap-y-3 border-b border-line py-8 sm:grid-cols-[14rem_1fr]">
              <dt className="text-xs uppercase tracking-[0.22em] text-muted">
                Told by
              </dt>
              <dd className="text-lg text-ink">
                {sourcePending ? (
                  <PendingBadge>Source pending verification</PendingBadge>
                ) : (
                  entry.told_by
                )}
              </dd>
            </div>

            <div className="grid gap-x-10 gap-y-3 border-b border-line py-8 sm:grid-cols-[14rem_1fr]">
              <dt className="text-xs uppercase tracking-[0.22em] text-muted">
                The story
              </dt>
              <dd className="space-y-4">
                {/* `whitespace-pre-line` keeps the line breaks a contributor
                    typed. React escapes the text, so a description can never
                    inject HTML. */}
                {prose ? (
                  <p className="whitespace-pre-line text-lg leading-relaxed text-ink">
                    {prose}
                  </p>
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
        </div>
      </div>
    </article>
  );
}
