"use client";

import Image from "next/image";
import { useActionState } from "react";

import { SubmitButton } from "@/components/SubmitButton";
import {
  initialEntryFormState,
  type EntryFormState,
  type EntryValues,
} from "@/lib/entry-form";
import type { Entry } from "@/lib/types";

/**
 * The six fields of an entry, as a form.
 *
 * Submitting a new dessert and editing an existing one ask for exactly the
 * same things, so they share this rather than keeping two copies that slowly
 * disagree about which fields are required or how large a photo may be.
 *
 * A Client Component, for one reason: when a submission fails, the text has
 * to come back. With a plain `<form action>` a failure could only redirect,
 * which empties the form — a story of several thousand characters gone
 * because of one missing field. `useActionState` keeps the action's answer in
 * memory instead: the action returns the error and the values as typed, and
 * the form is remounted (keyed on `attempt`) with those values as its starting
 * text. The photo is the one thing that cannot come back — no website can set
 * a file input's value — so the error message says to choose it again.
 *
 * The submit button disables itself while the action runs. That reduces
 * accidental duplicate submissions on a slow upload; it does not prevent
 * them (not without JavaScript, not before hydration, not across two tabs).
 *
 * Nothing here is a security boundary. The `required` attributes and the
 * `accept` filter are hints a browser can be told to ignore; the action
 * revalidates every field, the CHECK constraints in migration 0002 refuse an
 * invalid one, and the RLS policies decide whose row may be written at all.
 */
export function EntryForm({
  action,
  submitLabel,
  pendingLabel,
  entry,
}: {
  action: (state: EntryFormState, formData: FormData) => Promise<EntryFormState>;
  submitLabel: string;
  /** What the button says while the action runs. */
  pendingLabel: string;
  /** The entry being edited; absent when submitting a new one. */
  entry?: Entry | null;
}) {
  const [state, formAction] = useActionState(action, initialEntryFormState);

  // After a failed attempt, what was typed; otherwise the saved entry, if any.
  const value = (name: keyof EntryValues) => state.values?.[name] ?? entry?.[name];

  return (
    <>
      {/* role="alert" so a screen reader announces it: it appears after the
          submit, without a page load. React escapes the text. */}
      {state.error ? (
        <p
          role="alert"
          className="mt-8 border border-accent bg-accent-soft px-4 py-3 text-sm text-accent"
        >
          {state.error}
        </p>
      ) : null}

      <form key={state.attempt} action={formAction} className="mt-10 space-y-8">
        <div className="grid gap-8 sm:grid-cols-2">
          <Field
            name="name_khmer"
            label="Name in Khmer"
            hint="នំ… — the name as it is written."
            required
            defaultValue={value("name_khmer")}
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
            defaultValue={value("name_english")}
          />
        </div>

        <div className="grid gap-8 sm:grid-cols-2">
          <Field
            name="told_by"
            label="Told by"
            hint="The person who shared it, by name, with their permission."
            required
            defaultValue={value("told_by")}
          />
          <Field
            name="context"
            label="When it is made"
            hint="A festival, a ceremony, an everyday snack."
            required
            defaultValue={value("context")}
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
            defaultValue={value("description")}
            className="w-full border border-line bg-accent-soft px-4 py-3 text-ink transition-colors placeholder:text-muted focus:border-accent focus:outline-none"
          />
          <p className="text-xs text-muted">
            The memory behind it, and the ingredients or method if they are
            known. Line breaks are kept as you type them.
          </p>
        </div>

        <PhotoField currentUrl={entry?.photo_url ?? null} />

        <SubmitButton
          label={submitLabel}
          pendingLabel={pendingLabel}
          className="bg-accent px-8 py-3 text-xs uppercase tracking-[0.18em] text-on-accent transition-opacity hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:cursor-wait disabled:opacity-60"
        />
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
 * The photograph: required on a new entry, replaceable on an existing one.
 *
 * Required because Sprint 2's brief asks for text plus at least one photo,
 * and an entry is public the moment it is saved. Migration 0002 enforces the
 * same rule in the database — no published row without a photo — so the
 * `required` attribute here is only a hint; the server actions check it too.
 *
 * On an entry that already has one, the choice is two-way — keep or replace.
 * There is no "remove": a published entry cannot be left without a photo. An
 * empty file input means "keep", because that is also what the form sends
 * when someone edits the spelling of a name and touches nothing else.
 */
function PhotoField({ currentUrl }: { currentUrl: string | null }) {
  return (
    <div className="space-y-2">
      <label
        htmlFor="photo"
        className="block text-xs uppercase tracking-[0.18em] text-muted"
      >
        Photograph
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
          <p className="min-w-0 flex-1 text-xs uppercase tracking-[0.18em] text-muted">
            Current photograph
          </p>
        </div>
      ) : null}

      <input
        id="photo"
        name="photo"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        required={!currentUrl}
        className="w-full border border-line bg-accent-soft px-4 py-3 text-sm text-ink file:mr-4 file:border-0 file:bg-accent file:px-4 file:py-2 file:text-xs file:uppercase file:tracking-[0.18em] file:text-on-accent focus:border-accent focus:outline-none"
      />

      <p className="text-xs text-muted">
        {currentUrl
          ? "JPEG, PNG or WebP, up to 5 MB. Choosing a file replaces the photograph above; leaving this empty keeps it."
          : "JPEG, PNG or WebP, up to 5 MB. Every entry needs a photograph of the dessert."}
      </p>
    </div>
  );
}
