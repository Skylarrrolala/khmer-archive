import assert from "node:assert/strict";
import { test } from "node:test";

import { entryValues, formFailure, initialEntryFormState } from "../lib/entry-form.ts";

function form(fields: Record<string, string>) {
  const data = new FormData();
  for (const [name, value] of Object.entries(fields)) data.set(name, value);
  return data;
}

test("a failed attempt hands back the text exactly as typed, Khmer and line breaks included", () => {
  const typed = {
    name_khmer: "នំកង",
    name_english: "  Num Kong ",
    told_by: "Son",
    context: "Everyday snack",
    description: "Line one.\nLine two, with ឈ្មោះ in Khmer.",
  };
  assert.deepEqual(entryValues(form(typed)), typed);
});

test("missing fields come back as empty strings, never undefined", () => {
  assert.deepEqual(entryValues(form({})), {
    name_khmer: "",
    name_english: "",
    told_by: "",
    context: "",
    description: "",
  });
});

test("each failure bumps the attempt, so the form remounts with the returned text", () => {
  const values = entryValues(form({ name_khmer: "នំ" }));
  const first = formFailure(initialEntryFormState, "Add a photograph.", values);
  const second = formFailure(first, "Add a photograph.", values);
  assert.equal(first.attempt, 1);
  assert.equal(second.attempt, 2);
  assert.equal(second.error, "Add a photograph.");
  assert.equal(second.values?.name_khmer, "នំ");
});

test("the initial state has no error and no values", () => {
  assert.deepEqual(initialEntryFormState, { error: null, values: null, attempt: 0 });
});
