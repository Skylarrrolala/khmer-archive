import Image from "next/image";

import type { Entry } from "@/lib/types";

/**
 * The six fields of an entry, as a form.
 *
 * Submitting a new dessert and editing an existing one ask for exactly the
 * same things, so they share this rather than keeping two copies that slowly
 * disagree about which fields are required or how large a photo may be.
 *
 * It stays a Server Component. There is no `"use client"` anywhere in this
 * project: a plain `<form action={serverAction}>` posts as multipart on its
 * own, which is what lets the file input work with no client-side JavaScript
 * at all. The cost is that errors arrive back as a redirect carrying
 * `?error=`, because without `useActionState` there is nowhere in memory to
 * put them — the two pages pass that string in as `error`.
 *
 * Nothing here is a security boundary. The `required` attributes and the
 * `accept` filter are hints a browser can be told to ignore; the action
 * revalidates every field, the CHECK constraints in
 * supabase/migrations/0001_init.sql refuse an empty one, and the RLS policies
 * decide whose row may be written at all.
 */
export function EntryForm({
  action,
  submitLabel,
  entry,
  error,
}: {
  action: (formData: FormData) => void | Promise<void>;
  submitLabel: string;
  /** The entry being edited; absent when submitting a new one. */
  entry?: Entry | null;
  /** A message from the last attempt, already decoded from `?error=`. */
  error?: string;
}) {
  return (
    <>
      {/* Escaped by React on render, so a crafted ?error= is shown, not run. */}
      {error ? (
        <p className="mt-8 border border-accent bg-accent-soft px-4 py-3 text-sm text-accent">
          {error}
        </p>
      ) : null}

      <form action={action} className="mt-10 space-y-8">
        <div className="grid gap-8 sm:grid-cols-2">
          <Field
            name="name_khmer"
            label="Name in Khmer"
            hint="នំ… — the name as it is written."
            required
            defaultValue={entry?.name_khmer}
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
            defaultValue={entry?.name_english}
          />
        </div>

        <div className="grid gap-8 sm:grid-cols-2">
          <Field
            name="told_by"
            label="Told by"
            hint="The person who shared it, by name, with their permission."
            required
            defaultValue={entry?.told_by}
          />
          <Field
            name="context"
            label="When it is made"
            hint="A festival, a ceremony, an everyday snack."
            required
            defaultValue={entry?.context}
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
            defaultValue={entry?.description}
            className="w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none"
          />
          <p className="text-xs text-muted">
            The memory behind it, and the ingredients or method if they are
            known. Line breaks are kept as you type them.
          </p>
        </div>

        <PhotoField currentUrl={entry?.photo_url ?? null} />

        <button
          type="submit"
          className="bg-accent px-8 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          {submitLabel}
        </button>
      </form>
    </>
  );
}

/** One labelled text input. Four of them differ only in their strings. */
function Field({
  name,
  label,
  hint,
  required,
  defaultValue,
  inputClassName = "",
  lang,
}: {
  name: string;
  label: string;
  hint: string;
  required?: boolean;
  defaultValue?: string;
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
        defaultValue={defaultValue}
        className={`w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none ${inputClassName}`}
      />
      <p className="text-xs text-muted">{hint}</p>
    </div>
  );
}

/**
 * The photograph: optional on a new entry, replaceable on an existing one.
 *
 * Optional is deliberate, and it is the archive's subject matter rather than a
 * shortcut. CLAUDE.md's sprint list says "text + at least one photo upload",
 * but the data model is explicit that `photo_url` is nullable because
 * "desserts they only remember may have no photo at all" — and a dessert
 * nobody photographed is exactly what this archive exists to record.
 * Requiring a file would make that unrecordable.
 *
 * On an entry that already has one, the choice is three-way — keep, replace,
 * remove — so removal is a checkbox rather than the absence of a file. An
 * empty file input cannot mean "delete the photo", because that is also what
 * it means when someone edits the spelling of a name and touches nothing else.
 */
function PhotoField({ currentUrl }: { currentUrl: string | null }) {
  return (
    <div className="space-y-2">
      <label
        htmlFor="photo"
        className="block text-xs uppercase tracking-[0.18em] text-muted"
      >
        Photograph{" "}
        <span className="normal-case tracking-normal">(optional)</span>
      </label>

      {currentUrl ? (
        <div className="flex flex-wrap items-center gap-5 border border-line bg-card p-4">
          <div className="relative h-20 w-20 shrink-0 overflow-hidden bg-accent-soft">
            <Image
              src={currentUrl}
              alt=""
              fill
              sizes="80px"
              className="object-cover"
            />
          </div>
          <div className="min-w-0 flex-1 space-y-3">
            <p className="text-xs uppercase tracking-[0.18em] text-muted">
              Current photograph
            </p>
            <label className="flex items-center gap-3 text-sm text-ink">
              <input
                type="checkbox"
                name="remove_photo"
                value="1"
                className="h-4 w-4 accent-accent"
              />
              Remove this photograph
            </label>
          </div>
        </div>
      ) : null}

      <input
        id="photo"
        name="photo"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="w-full border border-line bg-accent-soft px-4 py-3 text-sm text-ink file:mr-4 file:border-0 file:bg-accent file:px-4 file:py-2 file:text-xs file:uppercase file:tracking-[0.18em] file:text-on-accent focus:border-accent focus:outline-none"
      />

      <p className="text-xs text-muted">
        {currentUrl
          ? "JPEG, PNG or WebP, up to 5 MB. Choosing a file replaces the photograph above; leaving this empty keeps it."
          : "JPEG, PNG or WebP, up to 5 MB. Leave this empty for a dessert that is remembered but was never photographed — that absence is part of the record, not a gap in it."}
      </p>
    </div>
  );
}
