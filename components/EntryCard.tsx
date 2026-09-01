import Image from "next/image";
import Link from "next/link";

import type { Entry } from "@/lib/types";

/**
 * One dessert in the browse list.
 *
 * `next/image` is used rather than a bare <img> so photos are resized and
 * lazily loaded. It only accepts remote URLs from hosts listed in
 * next.config.ts — that allowlist is what keeps the image optimizer from being
 * used as an open proxy for arbitrary URLs.
 *
 * `photo_url` is nullable by design: some desserts are only remembered, never
 * photographed. That case gets a labelled placeholder rather than a broken
 * image, so the absence reads as part of the record.
 */
export function EntryCard({ entry }: { entry: Entry }) {
  return (
    <li className="overflow-hidden rounded-lg border border-line bg-card">
      <Link href={`/entries/${entry.id}`} className="block">
        <div className="relative aspect-[4/3] bg-paper">
          {entry.photo_url ? (
            <Image
              src={entry.photo_url}
              alt={`${entry.name_english} (${entry.name_khmer})`}
              fill
              /* Tells the optimizer how wide the image renders, so it does not
                 ship a 1200px file into a 350px slot. */
              sizes="(max-width: 640px) 100vw, 320px"
              className="object-cover"
            />
          ) : (
            <div className="flex h-full items-center justify-center px-4 text-center text-sm text-muted">
              No photo — remembered, not made today
            </div>
          )}
        </div>

        <div className="space-y-1 p-4">
          <h2 className="font-khmer text-lg text-ink">{entry.name_khmer}</h2>
          <p className="text-sm font-medium text-ink">{entry.name_english}</p>
          <p className="text-sm text-muted">{entry.context}</p>
          <p className="text-sm text-muted">Told by {entry.told_by}</p>
        </div>
      </Link>
    </li>
  );
}
