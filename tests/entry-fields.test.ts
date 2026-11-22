import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { ENTRY_FIELDS, readEntryFields } from "../lib/entry-form.ts";

const valid = {
  name_khmer: "នំអន្សម",
  name_english: "Num ansom",
  told_by: "Yiey",
  context: "Pchum Ben",
  description: "Wrapped in banana leaf.",
};

function read(overrides: Partial<Record<keyof typeof valid, string>>) {
  const data = new FormData();
  for (const [name, value] of Object.entries({ ...valid, ...overrides })) data.set(name, value);
  return readEntryFields(data);
}

const errorOf = (result: ReturnType<typeof readEntryFields>) => (result.ok ? null : result.error);

test("every limit matches the char_length constraint in migration 0002", () => {
  const sql = readFileSync(new URL("../supabase/migrations/0002_sprint2_publish_on_submit.sql", import.meta.url), "utf8");
  const limits = Object.fromEntries([...sql.matchAll(/char_length\((\w+)\)\s*<=\s*(\d+)/g)].map((m) => [m[1], Number(m[2])]));
  assert.deepEqual(limits, Object.fromEntries(Object.entries(ENTRY_FIELDS).map(([name, f]) => [name, f.max])));
});

test("Khmer is counted mark by mark, as Postgres counts it: 120 is accepted, 121 is not", () => {
  const khmer120 = "នំ".repeat(60); // a consonant and a vowel sign: two code points each
  assert.equal([...khmer120].length, 120);
  assert.equal(read({ name_khmer: khmer120 }).ok, true);
  assert.equal(
    errorOf(read({ name_khmer: `${khmer120}ក` })),
    '"Name in Khmer" is too long: 121 characters, and the limit is 120.',
  );
});

test("an emoji is one character, not two", () => {
  assert.equal(read({ name_english: "🍮".repeat(150) }).ok, true);
  assert.match(errorOf(read({ name_english: "🍮".repeat(151) })) ?? "", /^"Name in English" is too long: 151 characters/);
});

test("the story may be 8,000 characters, and the message names it", () => {
  assert.equal(read({ description: "a".repeat(8000) }).ok, true);
  assert.equal(
    errorOf(read({ description: "a".repeat(8001) })),
    '"The story" is too long: 8,001 characters, and the limit is 8,000.',
  );
});

test("line breaks sent as CRLF count once, as the browser counts them, and are stored as \\n", () => {
  const story = `${"a".repeat(3999)}\r\n${"b".repeat(4000)}`; // 8,000 once the break counts as one
  const result = read({ description: story });
  assert.equal(result.ok && result.fields.description, `${"a".repeat(3999)}\n${"b".repeat(4000)}`);
});

test("single words and single letters are whole names", () => {
  assert.equal(read({ told_by: "Yiey", name_khmer: "ក", name_english: "X" }).ok, true);
});

test("surrounding spaces are trimmed before counting, and not stored", () => {
  const result = read({ told_by: `   ${"t".repeat(120)}   ` });
  assert.equal(result.ok && result.fields.toldBy, "t".repeat(120));
});

test("a field of only spaces or invisible marks counts as blank; Khmer split by zero-width spaces does not", () => {
  assert.equal(errorOf(read({ told_by: " ​ ⁠﻿ " })), "Credit the person who shared it, by name.");
  assert.equal(errorOf(read({ context: "‌‍" })), "Say when it is made — a festival, a daily snack.");
  assert.equal(read({ name_khmer: "នំ​អន្សម" }).ok, true);
});

test("with several problems, the first field in form order is reported", () => {
  assert.equal(errorOf(read({ name_khmer: "", description: "" })), "Give its name in Khmer script.");
});
