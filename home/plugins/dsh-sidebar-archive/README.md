# dsh-sidebar-archive

A DeepSeek Harness (DSH) Web UI plugin: a one-click **archive (×)** button on
every chat row in the sidebar, next to the existing ⋯ row menu — so clearing
out finished sessions no longer needs the three-dots detour.

## What it does

- Hovering a session row reveals `⋯ ×` in the row's action area (the × sits to
  the right of the menu button, in the same 16px icon style).
- Clicking × commits the **same `workspace.archiveSession` action** the menu's
  "Archive session" entry performs: non-destructive — the session log and the
  workspace accounting slot remain; the row disappears from every grouping
  surface (workspace groups, Ungrouped, search, flat list) as soon as the
  host's archive-set echo lands.
- The button holds itself in a pending state while the RPC is in flight (no
  double-submits) and re-enables on a rejected archive (console diagnostic).

There is deliberately no confirmation dialog: that matches the existing menu
behavior (archive commits without a dialog and is non-destructive).

## How it works

The session rows are rendered inside `dsh-client-ui-workspace` and declare no
slot for per-row affordances, so a third-party plugin cannot slot-register
into a row. This plugin therefore:

1. injects the `sessions` and `workspaces` browser services,
2. observes the sidebar DOM (MutationObserver over `document.body`),
3. decorates each rendered session row with its × button, and
4. resolves a row to a session id against the same stores the browser UI
   reads (`sessions.list` / `workspaces.list`): exact display-title match,
   scoped by the row's workspace group, then by the visible relative-time
   bucket. **When a row cannot be resolved unambiguously, no button is
   shown** — the plugin never guesses which session to archive.

Every lookup is guarded, so a UI generation that drops the expected classes
degrades to "no buttons", never to a broken sidebar.

## Pinning

Built and tested against the **0.1.0-rc.6** Web UI generation (the
`dsh-client-ui-workspace` row markup and CSS-module class names of that
release). If a future DSH release changes the sidebar DOM, the plugin simply
stops adding buttons; update the selectors in `lib/client.js`
(`ROW_SEL` and friends) to re-target it.

## Install

This repository ships the plugin through `home/deepseek-harness.nix`
(`programs.deepseek-harness.plugins`); a home-manager rebuild places it in
the `web` profile and the next `dsh web` start picks it up.

Standalone (any DSH ≥ 0.1.0-rc.6):

```sh
dsh plugin --profile web add <path-to-this-directory>
```

## Uninstall

`dsh plugin --profile web remove dsh-sidebar-archive` (or drop the entry from
the profile's `package.json` / `dsh.profile.bundles` and restart).

## Layout

- `lib/index.js` — host half: no-op (the tree row needs a resolvable module;
  there is no host-side capability behind the button).
- `lib/client.js` — browser half: the `__ModuleLoader__` factory with the
  DOM decoration and the row→session resolver.
- `test/resolve.test.mjs` — node harness for the pure resolver
  (`node test/resolve.test.mjs`).
