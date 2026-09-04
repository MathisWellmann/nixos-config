# nubuddy — an intelligent nushell, in the spirit of "IPython is all you need"

A proof-of-concept that ports the pattern from
[IPython is all you need](https://nathancooper.io/blog/2026-08-10-ipython-is-all-you-need)
to nushell: a shell whose history and state are visible to an LLM, which executes
shell commands through a safety-checked tool loop.

## Quickstart

Installed via this repo (`pkgs/nubuddy.nix`, wired into `home/shell.nix`): every
nushell REPL already has `ask`, and `nubuddy` is on `PATH`. Both default to the
Qwen3.8 SGLang server on desg0.

```sh
ask "what am I working on?"                 # uses your real shell history
ask "sum the two newest numbers in data.csv" --yes

# one-shot, no REPL:
nubuddy "list my files with sizes" --yes
```

Standalone, from this directory:

```sh
source ./nubuddy.nu                          # in a REPL
nu ./nubuddy-cli.nu "your prompt"            # one-shot
```

Env (any OpenAI-compatible endpoint that supports tool calls; the Nix install
sets the first three, values already present e.g. from `~/.env` win):

| Variable            | Meaning                                        | Example                          |
|---------------------|------------------------------------------------|----------------------------------|
| `NU_BUDDY_BASE_URL` | OpenAI-compatible base URL                     | `http://desg0:8000/v1`           |
| `NU_BUDDY_API_KEY`  | bearer token (any non-empty string for local servers) | `none`                    |
| `NU_BUDDY_MODEL`    | model slug                                     | `RadixArk/Qwen3.8-27B-NVFP4`     |
| `NU_BUDDY_DIR`      | where state lives (default `~/.config/nushell/nubuddy`) |                         |
| `NU_BUDDY_DEBUG`    | if set, every chat request body is dumped as `req.json` in this dir |             |

## How it maps to the blog

| Blog (IPython)                 | nubuddy (nushell)                                              |
|--------------------------------|----------------------------------------------------------------|
| `%rehashx`, `ipythonng`        | `history \| last N` — the REPL's own persisted command history |
| `build_ctx(N)` from In/Out     | recent history + the `transcript.jsonl` of what the LLM itself ran |
| `:query` input transformer     | `ask "..."` command (nushell has no input transformers)        |
| AsyncChat loop                 | `ask` def: `0..$steps \| reduce` chat loop, messages as JSON strings |
| `bash` tool + `safecmd` allowlist | `nu_exec` tool + `nubuddy-safe` deny/confirm gate            |
| `safe_python` in shared kernel | `$__S__` record: serialized before each run, read back after (NUON round-trip) |

## What the LLM can do

- `nu_exec` — run nushell code in your working directory. Errors come back as
  tool results (miette text), so the model can fix its own syntax. The mutable
  record `$__S__` persists between calls and between processes (blog "shared
  kernel" equivalent):

  ```nu
  ask "remember that my project is 'symbiont'"
  # later, even from another terminal:
  ask "what project am I working on?"
  ```

- `nu_history` — read your real nushell command history.

## Safety (the "safeish" part — advisory)

Same class as the blog's `safecmd`, stated honestly:

- **hard-blocked**: `:(` process-substitution, `plugin add`
- **asks you first**: statements starting with `rm`, `mv`, `kill`, or any
  external (`^cmd`)
- `--yes` skips confirmation (don't use it carelessly)

This is a keyword gate on statement first-tokens, not a sandbox. A determined
model (or a careless prompt) can still do things — e.g. via `save --force`,
`open --raw`, or an external that spawns a shell. Treat it as the human-in-the-loop
it is.

## State files (in `NU_BUDDY_DIR`)

- `state.json` — the persistent `$__S__` record (NUON/JSON)
- `transcript.jsonl` — last 30 LLM executions (`ts`, `script`, `out`), fed back
  into context as "your own previous executions"
- `last-run.nu` — the composed child script (state init + your script + state dump + marker)

## Design notes & gaps (vs. the blog)

- **No PTY needed**: each tool call runs a one-shot `nu <script>` child and
  captures stdout/stderr/exit code via `^nu $f | complete`. The blog's
  PTY-recorded outputs (the reason IPython feels rich) have no nushell
  equivalent: history files store *commands only*, no outputs, no images.
  The transcript file is the closest substitute.
- **One-shot child, not a live kernel**: state round-trips through a file.
  On a real terminal you could upgrade this to a `coproc` PTY session for
  true persistent-REPL semantics.
- **Script, not REPL**: bare pipeline values in `nu_exec` are not displayed, so
  the tool description tells the model to end pipelines with `| print`. Without
  that hint the model loops on empty results until the step limit.
- **Nushell gotchas this code works around** (0.114.1): no cross-scope
  reassignment of `mut` vars (so state is threaded through `reduce`, and no
  `try {}` wrapper around LLM code); only `($expr)` is interpolated in
  `$"..."` strings (bare `$var` stays literal); `source` needs a parse-time
  constant path; script args arrive via a `main` def auto-invocation;
  `history session` returns an int, not a table.

## Files

- `nubuddy.nu` — everything: `nubuddy-safe`, `nubuddy-exec`, `nubuddy-llm`, `ask`
- `nubuddy-cli.nu` — one-shot launcher (`def main` receives the script args)
- `../pkgs/nubuddy.nix` — Nix package: `bin/nubuddy` wrapper + `share/nubuddy/*.nu`
- `../home/shell.nix` — sources `nubuddy.nu` into the REPL and sets the `NU_BUDDY_*` defaults
