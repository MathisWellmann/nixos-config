/**
 * Node test harness for dsh-sidebar-archive's client half.
 *
 * Materializes the shipped client bundle (a `window.__ModuleLoader__.load`
 * factory, no external requires) inside a `vm` context and exercises the
 * pure row->session resolver against synthetic store snapshots. Run:
 *
 *   node test/resolve.test.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import assert from "node:assert/strict";

const here = path.dirname(fileURLToPath(import.meta.url));
const clientSrc = readFileSync(path.join(here, "..", "lib", "client.js"), "utf8");

const loadCalls = [];
const sandbox = {
  console,
  setTimeout,
  clearTimeout,
  Date,
  Math,
  Array,
  Object,
  String,
  Number,
  JSON,
  Set,
  Map,
  // The bundle registers itself through the host's module loader; capture the
  // load() call so the test can materialize the factory in isolation.
  __ModuleLoader__: { load: (def) => loadCalls.push(def) },
};
sandbox.window = sandbox;
sandbox.module = { exports: {} };
sandbox.require = () => {
  throw new Error("unexpected require in test: factory should be require-free");
};
vm.createContext(sandbox);
vm.runInContext(clientSrc, sandbox, { filename: "client.js" });

assert.equal(loadCalls.length, 1, "bundle calls __ModuleLoader__.load exactly once");
const loaded = loadCalls[0];
assert.equal(loaded.id, "dsh-sidebar-archive", "bundle registers its expected module id");

// Materialize the factory in the same realm; it returns its own module.exports.
const mod = loaded.factory(sandbox.require);

// Objects created inside the vm context carry vm-realm prototypes, so assert
// against host-realm copies instead of the raw cross-realm values.
const R = (result) => (result === null ? null : { id: String(result.id) });
const B = (bucket) => ({ unit: String(bucket.unit), n: bucket.n });

const { resolveBinding, relativeTime, timeLabelFor } = mod.__internal;
assert.deepEqual(Array.from(mod.inject), ["sessions", "workspaces"]);

const NOW = Date.parse("2026-08-29T12:00:00Z"); // Sunday
const ts = (daysAgo, minutesAgo = 0) => NOW - daysAgo * 86400e3 - minutesAgo * 60e3;

// --- synthetic store snapshots -------------------------------------------
const st = (id, title, extra = {}) => ({
  id,
  displayTitle: title,
  blank: false,
  updatedAt: ts(0),
  ...extra,
});

const ws = (workspaceId, title, sessionIds, extra = {}) => ({
  workspaceId,
  title,
  path: `/home/m/${workspaceId}`,
  sessionIds,
  ...extra,
});

// --- basics ----------------------------------------------------------------
{
  const sessionState = { ids: ["s1"], byId: { s1: st("s1", "Fix flake NIXOS-241") } };
  const workspaceState = { items: [], archivedSessionIds: [] };
  const row = {
    title: "Fix flake NIXOS-241",
    timeText: "now",
    group: null,
  };
  assert.deepEqual(R(resolveBinding(row, sessionState, workspaceState, NOW)), { id: "s1" });
}

// blank sessions are never resolved
{
  const sessionState = {
    ids: ["blank1"],
    byId: { blank1: st("blank1", "New chat", { blank: true }) },
  };
  const row = { title: "New chat", timeText: "now", group: null };
  assert.equal(resolveBinding(row, sessionState, { items: [], archivedSessionIds: [] }, NOW), null);
}

// archived sessions are never resolved
{
  const sessionState = { ids: ["gone"], byId: { gone: st("gone", "Old chat") } };
  const workspaceState = { items: [], archivedSessionIds: ["gone"] };
  const row = { title: "Old chat", timeText: "now", group: null };
  assert.equal(resolveBinding(row, sessionState, workspaceState, NOW), null);
}

// duplicate titles are disambiguated by the owning workspace group
{
  const sessionState = {
    ids: ["s1", "s2"],
    byId: {
      s1: st("s1", "Review PR", { updatedAt: ts(0, 5) }),
      s2: st("s2", "Review PR", { updatedAt: ts(0, 40) }),
    },
  };
  const workspaceState = {
    items: [
      ws("w1", "backend", ["s1"]),
      ws("w2", "frontend", ["s2"]),
    ],
    archivedSessionIds: [],
  };
  assert.deepEqual(
    R(resolveBinding({ title: "Review PR", timeText: "now", group: { title: "backend", iconButtons: 2 } }, sessionState, workspaceState, NOW)),
    { id: "s1" },
  );
  assert.deepEqual(
    R(resolveBinding({ title: "Review PR", timeText: "now", group: { title: "frontend", iconButtons: 2 } }, sessionState, workspaceState, NOW)),
    { id: "s2" },
  );
}

// a duplicate title inside the ungrouped bucket falls back to time-bucket matching
{
  const sessionState = {
    ids: ["s1", "s2"],
    byId: {
      s1: st("s1", "Review PR", { updatedAt: ts(1, 0) }), // 1d
      s2: st("s2", "Review PR", { updatedAt: NOW }), // now
    },
  };
  const workspaceState = { items: [], archivedSessionIds: [] };
  assert.deepEqual(
    R(resolveBinding({ title: "Review PR", timeText: "1d", group: { title: "Ungrouped", iconButtons: 1 } }, sessionState, workspaceState, NOW)),
    { id: "s1" },
  );
  assert.deepEqual(
    R(resolveBinding({ title: "Review PR", timeText: "now", group: { title: "Ungrouped", iconButtons: 1 } }, sessionState, workspaceState, NOW)),
    { id: "s2" },
  );
}

// Chinese locale: ungrouped header text plus relative-time bucket matching
{
  const sessionState = {
    ids: ["s1", "s2"],
    byId: {
      s1: st("s1", "看看这个", { updatedAt: ts(2, 0) }), // 2d
      s2: st("s2", "看看这个", { updatedAt: NOW }), // now
    },
  };
  const workspaceState = { items: [], archivedSessionIds: [] };
  assert.deepEqual(
    R(resolveBinding({ title: "看看这个", timeText: "2天", group: { title: "未分组", iconButtons: 1 } }, sessionState, workspaceState, NOW)),
    { id: "s1" },
  );
  assert.deepEqual(
    R(resolveBinding({ title: "看看这个", timeText: "刚刚", group: { title: "未分组", iconButtons: 1 } }, sessionState, workspaceState, NOW)),
    { id: "s2" },
  );
}

// ambiguous same-title + same-time-bucket rows must NOT guess
{
  // Both share the visible bucket "1min", so the row's time text cannot
  // distinguish them -> resolver must refuse (null), never guess.
  const oneMinAgo = NOW - 90e3;
  const sessionState = {
    ids: ["s1", "s2"],
    byId: {
      s1: st("s1", "Scratch", { updatedAt: oneMinAgo }),
      s2: st("s2", "Scratch", { updatedAt: oneMinAgo }),
    },
  };
  const row = { title: "Scratch", timeText: "1min", group: null };
  assert.equal(resolveBinding(row, sessionState, { items: [], archivedSessionIds: [] }, NOW), null);
}

// flat list (no group header) resolves unique titles regardless of time text
{
  const sessionState = {
    ids: ["a", "b"],
    byId: {
      a: st("a", "alpha", { updatedAt: ts(3, 0) }),
      b: st("b", "beta", { updatedAt: NOW }),
    },
  };
  const workspaceState = { items: [], archivedSessionIds: [] };
  assert.deepEqual(R(resolveBinding({ title: "alpha", timeText: "3d", group: null }, sessionState, workspaceState, NOW)), { id: "a" });
  assert.deepEqual(R(resolveBinding({ title: "beta", timeText: "now", group: null }, sessionState, workspaceState, NOW)), { id: "b" });
}

// unknown titles resolve to nothing
{
  const sessionState = { ids: ["s1"], byId: { s1: st("s1", "only") } };
  assert.equal(resolveBinding({ title: "ghost", timeText: "now", group: null }, sessionState, { items: [], archivedSessionIds: [] }, NOW), null);
}

// --- relativeTime / timeLabelFor ------------------------------------------
{
  assert.deepEqual(B(relativeTime(NOW - 30e3, NOW)), { unit: "now", n: 0 });
  assert.deepEqual(B(relativeTime(NOW - 10 * 60e3, NOW)), { unit: "minutes", n: 10 });
  assert.deepEqual(B(relativeTime(NOW - 2 * 3600e3, NOW)), { unit: "hours", n: 2 });
  assert.deepEqual(B(relativeTime(NOW - 3 * 86400e3, NOW)), { unit: "days", n: 3 });
  assert.deepEqual(B(relativeTime(NOW - 90 * 86400e3, NOW)), { unit: "months", n: 3 });
  assert.deepEqual(B(relativeTime(NOW - 740 * 86400e3, NOW)), { unit: "years", n: 2 });

  assert.equal(timeLabelFor({ unit: "now", n: 0 }, "en"), "now");
  assert.equal(timeLabelFor({ unit: "minutes", n: 10 }, "en"), "10min");
  assert.equal(timeLabelFor({ unit: "hours", n: 2 }, "zh"), "2小时");
  assert.equal(timeLabelFor({ unit: "months", n: 3 }, "zh"), "3个月");
  // unknown labels degrade gracefully instead of throwing
  assert.equal(typeof timeLabelFor({ unit: "weird", n: 1 }, "en"), "string");
}

console.log("dsh-sidebar-archive: all resolver tests passed");
