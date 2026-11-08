import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";

import { EntryWriteError } from "../lib/save-with-photo.ts";

// Run the actual server modules under Node, replacing only Next and network imports.
function loadModule<T>(path: string, imports: Record<string, unknown>): T {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  const require = (name: string) => {
    assert.ok(Object.hasOwn(imports, name), `Unexpected import: ${name}`);
    return imports[name];
  };
  return new Function("require", "exports", `${outputText}\nreturn exports;`)(require, exports);
}

const ID = "11111111-1111-4111-8111-111111111111";

class Redirect extends Error {
  readonly location: string;
  constructor(location: string) { super(location); this.location = location; }
}

function setup() {
  const state = {
    user: { id: "reviewer" } as { id: string } | null,
    reviewer: true,
    roleError: null as { code: string; message: string } | null,
    result: { data: true as boolean | null, error: null as { code: string; message: string } | null },
    transportError: false,
  };
  const decisions: unknown[] = [];
  const invalidated: string[] = [];
  const filters: unknown[] = [];
  const navigation = {
    redirect: (location: string): never => { throw new Redirect(location); },
    notFound: (): never => { throw new Error("NOT_FOUND"); },
  };
  const client = {
    createSupabaseServerClient: async () => ({
      auth: { getUser: async () => ({ data: { user: state.user }, error: null }) },
      rpc: async (name: string, args: unknown) => {
        if (name === "is_reviewer") return { data: state.reviewer, error: state.roleError };
        assert.equal(name, "review_entry");
        decisions.push(args);
        if (state.transportError) throw new Error("private connection details");
        return state.result;
      },
      from: (table: string) => {
        assert.equal(table, "entries");
        const query = {
          select: (columns: string) => { assert.equal(columns, "*"); return query; },
          eq: (column: string, value: unknown) => { filters.push([column, value]); return query; },
          order: async (column: string, options: unknown) => {
            filters.push([column, options]);
            return { data: [], error: null };
          },
        };
        return query;
      },
    }),
  };
  const auth = loadModule<typeof import("../lib/auth.ts")>("../lib/auth.ts", {
    react: { cache: (fn: unknown) => fn },
    "next/navigation": navigation,
    "@/lib/supabase/server": client,
  });
  const entries = loadModule<typeof import("../lib/entries.ts")>("../lib/entries.ts", {
    "@/lib/supabase/server": client,
    "@/lib/save-with-photo": { EntryWriteError },
  });
  const actions = loadModule<typeof import("../app/review/actions.ts")>("../app/review/actions.ts", {
    "next/navigation": navigation,
    "next/cache": { revalidatePath: (path: string) => invalidated.push(path) },
    "@/lib/auth": auth,
    "@/lib/entries": entries,
    "@/lib/save-with-photo": { EntryWriteError },
  });
  return { state, decisions, invalidated, filters, auth, entries, actions };
}

const redirectedTo = (location: string) => (error: unknown) =>
  error instanceof Redirect && error.location === location;

test("a logged-out action redirects to login without attempting a decision", async () => {
  const s = setup();
  s.state.user = null;
  await assert.rejects(s.actions.decideEntry(ID, "published"), redirectedTo("/login?next=%2Freview"));
  assert.deepEqual(s.decisions, []);
  assert.deepEqual(s.invalidated, []);
});

test("a contributor cannot invoke a bound review action directly", async () => {
  const s = setup();
  s.state.reviewer = false;
  await assert.rejects(s.actions.decideEntry(ID, "returned"), /NOT_FOUND/);
  assert.deepEqual(s.decisions, []);
});

test("reviewer permission is checked again when an action is submitted", async () => {
  const s = setup();
  assert.equal(await s.auth.isCurrentUserReviewer(), true);
  s.state.reviewer = false;
  await assert.rejects(s.actions.decideEntry(ID, "published"), /NOT_FOUND/);
  assert.deepEqual(s.decisions, []);
});

test("a failed reviewer lookup denies access and never attempts a write", async (t) => {
  t.mock.method(console, "error", () => {});
  const s = setup();
  s.state.roleError = { code: "XX000", message: "private database details" };
  await assert.rejects(s.actions.decideEntry(ID, "published"), /Could not check reviewer access/);
  assert.deepEqual(s.decisions, []);
});

for (const decision of ["published", "returned"]) {
  test(`a reviewer can mark an entry ${decision} through the existing RPC`, async () => {
    const s = setup();
    await assert.rejects(s.actions.decideEntry(ID, decision), redirectedTo(`/review?result=${decision}`));
    assert.deepEqual(s.decisions, [{ entry_id: ID, decision }]);
    assert.deepEqual(s.invalidated, ["/review", "/", `/entries/${ID}`, "/my-entries"]);
  });
}

test("malformed ids and unsupported decisions are rejected before the RPC", async () => {
  for (const [id, decision] of [
    ["not-a-uuid", "published"], ["", "returned"], [null, "published"],
    [ID, "pending"], [ID, "PUBLISHED"], [ID, null], [ID, ["published"]],
  ]) {
    const s = setup();
    await assert.rejects(
      s.actions.decideEntry(id as string, decision as string),
      redirectedTo("/review?result=invalid"),
    );
    assert.deepEqual(s.decisions, []);
    assert.deepEqual(s.invalidated, []);
  }
});

test("a refused or stale decision is never reported as successful", async () => {
  const s = setup();
  s.state.result.data = false;
  await assert.rejects(s.actions.decideEntry(ID, "published"), redirectedTo("/review?result=unchanged"));
  assert.deepEqual(s.invalidated, []);
});

test("an unexpected empty RPC response is not treated as a successful review", async () => {
  const s = setup();
  s.state.result.data = null;
  await assert.rejects(s.actions.decideEntry(ID, "returned"), redirectedTo("/review?result=unchanged"));
  assert.deepEqual(s.invalidated, []);
});

test("database and connection failures show a fixed failure result", async (t) => {
  t.mock.method(console, "error", () => {});
  for (const transportError of [false, true]) {
    const s = setup();
    s.state.transportError = transportError;
    s.state.result.error = { code: "23514", message: "private database details" };
    await assert.rejects(s.actions.decideEntry(ID, "published"), redirectedTo("/review?result=failed"));
    assert.deepEqual(s.invalidated, []);
  }
});

test("the review queue requests pending entries oldest first", async () => {
  const s = setup();
  assert.deepEqual(await s.entries.getPendingEntries(), []);
  assert.deepEqual(s.filters, [["status", "pending"], ["created_at", { ascending: true }]]);
});
