import type { Metadata } from "next";

import { submitEntry } from "@/app/submit/actions";
import { EntryForm } from "@/components/EntryForm";
import { requireUser } from "@/lib/auth";

export const metadata: Metadata = {
  title: "Submit a dessert — The Khmer Living Archive",
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
 * the two cannot disagree about what an entry needs.
 */
export default async function SubmitPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  await requireUser("/submit");

  const params = await searchParams;
  const raw = params.error;
  const error = (Array.isArray(raw) ? raw[0] : raw) ?? "";

  return (
    <section className="mx-auto max-w-3xl px-6 py-16 lg:py-20">
      <p className="text-xs uppercase tracking-[0.22em] text-muted">
        Contribute
      </p>

      <h1 className="mt-5 text-3xl uppercase leading-[1.1] tracking-[0.01em] text-accent sm:text-4xl">
        Add a dessert to the archive.
      </h1>

      <p className="mt-5 max-w-xl text-sm leading-relaxed text-muted">
        Your entry is saved as pending and stays off the public archive until a
        reviewer publishes it. You can see its status any time under your
        entries.
      </p>

      <EntryForm
        action={submitEntry}
        submitLabel="Submit for review"
        error={error}
      />
    </section>
  );
}
