import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";

import { saveEntry } from "@/app/my-entries/[id]/actions";
import { EntryForm } from "@/components/EntryForm";
import { requireUser } from "@/lib/auth";
import { getMyEntry } from "@/lib/entries";

export const metadata: Metadata = {
  title: "Edit an entry — The Khmer Living Archive",
};

export const dynamic = "force-dynamic";

/**
 * Editing one of your own entries.
 *
 * The 404 on the next-to-last line is the interesting part. It fires when
 * `getMyEntry` returns null, and that happens for a nonexistent id, a
 * malformed one, and another contributor's — all three identically. Nobody can
 * use this URL to learn that someone else's pending entry exists, which is the
 * same reason the public detail page 404s an unpublished entry instead of
 * saying "not public".
 *
 * And it is a 404 rather than a permission check because there is no
 * permission check here to fail. The row simply did not come back: the SELECT
 * policies in supabase/migrations/0001_init.sql left it in the database. If
 * this page forgot to call `notFound()`, the form would render empty and the
 * save would still be refused by the update policy.
 */
export default async function EditEntryPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const user = await requireUser(`/my-entries/${id}/edit`);
  const entry = await getMyEntry(id, user.id);

  if (!entry) notFound();

  return (
    <section className="mx-auto max-w-3xl px-6 py-16 lg:py-20">
      <Link
        href="/my-entries"
        className="text-xs uppercase tracking-[0.22em] text-accent hover:underline"
      >
        ← Back to your entries
      </Link>

      <p className="mt-12 text-xs uppercase tracking-[0.22em] text-muted">
        Edit
      </p>

      <h1 className="mt-5 text-3xl uppercase leading-[1.1] tracking-[0.01em] text-accent sm:text-4xl">
        {entry.name_english}
      </h1>

      {/*
        Saving sends an entry for review: the update policy accepts only a
        pending row, from anyone, reviewers included (migrations 0003, 0007).
        For a published entry that means it leaves the archive until it is
        published again — said plainly, before the form, because it is the one
        consequence a contributor might not expect.
      */}
      <p className="mt-8 border border-accent bg-accent-soft px-4 py-3 text-sm text-accent">
        {entry.status === "published"
          ? "Saving sends your changes to a reviewer. The entry leaves the public archive until it is published again."
          : "This entry is not public. Saving sends it to a reviewer."}
        {entry.photo_url ? null : " It needs a photograph first."}
      </p>

      {/* The id is bound into the action here, so it never appears in the
          markup as something to retype. Errors come back through the form's
          own state, not the URL. */}
      <EntryForm
        action={saveEntry.bind(null, entry.id)}
        submitLabel="Save and send for review"
        pendingLabel="Saving…"
        entry={entry}
      />

      <div className="mt-16 border-t border-line pt-8">
        <p className="text-xs uppercase tracking-[0.22em] text-muted">
          Remove this entry
        </p>
        <p className="mt-4 max-w-xl text-sm leading-relaxed text-muted">
          Deleting an entry removes it, and its photograph, for good. If the
          dessert is only half-remembered, an incomplete entry is worth more to
          the archive than none.
        </p>
        <Link
          href={`/my-entries/${entry.id}/delete`}
          className="mt-5 inline-block border border-accent px-6 py-3 text-xs uppercase tracking-[0.18em] text-accent transition-colors hover:bg-accent hover:text-on-accent"
        >
          Delete this entry
        </Link>
      </div>
    </section>
  );
}
