import assert from "node:assert/strict";
import { test } from "node:test";

import { safeInternalPath } from "../lib/safe-path.ts";

// Where a browser sitting on the live login page would actually end up if it
// were redirected to `path`. Node's URL parser follows the same WHATWG rules
// browsers do, which is the whole point: these tests check what a browser
// sees, not what the raw string looks like.
const SITE = "https://khmer-archive-zeta.vercel.app/login";
const SITE_HOST = new URL(SITE).host;
const landsOn = (path: string) => new URL(path, SITE).host;

test("keeps an ordinary path inside the app", () => {
  assert.equal(safeInternalPath("/my-entries"), "/my-entries");
  assert.equal(safeInternalPath("/submit"), "/submit");
  assert.equal(safeInternalPath("/"), "/");
});

test("keeps a query string and fragment", () => {
  assert.equal(safeInternalPath("/?q=num"), "/?q=num");
  assert.equal(safeInternalPath("/entries/abc#story"), "/entries/abc#story");
});

test("falls back to / for missing values and anything that is not a path", () => {
  for (const value of [undefined, "", "my-entries", "https://evil.example", "javascript:alert(1)"]) {
    assert.equal(safeInternalPath(value), "/", JSON.stringify(value));
  }
});

test("uses the first value when ?next= is repeated", () => {
  assert.equal(safeInternalPath(["/submit", "//evil.example"]), "/submit");
  assert.equal(safeInternalPath(["//evil.example", "/submit"]), "/");
});

test("rejects protocol-relative and backslash forms", () => {
  for (const value of ["//evil.example", "/\\evil.example", "/\\/evil.example"]) {
    assert.equal(landsOn(value), "evil.example", `premise: ${JSON.stringify(value)} leaves the site`);
    assert.equal(safeInternalPath(value), "/", JSON.stringify(value));
  }
});

test("rejects tab, newline and carriage-return tricks that browsers clean up", () => {
  // The bypass the old string check missed: "/\t/evil.example" does not start
  // with "//", but a browser deletes the tab and reads "//evil.example".
  for (const value of ["/\t/evil.example", "/\n/evil.example", "/\r/evil.example", "/\t\\evil.example"]) {
    assert.equal(landsOn(value), "evil.example", `premise: ${JSON.stringify(value)} leaves the site`);
    assert.equal(safeInternalPath(value), "/", JSON.stringify(value));
  }
});

test("rejects dot segments that collapse into a protocol-relative path", () => {
  // These resolve on this origin, but their cleaned-up path is
  // "//evil.example", which a browser reads as a host when redirected to it.
  for (const value of ["/..//evil.example", "/./%2e%2e//evil.example", "/x/../..//evil.example"]) {
    assert.equal(safeInternalPath(value), "/", JSON.stringify(value));
  }
});

test("percent-encoded slashes stay a harmless path on this site", () => {
  const out = safeInternalPath("/%2F%2Fevil.example");
  assert.equal(out, "/%2F%2Fevil.example");
  assert.equal(landsOn(out), SITE_HOST);
});

test("whatever it returns, a browser stays on this site", () => {
  const hostile = [
    "//evil.example", "/\\evil.example", "/\t/evil.example", "/\n/evil.example",
    "/ /evil.example", "/..//evil.example", "/.%2e/evil.example", "/\u0000/evil.example",
    "https:evil.example", "/https://evil.example", "/@evil.example", "/;//evil.example",
  ];
  for (const value of hostile) {
    const out = safeInternalPath(value);
    assert.ok(out.startsWith("/") && !out.startsWith("//"), `${JSON.stringify(value)} -> ${out}`);
    assert.equal(landsOn(out), SITE_HOST, `${JSON.stringify(value)} -> ${out}`);
  }
});
