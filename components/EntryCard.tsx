import Link from "next/link";
import type { CSSProperties } from "react";

import { EntryPhotoTransition } from "@/components/EntryPhotoTransition";
import { FadeInImage } from "@/components/FadeInImage";
import { NoPhotoPanel } from "@/components/NoPhotoPanel";
import { PendingBadge } from "@/components/PendingBadge";
import { PhotoCreditLine } from "@/components/PhotoCreditLine";
import { exhibitPhoto, isPhotoWithheld, provenanceSummary } from "@/lib/exhibit-records";
import { isPlaceholder } from "@/lib/placeholders";
import type { Entry } from "@/lib/types";

export function EntryCard({ entry, index }: { entry: Entry; index: number }) {
  const khmerPending = isPlaceholder(entry.name_khmer);
  const occasion = entry.context;
  const contextPending = isPlaceholder(occasion);
  const photo = exhibitPhoto(entry);
  const provenance = provenanceSummary(entry);
  const landingTurn = { "--i": 7 + Math.min(index, 5) } as CSSProperties;

  return (
    <li className="land group gallery-object" style={landingTurn}>
      <Link
        href={`/entries/${entry.id}`}
        className="gallery-object-link block min-w-0 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-accent"
      >
        <EntryPhotoTransition entryId={entry.id}>
          <div className="gallery-object-photo relative aspect-[4/3] bg-accent-soft">
            {photo ? (
              <FadeInImage
                src={photo.src}
                alt={photo.alt ?? (khmerPending ? entry.name_english : `${entry.name_english} (${entry.name_khmer})`)}
                fill
                sizes="(max-width: 639px) calc(100vw - 40px), (max-width: 767px) calc(100vw - 64px), (max-width: 1279px) calc((100vw - 104px) / 2), 576px"
                className="object-contain p-5"
              />
            ) : (
              <NoPhotoPanel withheld={isPhotoWithheld(entry)} />
            )}
          </div>
        </EntryPhotoTransition>

        <div className="gallery-object-caption">
          <div className="gallery-object-label bg-lacquer min-w-0 px-5 py-4">
            {khmerPending ? (
              <>
                <h2 className="font-display text-2xl leading-snug text-ink">{entry.name_english}</h2>
                <PendingBadge>Khmer name pending</PendingBadge>
              </>
            ) : (
              <>
                <h2 lang="km" className="font-khmer text-2xl leading-[1.7] text-ink">
                  {entry.name_khmer}
                </h2>
                <p className="mt-1 text-sm leading-relaxed text-muted">{entry.name_english}</p>
              </>
            )}
          </div>

          <div className="gallery-object-evidence space-y-2 text-sm leading-relaxed text-muted">
            {contextPending ? (
              <PendingBadge>Occasion not recorded</PendingBadge>
            ) : (
              <p className="text-ink">{occasion}</p>
            )}
            {!isPlaceholder(entry.told_by) ? <p>Recorded source: {entry.told_by}</p> : null}
            {provenance ? <p className="source-notice">{provenance}</p> : null}
          </div>
        </div>
      </Link>
      {photo ? (
        <p className="gallery-object-evidence text-sm leading-relaxed text-muted">
          <PhotoCreditLine credit={photo.credit} />
          {photo.caption ? <span className="block">{photo.caption}</span> : null}
        </p>
      ) : null}
    </li>
  );
}
