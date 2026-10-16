/**
 * Saving an entry together with a newly uploaded photo, so that a failure
 * never leaves the two out of step.
 *
 * The photo has to be uploaded first: the row stores the photo's URL, and
 * the database refuses a published row without one. So if the row then
 * fails to save, a file is sitting in Storage that nothing points at, in a
 * public bucket, belonging to someone who has just been told their entry
 * was not saved. This takes it back out. If even that fails, the outcome
 * says so, so the caller can tell the contributor instead of implying the
 * photo is gone.
 *
 * The steps arrive as functions so the decisions here can be tested without
 * Supabase. Kept free of imports so `node --test` can load it.
 */

/**
 * A database write that was refused or failed. `code` is the Postgres
 * SQLSTATE when there is one: 23514 for a CHECK constraint, 42501 for a
 * missing privilege or a row-level security refusal.
 *
 * The message is deliberately bland. What Postgres said goes to the server
 * log where the error is caught; it can name constraints, and its detail can
 * repeat the row, so it is never shown on a page.
 */
export class EntryWriteError extends Error {
  readonly code: string | undefined;

  constructor(code: string | undefined) {
    super(`The entry could not be written${code ? ` (${code})` : ""}.`);
    this.name = "EntryWriteError";
    this.code = code;
  }
}

export type UploadResult = { ok: true; url: string } | { ok: false; error: string };

/** What became of a photo uploaded for a write that did not land. */
export type Cleanup = "none-uploaded" | "removed" | "left-behind";

export type SaveOutcome<T> =
  | { status: "saved"; value: T; newPhotoUrl: string | null }
  | { status: "upload-failed"; error: string }
  | {
      status: "not-saved";
      /** "no-row": the write matched nothing, e.g. the entry is gone or not yours. */
      cause: "no-row" | "error";
      code: string | undefined;
      cleanup: Cleanup;
    };

export async function saveWithPhoto<T>(steps: {
  /** null when the form carried no new photo. */
  upload: (() => Promise<UploadResult>) | null;
  /** Writes the row. Resolves to null when it matched no row. */
  write: (newPhotoUrl: string | null) => Promise<T | null>;
  /** Removes an uploaded photo. Resolves to false if it could not. */
  removeUploaded: (url: string) => Promise<boolean>;
}): Promise<SaveOutcome<T>> {
  let newPhotoUrl: string | null = null;

  if (steps.upload) {
    const uploaded = await steps.upload();
    if (!uploaded.ok) return { status: "upload-failed", error: uploaded.error };
    newPhotoUrl = uploaded.url;
  }

  let value: T | null;
  try {
    value = await steps.write(newPhotoUrl);
  } catch (error) {
    return {
      status: "not-saved",
      cause: "error",
      code: error instanceof EntryWriteError ? error.code : undefined,
      cleanup: await takeBack(newPhotoUrl, steps.removeUploaded),
    };
  }

  if (value === null) {
    return {
      status: "not-saved",
      cause: "no-row",
      code: undefined,
      cleanup: await takeBack(newPhotoUrl, steps.removeUploaded),
    };
  }

  return { status: "saved", value, newPhotoUrl };
}

async function takeBack(
  url: string | null,
  remove: (url: string) => Promise<boolean>,
): Promise<Cleanup> {
  if (!url) return "none-uploaded";
  try {
    return (await remove(url)) ? "removed" : "left-behind";
  } catch {
    return "left-behind";
  }
}

/**
 * Why a save failed, in words a contributor can act on.
 *
 * It never repeats what the database said. It does say what happened to the
 * photo, because the file input cannot be refilled after a failed submit —
 * no website can set a file input's value — so if a photo was chosen, it has
 * to be chosen again.
 */
export function saveFailureMessage(
  kind: "new" | "edit",
  outcome: { code: string | undefined; cleanup: Cleanup },
): string {
  const subject =
    kind === "new"
      ? "Your entry was not saved, so nothing was published"
      : "Your changes were not saved";

  const reason =
    outcome.code === "23514"
      ? "one of the fields was not accepted. Check that each has some text and is not too long."
      : outcome.code === "42501"
        ? "you are not allowed to make that change."
        : "something went wrong on our side. Please try again in a moment.";

  return `${subject}: ${reason}${photoNote(outcome.cleanup)}`;
}

/** The sentence about the photo, after any failure once one was chosen. */
export function photoNote(cleanup: Cleanup): string {
  if (cleanup === "none-uploaded") return "";
  if (cleanup === "removed") return " Your text is kept; choose the photo again before you retry.";
  return (
    " The photo you chose was uploaded but could not be removed from storage." +
    " It is not attached to any entry. Your text is kept; choose the photo again before you retry."
  );
}
