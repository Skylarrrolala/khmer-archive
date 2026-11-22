import Link from "next/link";
import { notFound } from "next/navigation";
import type { CSSProperties } from "react";

import { EntryPhotoTransition } from "@/components/EntryPhotoTransition";
import { FadeInImage } from "@/components/FadeInImage";
import { NoPhotoPanel } from "@/components/NoPhotoPanel";
import { PendingBadge } from "@/components/PendingBadge";
import { PhotoCreditLine } from "@/components/PhotoCreditLine";
import { getPublishedEntry } from "@/lib/entries";
import {
  exhibitPhoto,
  getExhibitRecord,
  isResearchedRow,
  isPhotoWithheld,
  provenanceSummary,
} from "@/lib/exhibit-records";
import {
  descriptionNotes,
  descriptionProse,
  hasUnattributedSource,
  isPlaceholder,
} from "@/lib/placeholders";

export const dynamic = "force-dynamic";

export default async function EntryPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const entry = await getPublishedEntry(id);
  if (!entry) notFound();

  const record = getExhibitRecord(entry);
  const photo = exhibitPhoto(entry);
  const references = record?.references ?? [];
  const unresolved = record?.unresolved ?? [];
  const provenance = provenanceSummary(entry);

  const khmerPending = isPlaceholder(entry.name_khmer);
  const occasion = entry.context;
  const contextPending = isPlaceholder(occasion);
  const oralPending = hasUnattributedSource(entry.told_by);
  const prose = descriptionProse(entry.description);
  const notes = descriptionNotes(entry.description);
  const title = khmerPending ? entry.name_english : entry.name_khmer;
  // The frame takes the photograph's own proportions; unknown sizes get 2:3.
  const frame = { "--w": photo?.width ?? 2, "--h": photo?.height ?? 3 } as CSSProperties;

  return (
    <article className="gallery-shell archive-record py-8 sm:py-12">
      <nav aria-label="Breadcrumb" className="record-navigation mb-8 border-b border-line pb-6">
        <ol className="record-breadcrumb">
          <li>
            <Link href="/#collection" className="nav-dual text-accent hover:underline">
              <span lang="km">ត្រឡប់ទៅបណ្ដុំ</span>
              <span className="nav-english">Back to the collection</span>
            </Link>
          </li>
          <li aria-current="page" className="record-breadcrumb-current">
            <span lang={khmerPending ? undefined : "km"}>{title}</span>
          </li>
        </ol>
        <p className="text-sm text-muted">
          <span lang="km" className="font-khmer">នំខ្មែរ</span> · Khmer Traditional Cakes &amp; Snacks
        </p>
      </nav>

      <div className="record-layout">
        <header className="record-header min-w-0">
          <p className="record-eyebrow">
            <span lang="km" className="font-khmer">កំណត់ត្រាវត្ថុតាំងពិព័រណ៍</span>
            <span aria-hidden="true"> · </span>
            The object record
          </p>
          {khmerPending ? (
            <>
              <h1 className="font-display text-3xl leading-snug text-accent sm:text-4xl">
                {entry.name_english}
              </h1>
              <div className="mt-4"><PendingBadge>Khmer name pending</PendingBadge></div>
            </>
          ) : (
            <>
              <h1 lang="km" className="record-khmer-title font-khmer text-accent">
                {entry.name_khmer}
              </h1>
              <p className="record-english-title mt-4 font-display text-xl leading-relaxed text-ink sm:text-2xl">
                {entry.name_english}
              </p>
            </>
          )}
          {provenance ? <p className="record-source-summary source-notice">{provenance}</p> : null}
        </header>

        <figure className="record-figure mx-auto w-full max-w-[30rem] lg:mx-0">
          <EntryPhotoTransition entryId={entry.id}>
            <div className="record-photograph ornament-frame relative bg-accent-soft" style={frame}>
              {photo ? (
                <FadeInImage
                  src={photo.src}
                  alt={photo.alt ?? (khmerPending ? entry.name_english : `${entry.name_english} (${entry.name_khmer})`)}
                  fill
                  sizes="(max-width: 639px) calc(100vw - 40px), 480px"
                  className="object-contain p-3 sm:p-4"
                  preload
                />
              ) : (
                <NoPhotoPanel size="lg" withheld={isPhotoWithheld(entry)} />
              )}
            </div>
          </EntryPhotoTransition>
          {photo ? (
            <figcaption className="record-photo-credit">
              <span lang="km" className="font-khmer">ប្រភពរូបថត</span>
              <span className="record-label-english">Photo credit</span>
              <PhotoCreditLine credit={photo.credit} />
              {photo.caption ? <p>{photo.caption}</p> : null}
            </figcaption>
          ) : null}
        </figure>

        <section aria-labelledby="record-story-title" className="record-story-panel min-w-0">
          <h2 id="record-story-title" className="record-bilingual-label record-story-label">
            <span aria-hidden="true" className="heading-flower" />
            <span lang="km" className="font-khmer">រឿងរ៉ាវវប្បធម៌</span>
            <span className="record-label-english">The cultural story</span>
          </h2>
          <div className="record-prose space-y-5">
            {prose.split(/\n\s*\n/).map((paragraph, index) => (
              <p key={index} className="whitespace-pre-line text-ink">{paragraph}</p>
            ))}
            {notes.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {notes.map((note) => <PendingBadge key={note}>{note}</PendingBadge>)}
              </div>
            ) : null}
          </div>
        </section>

        <dl className="object-record record-metadata min-w-0 border-t border-line">
          <div>
            <dt className="record-bilingual-label">
              <span lang="km" className="font-khmer">ឱកាស</span>
              <span className="record-label-english">Occasion</span>
            </dt>
            <dd className="text-base leading-relaxed text-ink">
              {contextPending ? <PendingBadge>Occasion not recorded</PendingBadge> : occasion}
            </dd>
          </div>
          <div>
            <dt className="record-bilingual-label">
              <span lang="km" className="font-khmer">ប្រភពផ្ទាល់មាត់</span>
              <span className="record-label-english">Oral source</span>
            </dt>
            <dd className="space-y-3 text-base leading-relaxed text-ink">
              {!isPlaceholder(entry.told_by) ? <p>{entry.told_by}</p> : null}
              {oralPending ? (
                <p className="text-sm text-muted">
                  {isPlaceholder(entry.told_by)
                    ? "No named person has been recorded for this exhibit yet."
                    : "A general credit, not yet a named, consenting source."}
                  {record && isResearchedRow(entry) ? " The text draws on the written references below." : ""}
                </p>
              ) : null}
            </dd>
          </div>
        </dl>

        {references.length > 0 ? (
          <section aria-labelledby="record-references-title" className="record-references min-w-0">
            <h2 id="record-references-title" className="record-bilingual-label">
              <span lang="km" className="font-khmer">ឯកសារយោង</span>
              <span className="record-label-english">Sources &amp; references</span>
            </h2>
            <p className="record-references-note">
              Written research, not oral testimony. Each source is listed with what it documents for this record.
            </p>
            <ol className="record-reference-list">
              {references.map((ref) => (
                <li key={ref.url}>
                  <a href={ref.url} className="record-reference-title" lang={ref.lang}>
                    {ref.title}
                  </a>
                  <span className="record-reference-meta">
                    {[ref.author, ref.publisher, ref.published].filter(Boolean).join(" · ")}
                    {ref.lang === "km" ? " · in Khmer" : ref.lang === "fr" ? " · in French" : ""}
                  </span>
                  <span className="record-reference-supports">{ref.supports}</span>
                </li>
              ))}
            </ol>
          </section>
        ) : null}

        {unresolved.length > 0 ? (
          <section aria-labelledby="record-unresolved-title" className="record-unresolved min-w-0">
            <h2 id="record-unresolved-title" className="record-bilingual-label">
              <span lang="km" className="font-khmer">មិនទាន់បានផ្ទៀងផ្ទាត់</span>
              <span className="record-label-english">Not yet verified</span>
            </h2>
            <ul>
              {unresolved.map((item) => <li key={item}>{item}</li>)}
            </ul>
          </section>
        ) : null}
      </div>
    </article>
  );
}
