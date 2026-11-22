import assert from "node:assert/strict";
import { test } from "node:test";
import { getHomepageExhibits } from "../lib/homepage-exhibits.ts";
import type { Entry } from "../lib/types.ts";

function fixture(id: string, photo: string | null, status: Entry["status"] = "published"): Entry {
  return {
    id, photo_url: photo, status, name_khmer: "នំ", name_english: "Test fixture only",
    told_by: "[SOURCE PENDING]", context: "[TEST]", description: "Test fixture only",
    contributor_id: null, created_at: "2026-01-01T00:00:00Z",
  };
}

test("the homepage prefers the two existing photographs without changing browse order", () => {
  const other = fixture("other", "/other.jpg");
  const kong = fixture("kong", "/entries/num-korng.jpg");
  const plae = fixture("plae", "/entries/num-plae-ai.jpg");
  const entries = [other, kong, plae];
  assert.deepEqual(getHomepageExhibits(entries), [plae, kong]);
  assert.deepEqual(entries, [other, kong, plae]);
});

test("removed featured records fall back to available published photographs", () => {
  const other = fixture("other", "/other.jpg");
  const plae = fixture("plae", "/entries/num-plae-ai.jpg");
  assert.deepEqual(getHomepageExhibits([other, plae]), [plae, other]);
});

test("unpublished, photo-free and placeholder-name records are not featured", () => {
  const unnamed = { ...fixture("unnamed", "/unnamed.jpg"), name_khmer: "[NOT CONFIRMED]" };
  assert.deepEqual(getHomepageExhibits([
    fixture("pending", "/entries/num-plae-ai.jpg", "pending"),
    fixture("returned", "/entries/num-korng.jpg", "returned"),
    fixture("no-photo", null), unnamed,
  ]), []);
  assert.deepEqual(getHomepageExhibits([]), []);
});
