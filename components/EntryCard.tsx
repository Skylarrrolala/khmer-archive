import Image from "next/image";
import Link from "next/link";

import { NoPhotoPanel } from "@/components/NoPhotoPanel";
import type { Entry } from "@/lib/types";

/**
 * One dessert in the browse list.
 *
 * The Khmer name is the headline: it is set largest, in the archive's
 * terracotta, above the English name. Browsing this archive means looking for
 * a dessert you know by its Khmer name, so it has to be readable from the
 * grid without opening anything.
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
 * `photo_url` is nullable by design: some desserts are only remembered, never
 * photographed. That case gets <NoPhotoPanel />, which is a designed state
 * rather than a broken-image apology, so the absence reads as part of the
 * record.
 */
export function EntryCard({ entry }: { entry: Entry }) {
  return (
    <li className="group overflow-hidden rounded-xl border border-line bg-card transition-colors hover:border-accent">
      <Link
        href={`/entries/${entry.id}`}
        className="block focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        <div className="relative aspect-[4/3] bg-accent-soft">
          {entry.photo_url ? (
            <Image
              src={entry.photo_url}
              alt={`${entry.name_english} (${entry.name_khmer})`}
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

        <div className="space-y-1 border-t border-line p-4">
          <h2 className="font-khmer text-2xl leading-[1.7] text-accent">
            {entry.name_khmer}
          </h2>
          <p className="text-sm font-medium text-ink">{entry.name_english}</p>

          <div className="flex flex-wrap items-center gap-x-2 pt-1 text-xs text-muted">
            <span className="uppercase tracking-wide">{entry.context}</span>
            <span aria-hidden="true" className="text-gold">
              •
            </span>
            <span>Told by {entry.told_by}</span>
          </div>
        </div>
      </Link>
    </li>
  );
}
