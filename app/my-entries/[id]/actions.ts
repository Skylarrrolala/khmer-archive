"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireUser } from "@/lib/auth";
import {
  entryValues,
  formFailure,
  readEntryFields,
  readPhoto,
  type EntryFormState,
} from "@/lib/entry-form";
import { deleteEntry, getMyEntry, updateEntry } from "@/lib/entries";
import { deletePhoto, uploadPhoto } from "@/lib/photos";
import { EntryWriteError, saveFailureMessage, saveWithPhoto } from "@/lib/save-with-photo";

/**
 * Editing and deleting an entry you own.
 *
 * The id arrives bound into the action rather than as a hidden form field —
 * `saveEntry.bind(null, entry.id)` on the page — so there is no id in the
 * markup for anyone to retype. That is tidiness, not security: if the id were
 * a hidden input and someone swapped in another contributor's, every query
 * below would still come back empty, because the update and delete policies
 * compare `auth.uid()` to the row's `contributor_id` inside Postgres
 * (0001_init.sql, kept unchanged by 0002). The database is what refuses. These
 * functions decide what happens next — a redirect back to your own entries,
 * rather than a stack trace.
 */

/**
 * Rewrites an entry and sends it back for review — every edit, by anyone,
 * reviewers included (migration 0007). A reviewer's edit to their own
 * published entry used to stay public, so new text or a new photo went out
 * unreviewed.
 *
 * The photograph can be replaced but not removed: migration 0003's update
 * policy refuses an edited row without one. A chosen file replaces the
 * current photo; an empty file input keeps it, because an empty input is also
 * what an untouched form sends. The one case with no photo to keep is an
 * entry submitted before Sprint 2 that never had one — saving it needs a photo.
 *
 * Used with `useActionState`, like submitting: a failure comes back to the
 * form with the text as typed; success and "no such entry of yours" redirect.
 * Neither outcome reads as a success unless the row was actually written.
 */
export async function saveEntry(
  id: string,
  previous: EntryFormState,
  formData: FormData,
): Promise<EntryFormState> {
  const user = await requireUser(`/my-entries/${id}/edit`);

  const values = entryValues(formData);

  const read = readEntryFields(formData);
  if (!read.ok) return formFailure(previous, read.error, values);

  /*
   * Loaded to know which photo the entry has now, so that a replaced one can
   * be cleaned out of Storage afterwards, and so that an entry with no photo
   * can be asked for one. It is not an ownership check — `updateEntry` below
   * is subject to the same RLS whether this succeeded or not.
   */
  const current = await getMyEntry(id, user.id);
  if (!current) redirect("/my-entries?unchanged=1");

  const photo = readPhoto(formData);
  if (!photo && !current.photo_url) {
    return formFailure(
      previous,
      "Add a photograph of the cake or snack. Every entry needs one.",
      values,
    );
  }

  // The update policy refuses any other status (migration 0007).
  const status = "pending";

  const outcome = await saveWithPhoto({
    upload: photo ? () => uploadPhoto(user.id, photo, "edit") : null,
    write: (newPhotoUrl) =>
      updateEntry(id, { ...read.fields, photoUrl: newPhotoUrl ?? current.photo_url, status }),
    removeUploaded: (url) => deletePhoto(user.id, url),
  });

  if (outcome.status === "upload-failed") {
    return formFailure(
      previous,
      `${outcome.error} Your text is kept; choose the photo again before you retry.`,
      values,
    );
  }

  if (outcome.status === "not-saved") {
    // Matched no row: the entry was deleted meanwhile, or is not this
    // contributor's. Said as such on the list page — never as "saved".
    if (outcome.cause === "no-row") redirect("/my-entries?unchanged=1");
    return formFailure(previous, saveFailureMessage("edit", outcome), values);
  }

  /*
   * The old photo goes only once the row no longer points at it; the other
   * order risks a row pointing at a file that is already gone. If it cannot
   * be removed, the save still stands, and the notice says the old file is
   * still in storage.
   */
  const oldPhotoRemoved =
    outcome.newPhotoUrl && current.photo_url
      ? await deletePhoto(user.id, current.photo_url)
      : true;

  // A published entry has left the public archive, so the browse page and the
  // entry's own page change, not only "my entries".
  revalidatePath("/my-entries");
  revalidatePath("/");
  revalidatePath(`/entries/${id}`);
  const done = "/my-entries?updated=pending";
  redirect(oldPhotoRemoved ? done : `${done}&oldphoto=kept`);
}

/**
 * Deletes an entry and the photograph that belonged to it.
 *
 * `deleteEntry` hands back the row it removed, which is the only chance to
 * read its `photo_url` — afterwards there is nothing left to ask. A row that
 * comes back null was either already gone or was never this contributor's
 * (the delete policy filtered it out); either way nothing was deleted, and
 * the list page says so rather than claiming success.
 *
 * A database error goes back to the delete page as a flag, not as text: the
 * page shows a fixed sentence, so nothing Postgres says reaches the browser.
 * The same goes for a photo that could not be removed after the row was: the
 * deletion stands, and a flag adds one plain sentence saying so.
 */
export async function removeEntry(id: string) {
  const user = await requireUser(`/my-entries/${id}/delete`);

  let deleted;
  try {
    deleted = await deleteEntry(id);
  } catch (cause) {
    // deleteEntry logged a database refusal itself; anything else is logged here.
    if (!(cause instanceof EntryWriteError)) console.error("[entries] delete failed:", cause);
    redirect(`/my-entries/${id}/delete?failed=1`);
  }

  // Nothing changed, so there is nothing to refresh either.
  if (!deleted) redirect("/my-entries?unchanged=1");

  // deletePhoto logs a failure as [photo-cleanup] and never throws.
  const photoRemoved = await deletePhoto(user.id, deleted.photo_url);

  revalidatePath("/my-entries");
  revalidatePath("/");
  revalidatePath(`/entries/${id}`);
  redirect(photoRemoved ? "/my-entries?deleted=1" : "/my-entries?deleted=1&oldphoto=kept");
}
