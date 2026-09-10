// Drives the plugin's `apply` through a stub Cordis context: registers the
// tool, executes calls for two fake agents, and checks persistence, reset,
// error rendering and cleanup. Needs the vendored `node_modules` plus dsh's
// `@deepseek-ai/*` packages on NODE_PATH (the dsh launcher provides them):
//   MONTY_BIN=/path/to/monty NODE_PATH=<dsh>/node_modules node test/plugin.smoke.mjs
import assert from "node:assert/strict";
import { Config, apply, inject, name } from "../lib/index.js";

assert.equal(name, "tool-monty");
assert.deepEqual(inject, ["tools"]);

const disposers = [];
const stubCtx = (label) => ({
	label,
	effect(factory, note) {
		const dispose = factory();
		disposers.push({ label, note, dispose });
		return dispose;
	},
	logger: { warn: (msg) => console.warn(`[${label}] ${msg}`) },
});

let registered;
const ctx = { ...stubCtx("plugin"), tools: { register: (definition) => (registered = definition) } };
const config = new Config({ binaryPath: process.env.MONTY_BIN, requestTimeoutSecs: 3, maxSessions: 2 });
assert.equal(config.maxMemoryBytes, 256 * 1024 * 1024);
assert.equal(config.workspaceMount, "read-only");
apply(ctx, config);
assert.equal(registered.name, "python_repl");
assert.ok(registered.description.includes("PERSIST"));
assert.equal(registered.timeoutMs, 18000);

const agent = (id) => ({ id, ctx: stubCtx(`agent:${id}`), session: { header: { cwd: process.cwd() } } });
const run = async (owner, args) => {
	const value = await registered.execute(args, { agent: owner, signal: new AbortController().signal });
	return { value, text: registered.output.render(args, value).map((b) => b.text).join("") };
};

const a = agent("a");
const b = agent("b");

// persistence per agent, isolation between agents
assert.equal((await run(a, { code: "x = 21" })).text, "(no output)");
assert.equal((await run(a, { code: "x * 2" })).text, "=> 42");
assert.match((await run(b, { code: "x" })).text, /NameError: name 'x' is not defined/);
assert.equal((await run(b, { code: "x = 'other'\nx" })).text, "=> 'other'");
assert.equal((await run(a, { code: "print('p', x)\nx + 1" })).text, "p 21\n=> 22");

// workspace mount reads this directory
assert.match((await run(a, { code: "from pathlib import Path\nsorted(p.name for p in Path('/workspace').iterdir())[:1]" })).text, /=> \['/);

// runtime error keeps state
const failed = await run(a, { code: "1/0" });
assert.equal(failed.value.stateLost, false);
assert.match(failed.text, /ZeroDivisionError: division by zero/);
assert.equal((await run(a, { code: "x" })).text, "=> 21");

// syntax error renders, keeps state
assert.match((await run(a, { code: "def (" })).text, /SyntaxError/);

// argument validation from defineTool
await assert.rejects(registered.execute({ code: 5 }, { agent: a, signal: new AbortController().signal }));
await assert.rejects(run(a, { code: "   " }), /non-empty/);

// reset
const reset = await run(a, { code: "", reset: true });
assert.equal(reset.text, "[python_repl: state reset]");
assert.match((await run(a, { code: "x" })).text, /NameError/);
assert.equal((await run(a, { code: "y = 1\ny", reset: true })).text, "=> 1\n[python_repl: state reset]");

// worker timeout -> state lost, reported, next call starts fresh
const wedged = await run(a, { code: "while True:\n    pass" });
assert.equal(wedged.value.stateLost, true);
assert.match(wedged.text, /timed out after 3s/);
assert.match(wedged.text, /state was lost/);
assert.match((await run(a, { code: "y" })).text, /NameError/);

// presentation projections are pure
assert.equal(registered.presentCall({ code: "print(1)\n" }).title, "Python REPL: print(1)");
assert.equal(registered.presentCall({ code: "", reset: true }).title, "Reset Python REPL");
assert.match(registered.presentResult({ code: "1" }, { content: [{ type: "text", text: "=> 1" }], isError: false }).content[0].text, /```console\n=> 1\n```/);

// disposing an agent closes its session; disposing the plugin closes the pool
for (const d of disposers.filter((d) => d.label === "agent:a")) await d.dispose();
assert.equal((await run(a, { code: "'fresh'" })).text, "=> 'fresh'");
for (const d of disposers.filter((d) => d.label === "plugin")) await d.dispose();
await assert.rejects(run(b, { code: "1" }));
console.log("plugin.smoke.mjs: ok");
