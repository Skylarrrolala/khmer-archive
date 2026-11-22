import assert from "node:assert/strict";
import { test } from "node:test";
import {
  descriptionNotes,
  descriptionProse,
  hasUnattributedSource,
} from "../lib/placeholders.ts";

test("source markers and the existing generic Family credit need attribution", () => {
  assert.equal(hasUnattributedSource("[SOURCE PENDING — researched]"), true);
  assert.equal(hasUnattributedSource("  family\n"), true);
});

test("a personal name is not treated as a generic credit", () => {
  assert.equal(hasUnattributedSource("Sok Srey"), false);
  assert.equal(hasUnattributedSource("Family name recorded by contributor"), false);
});

test("story presentation preserves paragraphs while removing editing markers", () => {
  assert.equal(
    descriptionProse("Recorded text.\n\nAnother paragraph. [PHOTO CREDIT PENDING]"),
    "Recorded text.\n\nAnother paragraph.",
  );
  assert.deepEqual(
    descriptionNotes("Recorded text. [PHOTO CREDIT PENDING]"),
    ["Photo credit pending"],
  );
});
