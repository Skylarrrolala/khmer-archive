import Image from "next/image";
import Link from "next/link";

import { NoPhotoPanel } from "@/components/NoPhotoPanel";
import { PendingBadge } from "@/components/PendingBadge";
import { isPlaceholder } from "@/lib/placeholders";
import type { Entry } from "@/lib/types";

/**
 * One dessert in the browse list.
 *
 * The Khmer name is the headline: it is set largest, in the accent the card's
 * cream surface resolves to, above the English name. Browsing this archive
 * means looking for a dessert you know by its Khmer name, so it has to be
 * readable from the grid without opening anything.
 *
 * `leading-[1.7]` on the Khmer line is not decoration. Khmer stacks subscript
 * consonants below the baseline and vowel signs above it, and a tight
 * line-height clips them — the default heading leading cuts the descenders
 * off ក្រ and the like.
 *
 * `next/image` is used rather than a bare <img> so photos are resized and
 * lazily loaded. It only accepts remote URLs from hosts listed in
 * next.config.ts — that allowlist is what keeps the image optimizer from being
 * used as an open proxy for arbitrary URLs.
 *
 * The photo runs edge to edge and fills its tile. The archive's photos range
 * from 0.67 to 1.50 in aspect — a tall glass of num plae ai next to a wide
 * plate of num korng — so no single frame holds all of them uncropped. A
 * square crops least across that spread and keeps the grid a regular module,
 * but it is still a crop: the two portrait photos lose roughly a third, top
 * and bottom.
 *
 * `photo_url` is nullable by design: some desserts are only remembered, never
 * photographed. That case gets <NoPhotoPanel />, which is a designed state
 * rather than a broken-image apology, so the absence reads as part of the
 * record.
 *
 * The bracketed fields work the same way. A row that has no confirmed Khmer
 * spelling, no recorded occasion or no verified source holds a marker instead
 * of a value (see lib/placeholders.ts), and each one renders as a badge. The
 * marker stays in the database, where the cleanup queries match on it; what a
 * visitor sees is a stated gap rather than an editing note.
 *
 * When it is the Khmer name that is missing, the English name is promoted
 * into the <h2> rather than a badge being put there. A heading that reads
 * "Khmer name pending" would place a status message in the document outline,
 * where a screen reader expects the name of the dessert.
 *
 * `index` is the card's position in the list it is being rendered into, and it
 * is used for nothing but the printed number in the corner of the text block.
 */
export function EntryCard({ entry, index }: { entry: Entry; index: number }) {
  const khmerPending = isPlaceholder(entry.name_khmer);
  const contextPending = isPlaceholder(entry.context);
  const sourcePending = isPlaceholder(entry.told_by);

  return (
    <li className="group overflow-hidden border border-line bg-card transition-colors hover:border-accent">
      <Link
        href={`/entries/${entry.id}`}
        className="block focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        <div className="relative aspect-square bg-accent-soft">
          {entry.photo_url ? (
            <Image
              src={entry.photo_url}
              /* The Khmer name is dropped from the alt text when it is a
                 marker. Otherwise a screen reader would announce the photo as
                 "... ([KHMER SCRIPT NOT CONFIRMED])". */
              alt={
                khmerPending
                  ? entry.name_english
                  : `${entry.name_english} (${entry.name_khmer})`
              }
              fill
              /* Tells the optimizer how wide the image renders, so it does not
                 ship a 1200px file into a 350px slot. */
              sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 360px"
              className="object-cover"
            />
          ) : (
            <NoPhotoPanel />
          )}
        </div>

        <div className="space-y-1 border-t border-line p-5">
          {/*
            The card's place in the list, set the way a printed feature numbers
            its sections — the same device as the 01 / 02 / 03 on the fields of
            the detail page.

            aria-hidden because it is visual rhythm, not a fact about the
            dessert: it renumbers on every search, so announcing it would offer
            a screen reader something that looks like an identifier and is not.
            The surrounding <ul> already carries the count and the position.
          */}
          <p
            aria-hidden="true"
            className="mb-2 font-display text-4xl italic leading-none text-gold"
          >
            {String(index + 1).padStart(2, "0")}
          </p>

          {khmerPending ? (
            <>
              <h2 className="text-2xl text-accent">{entry.name_english}</h2>
              <PendingBadge>Khmer name pending</PendingBadge>
            </>
          ) : (
            <>
              <h2 className="font-khmer text-2xl leading-[1.7] text-accent">
                {entry.name_khmer}
              </h2>
              <p className="text-sm font-medium text-ink">
                {entry.name_english}
              </p>
            </>
          )}

          {/* `gap-y-1` because a badge is taller than the plain text it
              replaces, so a wrapped row would otherwise collide. */}
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1 pt-3 text-xs text-muted">
            {contextPending ? (
              <PendingBadge>Occasion not recorded</PendingBadge>
            ) : (
              <span className="uppercase tracking-[0.18em]">{entry.context}</span>
            )}
            <span aria-hidden="true" className="text-gold">
              •
            </span>
            {sourcePending ? (
              <PendingBadge>Source pending verification</PendingBadge>
            ) : (
              <span>Told by {entry.told_by}</span>
            )}
          </div>
        </div>
      </Link>
    </li>
  );
}
