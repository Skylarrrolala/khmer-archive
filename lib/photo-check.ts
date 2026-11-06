/**
 * What an entry photo must be. Kept free of imports: the server's upload code
 * (lib/photos.ts) and the browser's early size check (components/EntryForm.tsx)
 * both read it, and `node --test` can load it.
 */

/**
 * 4 MiB, the same as the bucket's file_size_limit (migration 0002). The
 * Server Action body limit in next.config.ts is sized to fit this.
 */
export const MAX_PHOTO_BYTES = 4 * 1024 * 1024;

export const PHOTO_TOO_LARGE = "That photo is larger than 4 MB. Try a smaller version.";

/**
 * The format a file's opening bytes say it is, or null when they are not a
 * JPEG, PNG or WebP signature. Twelve bytes are enough for all three.
 *
 * This decides the format, not the type the browser reports or the file's
 * name: both come from the visitor's machine, and a text file renamed
 * `photo.jpg` arrives declared as image/jpeg.
 *
 * Checks the signature only, not that the whole image decodes. On the server,
 * lib/photo-clean.ts then decodes and re-encodes the image, which refuses a
 * file that does not decode and drops anything after the image.
 */
export function photoFormat(head: Uint8Array): { type: string; extension: string } | null {
  const has = (bytes: number[], at = 0) => bytes.every((byte, i) => head[at + i] === byte);

  if (has([0xff, 0xd8, 0xff])) return { type: "image/jpeg", extension: "jpg" };
  if (has([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return { type: "image/png", extension: "png" };
  }
  // "RIFF", four bytes of length, then "WEBP". WAV and AVI files are RIFF too.
  if (has([0x52, 0x49, 0x46, 0x46]) && has([0x57, 0x45, 0x42, 0x50], 8)) {
    return { type: "image/webp", extension: "webp" };
  }
  return null;
}
