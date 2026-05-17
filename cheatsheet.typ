// Keybindings cheat sheet for this NixOS configuration.
// Compile with: `typst compile cheatsheet.typ` or live preview via tinymist in Helix.

#set document(title: "NixOS Keybindings Cheat Sheet", author: "Mathis Wellmann")
#set page(
  paper: "a4",
  margin: (x: 1.2cm, y: 1.4cm),
  fill: rgb("#1d2021"),
  header: align(right)[
    #text(fill: rgb("#928374"), size: 8pt)[NixOS keybindings · #datetime.today().display()]
  ],
)
#set text(font: ("JetBrains Mono", "DejaVu Sans Mono"), size: 9pt, fill: rgb("#ebdbb2"))
#set par(justify: false, leading: 0.5em)

// ---------- helpers ----------

#let accent = rgb("#fabd2f")
#let accent2 = rgb("#8ec07c")
#let accent3 = rgb("#fb4934")
#let muted = rgb("#928374")
#let panel = rgb("#282828")

#let kbd(k) = box(
  inset: (x: 5pt, y: 1pt),
  outset: (y: 2pt),
  radius: 3pt,
  fill: rgb("#3c3836"),
  stroke: 0.6pt + rgb("#504945"),
)[#text(fill: accent, weight: "bold", size: 8.5pt)[#k]]

#let combo(..keys) = {
  let parts = keys.pos()
  for (i, k) in parts.enumerate() {
    kbd(k)
    if i < parts.len() - 1 { h(2pt); text(fill: muted)[+]; h(2pt) }
  }
}

#let row(keys, desc) = (keys, text(size: 9pt)[#desc])

#let section(title, color, rows) = {
  block(
    width: 100%,
    fill: panel,
    radius: 5pt,
    inset: 8pt,
    stroke: (left: 3pt + color),
  )[
    #text(size: 11pt, weight: "bold", fill: color)[#title]
    #v(4pt)
    #table(
      columns: (auto, 1fr),
      column-gutter: 10pt,
      row-gutter: 4pt,
      stroke: none,
      align: (right + horizon, left + horizon),
      ..rows.flatten()
    )
  ]
}

// ---------- title ----------

#align(center)[
  #text(size: 22pt, weight: "bold", fill: accent)[NixOS Keybindings Cheat Sheet]
  #v(-6pt)
  #text(size: 9pt, fill: muted)[Hyprland · Helix · stochos]
]

#v(6pt)

// ---------- columns ----------

#show: rest => columns(2, gutter: 14pt, rest)

// ===== Hyprland =====

#section("Hyprland — Window Manager", accent2, (
  row(combo("Super", "Return"),  "Open terminal (ghostty)"),
  row(combo("Super", ","),       "App launcher (fuzzel)"),
  row(combo("Super", "Q"),       "Kill active window"),
  row(combo("Super", "J"),       "Exit Hyprland"),
  row(combo("Super", "V"),       "Toggle floating"),
  row(combo("Super", "F"),       "Toggle fullscreen"),
  row(combo("Super", "P"),       "Pseudo tile"),
  row(combo("Super", "S"),       "Toggle split direction"),
  row(combo("Super", "L"),       [Launch #raw("stochos")]),
))

#v(6pt)

#section("Hyprland — Focus (RSTHD layout)", accent2, (
  row(combo("Super", "M"), "Focus left"),
  row(combo("Super", "I"), "Focus right"),
  row(combo("Super", "N"), "Focus up"),
  row(combo("Super", "A"), "Focus down"),
  row(combo("Super", "←/→/↑/↓"), "Focus by arrow keys"),
))

#v(6pt)

#section("Hyprland — Workspaces & Mouse", accent2, (
  row(combo("Super", "1-9"),  "Switch to workspace 1–9"),
  row(combo("Super", "0"),    "Switch to workspace 10"),
  row(combo("Super", "LMB"),  "Move window (drag)"),
  row(combo("Super", "RMB"),  "Resize window (drag)"),
))

#v(6pt)

// ===== Helix =====

#section("Helix — Custom Normal-mode Keys", accent, (
  row(kbd("f"), "Open file picker"),
  row(kbd("a"), "Move character left"),
  row(kbd("}"), "Move character right"),
))

#v(6pt)

#section("Helix — Essentials (built-in)", accent, (
  row(kbd("i") + h(2pt) + kbd("a"),           "Insert before / after cursor"),
  row(kbd("o") + h(2pt) + kbd("O"),           "Open line below / above"),
  row(kbd("Esc"),                              "Return to normal mode"),
  row(kbd("x"),                                "Select line, extend down"),
  row(kbd("d") + h(2pt) + kbd("y"),           "Delete / yank selection"),
  row(kbd("p") + h(2pt) + kbd("P"),           "Paste after / before"),
  row(kbd("u") + h(2pt) + combo("Ctrl","r"),  "Undo / redo"),
  row(kbd(":w") + h(2pt) + kbd(":q"),         "Write / quit"),
  row(kbd("/") + h(2pt) + kbd("n"),           "Search / next match"),
  row(kbd("gd"),                               "Goto definition"),
  row(kbd("gr"),                               "Goto references"),
  row(kbd("space f"),                          "File picker"),
  row(kbd("space ?"),                          "Command palette"),
  row(kbd("space k"),                          "Hover docs"),
  row(kbd("space r"),                          "Rename symbol"),
  row(kbd("space a"),                          "Code actions"),
))

#v(6pt)

// ===== stochos =====

#block(
  width: 100%,
  fill: panel,
  radius: 5pt,
  inset: 8pt,
  stroke: (left: 3pt + accent3),
)[
  #text(size: 11pt, weight: "bold", fill: accent3)[stochos — Usage (Super_L)]
  #v(2pt)
  #text(size: 8.5pt)[
    + Trigger the overlay
    + Type *two letters* to select a grid cell (e.g. #kbd("a") then #kbd("s"))
    + Type *one more letter* to refine within the sub-grid
    + Perform an action below
  ]
]

#v(6pt)

#section("stochos — Default Keys", accent3, (
  row(kbd("Space"),     "Click"),
  row(kbd("Enter"),     "Double click"),
  row(kbd("Delete"),    "Right click"),
  row(kbd("Escape"),    "Close overlay"),
  row(kbd("Backspace"), "Undo last step"),
  row(kbd("↑ ↓ ← →"),   "Scroll (up/down/left/right)"),
  row(kbd("/"),         "Start drag (select end point, then Space)"),
  row(kbd("`"),         "Toggle macro recording"),
  row(kbd("@"),         "Replay macro by bind key"),
  row(kbd("Tab"),       "Search macros / quick-save position"),
  row(kbd("b"),         "Switch to bisect mode"),
  row(kbd("n"),         "Switch back to normal mode (from bisect)"),
  row(kbd("v"),         "Switch to free mode"),
))

#v(6pt)

#section("stochos — Free Mode", accent3, (
  row(kbd("h") + h(2pt) + kbd("j") + h(2pt) + kbd("k") + h(2pt) + kbd("l"), "Move cursor ← ↓ ↑ →"),
  row(kbd("="),     "Increase speed"),
  row(kbd("-"),     "Decrease speed"),
  row(kbd("Space"), "Click & exit"),
  row(kbd("Enter"), "Double click & exit"),
  row(kbd("Delete"),"Right click & exit"),
))
