import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { photoFormat } from "../lib/photo-check.ts";

const bytes = (...values: (number | string)[]) =>
  new Uint8Array(values.flatMap((v) => (typeof v === "string" ? [...Buffer.from(v, "latin1")] : [v])));

test("a real JPEG from the archive is recognised", () => {
  const jpeg = readFileSync(new URL("../public/entries/num-bot.jpg", import.meta.url));
  assert.deepEqual(photoFormat(jpeg.subarray(0, 12)), { type: "image/jpeg", extension: "jpg" });
});

test("PNG and WebP signatures are recognised", () => {
  assert.deepEqual(photoFormat(bytes(0x89, "PNG\r\n\x1a\n", 0, 0, 0, 13)), { type: "image/png", extension: "png" });
  assert.deepEqual(photoFormat(bytes("RIFF", 0x24, 0x10, 0, 0, "WEBP")), { type: "image/webp", extension: "webp" });
});

test("a text file renamed to .jpg is refused, whatever it claims to be", () => {
  const text = new TextEncoder().encode("Grandmother's recipe, typed up.\n");
  assert.equal(photoFormat(text.subarray(0, 12)), null);
});

test("other formats and short or empty files are refused", () => {
  assert.equal(photoFormat(bytes("RIFF", 0x24, 0x10, 0, 0, "WAVE")), null, "RIFF but not WebP");
  assert.equal(photoFormat(bytes("GIF89a", 1, 0, 1, 0, 0, 0)), null, "GIF");
  assert.equal(photoFormat(bytes("<svg xmlns=")), null, "SVG");
  assert.equal(photoFormat(bytes("%PDF-1.7\n%\xe2\xe3")), null, "PDF");
  assert.equal(photoFormat(bytes(0xff, 0xd8)), null, "two bytes of a JPEG header");
  assert.equal(photoFormat(new Uint8Array()), null, "empty");
});
