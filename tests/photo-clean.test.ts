import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test, type TestContext } from "node:test";

import sharp from "sharp";

import { MAX_PHOTO_PIXELS, PHOTO_UNREADABLE, cleanPhoto } from "../lib/photo-clean.ts";

/*
 * Every image here is made by sharp inside the test, so no photograph of
 * anyone is committed as a fixture. The one exception is a photo the app
 * already ships in public/entries/.
 */

const GPS = { GPSLatitudeRef: "N", GPSLatitude: "11/1 33/1 0/1", GPSLongitudeRef: "E", GPSLongitude: "105/1 20/1 0/1" };
const XMP =
  '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">' +
  '<rdf:Description xmlns:exif="http://ns.adobe.com/exif/1.0/" exif:GPSLatitude="11,33N"/></rdf:RDF></x:xmpmeta>';

/** A photo the way a phone writes one: camera, GPS and XMP in its metadata. */
const phonePhoto = (format: "jpeg" | "png" | "webp") =>
  sharp({ create: { width: 64, height: 48, channels: 3, background: "#b85" } })
    .toFormat(format)
    .withExif({ IFD0: { Make: "TestPhone", Model: "Fixture 1" }, IFD3: GPS })
    .withXmp(XMP)
    .toBuffer();

/** Red left half, blue right half, so where red ends up shows the rotation. */
function leftRedRightBlue(width: number, height: number) {
  const pixels = Buffer.alloc(width * height * 3);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 3;
      if (x < width / 2) pixels[i] = 255;
      else pixels[i + 2] = 255;
    }
  }
  return sharp(pixels, { raw: { width, height, channels: 3 } });
}

/** "red" or "blue": whichever dominates the pixel at (x, y). */
async function colourAt(image: Buffer, x: number, y: number) {
  const { data, info } = await sharp(image).raw().toBuffer({ resolveWithObject: true });
  const i = (y * info.width + x) * info.channels;
  return data[i] > data[i + 2] ? "red" : "blue";
}

/** Keeps the expected [photo-clean] log lines out of the test output. */
const quietLog = (t: TestContext) => t.mock.method(console, "error", () => {});

const contains = (haystack: Buffer, text: string) => haystack.includes(Buffer.from(text));

test("a phone JPEG loses its camera, GPS and XMP metadata", async () => {
  const input = await phonePhoto("jpeg");
  const before = await sharp(input).metadata();
  assert.ok(before.exif && before.xmp, "the fixture really carries EXIF and XMP");

  const result = await cleanPhoto(input, "image/jpeg");
  assert.equal(result.ok, true);
  if (!result.ok) return;

  const after = await sharp(result.bytes).metadata();
  assert.equal(after.format, "jpeg");
  assert.equal(after.exif, undefined);
  assert.equal(after.xmp, undefined);
  assert.equal(after.icc, undefined);
  assert.equal(contains(result.bytes, "TestPhone"), false);
  assert.equal(contains(result.bytes, "GPSLatitude"), false);
});

test("PNG and WebP lose their metadata too, and keep their format", async () => {
  for (const format of ["png", "webp"] as const) {
    const result = await cleanPhoto(await phonePhoto(format), `image/${format}`);
    assert.equal(result.ok, true, format);
    if (!result.ok) continue;

    const after = await sharp(result.bytes).metadata();
    assert.equal(after.format, format);
    assert.equal(after.exif, undefined, `${format} EXIF`);
    assert.equal(after.xmp, undefined, `${format} XMP`);
    assert.equal(contains(result.bytes, "TestPhone"), false, `${format} camera`);
    assert.equal(contains(result.bytes, "GPSLatitude"), false, `${format} GPS`);
  }
});

test("a photo taken sideways is stored upright, turned the right way", async () => {
  // EXIF orientation: 3 = turn 180°, 6 = turn 90° clockwise, 8 = 90° anticlockwise.
  // Where the red half lands after turning, in the 40×20 or 20×40 result:
  const cases = [
    { orientation: 3, width: 40, height: 20, red: [35, 10], blue: [4, 10] },
    { orientation: 6, width: 20, height: 40, red: [10, 4], blue: [10, 35] },
    { orientation: 8, width: 20, height: 40, red: [10, 35], blue: [10, 4] },
  ];

  for (const c of cases) {
    const input = await leftRedRightBlue(40, 20).jpeg().withMetadata({ orientation: c.orientation }).toBuffer();
    const result = await cleanPhoto(input, "image/jpeg");
    assert.equal(result.ok, true);
    if (!result.ok) continue;

    const after = await sharp(result.bytes).metadata();
    assert.equal(after.width, c.width, `orientation ${c.orientation}: width`);
    assert.equal(after.height, c.height, `orientation ${c.orientation}: height`);
    assert.equal(after.orientation, undefined, `orientation ${c.orientation}: no tag left to apply twice`);
    assert.equal(await colourAt(result.bytes, c.red[0], c.red[1]), "red", `orientation ${c.orientation}: red side`);
    assert.equal(await colourAt(result.bytes, c.blue[0], c.blue[1]), "blue", `orientation ${c.orientation}: blue side`);
  }
});

test("an upright photo keeps its size and its colours where they were", async () => {
  const input = await leftRedRightBlue(40, 20).png().toBuffer();
  const result = await cleanPhoto(input, "image/png");
  assert.equal(result.ok, true);
  if (!result.ok) return;

  const after = await sharp(result.bytes).metadata();
  assert.deepEqual([after.width, after.height], [40, 20]);
  assert.equal(await colourAt(result.bytes, 4, 10), "red");
  assert.equal(await colourAt(result.bytes, 35, 10), "blue");
});

test("one of the archive's own photos still goes through, at full resolution", async () => {
  const input = readFileSync(new URL("../public/entries/num-bot.jpg", import.meta.url));
  const before = await sharp(input).metadata();

  const result = await cleanPhoto(input, "image/jpeg");
  assert.equal(result.ok, true);
  if (!result.ok) return;

  const after = await sharp(result.bytes).metadata();
  assert.equal(after.format, "jpeg");
  assert.deepEqual([after.width, after.height], [before.autoOrient.width, before.autoOrient.height]);
});

test("bytes hidden after a valid image are not stored", async () => {
  const image = await leftRedRightBlue(40, 20).jpeg().toBuffer();
  const polyglot = Buffer.concat([image, Buffer.from("<?php system($_GET['c']); ?> PAYLOAD-MARKER")]);

  const result = await cleanPhoto(polyglot, "image/jpeg");
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(contains(result.bytes, "PAYLOAD-MARKER"), false);
  assert.equal(contains(result.bytes, "<?php"), false);
});

test("a truncated photo is refused", async (t) => {
  const log = quietLog(t);
  // Noise, so the image data is far bigger than the header and the cut lands
  // inside it. Cut a tiny image instead and the header breaks, which even
  // `failOn: "none"` refuses, so the test would not show the option matters.
  const width = 200;
  const height = 150;
  const noise = Buffer.alloc(width * height * 3);
  for (let i = 0; i < noise.length; i++) noise[i] = ((i * 2654435761) >>> 24) & 0xff;
  const image = await sharp(noise, { raw: { width, height, channels: 3 } }).jpeg().toBuffer();

  const result = await cleanPhoto(image.subarray(0, Math.floor(image.length * 0.6)), "image/jpeg");
  assert.deepEqual(result, { ok: false, error: PHOTO_UNREADABLE });
  assert.match(String(log.mock.calls[0].arguments[0]), /^\[photo-clean\] image\/jpeg: /);
});

test("a JPEG signature followed by something else is refused", async (t) => {
  quietLog(t);
  const fake = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.from("not an image at all ".repeat(20))]);

  assert.deepEqual(await cleanPhoto(fake, "image/jpeg"), { ok: false, error: PHOTO_UNREADABLE });
});

test(`an image over ${MAX_PHOTO_PIXELS / 1e6} megapixels is refused before it is decoded`, async (t) => {
  quietLog(t);
  // A few hundred KB on disk, 64 megapixels once decoded.
  const bomb = await sharp({ limitInputPixels: false, create: { width: 8000, height: 8000, channels: 3, background: "#fff" } })
    .png({ compressionLevel: 9 })
    .toBuffer();

  assert.deepEqual(await cleanPhoto(bomb, "image/png"), { ok: false, error: PHOTO_UNREADABLE });
});

test("a format the archive does not accept is refused without decoding", async () => {
  const gif = await sharp({ create: { width: 8, height: 8, channels: 3, background: "#000" } }).gif().toBuffer();

  assert.deepEqual(await cleanPhoto(gif, "image/gif"), { ok: false, error: PHOTO_UNREADABLE });
});

test("the contributor never sees sharp's own wording", async (t) => {
  quietLog(t);
  const result = await cleanPhoto(Buffer.from([0xff, 0xd8, 0xff, 0x00]), "image/jpeg");

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.error, PHOTO_UNREADABLE);
  assert.doesNotMatch(result.error, /vips|sharp|marker|header/i);
});
