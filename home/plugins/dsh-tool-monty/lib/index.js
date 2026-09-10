import z from "@deepseek-ai/schemastery";
import { defineTool } from "@deepseek-ai/dsh-tools";
import {
	CollectStreams,
	Monty,
	MontyCrashedError,
	MontyRuntimeError,
	MontySyntaxError,
	MontyTypingError,
	MountDir,
	ProtocolError,
} from "@pydantic/monty";
import { renderOutput, repr, truncateMiddle } from "./repr.js";

/**
 * Model-facing `python_repl` tool backed by a persistent Monty REPL per agent.
 *
 * One `@pydantic/monty` worker pool is created lazily for the plugin; each
 * agent that calls the tool checks out one REPL session (a dedicated worker)
 * and keeps it for the agent's lifetime, so every call builds on the
 * globals, functions and imports of the previous ones. The session is
 * closed when the agent is disposed, when the plugin unloads, when the model
 * asks for `reset`, when a call is cancelled, or when the worker crashes.
 * @module dsh-tool-monty
 */
export const name = "tool-monty";
export const inject = ["tools"];

export const Config = z.object({
	binaryPath: z.string(),
	maxMemoryBytes: z.natural().default(256 * 1024 * 1024),
	requestTimeoutSecs: z.number().default(60),
	maxDurationSecs: z.number().default(0),
	maxSessions: z.natural().default(32),
	checkoutTimeoutSecs: z.number().default(5),
	maxOutputChars: z.natural().default(20000),
	typeCheck: z.boolean().default(false),
	workspaceMount: z.union(["none", "read-only", "overlay", "read-write"]).default("read-only"),
});

const WORKSPACE_PATH = "/workspace";

const STDLIB = "asyncio, base64, collections, dataclasses, datetime, functools, itertools, json, math, os, pathlib, re, sys, typing, unicodedata";

function describe(config) {
	const workspace =
		config.workspaceMount === "none"
			? "There is no filesystem access."
			: `The session workspace is mounted at \`${WORKSPACE_PATH}\` (${config.workspaceMount}${config.workspaceMount === "overlay" ? ": writes are kept in memory and discarded after each call" : ""}); use \`pathlib.Path\` or \`open()\` on that path. No other filesystem, environment or network access exists.`;
	const timeout = config.requestTimeoutSecs > 0 ? `A call that runs longer than ${config.requestTimeoutSecs}s is killed.` : "";
	return (
		"Run Python in a persistent sandboxed REPL (Monty, a Python-subset interpreter). " +
		"Variables, functions, classes and imports PERSIST between calls in this session, so later calls build on earlier results. " +
		"Like an interactive interpreter, the value of a trailing expression is returned as `=> repr`; use `print()` for everything else. " +
		"Exceptions come back as a traceback and leave the state intact. " +
		"Python subset: NO third-party packages (no pip, numpy, pandas, requests) and only these stdlib modules: " +
		STDLIB +
		". No `match` statements, no generators (`yield`), no `input()`. Classes, dataclasses, closures, decorators, comprehensions, f-strings, try/except and async/await work. " +
		workspace +
		" " +
		timeout +
		" A crash, timeout or memory-limit hit LOSES the REPL state; the result says so explicitly, and the next call starts from an empty session. " +
		"Set `reset: true` to discard all state deliberately (code may then be empty). " +
		"Good for calculations, data transformation, parsing and JSON/regex/date work; use `bash` for anything that needs the real Python ecosystem."
	);
}

function firstLine(code) {
	const line = code.split("\n").find((part) => part.trim().length > 0) ?? "";
	return line.length > 80 ? `${line.slice(0, 77)}...` : line;
}

function isTerminalRuntimeError(err) {
	return err instanceof MontyRuntimeError && err.exception?.typeName === "MemoryError";
}

/**
 * Per-agent REPL sessions on one lazily created pool.
 * @param ctx - plugin context (for unload cleanup).
 * @param config - validated plugin config.
 */
function replSessions(ctx, config) {
	/** @type {Map<object, Promise<{ session: import('@pydantic/monty').MontySession, mount: MountDir | undefined }>>} */
	const sessions = new Map();
	const ownerCleanupInstalled = new WeakSet();
	/** @type {Promise<Monty> | undefined} */
	let pool;
	let disposed = false;

	const getPool = () => {
		if (pool === undefined) {
			pool = Monty.create({
				...(config.binaryPath === undefined ? {} : { binaryPath: config.binaryPath }),
				minProcesses: 0,
				maxProcesses: config.maxSessions,
				checkoutTimeout: config.checkoutTimeoutSecs,
				...(config.requestTimeoutSecs > 0 ? { requestTimeout: config.requestTimeoutSecs } : {}),
			}).catch((err) => {
				pool = undefined;
				throw new Error(`python_repl: could not start the Monty worker pool: ${err instanceof Error ? err.message : String(err)}`);
			});
		}
		return pool;
	};

	const openMount = (owner) => {
		if (config.workspaceMount === "none") return undefined;
		const cwd = owner.session?.header?.cwd;
		if (typeof cwd !== "string" || cwd.length === 0) return undefined;
		try {
			return new MountDir({ hostPath: cwd, virtualPath: WORKSPACE_PATH, mode: config.workspaceMount });
		} catch (err) {
			ctx.logger?.warn?.(`python_repl: workspace mount of ${cwd} failed: ${err instanceof Error ? err.message : String(err)}`);
			return undefined;
		}
	};

	const create = async (owner) => {
		const activePool = await getPool();
		if (disposed) throw new Error("python_repl: plugin disposed");
		let session;
		try {
			session = await activePool.checkout({
				scriptName: "repl.py",
				typeCheck: config.typeCheck,
				limits: {
					maxMemory: config.maxMemoryBytes,
					...(config.maxDurationSecs > 0 ? { maxDurationSecs: config.maxDurationSecs } : {}),
				},
			});
		} catch (err) {
			throw new Error(
				`python_repl: no REPL worker available (${config.maxSessions} sessions max, waited ${config.checkoutTimeoutSecs}s): ${err instanceof Error ? err.message : String(err)}`,
			);
		}
		const mount = openMount(owner);
		return { session, mount };
	};

	/** Close and forget the owner's session. Idempotent; never throws. */
	const discard = async (owner) => {
		const pending = sessions.get(owner);
		if (pending === undefined) return;
		sessions.delete(owner);
		try {
			const { session, mount } = await pending;
			mount?.close();
			await session.close();
		} catch {
			// A failed creation or an already-poisoned worker: nothing left to close.
		}
	};

	const get = (owner) => {
		const existing = sessions.get(owner);
		if (existing !== undefined) return existing;
		const created = create(owner);
		sessions.set(owner, created);
		created.catch(() => {
			if (sessions.get(owner) === created) sessions.delete(owner);
		});
		if (!ownerCleanupInstalled.has(owner)) {
			ownerCleanupInstalled.add(owner);
			owner.ctx.effect(() => () => {
				void discard(owner);
			}, "tool-monty owner session cleanup");
		}
		return created;
	};

	ctx.effect(
		() => async () => {
			disposed = true;
			await Promise.all([...sessions.keys()].map((owner) => discard(owner)));
			if (pool !== undefined) {
				try {
					await (await pool).close();
				} catch {
					// The pool never came up; nothing to close.
				}
				pool = undefined;
			}
		},
		"tool-monty pool cleanup",
	);

	return { get, discard };
}

function collect(streams, maxChars) {
	let stdout = "";
	let stderr = "";
	for (const entry of streams.output) {
		if (entry.stream === "stderr") stderr += entry.text;
		else stdout += entry.text;
	}
	return { stdout: truncateMiddle(stdout, maxChars), stderr: truncateMiddle(stderr, maxChars) };
}

function toOutput(parts) {
	return {
		stdout: parts.stdout ?? "",
		stderr: parts.stderr ?? "",
		result: parts.result ?? null,
		error: parts.error ?? null,
		stateLost: parts.stateLost ?? false,
		reset: parts.reset ?? false,
	};
}

function notice(value) {
	if (value.stateLost) return "[python_repl: the REPL state was lost; the next call starts from an empty session]";
	if (value.reset) return "[python_repl: state reset]";
	return null;
}

/**
 * Register the `python_repl` tool on `ctx.tools`.
 * @param ctx - registrant context carrying the tool registry.
 * @param config - deployment config (see {@link Config}).
 */
export function apply(ctx, config) {
	const repls = replSessions(ctx, config);
	const timeoutMs = config.requestTimeoutSecs > 0 ? Math.ceil((config.requestTimeoutSecs + 15) * 1000) : undefined;

	ctx.tools.register(
		defineTool({
			name: "python_repl",
			description: describe(config),
			parameters: {
				code: {
					type: "string",
					required: true,
					description: "Python source to execute in the persistent REPL. A trailing expression is evaluated and its repr returned. May be empty together with `reset: true`.",
				},
				reset: {
					type: "boolean",
					description: "Discard every variable, function and import of this session's REPL before running `code`. Default false.",
				},
			},
			output: {
				schema: {
					type: "object",
					additionalProperties: false,
					properties: {
						stdout: { type: "string", required: true },
						stderr: { type: "string", required: true },
						result: { oneOf: [{ type: "string" }, { type: "null" }], required: true },
						error: { oneOf: [{ type: "string" }, { type: "null" }], required: true },
						stateLost: { type: "boolean", required: true },
						reset: { type: "boolean", required: true },
					},
				},
				render: (_args, value) => [{ type: "text", text: renderOutput({ ...value, notice: notice(value) }) }],
			},
			...(timeoutMs === undefined ? {} : { timeoutMs }),
			async execute(args, exec) {
				const owner = exec.agent;
				if (!owner) throw new Error("python_repl requires an owning agent session");
				const code = args.code;
				const reset = args.reset === true;
				if (reset) await repls.discard(owner);
				if (code.trim().length === 0) {
					if (reset) return toOutput({ reset: true });
					throw new Error("invalid code: expected a non-empty string (or set `reset: true`)");
				}
				if (exec.signal.aborted) throw new Error("python_repl: cancelled before execution");

				const { session, mount } = await repls.get(owner);
				const streams = new CollectStreams();
				const onAbort = () => {
					void repls.discard(owner);
				};
				exec.signal.addEventListener("abort", onAbort, { once: true });
				try {
					const value = await session.feedRun(code, {
						printCallback: streams,
						...(mount === undefined ? {} : { mount }),
					});
					return toOutput({ ...collect(streams, config.maxOutputChars), result: repr(value), reset });
				} catch (err) {
					const captured = collect(streams, config.maxOutputChars);
					if (exec.signal.aborted) throw new Error("python_repl: cancelled; the REPL state was discarded");
					if (err instanceof MontyTypingError) {
						return toOutput({ ...captured, error: err.display(), reset });
					}
					if (err instanceof MontySyntaxError) {
						return toOutput({ ...captured, error: err.display("traceback"), reset });
					}
					if (isTerminalRuntimeError(err)) {
						await repls.discard(owner);
						return toOutput({ ...captured, error: err.display("type-msg"), stateLost: true, reset });
					}
					if (err instanceof MontyRuntimeError) {
						return toOutput({ ...captured, error: err.display("traceback"), reset });
					}
					if (err instanceof MontyCrashedError || err instanceof ProtocolError) {
						await repls.discard(owner);
						const reason = err instanceof MontyCrashedError && err.timedOut ? `timed out after ${config.requestTimeoutSecs}s` : err.message;
						return toOutput({ ...captured, error: `RuntimeError: Monty worker ${reason}`, stateLost: true, reset });
					}
					throw err;
				} finally {
					exec.signal.removeEventListener("abort", onAbort);
				}
			},
			presentCall: (args) => ({
				card: "generic",
				title: args.reset === true && args.code.trim().length === 0 ? "Reset Python REPL" : `Python REPL: ${firstLine(args.code)}`,
				kind: "execute",
				rawInput: args.code,
				content: [{ type: "text", text: `\`\`\`python\n${args.code.replace(/\n+$/, "")}\n\`\`\`` }],
			}),
			presentResult: (_args, result) => {
				const block = result.content.length === 1 ? result.content[0] : undefined;
				if (block === undefined || block.type !== "text") return undefined;
				return {
					card: "generic",
					content: [{ type: "text", text: `\`\`\`console\n${block.text.replace(/\n+$/, "")}\n\`\`\`` }],
				};
			},
		}),
	);
}
