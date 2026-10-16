import { createSupabaseServerClient } from "@/lib/supabase/server";

/**
 * Uploading and removing entry photographs.
 *
 * Submitting an entry and editing one need the same rules about what a photo
 * may be and where it may live. Before this file existed the rules lived in
 * app/submit/actions.ts; a second copy in the edit action is exactly the kind
 * of pair that drifts, and the half that drifts is the half that stops
 * rejecting something.
 *
 * None of this is the security boundary. The Storage policies in
 * supabase/migrations/0001_init.sql are: a contributor may write only inside a
 * folder named after their own user id, and Postgres refuses anything else. A
 * caller who skipped this file entirely could not put a file in someone else's
 * folder. What is here is the size and type limit, which Storage does not know
 * about, and a legible error instead of a 500.
 */

const BUCKET = "entry-photos";

/** 5 MB. A phone photo is comfortably under this; a video is not. */
export const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

/**
 * The formats the archive accepts, mapped to the extension the stored file
 * gets. The map is keyed on the MIME type the browser reports rather than on
 * the name the file arrived with, because a name is trivially renamed.
 */
const ALLOWED_PHOTO_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

/** Either a stored photo's public URL, or a sentence to show the contributor. */
export type PhotoUpload =
  | { ok: true; url: string }
  | { ok: false; error: string };

/**
 * Stores one photo in the contributor's own folder and returns its public URL.
 *
 * The path's first segment MUST be the user's id: the Storage policy checks
 * `(storage.foldername(name))[1] = auth.uid()::text`, so an upload anywhere
 * else is rejected by Postgres, not by this code.
 *
 * The filename is a fresh uuid rather than the one from the visitor's machine.
 * An uploaded name is untrusted input — it can carry path separators, unicode
 * that renders one way and sorts another, or simply collide with a file the
 * contributor uploaded last week and silently replace it. `upsert: false` is
 * the second half of that: a collision is an error, never an overwrite.
 */
export async function uploadPhoto(
  userId: string,
  photo: File,
): Promise<PhotoUpload> {
  const extension = ALLOWED_PHOTO_TYPES[photo.type];

  if (!extension) {
    return { ok: false, error: "Photos must be a JPEG, PNG or WebP image." };
  }
  if (photo.size > MAX_PHOTO_BYTES) {
    return {
      ok: false,
      error: "That photo is larger than 5 MB. Try a smaller version.",
    };
  }

  const supabase = await createSupabaseServerClient();
  const path = `${userId}/${crypto.randomUUID()}.${extension}`;

  const { error } = await supabase.storage
    .from(BUCKET)
    .upload(path, photo, { contentType: photo.type, upsert: false });

  if (error) {
    // Storage's own wording goes to the server log, not the page: it is
    // written for developers and can name internal limits and paths.
    console.error(`[photo-upload] ${path}: ${error.message}`);
    return {
      ok: false,
      error: "The photo could not be uploaded. Please try again, or try a smaller JPEG, PNG or WebP.",
    };
  }

  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);

  return { ok: true, url: data.publicUrl };
}

/**
 * The storage path inside the bucket that a public URL points at, or null.
 *
 * A public URL looks like
 *   https://<project>.supabase.co/storage/v1/object/public/entry-photos/<uid>/<uuid>.jpg
 * and the part worth having is everything after the bucket name.
 *
 * Returns null for anything that is not a URL into this bucket. That matters
 * for the seeded rows, whose `photo_url` is a local path like
 * `/entries/num-ansom.jpg` — there is no stored object behind those, and
 * asking Storage to delete one must not be attempted.
 */
export function storagePathFromUrl(publicUrl: string): string | null {
  const marker = `/storage/v1/object/public/${BUCKET}/`;
  const at = publicUrl.indexOf(marker);

  if (at === -1) return null;

  const path = publicUrl.slice(at + marker.length);

  return path.length > 0 ? decodeURIComponent(path) : null;
}

/**
 * Removes a photo the contributor owns, once nothing points at it any more.
 *
 * Resolves to true when the file is gone, or when there was nothing of this
 * contributor's to remove (no URL, or one of the seeded photographs in
 * public/entries/). Resolves to false when a removal was attempted and did
 * not happen — the file is still in the public bucket — so the caller can
 * tell the contributor rather than imply it is gone. It never throws: by the
 * time this runs the row has usually been written, and a file left behind
 * must not turn a saved entry into an error page.
 *
 * "Did not happen" includes Storage reporting success while removing
 * nothing, which is what it does for a path that does not exist or that the
 * delete policy filtered out. So it is the count of removed files that is
 * checked, not just the absence of an error.
 *
 * Each failure is logged with the path, under one tag, so a left-behind file
 * can be found and removed by hand: search the logs for [photo-cleanup].
 *
 * The ownership check is not what stops one contributor deleting another's
 * photo — the Storage delete policy does, by folder. It is here so a URL that
 * belongs to someone else is never even sent.
 */
export async function deletePhoto(
  userId: string,
  publicUrl: string | null,
): Promise<boolean> {
  if (!publicUrl) return true;

  const path = storagePathFromUrl(publicUrl);
  if (!path || !path.startsWith(`${userId}/`)) return true;

  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.storage.from(BUCKET).remove([path]);

    if (error || !data || data.length === 0) {
      console.error(
        `[photo-cleanup] ${BUCKET}/${path} was not removed: ${error ? error.message : "Storage removed nothing"}`,
      );
      return false;
    }
    return true;
  } catch (cause) {
    console.error(
      `[photo-cleanup] ${BUCKET}/${path} was not removed: ${cause instanceof Error ? cause.message : String(cause)}`,
    );
    return false;
  }
}
