import assert from "node:assert/strict";
import { test } from "node:test";
import { PHOTOGRAPHS, exhibitPhoto, isPhotoWithheld } from "../lib/exhibit-records.ts";
import { getHomepageExhibits } from "../lib/homepage-exhibits.ts";
import type { Entry } from "../lib/types.ts";

const kroch: Entry = {
  id: "7a6a74d7-4c12-4857-a1a7-ccda1d39c165", name_khmer: "នំក្រូច", name_english: "Num Kroch",
  told_by: "Family", context: "Everyday snack", description: "Existing contributor text.", status: "published",
  contributor_id: "61fe1754-18f6-46ff-b3ef-6b7dd1ac79a2", created_at: "2026-01-01T00:00:00Z",
  photo_url: "https://example.test/storage/v1/object/public/entry-photos/61fe1754-18f6-46ff-b3ef-6b7dd1ac79a2/b5834c0d-8f2b-4aa7-bece-7449401bce9c.jpg",
};

test("production photo rights hold is specific and leaves stored entry data unchanged", () => {
  const before = structuredClone(kroch);
  assert.equal(isPhotoWithheld(kroch), true);
  assert.equal(exhibitPhoto(kroch), null);
  assert.deepEqual(getHomepageExhibits([kroch]), []);
  assert.deepEqual(kroch, before);
  assert.equal(isPhotoWithheld({ ...kroch, photo_url: "/entries/new-owner-photo.jpg" }), false);
});

test("all seven production local photographs have linked Commons licences", () => {
  const expected = ["num-ansom-chek", "num-korm", "num-ansom-chrouk", "num-plae-ai", "num-korng", "num-akor", "num-bot"];
  for (const name of expected) {
    const photo = PHOTOGRAPHS[`/entries/${name}.jpg`];
    assert.ok(photo?.credit?.creator && photo.credit.title);
    assert.match(photo.credit.sourceUrl, /^https:\/\/commons\.wikimedia\.org\/wiki\/File:/);
    assert.match(photo.credit.licenceUrl, /^https:\/\/creativecommons\.org\/licenses\//);
    assert.ok(photo.credit.modifications);
  }
  assert.match(PHOTOGRAPHS["/entries/num-ansom-chek.jpg"].credit!.modifications!, /Cropped/);
  assert.match(PHOTOGRAPHS["/entries/num-korng.jpg"].caption!, /not an exclusive photograph/);
  assert.match(PHOTOGRAPHS["/entries/num-bot.jpg"].caption!, /does not show the mung-bean filling/);
});
