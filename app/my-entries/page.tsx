import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";

import { requireUser } from "@/lib/auth";
import { getMyEntries } from "@/lib/entries";
import { isPlaceholder } from "@/lib/placeholders";
import type { Entry, EntryStatus } from "@/lib/types";

export const metadata: Metadata = {
  title: "Your entries — The Khmer Living Archive",
};

export const dynamic = "force-dynamic";

/**
 * Everything this contributor has submitted, with where it stands.
 *
 * This is the one page in the archive that shows unpublished rows, and it is
 * worth being precise about why that is safe. It is not because of the
 * `requireUser` call at the top — that only decides whether to render. It is
 * because `getMyEntries` runs as this user's session, and the RLS policy
 * "contributors can read their own entries" is what makes Postgres willing to
 * return a pending row at all. Signed in as someone else, the same query
 * returns their rows and not these.
 */
export default async function MyEntriesPage({
  searchParams,
}: {
  searchParams: Promise<{
    submitted?: string | string[];
    updated?: string | string[];
    deleted?: string | string[];
  }>;
}) {
  const user = await requireUser("/my-entries");
  const entries = await getMyEntries(user.id);

  const params = await searchParams;
  const notice = noticeFor(params);

  const count = `${entries.length} ${entries.length === 1 ? "entry" : "entries"}`;

  return (
    <section className="mx-auto max-w-4xl px-6 py-16 lg:py-20">
      <p className="text-xs uppercase tracking-[0.22em] text-muted">
        Your submissions
      </p>

      <div className="mt-5 flex flex-wrap items-baseline justify-between gap-x-8 gap-y-4">
        <h1 className="text-3xl uppercase leading-[1.1] tracking-[0.01em] text-accent sm:text-4xl">
          Entries you have sent.
        </h1>

        <Link
          href="/submit"
          className="bg-accent px-6 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90"
        >
          Add a dessert
        </Link>
      </div>

      {notice ? (
        <p className="mt-8 border border-line bg-accent-soft px-4 py-3 text-sm text-ink">
          {notice}
        </p>
      ) : null}

      <p className="mt-8 text-xs uppercase tracking-[0.22em] text-muted">
        {count}
      </p>

      {entries.length === 0 ? (
        <p className="mt-6 border border-line bg-card p-8 text-muted">
          You have not submitted anything yet. The first one can be a dessert
          nobody photographed — a description on its own is a complete entry
          here.
        </p>
      ) : (
        <ul className="mt-6 space-y-5">
          {entries.map((entry) => (
            <MyEntryRow key={entry.id} entry={entry} />
          ))}
        </ul>
      )}
    </section>
  );
}

/**
 * One submission: a thumbnail, the name, and its review status.
 *
 * Deliberately not <EntryCard />. That component is built for the public grid,
 * where every row is published and links to a detail page. A pending entry has
 * no public detail page to link to — `getPublishedEntry` would 404 on it, on
 * purpose — so linking one would hand the contributor a broken promise.
 */
function MyEntryRow({ entry }: { entry: Entry }) {
  const khmerPending = isPlaceholder(entry.name_khmer);

  return (
    <li className="flex flex-wrap items-center gap-5 border border-line bg-card p-5 sm:flex-nowrap">
      <div className="relative h-20 w-20 shrink-0 overflow-hidden bg-accent-soft">
        {entry.photo_url ? (
          <Image
            src={entry.photo_url}
            alt=""
            fill
            sizes="80px"
            className="object-cover"
          />
        ) : (
          /* No photo is a legitimate state here, not a broken image, so it
             gets a label rather than an icon that looks like a failure. */
          <span className="flex h-full items-center justify-center px-2 text-center text-[0.6rem] uppercase tracking-[0.12em] text-muted">
            No photo
          </span>
        )}
      </div>

      <div className="min-w-0 flex-1">
        {khmerPending ? (
          <p className="text-lg text-accent">{entry.name_english}</p>
        ) : (
          <>
            <p className="font-khmer text-xl leading-[1.7] text-accent">
              {entry.name_khmer}
            </p>
            <p className="text-sm text-ink">{entry.name_english}</p>
          </>
        )}
        <p className="mt-1 text-xs uppercase tracking-[0.18em] text-muted">
          {new Date(entry.created_at).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric",
          })}
        </p>
      </div>

      <div className="flex shrink-0 flex-col items-start gap-3 sm:items-end">
        <StatusBadge status={entry.status} />

        {/* Shown for every row, including published ones: editing a published
            entry is allowed and returns it to the review queue, which the edit
            page says before the form. Hiding these links would not protect
            anything either way — the update and delete policies are what
            refuse a row that is not yours. */}
        <p className="flex gap-4 text-[0.65rem] uppercase tracking-[0.15em]">
          <Link
            href={`/my-entries/${entry.id}/edit`}
            className="text-accent hover:underline"
          >
            Edit
          </Link>
          <Link
            href={`/my-entries/${entry.id}/delete`}
            className="text-muted hover:text-accent hover:underline"
          >
            Delete
          </Link>
        </p>
      </div>
    </li>
  );
}

/**
 * The one-line result of whatever the contributor just did, or null.
 *
 * The three actions redirect back here with a flag rather than rendering their
 * own confirmation page, so the answer to "did that work?" is always in the
 * same place, next to the list it changed.
 */
function noticeFor(params: {
  submitted?: string | string[];
  updated?: string | string[];
  deleted?: string | string[];
}): string | null {
  const flag = (value: string | string[] | undefined) =>
    (Array.isArray(value) ? value[0] : value) === "1";

  if (flag(params.submitted)) {
    return "Thank you — your entry was received and is waiting for review.";
  }
  if (flag(params.updated)) {
    return "Your changes were saved. The entry is back in the review queue.";
  }
  if (flag(params.deleted)) {
    return "The entry was deleted.";
  }

  return null;
}

/**
 * Where an entry stands in review.
 *
 * The three states are the `entry_status` enum in the migration. Colour alone
 * does not carry the meaning — each badge says its own word — because a
 * red-green difference is exactly what a colour-blind reader cannot use, and
 * "rejected" is not something to communicate by hue.
 */
function StatusBadge({ status }: { status: EntryStatus }) {
  const label: Record<EntryStatus, string> = {
    pending: "Awaiting review",
    published: "Published",
    rejected: "Not accepted",
  };

  const tone: Record<EntryStatus, string> = {
    pending: "border-line text-muted",
    published: "border-accent text-accent",
    rejected: "border-line text-muted line-through",
  };

  return (
    <span
      className={`shrink-0 border px-3 py-1.5 text-[0.65rem] uppercase tracking-[0.15em] ${tone[status]}`}
    >
      {label[status]}
    </span>
  );
}
