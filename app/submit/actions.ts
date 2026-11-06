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
import { createEntry } from "@/lib/entries";
import { limitMessage } from "@/lib/limits";
import { deletePhoto, uploadPhoto } from "@/lib/photos";
import { EntryWriteError, photoNote, saveFailureMessage, saveWithPhoto } from "@/lib/save-with-photo";

/**
 * Submitting one dessert to the archive.
 *
 * A saved entry waits for a reviewer before it is public (migration 0003).
 * It must carry a photograph: the brief asks for text plus at least one
 * photo. That is checked here first, so a contributor is told before
 * anything is uploaded, and it is enforced again by 0003's insert policy,
 * which refuses a new row without one.
 *
 * Used with `useActionState` (see components/EntryForm.tsx): a failure
 * returns the message and the text exactly as typed, so the form comes back
 * filled in rather than empty. Success redirects. Nothing the database or
 * Storage says is passed through — it goes to the server log.
 *
 * Nothing in this file is what stops a contributor writing an entry owned by
 * someone else. The insert policy does that (auth.uid() = contributor_id),
 * and the Storage policy confines an upload to a folder named after the
 * uploader's own id.
 */
export async function submitEntry(
  previous: EntryFormState,
  formData: FormData,
): Promise<EntryFormState> {
  // Redirects to /login when signed out, so the rest of this can assume a user.
  const user = await requireUser("/submit");

  const values = entryValues(formData);

  const read = readEntryFields(formData);
  if (!read.ok) return formFailure(previous, read.error, values);

  const photo = readPhoto(formData);
  if (!photo) {
    return formFailure(previous, "Add a photograph of the dessert. Every entry needs one.", values);
  }

  /*
   * Upload, then insert; if the insert does not land, the photo is taken back
   * out of Storage, and if even that fails the message says so (see
   * lib/save-with-photo.ts).
   */
  const outcome = await saveWithPhoto({
    upload: () => uploadPhoto(user.id, photo, "new-entry"),
    write: (photoUrl) => {
      if (!photoUrl) throw new EntryWriteError(undefined);
      return createEntry({ contributorId: user.id, ...read.fields, photoUrl });
    },
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
    /*
     * The pending-entry limit is checked before the upload, but two
     * submissions sent at once can both pass that check; the database then
     * refuses the second entry (KA001, migration 0006). Its photo has already
     * been taken back out, and photoNote says so.
     */
    const limit = limitMessage(outcome.code);
    const message = limit ? `${limit}${photoNote(outcome.cleanup)}` : saveFailureMessage("new", outcome);
    return formFailure(previous, message, values);
  }

  // The new entry is pending, so only "my entries" changes.
  revalidatePath("/my-entries");
  redirect("/my-entries?submitted=1");
}
