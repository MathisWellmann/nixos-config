/**
 * Pure helpers: render the JS values `@pydantic/monty` hands back from a
 * feed as Python-flavoured `repr()` text, and combine the pieces of one call
 * into the model-facing text. Kept dependency-free so `test/repr.test.mjs`
 * can exercise them without a worker pool.
 * @module dsh-tool-monty/repr
 */

/** Python `repr()` of a string: single quotes unless the text has one and no double quote. */
function reprString(text) {
	const quote = text.includes("'") && !text.includes('"') ? '"' : "'";
	let out = quote;
	for (const ch of text) {
		if (ch === "\\") out += "\\\\";
		else if (ch === quote) out += "\\" + quote;
		else if (ch === "\n") out += "\\n";
		else if (ch === "\r") out += "\\r";
		else if (ch === "\t") out += "\\t";
		else out += ch;
	}
	return out + quote;
}

function reprNumber(value) {
	if (Number.isInteger(value)) return String(value);
	if (Number.isNaN(value)) return "nan";
	if (value === Infinity) return "inf";
	if (value === -Infinity) return "-inf";
	const text = String(value);
	return /e/.test(text) || text.includes(".") ? text : `${text}.0`;
}

function pad2(n) {
	return String(n).padStart(2, "0");
}

function reprMarker(value, depth) {
	switch (value.__monty_type__) {
		case "Date":
			return `datetime.date(${value.year}, ${value.month}, ${value.day})`;
		case "DateTime": {
			const parts = [value.year, value.month, value.day, value.hour, value.minute];
			if (value.second || value.microsecond) parts.push(value.second);
			if (value.microsecond) parts.push(value.microsecond);
			return `datetime.datetime(${parts.join(", ")})`;
		}
		case "Time":
			return `datetime.time(${value.hour}, ${value.minute}${value.second ? `, ${value.second}` : ""})`;
		case "TimeDelta":
			return `datetime.timedelta(days=${value.days}, seconds=${value.seconds}, microseconds=${value.microseconds})`;
		case "TimeZone":
			return `datetime.timezone(${value.offsetSeconds}s${value.name ? `, ${reprString(value.name)}` : ""})`;
		case "Exception":
			return `${value.excType}(${reprString(value.message)})`;
		case "Type":
			return `<class '${value.classType?.name ?? "object"}'>`;
		case "ClassInstance":
			return `<${value.name ?? "object"} instance>`;
		default:
			return reprObject(value, depth);
	}
}

function reprObject(value, depth) {
	const entries = Object.entries(value);
	return `{${entries.map(([k, v]) => `${reprString(k)}: ${repr(v, depth + 1)}`).join(", ")}}`;
}

/** Sandbox class instances arrive as read-only proxies (`name`, `attributes`, `isDataclass`). */
function isClassProxy(value) {
	return (
		typeof value === "object" &&
		value !== null &&
		typeof value.name === "string" &&
		typeof value.attributes === "object" &&
		value.attributes !== null &&
		typeof value.isDataclass === "boolean"
	);
}

const MAX_DEPTH = 8;

/**
 * Python-style repr of a converted Monty value.
 * @param {unknown} value - a value returned by `session.feedRun`.
 * @param {number} [depth] - current nesting (internal).
 * @returns {string} the repr text.
 */
export function repr(value, depth = 0) {
	if (depth > MAX_DEPTH) return "...";
	if (value === null || value === undefined) return "None";
	if (value === true) return "True";
	if (value === false) return "False";
	if (typeof value === "number") return reprNumber(value);
	if (typeof value === "bigint") return value.toString();
	if (typeof value === "string") return reprString(value);
	if (typeof Buffer !== "undefined" && Buffer.isBuffer(value)) return `b${reprString(value.toString("latin1"))}`;
	if (value instanceof Uint8Array) return `b${reprString(Buffer.from(value).toString("latin1"))}`;
	if (Array.isArray(value)) {
		const items = value.map((item) => repr(item, depth + 1));
		if (value.__tuple__ === true) return `(${items.join(", ")}${items.length === 1 ? "," : ""})`;
		return `[${items.join(", ")}]`;
	}
	if (value instanceof Map) {
		if (value.size === 0) return "{}";
		return `{${[...value].map(([k, v]) => `${repr(k, depth + 1)}: ${repr(v, depth + 1)}`).join(", ")}}`;
	}
	if (value instanceof Set) {
		if (value.size === 0) return "set()";
		return `{${[...value].map((item) => repr(item, depth + 1)).join(", ")}}`;
	}
	if (typeof value === "object") {
		if (typeof value.__monty_type__ === "string") return reprMarker(value, depth);
		if (isClassProxy(value)) {
			const fields = Object.entries(value.attributes).map(([k, v]) => `${k}=${repr(v, depth + 1)}`);
			return `${value.name}(${fields.join(", ")})`;
		}
		return reprObject(value, depth);
	}
	return String(value);
}

/**
 * Cut `text` to at most `max` characters, keeping the head and tail with a
 * marker in between so the model sees both the start and the end.
 * @param {string} text
 * @param {number} max
 * @returns {string}
 */
export function truncateMiddle(text, max) {
	if (text.length <= max) return text;
	const marker = `\n... [${text.length - max} chars truncated] ...\n`;
	const keep = Math.max(0, max - marker.length);
	const head = Math.ceil(keep * 0.7);
	const tail = keep - head;
	return text.slice(0, head) + marker + (tail > 0 ? text.slice(-tail) : "");
}

/**
 * Join the pieces of one REPL call into the text the model reads.
 * @param {{ stdout: string, stderr: string, result: string | null, error: string | null, notice: string | null }} parts
 * @returns {string}
 */
export function renderOutput(parts) {
	const sections = [];
	if (parts.stdout) sections.push(parts.stdout.replace(/\n$/, ""));
	if (parts.stderr) sections.push(`[stderr]\n${parts.stderr.replace(/\n$/, "")}`);
	if (parts.result !== null && parts.result !== "None") sections.push(`=> ${parts.result}`);
	if (parts.error) sections.push(parts.error.replace(/\n$/, ""));
	if (parts.notice) sections.push(parts.notice);
	return sections.length === 0 ? "(no output)" : sections.join("\n");
}
