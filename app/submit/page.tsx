import type { Metadata } from "next";

import { submitEntry } from "@/app/submit/actions";
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
 * The form is a plain `<form action={serverAction}>`. Server Actions post as
 * multipart automatically, which is what lets the file input work with no
 * client-side JavaScript at all.
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

      {/* Escaped by React on render, so a crafted ?error= is shown, not run. */}
      {error ? (
        <p className="mt-8 border border-accent bg-accent-soft px-4 py-3 text-sm text-accent">
          {error}
        </p>
      ) : null}

      <form action={submitEntry} className="mt-10 space-y-8">
        <div className="grid gap-8 sm:grid-cols-2">
          <Field
            name="name_khmer"
            label="Name in Khmer"
            hint="នំ… — the name as it is written."
            required
            /* The one input that must be Khmer script, so it asks for the
               Khmer keyboard on a phone and is set in the Khmer face with the
               leading that keeps subscripts from clipping. */
            inputClassName="font-khmer text-lg leading-[1.7]"
            lang="km"
          />
          <Field
            name="name_english"
            label="Name in English"
            hint="A transliteration, or a plain description."
            required
          />
        </div>

        <div className="grid gap-8 sm:grid-cols-2">
          <Field
            name="told_by"
            label="Told by"
            hint="The person who shared it, by name, with their permission."
            required
          />
          <Field
            name="context"
            label="When it is made"
            hint="A festival, a ceremony, an everyday snack."
            required
          />
        </div>

        <div className="space-y-2">
          <label
            htmlFor="description"
            className="block text-xs uppercase tracking-[0.18em] text-muted"
          >
            The story
          </label>
          <textarea
            id="description"
            name="description"
            required
            rows={10}
            className="w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none"
          />
          <p className="text-xs text-muted">
            The memory behind it, and the ingredients or method if they are
            known. Line breaks are kept as you type them.
          </p>
        </div>

        <div className="space-y-2">
          <label
            htmlFor="photo"
            className="block text-xs uppercase tracking-[0.18em] text-muted"
          >
            Photograph <span className="normal-case tracking-normal">(optional)</span>
          </label>
          <input
            id="photo"
            name="photo"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="w-full border border-line bg-accent-soft px-4 py-3 text-sm text-ink file:mr-4 file:border-0 file:bg-accent file:px-4 file:py-2 file:text-xs file:uppercase file:tracking-[0.18em] file:text-on-accent focus:border-accent focus:outline-none"
          />
          <p className="text-xs text-muted">
            JPEG, PNG or WebP, up to 5 MB. Leave this empty for a dessert that
            is remembered but was never photographed — that absence is part of
            the record, not a gap in it.
          </p>
        </div>

        <button
          type="submit"
          className="bg-accent px-8 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          Submit for review
        </button>
      </form>
    </section>
  );
}

/** One labelled text input. Six of them differ only in their strings. */
function Field({
  name,
  label,
  hint,
  required,
  inputClassName = "",
  lang,
}: {
  name: string;
  label: string;
  hint: string;
  required?: boolean;
  inputClassName?: string;
  lang?: string;
}) {
  return (
    <div className="space-y-2">
      <label
        htmlFor={name}
        className="block text-xs uppercase tracking-[0.18em] text-muted"
      >
        {label}
      </label>
      <input
        id={name}
        name={name}
        type="text"
        lang={lang}
        required={required}
        className={`w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none ${inputClassName}`}
      />
      <p className="text-xs text-muted">{hint}</p>
    </div>
  );
}
