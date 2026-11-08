import type { Metadata } from "next";
import { Suspense } from "react";

import { decideEntry } from "@/app/review/actions";
import { FadeInImage } from "@/components/FadeInImage";
import { SubmitButton } from "@/components/SubmitButton";
import { requireReviewer } from "@/lib/auth";
import { getPendingEntries } from "@/lib/entries";

export const metadata: Metadata = {
  title: "Review entries — The Khmer Living Archive",
};

export const dynamic = "force-dynamic";

const notices: Record<string, string> = {
  published: "The entry was published and is now in the public archive.",
  returned: "The entry was returned. Its contributor can edit it and submit it for review again.",
  unchanged: "Nothing was changed. The entry may already have been reviewed or deleted, or it may be your own submission.",
  failed: "The decision could not be saved. Please try again. Publishing requires a photograph.",
  invalid: "That review request was invalid. Please use the Publish or Return buttons below.",
};

export default async function ReviewPage({
  searchParams,
}: {
  searchParams: Promise<{ result?: string | string[] }>;
}) {
  const user = await requireReviewer();
  const { result } = await searchParams;
  const notice = typeof result === "string" && Object.hasOwn(notices, result) ? notices[result] : null;

  return (
    <section className="mx-auto max-w-4xl px-6 py-16 lg:py-20">
      <h1 className="text-3xl leading-tight text-accent sm:text-4xl">Review entries</h1>
      <p className="mt-4 text-muted">
        Pending entries are hidden from the public. Read the submission and check its photograph
        before publishing or returning it.
      </p>

      {notice ? (
        <p role="status" className="mt-8 border border-line bg-accent-soft px-4 py-3 text-sm">
          {notice}
        </p>
      ) : null}

      {/* Authorize before streaming a loading state, so denied requests retain their redirect/404. */}
      <Suspense fallback={<p role="status" className="mt-8 text-muted">Loading pending entries…</p>}>
        <PendingEntries reviewerId={user.id} />
      </Suspense>
    </section>
  );
}

async function PendingEntries({ reviewerId }: { reviewerId: string }) {
  const entries = await getPendingEntries();

  if (entries.length === 0) {
    return <p className="mt-8 border border-line bg-card p-8 text-muted">No entries are waiting for review.</p>;
  }

  return (
    <ul className="mt-8 space-y-8">
      {entries.map((entry) => (
        <li key={entry.id} className="border border-line bg-card p-5 sm:p-8">
          <article aria-labelledby={`entry-${entry.id}`} className="space-y-5 break-words">
            <header>
              <h2 id={`entry-${entry.id}`} className="font-khmer text-2xl leading-[1.7] text-accent">
                {entry.name_khmer}
              </h2>
              <p className="text-lg">{entry.name_english}</p>
            </header>

            {entry.photo_url ? (
              <div className="relative aspect-[4/3] bg-accent-soft">
                <FadeInImage
                  src={entry.photo_url}
                  alt={entry.name_english}
                  fill
                  sizes="(max-width: 896px) 100vw, 768px"
                  className="object-contain"
                />
              </div>
            ) : (
              <p className="text-sm text-muted">No photograph. This entry can be returned, but needs a photo before publishing.</p>
            )}

            <dl className="space-y-4">
              <div><dt className="text-sm font-semibold">Told by</dt><dd>{entry.told_by}</dd></div>
              <div><dt className="text-sm font-semibold">Occasion or context</dt><dd>{entry.context}</dd></div>
              <div><dt className="text-sm font-semibold">Story or description</dt><dd className="whitespace-pre-wrap">{entry.description}</dd></div>
            </dl>

            {entry.contributor_id === reviewerId ? (
              <p className="text-sm text-muted">This is your submission. Another reviewer must review it.</p>
            ) : (
              <div className="flex flex-wrap gap-4">
                {entry.photo_url ? (
                  <form action={decideEntry.bind(null, entry.id, "published")}>
                    <SubmitButton
                      label="Publish"
                      pendingLabel="Publishing…"
                      className="bg-accent px-6 py-3 text-sm text-on-accent disabled:opacity-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
                    />
                  </form>
                ) : null}
                <form action={decideEntry.bind(null, entry.id, "returned")}>
                  <SubmitButton
                    label="Return"
                    pendingLabel="Returning…"
                    className="border border-accent px-6 py-3 text-sm text-accent disabled:opacity-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
                  />
                </form>
              </div>
            )}
          </article>
        </li>
      ))}
    </ul>
  );
}
