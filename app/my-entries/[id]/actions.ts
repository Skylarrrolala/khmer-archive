"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireUser } from "@/lib/auth";
import { readEntryFields, readPhoto } from "@/lib/entry-form";
import { deleteEntry, getMyEntry, updateEntry } from "@/lib/entries";
import { deletePhoto, uploadPhoto } from "@/lib/photos";

/**
 * Editing and deleting an entry you own.
 *
 * The id arrives bound into the action rather than as a hidden form field —
 * `saveEntry.bind(null, entry.id)` on the page — so there is no id in the
 * markup for anyone to retype. That is tidiness, not security: if the id were
 * a hidden input and someone swapped in another contributor's, every query
 * below would still come back empty, because the update and delete policies in
 * supabase/migrations/0001_init.sql compare `auth.uid()` to the row's
 * `contributor_id` inside Postgres. The database is what refuses. These
 * functions decide what happens next — a redirect back to your own entries,
 * rather than a stack trace.
 */

function backToForm(id: string, message: string): never {
  redirect(`/my-entries/${id}/edit?error=${encodeURIComponent(message)}`);
}

/**
 * Rewrites an entry and returns it to the review queue.
 *
 * The photograph is a three-way choice, and the order of the branches is the
 * order of intent: a chosen file wins, then an explicit removal, and doing
 * neither keeps what is already there. An empty file input cannot mean
 * "delete the photo" — it is also what an untouched form sends.
 */
export async function saveEntry(id: string, formData: FormData) {
  const user = await requireUser(`/my-entries/${id}/edit`);

  const read = readEntryFields(formData);
  if (!read.ok) backToForm(id, read.error);

  /*
   * Loaded for one reason: to know which file the old `photo_url` points at,
   * so a replaced photograph can be cleaned out of Storage afterwards. It is
   * not an ownership check — `updateEntry` below is subject to the same RLS
   * whether this succeeded or not.
   */
  const current = await getMyEntry(id, user.id);
  if (!current) redirect("/my-entries");

  const photo = readPhoto(formData);
  const removeRequested = formData.get("remove_photo") === "1";

  let photoUrl = current.photo_url;
  let replaced: string | null = null;

  if (photo) {
    const upload = await uploadPhoto(user.id, photo);
    if (!upload.ok) backToForm(id, upload.error);

    photoUrl = upload.url;
    replaced = current.photo_url;
  } else if (removeRequested) {
    photoUrl = null;
    replaced = current.photo_url;
  }

  /*
   * Only the one call is wrapped. `redirect()` works by throwing, so a
   * try/catch thrown around anything wider would swallow the redirects below
   * and turn a successful save into a blank page.
   */
  let updated;
  try {
    updated = await updateEntry(id, { ...read.fields, photoUrl });
  } catch (cause) {
    // A policy refusal, phrased for a contributor. Reaching this means the
    // database declined the write — worth showing on the form rather than as
    // a 500, which tells them nothing about what to do next.
    if (photo && photoUrl) await deletePhoto(user.id, photoUrl);
    backToForm(id, cause instanceof Error ? cause.message : "That change was refused.");
  }

  if (!updated) {
    // RLS matched no row. If a new file was just uploaded, nothing points at
    // it now, so take it back out rather than leaving it in the bucket.
    if (photo && photoUrl) await deletePhoto(user.id, photoUrl);
    redirect("/my-entries");
  }

  // Only once the row no longer refers to it. The other order risks a row
  // pointing at a file that is already gone.
  await deletePhoto(user.id, replaced);

  /*
   * An edit sets the entry back to pending, so a previously published one has
   * just left the public archive: the browse page and its detail page both
   * change, not only "my entries".
   */
  revalidatePath("/my-entries");
  revalidatePath("/");
  revalidatePath(`/entries/${id}`);
  redirect("/my-entries?updated=1");
}

/**
 * Deletes an entry and the photograph that belonged to it.
 *
 * `deleteEntry` hands back the row it removed, which is the only chance to
 * read its `photo_url` — afterwards there is nothing left to ask. A row that
 * comes back null was either already gone or was never this contributor's;
 * both mean the same thing to them, and both end on the same page.
 */
export async function removeEntry(id: string) {
  const user = await requireUser(`/my-entries/${id}/delete`);

  let deleted;
  try {
    deleted = await deleteEntry(id);
  } catch (cause) {
    const message =
      cause instanceof Error ? cause.message : "That entry could not be deleted.";
    redirect(`/my-entries/${id}/delete?error=${encodeURIComponent(message)}`);
  }

  if (deleted) await deletePhoto(user.id, deleted.photo_url);

  revalidatePath("/my-entries");
  revalidatePath("/");
  revalidatePath(`/entries/${id}`);
  redirect("/my-entries?deleted=1");
}
