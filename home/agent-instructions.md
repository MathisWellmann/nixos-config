# Global agent instructions

These rules apply to every project unless the project's own `AGENTS.md`,
`CONTRIBUTING.md` or CI config says otherwise. Project rules win. Every rule
has a reason. If a rule really cannot be followed, say why in the change
description.

## Version control: jj (Jujutsu)

- Use `jj`, not `git`, for history. Repos are colocated, so `git` still works
  for reading. Do not use `git commit`, `git rebase`, `git stash` or
  `git checkout`, because they fight with jj's working-copy commit.
- One logical change per revision. Start with `jj new`, set the message with
  `jj describe -m "<scope>: <what and why>"`, and split mixed work with
  `jj split` or `jj squash --from X --into Y <paths>`.
- Every revision must pass CI by itself (see "Checks" below). A clean history
  lets `jj bisect`, reverts and reviews work on any revision.
- Run `jj new` alone, not in the same batch as file edits. Otherwise an edit
  can land in the old revision.
- Do not push, move bookmarks, or rewrite revisions you did not create unless
  the user asks. Never skip hooks.
- Keep a revision under ~500 changed lines when you can, so it can be
  reviewed in about 15 minutes. Do not split related work into tiny
  revisions (<100 lines) without a reason.

## Checks: every revision is clean

Before you finish a revision, run what CI runs. Read the CI config first
(`.forgejo/workflows/`, `.github/workflows/`, `flake.nix` `checks`,
`treefmt.nix`) and run the same commands. Use the same environment as CI:
`nix develop .#ci --command ...` if that shell exists, else `nix develop`.
If the project has `nix fmt` (treefmt), run it too.

If there is no CI config, use these defaults for the file types you changed:

| Files     | Format                  | Lint / check                                              |
|-----------|-------------------------|-----------------------------------------------------------|
| `*.rs`    | `cargo fmt`             | `RUSTFLAGS="-D warnings" cargo clippy --workspace --all-targets` |
| `*.rs`    |                         | `cargo nextest run --workspace` (or `cargo test`), plus `cargo test --doc` |
| `Cargo.*` | `taplo fmt`             | `cargo metadata --locked --no-deps --format-version 1 >/dev/null` |
| `*.toml`  | `taplo fmt`             | `taplo fmt --check`                                       |
| `*.nix`   | `alejandra .`           | `statix check`, `deadnix -f`, `nix flake check`           |
| `*.yml`   | `yamlfmt .`             | `yamlfmt -lint .`, `actionlint` for workflow files        |
| `*.sh`    |                         | `shellcheck`                                              |

- Fix all warnings. CI builds with `-D warnings`, so a warning is an error.
- Do not silence a lint to make it pass. If an `#[allow(...)]` is really
  needed, add `reason = "..."`. The `allow_attributes_without_reason` lint
  denies it without one.
- Formatter output that touches files you did not change goes in its own
  revision, not mixed into your change.
- If a check cannot run (missing tool, no network, no GPU), say so. Do not
  claim it passed.

## Rust

### Visibility and API shape

- Use the smallest visibility that works: private > `pub(super)` >
  `pub(crate)` > `pub`. Small visibility makes dead code visible to the
  compiler (`dead_code`, `unreachable_pub`) and keeps invariants local.
- No `pub` struct fields unless the type is plain data with no invariants.
  Use a constructor (`new`, `TryFrom`, `typed_builder`) that checks the
  invariants, and getters (`getset`) for reads. Also avoid `pub(crate)` fields
  (`field_scoped_visibility_modifiers`): scoped fields need the whole crate
  to be checked to prove an invariant.
- No `pub` functions or methods unless another crate calls them.
- Add a `///` doc comment to every `pub` item (`missing_docs`).
- Put `#[must_use]` on types and functions whose result must not be
  dropped.
- Use newtypes (`struct OrderId(u64);`) so IDs and units cannot be mixed up,
  and to enforce invariants. If a newtype is too much, use a type alias
  (`type AgentIndex = usize;`) for readability.
- Derive `Eq` when `PartialEq` is derived and all fields allow it.

### Errors and panics

- Never `.unwrap()` outside tests (`unwrap_used` is denied). Use
  `.expect("why this cannot fail")`, so the invariant is written down.
- If you cannot prove the `expect` always holds, handle it:
  `let Some(v) = opt else { ... };` or return an error (`thiserror` for
  libraries, `anyhow` for binaries).
- `From` impls must not panic. Use `TryFrom` when the conversion can fail.
- No `as` casts that can wrap or lose data (`cast_possible_wrap`,
  `as_underscore`). Use `TryFrom`/`try_into()` with a clear error.

### Assertions

Assertions find programmer errors. The only safe reaction to corrupt state is
to crash, which turns a correctness bug into a liveness bug.

- Assert arguments, return values, preconditions, postconditions and
  invariants. Aim for at least two assertions per function.
- Assert the positive space (what you expect) AND the negative space (what
  you do not expect). Bugs are found where data crosses that boundary.
- Split compound assertions: `assert!(a); assert!(b);`, not `assert!(a && b)`.
  The failure message is then exact.
- Assert an implication with a one-line `if`: `if a { assert!(b) }`.
- No side effects in `debug_assert!` (`debug_assert_with_mut_call`): they
  are removed in release builds.
- Tests must cover invalid input and the edge where valid data becomes
  invalid, not only the happy path.

### Function structure

- Keep function bodies under ~70 lines (clippy `too_many_lines` is set to
  100 as the hard limit). Long functions hide structure.
- Few parameters, a simple return type, the logic in the body. No more than
  one `bool` parameter (`fn_params_excessive_bools`); use an enum.
- Push `if`s up and `for`s down: keep all control flow in the parent
  function. Helpers do non-branching work.
- Keep state changes in the parent. Helpers compute what must change and
  return it; the parent applies it. Leaf functions stay pure.
- Take `&mut` only when the function mutates (`needless_pass_by_ref_mut`).

### New Rust projects

Start with the same lint setup as `~/MathisWellmann/nexus`: its
`[workspace.lints]` in `Cargo.toml` (with `[lints] workspace = true` in each
crate), `clippy.toml`, `rustfmt.toml` (`group_imports = "StdExternalCrate"`,
`imports_granularity = "Crate"`, `imports_layout = "Vertical"`, needs
nightly rustfmt) and `taplo.toml` (`reorder_keys`, `reorder_arrays`).

### Preferred crates and patterns

- PRNG: use `romu` (`romu::Rng` / `romu::RngWide`), not `rand`'s generators.
  It is much faster and has a small state. Seed it explicitly
  (`Rng::from_seed_with_64bit(seed)`) so runs are reproducible.
  For this reason `clippy.toml` lists `Rng::new()` in `disallowed-methods`.
  Use `rand` / `rand_distr` only for distributions, through romu's `rand`
  feature.
- Time: use `minstant::Instant`, not `std::time::Instant`. `minstant` reads
  the TSC and is much faster. For this reason `clippy.toml` lists
  `std::time::Instant` in `disallowed-methods`.
- Channels: always bounded (`crossfire`, or `tokio::sync::mpsc::channel(n)`).
  Unbounded channels hide backpressure and grow memory without limit.
  `clippy.toml` lists `kanal::unbounded` in `disallowed-methods`.
- Shared state: avoid `Arc<Mutex<_>>` for interior mutability (about 25 us per
  contended lock). Prefer, in order of fit:
  - channels for many-producer / single-consumer message passing,
  - ring buffers for single-producer / single-consumer,
  - atomics with an explicit, minimal `Ordering` for simple state,
  - `parking_lot::RwLock` when reads far outnumber writes.
  Never `Rc<Mutex<_>>` (`rc_mutex`).
- Floats: use `f64` in CPU numeric/feature pipelines. `f32` causes bad
  anomalies (for example in z-score normalization). Use lower precision only
  on normalized ranges or on the GPU, after checking correctness.
- Strings: append with `write!(s, ...)`, not `s.push_str(&format!(...))`
  (`format_push_string`, `format_collect`).
- Iterators: `find_map` over `filter_map().next()`, `filter_map` over
  `flat_map` on `Option`, no `collect()` just to iterate again
  (`needless_collect`), `.clear()` over `.drain(..)`.
- Async: prefer `async |x| {}` closures over closures that return an
  `async` block.
- Imports: import macros with `use` (`use tracing::info;`), never
  `#[macro_use] extern crate`. Only ASCII identifiers.

### Performance

- Think about performance in the design, before there is code to profile.
  That is where the 1000x wins are.
- Optimize the slowest resource first: network, then disk, then memory, then
  CPU, weighted by how often each is used.
- Batch network, disk, memory and CPU access to amortize the cost.
- Be explicit. Extract hot loops into standalone functions with primitive
  arguments (no `self`), so the compiler does not have to prove that fields
  can stay in registers, and readers can see redundant work.

## Dependencies (Cargo)

- A dependency used by two or more crates goes in the root
  `[workspace.dependencies]`. Crates use `dep.workspace = true`.
- Order a crate's `[dependencies]` in groups, with a comment per group:
  1. local workspace crates (`path = "../x"`),
  2. `*.workspace = true` dependencies,
  3. dependencies used only by this crate,
  4. optional dependencies.
- Pin git dependencies with `rev = "<sha>"`. An unpinned git dependency moves
  with the default branch on every re-resolve.
- Check that a crate is already in the workspace before you add a new one.
  Prefer the existing choice (for example `crossfire` over `flume`/`kanal`).

## Nix

- Every system dependency needed to build or test goes in `flake.nix`
  (dev shell and CI shell), so "works on my machine" means it works in CI.
- Keep `.nix` files clean for `alejandra`, `statix` and `deadnix`: no unused
  bindings or arguments, no legacy `let` / `with` anti-patterns.

## Writing

- Always say why: in comments, revision descriptions and answers. The reason
  lets the reader judge the decision.
- Comments explain why, not what the code already says.
- Report negative results and failed approaches too, with what was learned.
- Further reading: [NASA Power of Ten](https://spinroot.com/gerard/pdf/P10.pdf),
  [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md).
