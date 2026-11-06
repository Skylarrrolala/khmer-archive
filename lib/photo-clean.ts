import sharp from "sharp";

/**
 * Re-encoding an entry photo before it is stored. Review finding M2.
 *
 * A photo is uploaded to a public bucket, and a phone photo carries EXIF: the
 * camera, the time it was taken, and often the GPS position. In this archive
 * that position is usually a grandparent's home. lib/photo-check.ts reads only
 * a file's first bytes, so until now the original bytes were stored as sent,
 * metadata and all, and a valid header followed by anything at all passed.
 *
 * Decoding the image and encoding it again fixes both at once:
 *   * nothing is copied but the pixels. sharp writes no EXIF, XMP or colour
 *     profile unless asked to (keepMetadata, withMetadata, withExif), and
 *     nothing here asks;
 *   * a file that does not decode is refused, and bytes appended after a valid
 *     image are not part of the pixels, so they are not in the output.
 *
 * `.rotate()` with no angle turns the pixels upright by the EXIF orientation
 * before that orientation is dropped. Without it a phone photo taken sideways
 * would be stored sideways.
 *
 * The resolution is kept: the archive preserves the photo as taken. The format
 * is kept too: a JPEG stays a JPEG, at quality 80; PNG and WebP keep sharp's
 * defaults. The colours are converted to sRGB, the space browsers assume when
 * there is no profile.
 *
 * Imports nothing of the app's own, so `node --test` can load it.
 */

/** 50 megapixels. A larger image is refused before it is decoded into memory. */
export const MAX_PHOTO_PIXELS = 50_000_000;

const JPEG_QUALITY = 80;

export const PHOTO_UNREADABLE =
  "That file could not be read as a photo. Try another JPEG, PNG or WebP.";

/** The cleaned bytes, or a sentence to show the contributor. */
export type CleanedPhoto =
  | { ok: true; bytes: Buffer }
  | { ok: false; error: string };

const OUTPUT = {
  "image/jpeg": "jpeg",
  "image/png": "png",
  "image/webp": "webp",
} as const;

/**
 * `type` is the format photoFormat() read from the file's signature; the output
 * is written in that format. It never throws: sharp's own wording goes to the
 * server log, as [photo-clean], and the contributor gets PHOTO_UNREADABLE.
 */
export async function cleanPhoto(bytes: Uint8Array, type: string): Promise<CleanedPhoto> {
  const format = OUTPUT[type as keyof typeof OUTPUT];
  if (!format) return { ok: false, error: PHOTO_UNREADABLE };

  try {
    // failOn "warning": a truncated or damaged file is refused, not patched up.
    const image = sharp(bytes, { failOn: "warning", limitInputPixels: MAX_PHOTO_PIXELS }).rotate();
    const encoded =
      format === "jpeg" ? image.jpeg({ quality: JPEG_QUALITY }) : image.toFormat(format);

    return { ok: true, bytes: await encoded.toBuffer() };
  } catch (cause) {
    console.error(`[photo-clean] ${type}: ${cause instanceof Error ? cause.message : String(cause)}`);
    return { ok: false, error: PHOTO_UNREADABLE };
  }
}
