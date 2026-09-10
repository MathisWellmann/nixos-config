// End-to-end smoke test against a real `@pydantic/monty` pool. Needs the
// vendored `node_modules` (run from the nix-built plugin directory) and the
// `monty` worker: `MONTY_BIN=/path/to/monty node test/pool.smoke.mjs`.
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CollectStreams, Monty, MontyCrashedError, MontyRuntimeError, MontySyntaxError, MountDir } from "@pydantic/monty";
import { repr } from "../lib/repr.js";

const binaryPath = process.env.MONTY_BIN;
const pool = await Monty.create({ ...(binaryPath ? { binaryPath } : {}), minProcesses: 0, maxProcesses: 2, requestTimeout: 3 });
try {
	// state persists across feeds
	const session = await pool.checkout({ limits: { maxMemory: 64 * 1024 * 1024 } });
	assert.equal(await session.feedRun("x = 21"), null);
	assert.equal(repr(await session.feedRun("x * 2")), "42");
	await session.feedRun("def f(n):\n    return [i * x for i in range(n)]");
	assert.equal(repr(await session.feedRun("f(3)")), "[0, 21, 42]");
	assert.equal(repr(await session.feedRun("(1, 'a', {'k': None}, {2, 3})")), "(1, 'a', {'k': None}, {2, 3})");

	// print capture
	const streams = new CollectStreams();
	await session.feedRun("print('hello')\nprint('again', 2)", { printCallback: streams });
	assert.ok(streams.output.every((e) => e.stream === "stdout"));
	assert.equal(streams.output.map((e) => e.text).join(""), "hello\nagain 2\n");

	// runtime error keeps the session
	await assert.rejects(session.feedRun("1 / 0"), (err) => err instanceof MontyRuntimeError && err.exception.typeName === "ZeroDivisionError" && err.display("traceback").includes("ZeroDivisionError"));
	assert.equal(repr(await session.feedRun("x")), "21");

	// syntax error keeps the session
	await assert.rejects(session.feedRun("def ("), (err) => err instanceof MontySyntaxError);
	assert.equal(repr(await session.feedRun("x + 1")), "22");

	// dataclass instance crosses as a proxy
	assert.equal(repr(await session.feedRun("from dataclasses import dataclass\n@dataclass\nclass P:\n    x: int\n    y: str\nP(1, 'z')")), "P(x=1, y='z')");

	// read-only workspace mount
	const dir = mkdtempSync(join(tmpdir(), "monty-smoke-"));
	writeFileSync(join(dir, "data.json"), '{"a": [1, 2, 3]}');
	const mount = new MountDir({ hostPath: dir, virtualPath: "/workspace", mode: "read-only" });
	assert.equal(repr(await session.feedRun("import json\nfrom pathlib import Path\njson.loads(Path('/workspace/data.json').read_text())['a']", { mount })), "[1, 2, 3]");
	await assert.rejects(session.feedRun("Path('/workspace/new.txt').write_text('x')", { mount }), (err) => err instanceof MontyRuntimeError);
	mount.close();

	// no ambient access
	await assert.rejects(session.feedRun("open('/etc/passwd').read()"), (err) => err instanceof MontyRuntimeError);

	// requestTimeout kills a wedged worker -> crashed, session lost
	await assert.rejects(session.feedRun("while True:\n    pass"), (err) => err instanceof MontyCrashedError && err.timedOut === true);
	await assert.rejects(session.feedRun("x"), (err) => err instanceof MontyCrashedError);
	await session.close();

	// a fresh checkout after the crash works
	const fresh = await pool.checkout();
	assert.equal(repr(await fresh.feedRun("'ok'")), "'ok'");
	await fresh.close();
	console.log("pool.smoke.mjs: ok");
} finally {
	await pool.close();
}
