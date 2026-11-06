import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { LIMIT_MESSAGES, limitMessage } from "../lib/limits.ts";
import { EntryWriteError, photoNote, saveWithPhoto } from "../lib/save-with-photo.ts";

test("each limit's code has its own sentence", () => {
  assert.match(limitMessage("KA001") ?? "", /5 entries waiting for review/);
  assert.match(limitMessage("KA002") ?? "", /20 photos in the last 24 hours/);
  assert.match(limitMessage("KA003") ?? "", /10 uploaded photos that aren't attached/);
});

test("any other code is not a limit", () => {
  for (const code of [undefined, "", "42501", "23514", "P0001", "KA004", "ka001", "toString", "__proto__"]) {
    assert.equal(limitMessage(code), null, String(code));
  }
});

test("the codes match the ones the migration raises", () => {
  const migration = readFileSync(
    new URL("../supabase/migrations/0006_contributor_limits.sql", import.meta.url),
    "utf8",
  );
  const raised = new Set([...migration.matchAll(/errcode = '(KA\d{3})'/g)].map((m) => m[1]));
  assert.deepEqual([...raised].sort(), Object.keys(LIMIT_MESSAGES).sort());
});

test("an entry refused at the limit after its photo was uploaded: the limit's sentence, and the photo taken back out", async () => {
  const removed: string[] = [];
  const outcome = await saveWithPhoto({
    upload: async () => ({ ok: true, url: "https://p.supabase.co/storage/v1/object/public/entry-photos/u/1.jpg" }),
    write: async () => {
      throw new EntryWriteError("KA001");
    },
    removeUploaded: async (url) => {
      removed.push(url);
      return true;
    },
  });

  assert.equal(outcome.status, "not-saved");
  if (outcome.status !== "not-saved") return;
  assert.equal(removed.length, 1, "the uploaded photo was removed");
  assert.equal(
    `${limitMessage(outcome.code)}${photoNote(outcome.cleanup)}`,
    `${LIMIT_MESSAGES.KA001} Your text is kept; choose the photo again before you retry.`,
  );
});
