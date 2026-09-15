import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";

import { removeEntry } from "@/app/my-entries/[id]/actions";
import { requireUser } from "@/lib/auth";
import { getMyEntry } from "@/lib/entries";
import { isPlaceholder } from "@/lib/placeholders";

export const metadata: Metadata = {
  title: "Delete an entry — The Khmer Living Archive",
};

export const dynamic = "force-dynamic";

/**
 * Confirming a deletion.
 *
 * A page rather than a dialog, for two reasons. This project has no client
 * components at all — every form posts to a Server Action — and `confirm()`
 * would be the first, for the one interaction that least deserves JavaScript
 * standing between the click and the outcome. And a modal that asks "are you
 * sure?" shows nothing; this shows the entry itself, so what is about to be
 * lost is on screen at the moment of deciding.
 *
 * The delete is a POST from a form, never a link. A GET that destroys
 * something can be fired by a prefetch, a crawler, or an <img> on another
 * site; this URL only ever displays.
 */
export default async function DeleteEntryPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  const { id } = await params;
  const user = await requireUser(`/my-entries/${id}/delete`);
  const entry = await getMyEntry(id, user.id);

  // Someone else's entry, or none — indistinguishable here, deliberately.
  if (!entry) notFound();

  const query = await searchParams;
  const raw = query.error;
  const error = (Array.isArray(raw) ? raw[0] : raw) ?? "";

  const khmerPending = isPlaceholder(entry.name_khmer);

  return (
    <section className="mx-auto max-w-2xl px-6 py-16 lg:py-20">
      <Link
        href={`/my-entries/${entry.id}/edit`}
        className="text-xs uppercase tracking-[0.22em] text-accent hover:underline"
      >
        ← Back to editing
      </Link>

      <p className="mt-12 text-xs uppercase tracking-[0.22em] text-muted">
        Delete
      </p>

      <h1 className="mt-5 text-3xl uppercase leading-[1.1] tracking-[0.01em] text-accent sm:text-4xl">
        Delete this entry?
      </h1>

      {/* A refusal from the delete policy, said plainly. Escaped by React on
          render, so a crafted ?error= is shown, not run. */}
      {error ? (
        <p className="mt-8 border border-accent bg-accent-soft px-4 py-3 text-sm text-accent">
          {error}
        </p>
      ) : null}

      <div className="mt-10 flex flex-wrap items-center gap-5 border border-line bg-card p-5 sm:flex-nowrap">
        <div className="relative h-24 w-24 shrink-0 overflow-hidden bg-accent-soft">
          {entry.photo_url ? (
            <Image
              src={entry.photo_url}
              alt=""
              fill
              sizes="96px"
              className="object-cover"
            />
          ) : (
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
          <p className="mt-2 text-sm text-muted">Told by {entry.told_by}</p>
        </div>
      </div>

      <p className="mt-8 text-sm leading-relaxed text-muted">
        The entry and its photograph are removed for good. There is no undo, and
        no copy kept anywhere else — if this is the only record of how the
        dessert was made, it goes with it.
      </p>

      <div className="mt-10 flex flex-wrap items-center gap-6">
        <form action={removeEntry.bind(null, entry.id)}>
          <button
            type="submit"
            className="bg-accent px-8 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          >
            Yes, delete it
          </button>
        </form>

        <Link
          href="/my-entries"
          className="text-xs uppercase tracking-[0.18em] text-accent hover:underline"
        >
          Keep it
        </Link>
      </div>
    </section>
  );
}
