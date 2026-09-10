import assert from "node:assert/strict";
import { renderOutput, repr, truncateMiddle } from "../lib/repr.js";

const tuple = (...items) => {
	Object.defineProperty(items, "__tuple__", { value: true, enumerable: false });
	return items;
};

// scalars
assert.equal(repr(null), "None");
assert.equal(repr(undefined), "None");
assert.equal(repr(true), "True");
assert.equal(repr(false), "False");
assert.equal(repr(42), "42");
assert.equal(repr(2.5), "2.5");
assert.equal(repr(1e21), "1e+21");
assert.equal(repr(NaN), "nan");
assert.equal(repr(-Infinity), "-inf");
assert.equal(repr(2n ** 64n), "18446744073709551616");
assert.equal(repr("a"), "'a'");
assert.equal(repr("it's"), '"it\'s"');
assert.equal(repr(`both ' and "`), "'both \\' and \"'");
assert.equal(repr("line\nbreak\ttab\\"), "'line\\nbreak\\ttab\\\\'");
assert.equal(repr(Buffer.from("hi")), "b'hi'");

// containers
assert.equal(repr([1, "a", null]), "[1, 'a', None]");
assert.equal(repr(tuple(1, 2)), "(1, 2)");
assert.equal(repr(tuple(1)), "(1,)");
assert.equal(repr(tuple()), "()");
assert.equal(repr(new Map([["k", [1]], [2, "v"]])), "{'k': [1], 2: 'v'}");
assert.equal(repr(new Map()), "{}");
assert.equal(repr(new Set([1, 2])), "{1, 2}");
assert.equal(repr(new Set()), "set()");
assert.equal(repr({ a: 1 }), "{'a': 1}");

// monty markers
assert.equal(repr({ __monty_type__: "Date", year: 2020, month: 1, day: 2 }), "datetime.date(2020, 1, 2)");
assert.equal(
	repr({ __monty_type__: "DateTime", year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 0, microsecond: 0 }),
	"datetime.datetime(2020, 1, 2, 0, 0)",
);
assert.equal(
	repr({ __monty_type__: "DateTime", year: 2020, month: 1, day: 2, hour: 3, minute: 4, second: 5, microsecond: 6 }),
	"datetime.datetime(2020, 1, 2, 3, 4, 5, 6)",
);
assert.equal(repr({ __monty_type__: "TimeDelta", days: 1, seconds: 2, microseconds: 0 }), "datetime.timedelta(days=1, seconds=2, microseconds=0)");
assert.equal(repr({ __monty_type__: "Exception", excType: "ValueError", message: "bad" }), "ValueError('bad')");

// sandbox class instances arrive as read-only proxies
assert.equal(repr({ name: "P", isDataclass: true, id: "x", attributes: { x: 1, y: "z" } }), "P(x=1, y='z')");

// depth guard terminates
const deep = [];
let cursor = deep;
for (let i = 0; i < 20; i++) {
	const next = [];
	cursor.push(next);
	cursor = next;
}
assert.ok(repr(deep).includes("..."));

// truncation keeps head and tail
const long = "a".repeat(500) + "b".repeat(500);
const cut = truncateMiddle(long, 200);
assert.ok(cut.length <= 200 + 60);
assert.ok(cut.startsWith("aaaa"));
assert.ok(cut.endsWith("bbbb"));
assert.ok(cut.includes("chars truncated"));
assert.equal(truncateMiddle("short", 200), "short");

// rendering
assert.equal(renderOutput({ stdout: "", stderr: "", result: "None", error: null, notice: null }), "(no output)");
assert.equal(renderOutput({ stdout: "hi\n", stderr: "", result: "42", error: null, notice: null }), "hi\n=> 42");
assert.equal(renderOutput({ stdout: "", stderr: "warn\n", result: null, error: "Traceback\nZeroDivisionError: division by zero\n", notice: null }), "[stderr]\nwarn\nTraceback\nZeroDivisionError: division by zero");
assert.equal(renderOutput({ stdout: "", stderr: "", result: null, error: null, notice: "[python_repl: state reset]" }), "[python_repl: state reset]");

console.log("repr.test.mjs: ok");
