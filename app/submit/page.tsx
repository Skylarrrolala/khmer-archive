import type { Metadata } from "next";

import { submitEntry } from "@/app/submit/actions";
import { EntryForm } from "@/components/EntryForm";
import { requireUser } from "@/lib/auth";

export const metadata: Metadata = {
  title: "Submit a cake or snack — The Khmer Living Archive",
};

export const dynamic = "force-dynamic";

/**
 * The submission form.
 *
 * `requireUser` runs here rather than in a layout: a layout does not control
 * whether the routes inside it render, so Next's authentication guide puts the
 * check in the page or, better, next to the data. The action calls it a second
 * time for itself — a page that renders a form is not a guarantee that the
 * POST which follows came from a signed-in session.
 *
 * The fields themselves live in <EntryForm />, shared with the edit page so
 * the two cannot disagree about what an entry needs. Errors come back through
 * the form's own state, not the URL, so this page reads no query string.
 */
export default async function SubmitPage() {
  await requireUser("/submit");

  return (
    <section className="mx-auto max-w-3xl px-6 py-16 lg:py-20">
      <p className="text-xs uppercase tracking-[0.22em] text-muted">
        Contribute
      </p>

      <h1 className="mt-5 text-3xl uppercase leading-[1.1] tracking-[0.01em] text-accent sm:text-4xl">
        Add a cake or snack to the archive.
      </h1>

      <p className="mt-5 max-w-xl text-sm leading-relaxed text-muted">
        A reviewer reads every entry before it appears in the public archive,
        credited to the person you name below. You can follow its status, and
        edit or delete it, from your entries.
      </p>

      <EntryForm
        action={submitEntry}
        submitLabel="Submit for review"
        pendingLabel="Submitting…"
      />
    </section>
  );
}
