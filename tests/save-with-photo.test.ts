import assert from "node:assert/strict";
import { test } from "node:test";

import {
  EntryWriteError,
  saveFailureMessage,
  saveWithPhoto,
  type UploadResult,
} from "../lib/save-with-photo.ts";

const URL_A = "https://test-project.supabase.co/storage/v1/object/public/entry-photos/a/1.jpg";

/** Fake steps that record what was called, standing in for Storage and Postgres. */
function steps(opts: {
  upload?: UploadResult | "none";
  write?: "row" | "no-row" | Error;
  remove?: boolean | Error;
}) {
  const calls = { upload: 0, write: [] as (string | null)[], remove: [] as string[] };
  const uploadResult = opts.upload ?? { ok: true, url: URL_A };
  return {
    calls,
    upload:
      uploadResult === "none"
        ? null
        : async () => {
            calls.upload += 1;
            return uploadResult;
          },
    write: async (photoUrl: string | null) => {
      calls.write.push(photoUrl);
      const w = opts.write ?? "row";
      if (w instanceof Error) throw w;
      return w === "row" ? { id: "entry-1" } : null;
    },
    removeUploaded: async (url: string) => {
      calls.remove.push(url);
      const r = opts.remove ?? true;
      if (r instanceof Error) throw r;
      return r;
    },
  };
}

test("upload, then a successful write: saved, and the photo is not removed", async () => {
  const s = steps({});
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "saved", value: { id: "entry-1" }, newPhotoUrl: URL_A });
  assert.deepEqual(s.calls.write, [URL_A]);
  assert.deepEqual(s.calls.remove, []);
});

test("a failed upload stops before anything is written", async () => {
  const s = steps({ upload: { ok: false, error: "Photos must be a JPEG, PNG or WebP image." } });
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "upload-failed", error: "Photos must be a JPEG, PNG or WebP image." });
  assert.deepEqual(s.calls.write, []);
  assert.deepEqual(s.calls.remove, []);
});

test("a refused insert takes the uploaded photo back out", async () => {
  const s = steps({ write: new EntryWriteError("23514") });
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "not-saved", cause: "error", code: "23514", cleanup: "removed" });
  assert.deepEqual(s.calls.remove, [URL_A], "the photo just uploaded is the one removed");
});

test("if the photo cannot be removed, the outcome says it was left behind", async () => {
  const s = steps({ write: new EntryWriteError("42501"), remove: false });
  const outcome = await saveWithPhoto(s);
  assert.equal(outcome.status, "not-saved");
  assert.equal(outcome.status === "not-saved" && outcome.cleanup, "left-behind");
});

test("a removal that throws is treated as left behind, not as an unhandled crash", async () => {
  const s = steps({ write: new Error("network down"), remove: new Error("storage down") });
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "not-saved", cause: "error", code: undefined, cleanup: "left-behind" });
});

test("an error that is not an EntryWriteError carries no code", async () => {
  const s = steps({ write: new Error("Could not connect") });
  const outcome = await saveWithPhoto(s);
  assert.equal(outcome.status === "not-saved" && outcome.code, undefined);
});

test("a write that matches no row is not-saved, and its new photo is removed", async () => {
  const s = steps({ write: "no-row" });
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "not-saved", cause: "no-row", code: undefined, cleanup: "removed" });
  assert.deepEqual(s.calls.remove, [URL_A]);
});

test("with no new photo, a failed write has nothing to clean up", async () => {
  const s = steps({ upload: "none", write: new EntryWriteError("23514") });
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "not-saved", cause: "error", code: "23514", cleanup: "none-uploaded" });
  assert.deepEqual(s.calls.write, [null]);
  assert.deepEqual(s.calls.remove, []);
});

test("with no new photo, a successful write reports no new photo", async () => {
  const s = steps({ upload: "none" });
  const outcome = await saveWithPhoto(s);
  assert.deepEqual(outcome, { status: "saved", value: { id: "entry-1" }, newPhotoUrl: null });
});

test("failure messages say what happened without repeating the database", () => {
  const constraint = saveFailureMessage("new", { code: "23514", cleanup: "removed" });
  assert.match(constraint, /^Your entry was not saved, so nothing was published: /);
  assert.match(constraint, /not accepted/);
  assert.match(constraint, /choose the photo again/);

  assert.match(saveFailureMessage("edit", { code: "42501", cleanup: "none-uploaded" }), /^Your changes were not saved: you are not allowed/);
  assert.match(saveFailureMessage("edit", { code: undefined, cleanup: "none-uploaded" }), /went wrong on our side/);

  for (const code of ["23514", "42501", "XX000", undefined]) {
    const message = saveFailureMessage("new", { code, cleanup: "left-behind" });
    assert.doesNotMatch(message, /violates|constraint|relation|policy|SQLSTATE|entries_/i, `${code}: ${message}`);
  }
});

test("a photo left behind is said plainly; a removed one only asks to choose it again", () => {
  const left = saveFailureMessage("new", { code: undefined, cleanup: "left-behind" });
  assert.match(left, /could not be removed from storage/);
  assert.match(left, /not attached to any entry/);

  const removed = saveFailureMessage("new", { code: undefined, cleanup: "removed" });
  assert.doesNotMatch(removed, /could not be removed/);
  assert.match(removed, /choose the photo again/);

  const none = saveFailureMessage("edit", { code: undefined, cleanup: "none-uploaded" });
  assert.doesNotMatch(none, /photo/);
});
