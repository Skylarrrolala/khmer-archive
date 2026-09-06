"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireUser } from "@/lib/auth";
import { createEntry } from "@/lib/entries";
import { createSupabaseServerClient } from "@/lib/supabase/server";

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

/** Photo limits. Enforced here because the `accept` attribute is a hint only. */
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const ALLOWED_PHOTO_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

function backToForm(message: string): never {
  redirect(`/submit?error=${encodeURIComponent(message)}`);
}

export async function submitEntry(formData: FormData) {
  // Redirects to /login when signed out, so the rest of this can assume a user.
  const user = await requireUser("/submit");

  const nameKhmer = String(formData.get("name_khmer") ?? "").trim();
  const nameEnglish = String(formData.get("name_english") ?? "").trim();
  const toldBy = String(formData.get("told_by") ?? "").trim();
  const context = String(formData.get("context") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const photo = formData.get("photo");

  /*
   * The four not-null, non-empty columns. The same rule is a CHECK constraint
   * in the migration, so a row that got past this would still be refused by
   * Postgres — this exists so the contributor is told which field, rather than
   * being shown a constraint violation.
   */
  if (!nameEnglish) backToForm("Give the dessert a name in English.");
  if (!nameKhmer) backToForm("Give the dessert's name in Khmer script.");
  if (!context) {
    backToForm("Say when the dessert is made — a festival, a daily snack.");
  }
  if (!description) backToForm("Add the story or description.");

  /*
   * `told_by` is the archive's sourcing rule expressed as a form field: every
   * entry credits the person who shared it, by name, with their permission.
   * The column is `not null` for the same reason. This is the one field a
   * contributor cannot shrug off.
   */
  if (!toldBy) {
    backToForm("Credit the person who shared this dessert, by name.");
  }

  let photoUrl: string | null = null;

  /*
   * The photo is optional, and that is deliberate. CLAUDE.md's sprint list
   * says "text + at least one photo upload", but the data model is explicit
   * that `photo_url` is nullable because "desserts they only remember may have
   * no photo at all" — and a dessert nobody photographed is exactly what this
   * archive exists to record. Requiring a file would make that unrecordable.
   * The form still uploads one when there is one. Flag this if the sprint
   * wording was meant strictly.
   */
  if (photo instanceof File && photo.size > 0) {
    const extension = ALLOWED_PHOTO_TYPES[photo.type];

    if (!extension) {
      backToForm("Photos must be a JPEG, PNG or WebP image.");
    }
    if (photo.size > MAX_PHOTO_BYTES) {
      backToForm("That photo is larger than 5 MB. Try a smaller version.");
    }

    const supabase = await createSupabaseServerClient();

    /*
     * The path's first folder MUST be the user's id: the Storage policy checks
     * `(storage.foldername(name))[1] = auth.uid()::text`, so an upload
     * anywhere else is rejected by Postgres, not by this code.
     *
     * The filename is a fresh uuid rather than the one from the visitor's
     * machine. An uploaded name is untrusted input — it can carry path
     * separators, unicode that renders one way and sorts another, or simply
     * collide with a file the contributor uploaded last week and silently
     * replace it.
     */
    const path = `${user.id}/${crypto.randomUUID()}.${extension}`;

    const { error: uploadError } = await supabase.storage
      .from("entry-photos")
      .upload(path, photo, { contentType: photo.type, upsert: false });

    if (uploadError) {
      backToForm(`The photo could not be uploaded: ${uploadError.message}`);
    }

    const { data } = supabase.storage.from("entry-photos").getPublicUrl(path);
    photoUrl = data.publicUrl;
  }

  await createEntry({
    contributorId: user.id,
    nameKhmer,
    nameEnglish,
    toldBy,
    context,
    description,
    photoUrl,
  });

  // The new row is pending, so the public browse page does not change — but
  // "my entries" does, and the masthead count with it.
  revalidatePath("/my-entries");
  redirect("/my-entries?submitted=1");
}
