import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  exhibitPhoto,
  getExhibitRecord,
  PHOTOGRAPHS,
  photoCreditParts,
  provenanceSummary,
  RECORDS,
} from "../lib/exhibit-records.ts";
import type { Entry } from "../lib/types.ts";
import {
  renderPreflight,
  renderRollback,
  renderUpdate,
  SNAPSHOT,
} from "../scripts/generate-content-update.ts";

const CHECKED = {
  name_khmer: "នំ",
  name_english: "Num",
  context: "Checked occasion",
  description: "Checked text.",
};

const row = (over: Partial<Entry> = {}): Entry => ({
  id: "test-record",
  ...CHECKED,
  told_by: "[SOURCE PENDING — researched]",
  photo_url: "/entries/stored.jpg",
  status: "published",
  contributor_id: null,
  created_at: "2026-01-01T00:00:00Z",
  ...over,
});

const reference = {
  title: "A source",
  publisher: "Publisher",
  url: "https://example.org/a",
  lang: "en" as const,
  supports: "Something",
};

function withRecord(run: () => void) {
  RECORDS["test-record"] = {
    checked: { ...CHECKED },
    references: [reference, { ...reference, url: "https://example.org/b" }],
    unresolved: [],
    photo: "/entries/licensed.jpg",
  };
  PHOTOGRAPHS["/entries/licensed.jpg"] = {
    width: 4,
    height: 3,
    credit: {
      creator: "A. Photographer",
      sourceUrl: "https://example.org/file",
      sourceName: "Example",
      licence: "CC BY 4.0",
      licenceUrl: "https://creativecommons.org/licenses/by/4.0/",
    },
  };
  try {
    run();
  } finally {
    delete RECORDS["test-record"];
    delete PHOTOGRAPHS["/entries/licensed.jpg"];
  }
}

test("a row without a record keeps its stored photo and an honest gap", () => {
  const entry = row({ id: "no-record" });
  assert.equal(getExhibitRecord(entry), undefined);
  assert.deepEqual(exhibitPhoto(entry), { src: "/entries/stored.jpg" });
  assert.equal(provenanceSummary(entry), "Source pending verification");
});

test("a record attaches only while the row says exactly what was checked", () => {
  withRecord(() => {
    const entry = row();
    assert.ok(getExhibitRecord(entry));
    assert.equal(exhibitPhoto(entry)?.src, "/entries/licensed.jpg");
    assert.equal(
      provenanceSummary(entry),
      "Researched from 2 published references · no oral source recorded yet",
    );
  });
});

test("editing any checked field detaches the references (regression)", () => {
  withRecord(() => {
    for (const field of ["name_khmer", "name_english", "context", "description"] as const) {
      const edited = row({ contributor_id: "someone", told_by: "Family", [field]: `${CHECKED[field]} edited` });
      assert.equal(getExhibitRecord(edited), undefined, field);
      assert.equal(provenanceSummary(edited), "Source not yet named", field);
      assert.deepEqual(exhibitPhoto(edited), { src: "/entries/stored.jpg" }, field);
    }
    // Even a whitespace-only change counts: the references were not checked against it.
    assert.equal(getExhibitRecord(row({ description: "Checked text. " })), undefined);
  });
});

test("a contributor's own photograph is never replaced, even when the record attaches", () => {
  withRecord(() => {
    const entry = row({ contributor_id: "someone", told_by: "Family" });
    assert.ok(getExhibitRecord(entry));
    assert.deepEqual(exhibitPhoto(entry), { src: "/entries/stored.jpg" });
    assert.equal(provenanceSummary(entry), "Checked against 2 published references · source not yet named");
  });
});

test("a named oral source is never reported missing, with or without references", () => {
  const named = { contributor_id: "someone", told_by: "Sok Srey" };
  // No references: nothing is missing, so no warning line at all.
  assert.equal(provenanceSummary(row({ id: "no-record", ...named })), null);
  withRecord(() => {
    assert.equal(provenanceSummary(row(named)), "Checked against 2 published references");
  });
});

test("oral source and written research are reported separately", () => {
  const cases: [string, string | null, string][] = [
    ["[SOURCE PENDING — researched]", null, "Source pending verification"],
    ["Family", null, "Source not yet named"],
    ["Sok Srey", "someone", ""],
  ];
  for (const [toldBy, owner, expected] of cases) {
    const entry = row({ id: "no-record", told_by: toldBy, contributor_id: owner });
    assert.equal(provenanceSummary(entry) ?? "", expected, toldBy);
  }
});

test("a credit belongs to its image, not to the entry", () => {
  withRecord(() => {
    const changed = row({ contributor_id: "someone", photo_url: "/entries/other.jpg" });
    assert.equal(exhibitPhoto(changed)?.credit, undefined);
  });
});

test("the real Num Kroch record detaches when its contributor edits the text", () => {
  const id = "7a6a74d7-4c12-4857-a1a7-ccda1d39c165";
  const checked = RECORDS[id].checked;
  const kroch = row({ id, ...checked, contributor_id: "owner", told_by: "Family" });
  assert.ok(getExhibitRecord(kroch));
  assert.equal(getExhibitRecord({ ...kroch, description: "A new story about these cakes." }), undefined);
});

test("researched rows stay detached until the reviewed text is in the database", () => {
  for (const [id, record] of Object.entries(RECORDS)) {
    const seedState = row({ id, ...record.checked, description: "old seed text" });
    assert.equal(getExhibitRecord(seedState), undefined, id);
  }
});

const CREDIT = {
  creator: "Turaids",
  title: "Num Krouch, Num Krong, and Num Pong Ansorng",
  sourceUrl: "https://commons.wikimedia.org/wiki/File:Example.jpg",
  sourceName: "Wikimedia Commons",
  licence: "CC BY-SA 4.0",
  licenceUrl: "https://creativecommons.org/licenses/by-sa/4.0",
  modifications: "Cropped and resized",
};
const text = (parts: { text: string }[]) => parts.map((part) => part.text).join("");

test("a photo credit gives title, creator, source, licence and modification", () => {
  const parts = photoCreditParts(CREDIT);
  assert.equal(
    text(parts),
    "Photo: “Num Krouch, Num Krong, and Num Pong Ansorng” by Turaids / Wikimedia Commons — CC BY-SA 4.0. Cropped and resized.",
  );
  // The source page and the licence are links; nothing else is.
  assert.deepEqual(
    parts.filter((part) => part.href).map((part) => [part.text, part.href]),
    [
      ["Wikimedia Commons", CREDIT.sourceUrl],
      ["CC BY-SA 4.0", CREDIT.licenceUrl],
    ],
  );
});

test("a credit without a title or modification omits them cleanly", () => {
  const bare = { ...CREDIT, title: undefined, modifications: undefined };
  assert.equal(text(photoCreditParts(bare)), "Photo: Turaids / Wikimedia Commons — CC BY-SA 4.0.");
});

const KROCH = "7a6a74d7-4c12-4857-a1a7-ccda1d39c165";

test("the committed update, rollback and preflight are exactly what the generator writes", () => {
  const committed = (file: string) =>
    readFileSync(new URL(`../docs/v2/content/${file}`, import.meta.url), "utf8");
  const hint = "regenerate with: node scripts/generate-content-update.ts";
  assert.equal(committed("proposed-content-update.sql"), renderUpdate(), hint);
  assert.equal(committed("rollback-content-update.sql"), renderRollback(), hint);
  assert.equal(committed("preflight-content-update.sql"), renderPreflight(), hint);
});

test("the snapshot covers exactly the seven researched records, never a contributor's entry", () => {
  const researched = Object.keys(RECORDS).filter((id) => id !== KROCH).sort();
  assert.deepEqual(SNAPSHOT.map((row) => row.id).sort(), researched);
  for (const row of SNAPSHOT) {
    assert.equal(row.contributor_id, null, row.id);
    assert.equal(row.status, "published", row.id);
    assert.match(row.told_by, /^\[SOURCE PENDING/, `${row.id}: the source marker is carried, not replaced`);
  }
  assert.ok(!renderUpdate().includes(KROCH) && !renderRollback().includes(KROCH));
});

test("both directions are guarded, atomic and require exactly seven rows", () => {
  for (const sql of [renderUpdate(), renderRollback()]) {
    assert.match(sql, /^begin;$/m);
    assert.match(sql, /for update;/);
    assert.match(sql, /target rows found/);
    assert.match(sql, /not in the expected starting state/);
    assert.match(sql, /get diagnostics changed = row_count;/);
    assert.match(sql, /expected constant int := 7;/);
    assert.match(sql, /unexpected result for/);
    assert.match(sql, /^commit;$/m);
    // Identity: all seven target ids must survive, and every planned id is
    // checked from the plan side, so a changed or missing id cannot drop out.
    assert.match(sql, /target ids present afterwards/);
    assert.equal(
      sql.match(/from content_plan p left join public\.entries e on e\.id = p\.id\s+(?:--[^\n]*\n\s*)?where e\.id is null or/g)?.length,
      2,
      "both the starting-state and the result checks join from the plan",
    );
    assert.doesNotMatch(sql, /from content_plan p join public\.entries/);
    // History: locked against concurrent writers, and compared in full content.
    assert.match(sql, /lock table public\.review_history in share mode;/);
    assert.match(sql, /create temp table history_before on commit drop as select \* from public\.review_history;/);
    assert.match(sql, /select \* from history_before except all select \* from public\.review_history/);
    assert.match(sql, /select \* from public\.review_history except all select \* from history_before/);
    assert.match(sql, /review history changed/);
    assert.doesNotMatch(sql, /select count\(\*\) from public\.review_history/);
    // Every guard compares all four text fields and every protected field.
    for (const field of ["name_khmer", "name_english", "context", "description", "told_by", "photo_url", "created_at"]) {
      assert.match(sql, new RegExp(`e\\.${field} = p\\.`), field);
    }
  }
});

test("once applied, the corrected Num Akor name is what search reads", () => {
  // The browse query matches name_khmer, name_english and context (lib/entries.ts).
  const { checked } = RECORDS["10793f27-f7b5-4db0-937d-7438c573634a"];
  assert.equal(checked.name_khmer, "នំអាកោត្នោត");
  assert.ok([checked.name_khmer, checked.name_english, checked.context].some((f) => /akor/i.test(f)));
});

test("every record is complete, within the database limits and free of invented testimony", () => {
  for (const [id, record] of Object.entries(RECORDS)) {
    const { checked } = record;
    assert.ok(record.references.length > 0, `${id}: references`);
    for (const ref of record.references) {
      // SEAlang's dictionaries are served over plain HTTP only.
      assert.match(ref.url, /^https?:\/\//, `${id}: reference URL`);
      assert.ok(ref.title && ref.publisher && ref.supports, `${id}: reference fields`);
    }
    // Migration 0002's limits, so the content update can actually be applied.
    assert.ok(checked.name_khmer.length <= 120 && checked.name_english.length <= 150, `${id}: name limits`);
    assert.ok(checked.context.length <= 300 && checked.description.length <= 8000, `${id}: text limits`);
    assert.doesNotMatch(checked.description, /\[|\]/, `${id}: no bracketed markers or citations`);
    if (id !== "7a6a74d7-4c12-4857-a1a7-ccda1d39c165") {
      // A contributor may write in their own voice; researched text may not.
      assert.doesNotMatch(
        checked.description,
        /\b(I|my|we|our)\b|grand(mother|father|parent)|recalls?\b/i,
        `${id}: no first-person or family testimony`,
      );
    }
    if (record.photo) assert.ok(Object.hasOwn(PHOTOGRAPHS, record.photo), `${id}: photo is registered`);
  }
  for (const [src, photo] of Object.entries(PHOTOGRAPHS)) {
    assert.ok(photo.width > 0 && photo.height > 0, `${src}: size`);
    if (photo.credit) {
      assert.match(photo.credit.sourceUrl, /^https:\/\//, `${src}: source page`);
      assert.match(photo.credit.licenceUrl, /^https:\/\//, `${src}: licence page`);
      assert.ok(photo.credit.creator && photo.credit.licence, `${src}: creator and licence`);
    }
  }
});
