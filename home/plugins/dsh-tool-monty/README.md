# dsh-tool-monty

A DeepSeek Harness (DSH) plugin that gives the model a `python_repl` tool:
Python code runs in a **persistent, sandboxed REPL** powered by
[pydantic/monty](https://github.com/pydantic/monty), a Python-subset
interpreter written in Rust.

## What it does

- Registers one model-facing tool, `python_repl(code, reset?)`.
- Each agent (chat session) gets its **own interpreter that lives as long as
  the agent does**. Variables, functions, classes and imports persist between
  calls, so a later call can build on earlier results — like a Jupyter kernel
  without the kernel.
- Like an interactive interpreter, the value of a trailing expression comes
  back as `=> <repr>`; `print()` output is captured; exceptions come back as
  a Python traceback and leave the state intact.
- The session workspace (the agent's `cwd`) is mounted **read-only** at
  `/workspace` inside the sandbox (configurable: `none`, `read-only`,
  `overlay`, `read-write`). Nothing else on the host is reachable: no other
  filesystem paths, no environment variables, no network, no subprocesses.
- Each call is bounded by a hard per-call timeout and a memory cap. When a
  limit fires, the worker is killed and the REPL state is lost; the result
  says so explicitly and the next call starts from an empty session.
- `reset: true` discards the state deliberately.

## Why Monty

Monty starts in microseconds, needs no container, and has no ambient access
to the machine, so the model can run small computations (arithmetic, data
reshaping, JSON/regex/date work, quick algorithm checks) without a bash round
trip and without a sandboxing service. It runs a useful **subset** of Python:

- no third-party packages (no pip, numpy, pandas, requests);
- only these stdlib modules: `asyncio base64 collections dataclasses datetime
  functools itertools json math os pathlib re sys typing unicodedata`;
- no `match` statements, no generators (`yield`), no `input()`,
  no `print(file=...)`.

Classes, dataclasses, closures, decorators, comprehensions, f-strings,
try/except and async/await all work. The tool description tells the model
these limits and points it to `bash` for anything needing the real Python
ecosystem.

## How it works

`lib/index.js` is a host-plane Cordis plugin (`inject: ['tools']`). Its
`apply` registers the tool through `defineTool` from `@deepseek-ai/dsh-tools`
into the registry's global layer, which every agent preset sees.

Interpreter state lives in `@pydantic/monty` **worker subprocesses**
(`monty subprocess`), one per agent, checked out from a lazily created pool:

- `exec.agent` (the owning agent) keys a `Map<Agent, session>`; the first
  call of an agent checks out a worker, later calls reuse it.
- `agent.ctx.effect(...)` closes the worker when the agent is disposed;
  `ctx.effect(...)` closes every worker and the pool when the plugin unloads.
- `MontyRuntimeError` / `MontySyntaxError` / `MontyTypingError` are rendered
  into the result (state survives). `MemoryError`, `MontyCrashedError`
  (crash or watchdog timeout) and `ProtocolError` discard the session and set
  `stateLost: true`. A cancelled call (`exec.signal`) discards the session
  too, since a worker mid-turn cannot be interrupted any other way.
- Return values arrive as JS (`Map` for dict, `__tuple__`-tagged arrays for
  tuples, `BigInt` for large ints, marker objects for `datetime`); `lib/repr.js`
  renders them back as Python `repr` text.

## Config

Set on the `tool-monty` row in `cordis.patch.yml` (see the comments there):

| key                   | default        | meaning                                                              |
| --------------------- | -------------- | -------------------------------------------------------------------- |
| `binaryPath`          | nix-built path | the `monty` worker executable                                        |
| `maxMemoryBytes`      | 256 MiB        | sandbox heap cap per session (a hit loses the session)               |
| `requestTimeoutSecs`  | 60             | hard per-call deadline; the worker is killed (`0` disables)          |
| `maxDurationSecs`     | 0 (off)        | Monty's cumulative execution budget; off because it never resets     |
| `maxSessions`         | 32             | cap on live workers (one per agent)                                  |
| `checkoutTimeoutSecs` | 5              | how long a call waits for a free worker when the cap is reached      |
| `maxOutputChars`      | 20000          | stdout/stderr truncation (head + tail kept)                          |
| `typeCheck`           | false          | run Monty's `ty`-based type checker on each snippet before executing |
| `workspaceMount`      | `read-only`    | `none` / `read-only` / `overlay` / `read-write` mount of the cwd     |

## Install

This repository ships the plugin through `home/deepseek-harness.nix`
(`programs.deepseek-harness.plugins`), built by `pkgs/dsh-tool-monty.nix`,
which vendors `@pydantic/monty` (+ napi addon, OpenTelemetry API deps) into
`node_modules` and bakes in the nix-built `monty` from
`pkgs/monty-runtime.nix`. A home-manager rebuild places it in the `web`
profile; the next `dsh web` start picks it up.

Standalone (DSH ≥ 0.1.1-rc.2, Node ≥ 22):

```sh
npm install                       # pulls @pydantic/monty and its platform package
# edit cordis.patch.yml: set binaryPath, or delete the key to auto-resolve
dsh plugin --profile web add <path-to-this-directory>
```

## Tests

```sh
node test/repr.test.mjs           # pure helpers, no worker needed
MONTY_BIN=$(nix build .#monty --print-out-paths)/bin/monty \
  node test/pool.smoke.mjs        # real pool: persistence, errors, mounts, timeouts
MONTY_BIN=... node test/plugin.smoke.mjs   # the plugin through a stub Cordis context
```

The smoke tests need the vendored `node_modules` (run them from the
nix-built plugin directory, with dsh's `@deepseek-ai/*` linked in as
`home/deepseek-harness.nix` does for every plugin).

## Layout

- `lib/index.js` — the plugin: config schema, tool definition, per-agent
  session cache, error mapping.
- `lib/repr.js` — pure helpers: Python-style `repr` of Monty return values,
  output truncation and rendering.
- `cordis.patch.yml` — the one bundle row with the defaults above.
- `test/` — `repr.test.mjs` (pure), `pool.smoke.mjs`, `plugin.smoke.mjs`.
