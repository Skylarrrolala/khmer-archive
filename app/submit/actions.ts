"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireUser } from "@/lib/auth";
import { readEntryFields, readPhoto } from "@/lib/entry-form";
import { createEntry } from "@/lib/entries";
import { uploadPhoto } from "@/lib/photos";

/**
 * Submitting one dessert to the archive.
 *
 * A Server Action rather than a route handler, so the form is a plain
 * `<form action={...}>` with no client component — the same choice the search
 * box and the auth forms make. Errors come back as a redirect carrying
 * `?error=`, because without `useActionState` there is nowhere in memory to
 * put them.
 *
 * Nothing in this file is what stops a contributor writing an entry owned by
 * someone else, or publishing one without review. The insert policy in
 * supabase/migrations/0001_init.sql does that, and the Storage policy confines
 * an upload to a folder named after the uploader's own id. What is here is the
 * validation that makes the failure legible instead of a 500.
 */

function backToForm(message: string): never {
  redirect(`/submit?error=${encodeURIComponent(message)}`);
}

export async function submitEntry(formData: FormData) {
  // Redirects to /login when signed out, so the rest of this can assume a user.
  const user = await requireUser("/submit");

  const read = readEntryFields(formData);
  if (!read.ok) backToForm(read.error);

  const photo = readPhoto(formData);
  let photoUrl: string | null = null;

  if (photo) {
    const upload = await uploadPhoto(user.id, photo);
    if (!upload.ok) backToForm(upload.error);
    photoUrl = upload.url;
  }

  await createEntry({
    contributorId: user.id,
    ...read.fields,
    photoUrl,
  });

  // The new row is pending, so the public browse page does not change — but
  // "my entries" does, and the masthead count with it.
  revalidatePath("/my-entries");
  redirect("/my-entries?submitted=1");
}
